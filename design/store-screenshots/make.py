from io import BytesIO
from pathlib import Path

from PIL import Image, ImageCms, ImageOps

FOCUS = {i: (0.5, 0.5) for i in range(1, 8)}
FOCUS.update({5: (0.5, 0.4), 7: (0.5, 0.42)})

ROOT = Path(__file__).resolve().parent
SRGB = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB"))
TARGETS = {"play": (1920, 1080), "ios": (2622, 1206)}


def main():
    for folder in TARGETS:
        (ROOT / folder).mkdir(exist_ok=True)
    for number in range(1, 8):
        focus = FOCUS[number]
        assert len(focus) == 2 and all(0 <= v <= 1 for v in focus)
        with Image.open(ROOT / "src" / f"{number}.webp") as source:
            profile = source.info.get("icc_profile")
            photo = ImageOps.exif_transpose(source).convert("RGB")
            if profile:
                photo = ImageCms.profileToProfile(
                    photo, ImageCms.ImageCmsProfile(BytesIO(profile)),
                    SRGB, outputMode="RGB",
                )
            for folder, size in TARGETS.items():
                result = ImageOps.fit(
                    photo, size, method=Image.Resampling.LANCZOS,
                    centering=focus,
                )
                assert result.size == size and result.mode == "RGB"
                result.info.clear()
                path = ROOT / folder / f"{number:02}.jpg"
                result.save(path, quality=92, icc_profile=SRGB.tobytes())
                with Image.open(path) as saved:
                    assert saved.size == size and saved.mode == "RGB"
    print("Created 7 Play and 7 iOS screenshots.")


if __name__ == "__main__":
    main()
