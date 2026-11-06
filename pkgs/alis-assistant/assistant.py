#!/usr/bin/env python3
"""
ALIS Assistant for ALIS OS: "Hey ALIS" on every PC and laptop.

Uses NEST's real voice pipeline, the same as the dashboards and the phone app
(see alis-assistant/README.md, "Architecture correction"):

  mic --(16 kHz PCM)--> NEST /api/wake/ws   "Hey ALIS" heard  (openWakeWord, hey_alis model)
      record until quiet --> NEST /api/stt   speech -> text   (Whisper)
      text --> NEST /api/brain               the shared brain (house, timers, web questions)
      speech --> NEST /api/tts --> speakers                   (Piper)

The brain hands back device actions (open an app, volume, media...) that this
PC carries out itself. A few PC-only things the brain doesn't know yet
(screenshots, locking, folders, web search) are handled here first.

Mute is a hard off: the microphone isn't opened at all while muted.

Controls (also on the orb's buttons): a tiny web server on 127.0.0.1 only.
  POST /api/talk          start listening now (no wake word needed)
  POST /api/stop          stop talking / end the conversation
  POST /api/mute | /api/unmute | /api/toggle-mute
  GET  /api/status        JSON state
  GET  /  and  /events    the browser orb page (kiosks/tests) and its live state feed
The PC overlay (alis-ui.qml: orb in the top-right corner, Mic/Stop by the
dock) polls /api/status.

Python standard library only, like NEST. Settings come from the environment
(set by ALIS OS, see modules/assistant.nix).
"""
import base64
import difflib
import glob
import io
import json
import os
import queue
import re
import shlex
import socket
import ssl
import struct
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
ENV = os.environ.get

NEST_URLS = [u.rstrip("/") for u in ENV("ALIS_NEST_URLS", "http://192.168.1.235:8080").split() if u]
DEVICE = ENV("ALIS_DEVICE") or socket.gethostname()
PORT = int(ENV("ALIS_ASSISTANT_PORT", "47100"))
START_MUTED = ENV("ALIS_START_MUTED", "0") == "1"
DRY_RUN = ENV("ALIS_DRY_RUN", "0") == "1"      # tests: print actions instead of doing them
AUDIO_CMD = shlex.split(ENV("ALIS_AUDIO_CMD",
                            "parec --rate=16000 --channels=1 --format=s16le --raw --latency-msec=40"))
PLAY_CMD = shlex.split(ENV("ALIS_PLAY_CMD", "paplay"))
HOME = os.path.expanduser("~")

RATE, FRAME = 16000, 1280                 # 80 ms frames, what openWakeWord expects
FRAME_BYTES = FRAME * 2
MAX_LISTEN_S, NO_SPEECH_S, END_SILENCE_S = 10.0, 4.0, 1.1   # false "Hey ALIS"? gone after 4 s of silence
PREROLL_FRAMES = 13            # keep ~1 s of sound before the wake word fires, so "Hey ALIS, lights on" in one breath works
CAPS = ["open_app", "phone_media", "phone_volume", "brightness", "wifi", "bluetooth"]


def log(*a):
    print("alis-assistant:", *a, flush=True)


# ---------------------------------------------------------------- state + orb feed
class State:
    def __init__(self):
        self.lock = threading.Lock()
        self.state, self.level, self.caption, self.heard = "idle", 0.0, "", ""
        self.muted = START_MUTED
        self.listeners = []

    def snapshot(self):
        return {"state": self.state, "level": round(self.level, 3), "caption": self.caption,
                "heard": self.heard, "muted": self.muted}

    def set(self, **kw):
        with self.lock:
            for k, v in kw.items():
                setattr(self, k, v)
            snap = self.snapshot()
            for q in list(self.listeners):
                try:
                    q.put_nowait(snap)
                except queue.Full:
                    pass


S = State()


# ---------------------------------------------------------------- talking to NEST
_base = {"url": None, "at": 0.0}


def nest():
    """First NEST address that answers (home network first, then Tailscale on laptops)."""
    if _base["url"] and time.time() - _base["at"] < 60:
        return _base["url"]
    for u in NEST_URLS:
        try:
            urllib.request.urlopen(u + "/api/health", timeout=3).read()
            _base.update(url=u, at=time.time())
            return u
        except Exception:  # noqa
            continue
    _base.update(url=None, at=0.0)
    return None


def nest_post(path, data, ctype="application/json", timeout=30, raw=False):
    base = nest()
    if not base:
        raise ConnectionError("NEST isn't answering")
    body = data if isinstance(data, bytes) else json.dumps(data).encode()
    req = urllib.request.Request(base + path, data=body, method="POST",
                                 headers={"Content-Type": ctype, "User-Agent": f"alis-os-assistant/{DEVICE}"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        out = r.read()
    return out if raw else json.loads(out or b"{}")


class WakeSocket:
    """Minimal WebSocket client (RFC 6455) for NEST's /api/wake/ws: we send binary
    PCM frames, NEST sends {"detected": "hey_alis"} back."""

    def __init__(self, url):
        u = urllib.parse.urlparse(url + "/api/wake/ws")
        port = u.port or (443 if u.scheme == "https" else 80)
        raw = socket.create_connection((u.hostname, port), timeout=10)
        self.sock = ssl.create_default_context().wrap_socket(raw, server_hostname=u.hostname) \
            if u.scheme == "https" else raw
        key = base64.b64encode(os.urandom(16)).decode()
        self.sock.sendall((f"GET {u.path} HTTP/1.1\r\nHost: {u.hostname}:{port}\r\nUpgrade: websocket\r\n"
                           f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n"
                           f"User-Agent: alis-os-assistant/{DEVICE}\r\n\r\n").encode())
        head = b""
        while b"\r\n\r\n" not in head:
            chunk = self.sock.recv(1024)
            if not chunk:
                raise ConnectionError("wake socket closed during handshake")
            head += chunk
        if b" 101 " not in head.split(b"\r\n", 1)[0]:
            raise ConnectionError("wake socket refused: " + head.split(b"\r\n", 1)[0].decode(errors="replace"))
        self.buf = head.split(b"\r\n\r\n", 1)[1]
        self.sock.settimeout(1.0)     # wake up every second to notice mute / closing
        self.closed = False
        self.wlock = threading.Lock()

    def send(self, payload, opcode=0x2):
        mask = os.urandom(4)
        n = len(payload)
        hdr = bytes([0x80 | opcode])
        hdr += bytes([0x80 | n]) if n < 126 else (bytes([0x80 | 126]) + struct.pack(">H", n) if n < 65536
                                                  else bytes([0x80 | 127]) + struct.pack(">Q", n))
        data = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        with self.wlock:
            self.sock.sendall(hdr + mask + data)

    def _read(self, n):
        while len(self.buf) < n:
            if self.closed or S.muted:
                raise ConnectionError("wake socket closed")
            try:
                chunk = self.sock.recv(4096)
            except socket.timeout:
                continue
            if not chunk:
                raise ConnectionError("wake socket closed")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def recv(self):
        b1, b2 = self._read(2)
        n = b2 & 0x7F
        if n == 126:
            n = struct.unpack(">H", self._read(2))[0]
        elif n == 127:
            n = struct.unpack(">Q", self._read(8))[0]
        mask = self._read(4) if b2 & 0x80 else None
        data = self._read(n)
        if mask:
            data = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
        return b1 & 0x0F, data

    def close(self):
        self.closed = True
        for fn in (lambda: self.sock.shutdown(socket.SHUT_RDWR), self.sock.close):
            try:
                fn()
            except Exception:  # noqa
                pass


# ---------------------------------------------------------------- audio helpers
def rms(pcm):
    n = len(pcm) // 2
    if not n:
        return 0.0
    s = struct.unpack(f"<{n}h", pcm[:n * 2])
    return (sum(x * x for x in s) / n) ** 0.5 / 32768.0


def to_wav(pcm):
    b = io.BytesIO()
    with wave.open(b, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm)
    return b.getvalue()


def wav_levels(wav, step_s=0.05):
    """Loudness every 50 ms of a WAV, so the orb pulses with her real voice."""
    try:
        with wave.open(io.BytesIO(wav)) as w:
            rate, width, ch = w.getframerate(), w.getsampwidth(), w.getnchannels()
            pcm = w.readframes(w.getnframes())
    except Exception:  # noqa
        return []
    if width != 2:
        return []
    step = int(rate * step_s) * 2 * ch
    lv = [rms(pcm[i:i + step]) for i in range(0, len(pcm), step)]
    peak = max(lv or [0]) or 1.0
    return [min(1.0, x / peak) for x in lv]


# ---------------------------------------------------------------- the assistant
class Assistant:
    def __init__(self):
        self.frames = queue.Queue(maxsize=200)   # mic frames for the current listen
        self.listening = threading.Event()
        self.trigger = threading.Event()
        self.cancel = threading.Event()
        self.player = None
        self.mic = None
        self.mic_lock = threading.Lock()
        self.ws = None
        self.session = None
        self.idle_since = time.time()
        self.noise = 0.003          # the room's quiet level (raw mic, no automatic boost)
        self.preroll = []           # the last ~1 s of sound while idle

    # -- microphone (hard off while muted) --------------------------------
    def mic_loop(self):
        while True:
            if S.muted:
                time.sleep(0.2)
                continue
            try:
                with self.mic_lock:
                    self.mic = subprocess.Popen(AUDIO_CMD, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
                while not S.muted:
                    pcm = self.mic.stdout.read(FRAME_BYTES)
                    if not pcm or len(pcm) < FRAME_BYTES:
                        break
                    if self.listening.is_set():
                        try:
                            self.frames.put_nowait(pcm)
                        except queue.Full:
                            pass
                    elif S.state == "idle":
                        # Learn the room's quiet level from its quietest moments: falls fast,
                        # rises very slowly, so talking (or "Hey ALIS" itself) doesn't raise it.
                        r = rms(pcm)
                        self.noise = 0.8 * self.noise + 0.2 * r if r < self.noise else 0.998 * self.noise + 0.002 * r
                        self.preroll = (self.preroll + [pcm])[-PREROLL_FRAMES:]
                        ws = self.ws
                        if ws:
                            try:
                                ws.send(pcm)
                            except Exception:  # noqa
                                self.ws = None
            except FileNotFoundError:
                log("no microphone tool found:", AUDIO_CMD[0])
                time.sleep(10)
            except Exception as e:  # noqa
                log("microphone:", e)
            finally:
                self.stop_mic()
            if not S.muted:
                time.sleep(1)   # mic unplugged / ended: try again shortly

    def stop_mic(self):
        with self.mic_lock:
            if self.mic and self.mic.poll() is None:
                self.mic.terminate()
                try:
                    self.mic.wait(2)
                except Exception:  # noqa
                    self.mic.kill()
            self.mic = None

    # -- "Hey ALIS" via NEST ------------------------------------------------
    def wake_loop(self):
        wait = 2
        while True:
            if S.muted:
                time.sleep(0.5)
                continue
            base = nest()
            if not base:
                time.sleep(min(wait, 30))
                wait = min(wait * 2, 30)
                continue
            try:
                ws = WakeSocket(base)
                self.ws, wait = ws, 2
                log("listening for 'Hey ALIS' via", base)
                while not S.muted:
                    op, data = ws.recv()
                    if op == 0x8:
                        break
                    if op == 0x9:
                        ws.send(data, opcode=0xA)
                    elif op == 0x1:
                        msg = json.loads(data or b"{}")
                        if msg.get("detected") and S.state == "idle" and not S.muted:
                            log("heard:", msg["detected"])
                            self.trigger.set()
                        elif msg.get("error"):
                            log("wake word service:", msg["error"])
                            break
            except Exception as e:  # noqa
                log("wake connection:", e)
            finally:
                if self.ws:
                    self.ws.close()
                self.ws = None
            time.sleep(min(wait, 30))
            wait = min(wait * 2, 30)

    # -- one conversation ---------------------------------------------------
    def listen(self, preroll=True):
        """Record until she's been spoken to and it's gone quiet again.

        Raw laptop mics are much quieter than a browser's boosted mic, so "speech" means
        clearly louder than this room's own quiet level, not a fixed number."""
        while not self.frames.empty():
            self.frames.get_nowait()
        got = list(self.preroll) if preroll else []   # the start of a one-breath command
        self.preroll = []
        self.listening.set()
        S.set(state="listening", caption="", heard="")
        spoke, quiet, t0, peak = False, 0.0, time.time(), 0.0
        thresh = max(0.004, self.noise * 3.0)
        try:
            while time.time() - t0 < MAX_LISTEN_S and not self.cancel.is_set():
                try:
                    pcm = self.frames.get(timeout=0.5)
                except queue.Empty:
                    if S.muted:
                        break
                    continue
                got.append(pcm)
                r = rms(pcm)
                peak = max(peak, r)
                S.set(level=min(1.0, r / (thresh * 4)))
                if r > thresh:
                    spoke, quiet = True, 0.0
                elif spoke:
                    quiet += FRAME / RATE
                    if quiet >= END_SILENCE_S:
                        break
                if not spoke and time.time() - t0 > NO_SPEECH_S:
                    break
        finally:
            self.listening.clear()
            S.set(level=0.0)
        log(f"listen: room={self.noise:.4f} threshold={thresh:.4f} loudest={peak:.4f} "
            f"spoke={spoke} {time.time() - t0:.1f}s")
        return b"".join(got) if spoke else b""

    def converse(self):
        self.cancel.clear()
        self.session = f"{DEVICE}-{int(time.time())}"
        follow_ups = 0
        try:
            while not self.cancel.is_set():
                pcm = self.listen(preroll=follow_ups == 0)
                if self.cancel.is_set():
                    break
                if not pcm:
                    S.set(caption="I didn't catch that." if follow_ups == 0 else "")
                    break
                S.set(state="thinking")
                try:
                    text = (nest_post("/api/stt", to_wav(pcm), ctype="audio/wav").get("text") or "").strip()
                except Exception as e:  # noqa
                    self.say(f"Sorry, I can't reach the ALIS brain right now.")
                    log("stt:", e)
                    break
                if not text:
                    log("stt: no words recognised")
                    S.set(caption="Sorry, I didn't catch that.")
                    break
                S.set(heard=text)
                log("you said:", text)
                speech, again = self.handle(text)
                if self.cancel.is_set():
                    break
                if speech:
                    self.say(speech)
                if not again or follow_ups >= 3:
                    break
                follow_ups += 1
        finally:
            S.set(state="idle", level=0.0)
            self.idle_since = time.time()

    def handle(self, text):
        """PC-only commands first, then the shared brain. Returns (speech, listen_again)."""
        local = self.local_command(text)
        if local is not None:
            return local, False
        ctx = {}
        playing = self.now_playing()
        if playing:
            ctx["now_playing"] = playing
        try:
            out = nest_post("/api/brain", {"text": text, "session": self.session, "device": DEVICE,
                                           "caps": CAPS, "context": ctx}, timeout=45)
        except Exception as e:  # noqa
            log("brain:", e)
            return "Sorry, the ALIS brain isn't answering.", False
        speech = out.get("speech") or ""
        act = out.get("action")
        if act:
            report = self.do_action(act)
            if not speech and report:
                speech = report
            try:
                nest_post("/api/brain/log", {"device": DEVICE, "action": act, "result": report or "done"}, timeout=5)
            except Exception:  # noqa
                pass
        return speech, bool(out.get("listen"))

    # -- speaking -----------------------------------------------------------
    def say(self, text):
        S.set(state="speaking", caption=text)
        try:
            wav = nest_post("/api/tts", {"text": text}, timeout=30, raw=True)
        except Exception as e:  # noqa
            log("tts:", e)
            S.set(state="idle")
            return
        levels = wav_levels(wav)
        path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "alis-say.wav")
        with open(path, "wb") as f:
            f.write(wav)
        try:
            self.player = subprocess.Popen(PLAY_CMD + [path], stderr=subprocess.DEVNULL)
        except FileNotFoundError:
            log("no audio player:", PLAY_CMD[0])
            return
        t0 = time.time()
        while self.player.poll() is None:
            i = int((time.time() - t0) / 0.05)
            S.set(level=levels[i] if i < len(levels) else 0.0)
            time.sleep(0.05)
        self.player = None
        S.set(level=0.0)

    def stop(self):
        self.cancel.set()
        p = self.player
        if p and p.poll() is None:
            p.terminate()
        S.set(state="idle", level=0.0)

    # -- PC-only commands (the brain doesn't know these yet) -------------------
    FOLDERS = {"downloads": "Downloads", "documents": "Documents", "pictures": "Pictures", "photos": "Pictures",
               "music": "Music", "videos": "Videos", "desktop": "Desktop", "home": ""}

    def local_command(self, text):
        t = re.sub(r"[^\w\s.'-]", " ", text.lower()).strip()
        t = re.sub(r"^(hey |ok |okay )?(alis|alice|ellis)[ ,]*", "", t)
        if re.search(r"\b(take|grab|get)\b.*\bscreen ?shot\b|^screen ?shot\b", t):
            out = os.path.join(HOME, "Pictures", "Screenshots", time.strftime("Screenshot %Y-%m-%d %H.%M.%S.png"))
            os.makedirs(os.path.dirname(out), exist_ok=True)
            self.run(["spectacle", "--background", "--nonotify", "--fullscreen", "--output", out])
            return "Screenshot saved in your Pictures folder."
        if re.search(r"\block\b.*\b(computer|screen|pc|laptop|it)\b|^lock$", t):
            threading.Timer(1.5, lambda: self.run(["loginctl", "lock-session"])).start()
            return "Locking the computer."
        if re.search(r"\b(stop listening|mute (the )?(mic|microphone)|go to sleep)\b", t):
            threading.Timer(1.5, lambda: set_muted(True)).start()
            return "Microphone off. Press Windows, Shift and A to turn me back on."
        m = re.search(r"\bopen (my |the )?(downloads|documents|pictures|photos|music|videos|desktop|home)\b( folder)?", t)
        if m:
            self.run(["xdg-open", os.path.join(HOME, self.FOLDERS[m.group(2)])])
            return f"Opening your {m.group(2)}."
        m = re.search(r"\b(?:search|look up|google)(?: the web| online| the internet)?(?: for)? (.+)$", t)
        if m and not re.search(r"\b(spotify|music|song|playlist)\b", t):
            q = m.group(1).strip()
            self.run(["xdg-open", "https://duckduckgo.com/?q=" + urllib.parse.quote(q)])
            return f"Here's a web search for {q}."
        m = re.search(r"\b(?:open|go to)\s+((?:[a-z0-9-]+\.)+(?:com|co\.uk|org|net|uk|io|tv))\b", t)
        if m:
            self.run(["xdg-open", "https://" + m.group(1)])
            return f"Opening {m.group(1)}."
        return None

    # -- actions the brain hands back ----------------------------------------
    def do_action(self, a):
        typ = a.get("type")
        if typ == "open_app":
            return self.open_app(a.get("name", ""))
        if typ == "media":
            op = a.get("op")
            if op == "now_playing":
                return self.now_playing() or "Nothing's playing on this computer."
            self.run(["playerctl", {"play": "play", "pause": "pause", "next": "next",
                                    "previous": "previous"}.get(op, "play-pause")])
            return ""
        if typ == "volume":
            up = int(a.get("delta", 1)) > 0
            self.run(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "10%+" if up else "10%-"])
            return ""
        if typ == "brightness":
            up = int(a.get("delta", 1)) > 0
            self.run(["brightnessctl", "set", "15%+" if up else "15%-"])
            return ""
        if typ == "wifi":
            self.run(["systemsettings", "kcm_networkmanagement"])
            return "Here are the Wi-Fi settings."
        if typ == "bluetooth":
            self.run(["bluetoothctl", "power", "on" if a.get("on", True) else "off"])
            return ""
        log("action this PC can't do:", a)
        return ""

    def now_playing(self):
        if DRY_RUN:
            return ""
        try:
            out = subprocess.run(["playerctl", "metadata", "--format", "{{artist}} - {{title}}"],
                                 capture_output=True, text=True, timeout=3)
            s = out.stdout.strip()
            return s if out.returncode == 0 and s.strip(" -") else ""
        except Exception:  # noqa
            return ""

    def open_app(self, name):
        """Find the closest installed app by its menu name and start it."""
        apps = {}
        dirs = os.environ.get("XDG_DATA_DIRS", "").split(":") + \
            ["/run/current-system/sw/share", os.path.join(HOME, ".local/share")]
        for d in dirs:
            for f in glob.glob(os.path.join(d, "applications", "*.desktop")):
                try:
                    txt = open(f, encoding="utf-8", errors="replace").read()
                except Exception:  # noqa
                    continue
                if re.search(r"^NoDisplay=true", txt, re.M):
                    continue
                n = re.search(r"^Name=(.+)$", txt, re.M)
                e = re.search(r"^Exec=(.+)$", txt, re.M)
                if n and e:
                    apps.setdefault(n.group(1).strip().lower().replace("alis · ", ""), e.group(1).strip())
        want = name.lower().strip()
        hit = want if want in apps else (difflib.get_close_matches(want, list(apps), n=1, cutoff=0.6) or [None])[0]
        if not hit:
            hit = next((k for k in apps if want and want in k), None)
        if not hit:
            return f"I couldn't find an app called {name}."
        cmd = [w for w in shlex.split(apps[hit]) if not re.fullmatch(r"%[a-zA-Z]", w)]
        self.run(cmd)
        return f"Opening {hit}."

    def run(self, cmd):
        if DRY_RUN:
            log("WOULD RUN:", " ".join(cmd))
            return
        try:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        except FileNotFoundError:
            log("not installed:", cmd[0])

    def main_loop(self):
        while True:
            self.trigger.wait()
            self.trigger.clear()
            if S.muted:
                continue
            try:
                self.converse()
            except Exception as e:  # noqa
                log("conversation:", e)
                S.set(state="idle")


A = Assistant()


def set_muted(on):
    S.set(muted=on)
    if on:
        A.stop()
        A.stop_mic()
        if A.ws:
            A.ws.close()
    log("microphone", "OFF (muted)" if on else "on")
    if not DRY_RUN:
        try:
            subprocess.Popen(["notify-send", "--app-name=ALIS", "--icon=audio-input-microphone" + ("-muted" if on else ""),
                              "ALIS", "Microphone off - I'm not listening." if on else "I'm listening for “Hey ALIS”."],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except FileNotFoundError:
            pass


# ---------------------------------------------------------------- local control server
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _json(self, obj, code=200):
        b = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path == "/":
            b = open(os.path.join(HERE, "orb.html"), "rb").read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(b)))
            self.end_headers()
            self.wfile.write(b)
        elif self.path == "/events":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            q = queue.Queue(maxsize=50)
            with S.lock:
                S.listeners.append(q)
            try:
                q.put_nowait(S.snapshot())
                while True:
                    try:
                        snap = q.get(timeout=15)
                        self.wfile.write(b"data: " + json.dumps(snap).encode() + b"\n\n")
                    except queue.Empty:
                        self.wfile.write(b": keep-alive\n\n")
                    self.wfile.flush()
            except Exception:  # noqa - window closed
                pass
            finally:
                with S.lock:
                    S.listeners.remove(q)
        elif self.path == "/api/status":
            self._json(dict(S.snapshot(), nest=nest(), device=DEVICE, wake_connected=A.ws is not None))
        else:
            self._json({"error": "not found"}, 404)

    def do_POST(self):
        p = self.path
        if p == "/api/talk":
            if S.muted:
                set_muted(False)
            A.trigger.set()
        elif p == "/api/stop":
            A.stop()
        elif p == "/api/mute":
            set_muted(True)
        elif p == "/api/unmute":
            set_muted(False)
        elif p == "/api/toggle-mute":
            set_muted(not S.muted)
        else:
            return self._json({"error": "not found"}, 404)
        self._json(S.snapshot())


def main():
    log(f"starting on {DEVICE}; NEST at {' then '.join(NEST_URLS)}; {'muted' if S.muted else 'listening'}")
    for fn in (A.mic_loop, A.wake_loop, A.main_loop):
        threading.Thread(target=fn, daemon=True).start()
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    srv.daemon_threads = True
    srv.serve_forever()


if __name__ == "__main__":
    sys.exit(main())
