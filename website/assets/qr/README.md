# V.Go Rider QR

رموز QR ثابتة تحفظ الرابط مباشرة، بدون خدمة خارجية، ولا تنتهي صلاحيتها بذاتها.
رمز `vgo-rider-app` يعتمد على استمرار تجديد نطاق `vgo-eg.com` وإتاحة صفحة `/app/`؛
الرمزان المباشران يعتمدان فقط على استمرار إتاحة صفحات التطبيق في المتجرين.

Static QR codes encode each URL directly, use no third-party QR service, and never
expire themselves. The `app` code depends on keeping `vgo-eg.com` renewed and
`/app/` available; the two direct codes depend only on the store listings.

| Files (SVG + PNG) | Encoded URL |
| --- | --- |
| `vgo-rider-app` | https://vgo-eg.com/app/ |
| `vgo-rider-play` | https://play.google.com/store/apps/details?id=com.scooterapp.vgo |
| `vgo-rider-appstore` | https://apps.apple.com/app/id6820955516 |

لإنشاء الصور: ثبّت `segno` ثم شغّل السكربت من جذر المستودع.
To generate the images, install `segno`, then run from the repository root:

```sh
python3 -m pip install segno
python3 website/_make_qr.py
```

تصحيح أخطاء H، هامش ٤ وحدات، أسود على أبيض، وPNG بعرض يقارب ١٢٠٠ بكسل.
H error correction, 4-module border, black on white, PNG approximately 1200 px wide.
Use SVG for scalable printing; keep the white border intact.
