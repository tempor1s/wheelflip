# WheelFlip

A tiny macOS menu bar app that reverses scrolling for **mouse wheels only**. The trackpad (and Magic Mouse) keep macOS "natural" scrolling, so you don't have to flip the system setting every time you switch.

## How it tells mouse from trackpad

It uses a `CGEventTap` on scroll events. Trackpad and Magic Mouse scrolls always carry a gesture phase (began/changed/ended) or a momentum phase, and a mouse wheel's scrolls have neither. Only phase-less events get flipped, covering the integer, fixed-point and pixel deltas so every app sees the same direction.

## Install

Needs the Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/tempor1s/wheelflip && cd wheelflip
./build.sh                       # builds + runs the self-test
cp -R build/WheelFlip.app /Applications/ && open /Applications/WheelFlip.app
```

Then grant **System Settings → Privacy & Security → Accessibility → WheelFlip**. The app picks it up within a couple of seconds, with no relaunch needed. On first run it also adds itself as a login item.

Keep macOS's **Natural scrolling** turned **on**. WheelFlip flips the mouse back to "classic" direction on top of that.

## Menu

- Reverse Mouse Wheel (on/off), with separate Vertical / Horizontal toggles (horizontal is off by default)
- Launch at Login
- Menu bar icon: filled mouse = reversing, outline = paused, ⚠️ = missing Accessibility permission

## Notes

- The app is ad-hoc signed, so after **rebuilding** it macOS may treat it as a new app. If scrolling stops flipping, remove WheelFlip from the Accessibility list and add it again.
- `WheelFlip.app/Contents/MacOS/WheelFlip --selftest` checks the flip and detection logic without any permissions.
