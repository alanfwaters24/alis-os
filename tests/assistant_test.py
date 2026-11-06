#!/usr/bin/env python3
"""End-to-end test for ALIS Assistant (pkgs/alis-assistant) with no real hardware:
a pretend NEST (wake word socket, STT, brain, TTS) and a pretend microphone.

  python3 tests/assistant_test.py

Checks: wake word over the WebSocket -> listen -> STT -> PC-only command or the
brain -> the brain's action is carried out -> reply spoken; plus mute (mic hard
off), unmute, push-to-talk and stop, through the same local API the orb uses.
"""
import base64
import hashlib
import io
import json
import os
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSISTANT = os.path.join(ROOT, "pkgs", "alis-assistant", "assistant.py")

SAID = ["open my downloads", "turn it up", "open score", "take a screenshot", "what's the weather"]
BRAIN = {
    "turn it up": {"speech": "", "action": {"type": "volume", "delta": 1}, "listen": False},
    "open score": {"speech": "", "action": {"type": "open_app", "name": "SCORE"}, "listen": False},
    "what's the weather": {"speech": "Fourteen degrees and partly cloudy.", "action": None, "listen": False},
}
seen = {"stt": 0, "brain": [], "tts": [], "wake_clients": 0, "frames": 0}


def tiny_wav():
    b = io.BytesIO()
    with wave.open(b, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000)
        w.writeframes(b"\x00\x10" * 3200)
    return b.getvalue()


class FakeNest(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _json(self, obj):
        b = json.dumps(obj).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)

    def do_GET(self):
        if self.path == "/api/health":
            return self._json({"ok": True})
        if self.path == "/api/wake/ws":
            key = self.headers["Sec-WebSocket-Key"]
            acc = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
            self.wfile.write(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                              f"Sec-WebSocket-Accept: {acc}\r\n\r\n").encode()); self.wfile.flush()
            seen["wake_clients"] += 1
            n = 0
            while True:
                h = self.rfile.read(2)
                if len(h) < 2:
                    return
                ln = h[1] & 0x7F
                if ln == 126:
                    ln = struct.unpack(">H", self.rfile.read(2))[0]
                self.rfile.read(4); self.rfile.read(ln)        # mask + payload
                if h[0] & 0x0F == 0x2:
                    n += 1; seen["frames"] += 1
                    if n % 25 == 0 and seen["stt"] < len(SAID):  # every ~2 s of audio, "Hey ALIS"
                        msg = json.dumps({"detected": "hey_alis"}).encode()
                        self.wfile.write(bytes([0x81, len(msg)]) + msg); self.wfile.flush()
        self.send_response(404); self.end_headers()

    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(n)
        if self.path == "/api/stt":
            text = SAID[seen["stt"]] if seen["stt"] < len(SAID) else ""
            seen["stt"] += 1
            return self._json({"text": text})
        if self.path == "/api/brain":
            req = json.loads(body)
            seen["brain"].append(req)
            return self._json(BRAIN.get(req["text"], {"speech": "OK.", "listen": False}))
        if self.path == "/api/brain/log":
            return self._json({"ok": True})
        if self.path == "/api/tts":
            seen["tts"].append(json.loads(body)["text"])
            wav = tiny_wav()
            self.send_response(200); self.send_header("Content-Type", "audio/wav")
            self.send_header("Content-Length", str(len(wav))); self.end_headers(); self.wfile.write(wav)
            return
        self.send_response(404); self.end_headers()


MIC = r'''
import sys, time, struct, random
# pretend microphone: quiet room, then someone talks for ~1.2 s, then quiet; repeat
frame = 1280
def out(level):
    s = [int(random.gauss(0, level)) for _ in range(frame)]
    sys.stdout.buffer.write(struct.pack("<%dh" % frame, *[max(-32000, min(32000, x)) for x in s])); sys.stdout.flush()
    time.sleep(0.08)
while True:
    for _ in range(28): out(60)        # quiet (wake word streams meanwhile)
    for _ in range(15): out(6000)      # speech
    for _ in range(20): out(60)        # quiet -> end of command
'''


def api(port, path, method="GET"):
    req = urllib.request.Request(f"http://127.0.0.1:{port}{path}", method=method, data=b"" if method == "POST" else None)
    return json.loads(urllib.request.urlopen(req, timeout=5).read())


def main():
    srv = ThreadingHTTPServer(("127.0.0.1", 0), FakeNest); srv.daemon_threads = True
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    nest_port = srv.server_address[1]
    tmp = tempfile.mkdtemp()
    os.makedirs(os.path.join(tmp, "applications"))
    with open(os.path.join(tmp, "applications", "alis-score.desktop"), "w") as f:
        f.write("[Desktop Entry]\nType=Application\nName=ALIS · SCORE\nExec=alis-open-url http://192.168.1.235:3503 -- --class=alis-score\n")
    mic = os.path.join(tmp, "mic.py"); open(mic, "w").write(MIC)
    s = socket.socket(); s.bind(("127.0.0.1", 0)); port = s.getsockname()[1]; s.close()
    env = dict(os.environ, ALIS_NEST_URLS=f"http://127.0.0.1:1 http://127.0.0.1:{nest_port}",  # first address is "down"
               ALIS_DEVICE="test-laptop", ALIS_ASSISTANT_PORT=str(port), ALIS_DRY_RUN="1", ALIS_NO_ORB="1",
               ALIS_AUDIO_CMD=f"{sys.executable} -u {mic}", ALIS_PLAY_CMD="sleep 0.3 #", XDG_DATA_DIRS=tmp,
               XDG_RUNTIME_DIR=tmp, HOME=tmp, PYTHONUNBUFFERED="1")
    env["ALIS_PLAY_CMD"] = f"{sys.executable} -c 'import time; time.sleep(0.3)'"
    proc = subprocess.Popen([sys.executable, ASSISTANT], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines = []
    threading.Thread(target=lambda: [lines.append(l.rstrip()) for l in proc.stdout], daemon=True).start()
    ok = True

    def check(name, cond):
        nonlocal ok
        print(("PASS " if cond else "FAIL ") + name)
        ok &= bool(cond)

    try:
        t0 = time.time()
        while seen["stt"] < len(SAID) and time.time() - t0 < 90:
            time.sleep(0.5)
        time.sleep(3)
        out = "\n".join(lines)
        check("wake word stream connected (skipping the 'down' address)", seen["wake_clients"] >= 1 and seen["frames"] > 20)
        check("heard all 5 commands through wake word + STT", seen["stt"] >= len(SAID))
        check("'open my downloads' handled on the PC (not sent to the brain)",
              "WOULD RUN: xdg-open " + os.path.join(tmp, "Downloads") in out
              and all(b["text"] != "open my downloads" for b in seen["brain"]))
        check("'take a screenshot' handled on the PC", "WOULD RUN: spectacle" in out)
        check("brain got device name + PC abilities",
              any(b["device"] == "test-laptop" and "open_app" in b["caps"] for b in seen["brain"]))
        check("brain 'volume' action -> wpctl", "WOULD RUN: wpctl set-volume" in out)
        check("brain 'open_app SCORE' -> the ALIS · SCORE app", "WOULD RUN: alis-open-url http://192.168.1.235:3503" in out)
        check("brain answer spoken", "Fourteen degrees and partly cloudy." in seen["tts"])

        # mute = mic hard off
        api(port, "/api/mute", "POST"); time.sleep(1.5)
        f0 = seen["frames"]; time.sleep(2.5)
        st = api(port, "/api/status")
        check("mute: status says muted", st["muted"] is True)
        check("mute: no audio sent while muted (mic closed)", seen["frames"] == f0)
        api(port, "/api/unmute", "POST")
        t1 = time.time()
        while seen["frames"] == f0 and time.time() - t1 < 15:
            time.sleep(0.25)
        print(f"     (audio resumed {time.time() - t1:.1f}s after unmute; status: {api(port, '/api/status')})")
        check("unmute: audio flowing again within 6 s", seen["frames"] > f0 and time.time() - t1 < 6)
        # push-to-talk and stop
        api(port, "/api/talk", "POST"); time.sleep(0.6)
        check("talk button: starts listening", api(port, "/api/status")["state"] == "listening")
        api(port, "/api/stop", "POST"); time.sleep(1)
        check("stop button: back to idle", api(port, "/api/status")["state"] == "idle")
        page = urllib.request.urlopen(f"http://127.0.0.1:{port}/", timeout=5).read().decode()
        check("orb page served with mute/stop buttons", "ALIS Assistant" in page and "toggle-mute" in page)
    finally:
        proc.terminate()
        if not ok:
            print("\n--- assistant log ---\n" + "\n".join(lines[-60:]))
    print("\nALL PASSED" if ok else "\nSOME CHECKS FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
