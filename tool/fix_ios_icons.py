"""Regenerates iOS app icons from the 1024px master without alpha.

Also writes loose AppIcon*.png files into ios/Runner so builds that skip
actool (no Assets.car) still find an icon via CFBundleIconFiles.
"""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ICONSET = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
RUNNER = ROOT / "ios" / "Runner"
MASTER = ICONSET / "Icon-App-1024x1024@1x.png"

LOOSE = {
    "AppIcon60x60@2x.png": 120,
    "AppIcon60x60@3x.png": 180,
    "AppIcon76x76~ipad.png": 76,
    "AppIcon76x76@2x~ipad.png": 152,
    "AppIcon83.5x83.5@2x~ipad.png": 167,
}


def flat(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    bg = Image.new("RGB", img.size, (255, 255, 255))
    bg.paste(img, mask=img.split()[3])
    return bg


def main() -> None:
    master = flat(Image.open(MASTER))
    master.save(MASTER, "PNG")

    contents = json.loads((ICONSET / "Contents.json").read_text())
    for entry in contents["images"]:
        name = entry.get("filename")
        if not name:
            continue
        base = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        px = round(base * scale)
        master.resize((px, px), Image.LANCZOS).save(ICONSET / name, "PNG")
        print(f"{name}: {px}px")

    for name, px in LOOSE.items():
        master.resize((px, px), Image.LANCZOS).save(RUNNER / name, "PNG")
        print(f"loose {name}: {px}px")


if __name__ == "__main__":
    main()
