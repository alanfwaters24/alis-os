# Keeping the PC assistant in step with the phone app

**Rule (Alan, 7 Nov 2026):** any change to how the ALIS Assistant phone app
(`alanfwaters24/alis-assistant`, Android) behaves as an assistant must also be
applied here, to ALIS OS's built-in assistant (`pkgs/alis-assistant/`), so
ALIS acts the same on every device.

Anything that is "brain" logic lives in NEST (`alis-live/brain.py`) and is
shared automatically. This list is for the **device-side behaviour** each
assistant has to do itself. Tick items off as they're ported.

## Waiting to be ported

### Phone 0.8.0 — "Read on request" notifications (7 Nov 2026)

What the phone now does:

- **She never reads or announces notifications on her own** (the old "You have
  3 new notifications, would you like me to read them?" is off by default;
  a "Read new notifications out loud" switch brings it back).
- **Device in use** → her teal/violet ALIS banner at the top for every new
  notification. One waiting = app + sender + preview; several =
  "N waiting · apps" + the newest one. Tap = she reads them all now.
- **Device locked / screen off** → one soft chime only (at most once every
  2 minutes, never when the device is muted). No speech.
- **On a call or in Do Not Disturb** (device DND or NEST's DND hours) →
  nothing at all; only her quiet list updates.
- **One quiet "ALIS · 3 waiting · WhatsApp, Gmail" entry** in the
  notification area with **▶ Read them** (reads straight away, no question)
  and **Clear** (forgets ALIS's list only; the apps' own notifications are
  left alone). Kept up to date as things are read or dismissed.
- After reading: they're taken off the waiting list; a single one still gets
  "Want me to open it?".
- **"Read my notifications" by voice** still works. The brain now returns an
  action `{"type": "notifications_read"}` when the device lists
  `notifications_read` in its caps; the device then clears exactly the ones it
  sent in `context.notifications`.

What that would mean on ALIS OS (not built yet — needs planning with Alan):

- The PC assistant doesn't read desktop notifications at all today. Porting
  this means listening to the desktop's notifications (KDE / freedesktop
  `org.freedesktop.Notifications` on D-Bus), keeping a waiting list, showing
  the ALIS-style banner by the top-right orb instead of reading aloud, a soft
  chime when the screen is locked, nothing in DND, a "N waiting" tray entry
  with Read / Clear, and sending `notifications` + the `notifications_read`
  cap to the brain.
