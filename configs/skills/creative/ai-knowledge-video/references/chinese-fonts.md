# Chinese Fonts for FFmpeg drawtext

## The Problem

DejaVu fonts (default on most Linux systems) do NOT support CJK characters.
Chinese text rendered with DejaVu will show as empty boxes (tofu).

## Install Chinese Fonts

```bash
# Debian/Ubuntu
apt-get install fonts-noto-cjk

# Or a smaller package
apt-get install fonts-wqy-zenhei
```

## Find Font Path

```bash
fc-list :lang=zh | head -5
# Or search directly
find /usr/share/fonts -name '*CJK*' -o -name '*wqy*' -o -name '*NotoSansCJK*'
```

## Common Paths

| Font | Path |
|------|------|
| Noto Sans CJK | `/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc` |
| WenQuanYi Zen Hei | `/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc` |
| Noto Sans SC | `/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc` |

## FFmpeg Usage

```bash
ffmpeg -f lavfi -i "color=c=black:s=1920x1080:d=5:r=30" \
  -vf "drawtext=text='你好世界':fontfile=/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc:fontsize=64:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2" \
  output.mp4
```

## Note on .ttc Files

FFmpeg's drawtext can use `.ttc` (TrueType Collection) files directly.
If you get errors, extract a single `.ttf` using `fonttools`:
```bash
pip install fonttools
fonttools ttLib.woff2 decompress NotoSansCJK-Regular.ttc
```
