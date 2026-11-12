#!/usr/bin/env python3
"""Generate static rider QR assets. Requires: python3 -m pip install segno."""

from pathlib import Path

import segno


OUTPUT_DIR = Path(__file__).resolve().parent / "assets" / "qr"
URLS = {
    "vgo-rider-app": "https://vgo-eg.com/app/",
    "vgo-rider-play": "https://play.google.com/store/apps/details?id=com.scooterapp.vgo",
    "vgo-rider-appstore": "https://apps.apple.com/app/id6820955516",
}


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, url in URLS.items():
        qr = segno.make_qr(url, error="H", boost_error=False)
        width, _ = qr.symbol_size(scale=1, border=4)
        # Whole pixels per module keep edges sharp, including the quiet zone.
        scale = max(1, round(1200 / width))
        qr.save(str(OUTPUT_DIR / (name + ".svg")),
                border=4, dark="black", light="white", scale=1)
        qr.save(str(OUTPUT_DIR / (name + ".png")),
                border=4, dark="black", light="white", scale=scale)
        print(f"{name}: SVG + PNG ({width * scale} px) -> {url}")
    print(f"Wrote 3 static QR codes (6 files) to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
