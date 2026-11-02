from pathlib import Path
from PIL import Image, ImageOps
import json
root = Path(__file__).parent
manifest = json.loads((root/'_images.json').read_text(encoding='utf-8'))
for item in manifest:
    source = Image.open(item['path']).convert('RGB')
    name = item['name']
    if name.startswith('og-'):
        # Open Graph cards follow the og:image width/height metadata.
        source = ImageOps.fit(source, (1200,630), method=Image.Resampling.LANCZOS)
        output = root/'assets/img'/f'{name}.jpg'
        source.save(output,quality=88,optimize=True)
        print(name, source.size, output.stat().st_size)
        continue
    # 'rider-feature-*' and 'rider-step-*' share the 800x600 card size.
    if 'feature-' in name or 'step-' in name:
        source = ImageOps.fit(source,(800,600),method=Image.Resampling.LANCZOS)
    elif name == 'earnings-finance':
        source = ImageOps.fit(source,(1200,800),method=Image.Resampling.LANCZOS)
    else:
        source = ImageOps.fit(source,(1536,1024),method=Image.Resampling.LANCZOS)
    output = root/'assets/img'/f'{name}.webp'
    quality = 85
    while True:
        source.save(output,format='WEBP',quality=quality,method=6)
        if output.stat().st_size < 300000 or quality <= 40: break
        quality -= 5
    print(name, source.size, output.stat().st_size)
icon = Image.open(root.parent/'V-GoCaptain/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png')
for name,size in [('captain-icon',256),('favicon',64)]:
    icon.resize((size,size),Image.Resampling.LANCZOS).save(root/f'assets/img/{name}.png',optimize=True)
