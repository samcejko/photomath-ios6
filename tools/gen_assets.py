#!/usr/bin/env python3
"""Generates the app icon and launch images for Photomath iOS 6 (run in CI, needs Pillow).

Usage: python3 tools/gen_assets.py Resources
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "Resources"
os.makedirs(OUT, exist_ok=True)

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
    "/Library/Fonts/Arial Bold.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
]


_R = getattr(Image, "Resampling", Image)
LANCZOS, NEAREST = _R.LANCZOS, _R.NEAREST


def font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    try:
        return ImageFont.load_default(size)  # Pillow >= 10.1
    except TypeError:
        sys.exit("gen_assets: no TrueType font found (install fonts-dejavu-core)")


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vertical_gradient(size, top, bottom):
    w, h = size
    col = Image.new("RGB", (1, h))
    col.putdata([lerp(top, bottom, y / max(1, h - 1)) for y in range(h)])
    return col.resize((w, h), NEAREST)


def text_size(draw, text, fnt):
    if hasattr(draw, "textbbox"):
        l, t, r, b = draw.textbbox((0, 0), text, font=fnt)
        return r - l, b - t, l, t
    w, h = draw.textsize(text, font=fnt)
    return w, h, 0, 0


_BASE_ICON = None


def base_icon():
    """The 1024 px master icon for Photomath."""
    global _BASE_ICON
    if _BASE_ICON is not None:
        return _BASE_ICON
    base = 1024
    # Classic Photomath vibrant red/coral gradient
    img = vertical_gradient((base, base), (250, 75, 75), (205, 30, 35))
    gloss = Image.new("RGBA", (base, base), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gloss)
    gd.rectangle((0, 0, base, base // 2), fill=(255, 255, 255, 32))
    img = Image.alpha_composite(img.convert("RGBA"), gloss)

    # Draw the white math scanning viewfinder + 'x' or math symbol
    d = ImageDraw.Draw(img)
    margin = int(base * 0.20)
    x0, y0, x1, y1 = margin, margin, base - margin, base - margin
    corner_len = int(base * 0.16)
    stroke = int(base * 0.055)

    # Viewfinder 4 corners (Photomath signature)
    white = (255, 255, 255, 255)
    # Top-Left
    d.rectangle((x0, y0, x0 + corner_len, y0 + stroke), fill=white)
    d.rectangle((x0, y0, x0 + stroke, y0 + corner_len), fill=white)
    # Top-Right
    d.rectangle((x1 - corner_len, y0, x1, y0 + stroke), fill=white)
    d.rectangle((x1 - stroke, y0, x1, y0 + corner_len), fill=white)
    # Bottom-Left
    d.rectangle((x0, y1 - stroke, x0 + corner_len, y1), fill=white)
    d.rectangle((x0, y1 - corner_len, x0 + stroke, y1), fill=white)
    # Bottom-Right
    d.rectangle((x1 - corner_len, y1 - stroke, x1, y1), fill=white)
    d.rectangle((x1 - stroke, y1 - corner_len, x1, y1), fill=white)

    # Center math symbol: "x" (algebra variable) or "+"
    fnt = font(int(base * 0.38))
    tw, th, tl, tt = text_size(d, "x", fnt)
    cx, cy = base // 2, base // 2
    d.text((cx - tw // 2 - tl, cy - th // 2 - tt - int(base * 0.02)), "x", font=fnt, fill=white)

    _BASE_ICON = img.convert("RGB")
    return _BASE_ICON


def make_icon(size):
    return base_icon().resize((size, size), LANCZOS)


def rounded_mask(size, radius_ratio=0.1757):
    """An anti-aliased rounded-rectangle alpha mask (iOS 6 home-screen corner radius)."""
    scale = 4
    big = size * scale
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big - 1, big - 1), radius=int(big * radius_ratio), fill=255)
    return mask.resize((size, size), LANCZOS)


def make_home_icon(size):
    """The icon as it sits on the home screen: rounded corners baked in (UIPrerenderedIcon is on)."""
    icon = make_icon(size).convert("RGBA")
    icon.putalpha(rounded_mask(size))
    return icon


def make_launch(w, h):
    img = vertical_gradient((w, h), (242, 244, 248), (220, 224, 232))
    d = ImageDraw.Draw(img)
    s = int(min(w, h) * 0.22)
    icon = make_icon(s)
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, s - 1, s - 1), radius=int(s * 0.22), fill=255)
    cx, cy = w // 2, int(h * 0.40)
    img.paste(icon, (cx - s // 2, cy - s // 2), mask)
    fnt = font(int(min(w, h) * 0.065))
    tw, th, l, t = text_size(d, "Photomath", fnt)
    d.text((cx - tw // 2 - l, cy + s // 2 + int(s * 0.25) - t), "Photomath", font=fnt, fill=(50, 54, 66))

    subfnt = font(int(min(w, h) * 0.032))
    subtext = "Smart Math Camera"
    sw, sh, sl, st = text_size(d, subtext, subfnt)
    d.text((cx - sw // 2 - sl, cy + s // 2 + int(s * 0.25) + th + int(s * 0.1) - st), subtext, font=subfnt, fill=(110, 116, 130))
    return img


def make_logo(size):
    """The icon with rounded corners: the launch screen of the arm64 build."""
    icon = make_icon(size).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=int(size * 0.2237), fill=255)
    icon.putalpha(mask)
    return icon


ICONS = {
    # iOS 6
    "Icon.png": 57,
    "Icon@2x.png": 114,
    "Icon-72.png": 72,
    "Icon-72@2x.png": 144,
    "Icon-Small.png": 29,
    "Icon-Small@2x.png": 58,
    "Icon-Small-50.png": 50,
    "Icon-Small-50@2x.png": 100,
    # iOS 7 and newer (the arm64 build)
    "Icon-60@2x.png": 120,
    "Icon-60@3x.png": 180,
    "Icon-76.png": 76,
    "Icon-76@2x.png": 152,
    "Icon-83.5@2x.png": 167,
}

LOGOS = {
    "LaunchLogo.png": 100,
    "LaunchLogo@2x.png": 200,
    "LaunchLogo@3x.png": 300,
}

LAUNCH = {
    "Default.png": (320, 480),
    "Default@2x.png": (640, 960),
    "Default-568h@2x.png": (640, 1136),
    "Default-Portrait~ipad.png": (768, 1004),
    "Default-Portrait@2x~ipad.png": (1536, 2008),
    "Default-Landscape~ipad.png": (1024, 748),
    "Default-Landscape@2x~ipad.png": (2048, 1496),
}

if __name__ == "__main__":
    for name, size in ICONS.items():
        make_home_icon(size).save(os.path.join(OUT, name), "PNG")
        print("icon", name)

    for name, (w, h) in LAUNCH.items():
        make_launch(w, h).save(os.path.join(OUT, name), "PNG")
        print("launch", name)

    for name, size in LOGOS.items():
        make_logo(size).save(os.path.join(OUT, name), "PNG")
        print("logo", name)
