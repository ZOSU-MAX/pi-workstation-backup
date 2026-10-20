"""Debug HUD region alignment for game autopilot.

Captures a screenshot, saves it as debug_screenshot.png, and prints color
statistics for each configured HUD region. Use this to verify that the
YAML region coordinates actually align with the visible game HUD.

Run while the game is visible (NOT minimized).

Usage:
    python -m <skill_dir>.scripts.debug_hud   # if installed as package
    OR copy to project root and run: python debug_hud.py
"""

from __future__ import annotations
import sys
import os
import numpy as np

# Allow running standalone from a project root that has capture/ as a submodule
# expecting capture/__init__.py with ScreenCapture class
def _import_capture():
    """Import ScreenCapture, trying project root first."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    try:
        from capture import ScreenCapture
        return ScreenCapture
    except ImportError:
        print("[ERROR] Cannot import capture.ScreenCapture.")
        print("  Make sure capture/__init__.py exists with ScreenCapture class.")
        sys.exit(1)


def debug():
    ScreenCapture = _import_capture()

    print("=" * 60)
    print("  HUD Debug — Screen Region Analysis")
    print("=" * 60)

    cap = ScreenCapture(monitor=1)

    # Capture full frame
    frame = cap.capture_full()
    screenshot_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "debug_screenshot.png"
    )

    # Save screenshot for visual inspection
    try:
        from PIL import Image
        rgb = frame[:, :, ::-1].copy()  # BGR → RGB
        Image.fromarray(rgb).save(screenshot_path)
        print(f"\n[OK] Screenshot saved: {screenshot_path}")
        print(f"     Resolution: {frame.shape[1]}x{frame.shape[0]}")
    except ImportError:
        print("\n[PIL not available — skipping screenshot save]")

    # Analyze each configured region
    print("\n" + "-" * 60)
    print("Region Analysis (current YAML config):")
    print("-" * 60)

    for name, region in cap.regions.items():
        try:
            img = frame[region.to_slice()]
            mean = np.mean(img, axis=(0, 1))
            min_v = np.min(img, axis=(0, 1))
            max_v = np.max(img, axis=(0, 1))
            std = np.std(img, axis=(0, 1))

            print(f"\n  {name}:")
            print(f"    Position: x={region.x}, y={region.y}, w={region.w}, h={region.h}")
            print(f"    Mean BGR: ({mean[0]:.0f}, {mean[1]:.0f}, {mean[2]:.0f})")
            print(f"    Min BGR:  ({min_v[0]:.0f}, {min_v[1]:.0f}, {min_v[2]:.0f})")
            print(f"    Max BGR:  ({max_v[0]:.0f}, {max_v[1]:.0f}, {max_v[2]:.0f})")
            print(f"    Std BGR:  ({std[0]:.0f}, {std[1]:.0f}, {std[2]:.0f})"

            # Region-specific checks
            if "altitude" in name:
                green_mask =
                    (img[:, :, 1] > 100)
                    & (img[:, :, 1] > img[:, :, 0] + 20)
                    & (img[:, :, 1] > img[:, :, 2] + 20)
                green_pct = np.mean(green_mask) * 100
                print(f"    Green pixels: {green_pct:.1f}%")

            if "speed" in name or "heading" in name or "compass" in name:
                bright_mask =
                    (img[:, :, 0] > 150)
                    & (img[:, :, 1] > 150)
                    & (img[:, :, 2] > 150)
                bright_pct = np.mean(bright_mask) * 100
                print(f"    Bright pixels: {bright_pct:.1f}%")

        except Exception as e:
            print(f"\n  {name}: ERROR — {e}")

    print("\n" + "-" * 60)
    print("Next steps:")
    print("  1. Open debug_screenshot.png in an image viewer")
    print("  2. Compare HUD element positions vs configured x,y")
    print("  3. If mismatch, update config/hud_regions.yaml")
    print("  4. Re-run until color stats look right for each region")
    print("-" * 60)


if __name__ == "__main__":
    debug()
