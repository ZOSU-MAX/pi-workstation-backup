---
name: ai-knowledge-video
description: "Use when making AI knowledge/science videos for Douyin."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [AI, Video, TTS, FFmpeg, Douyin, Knowledge]
    related_skills: [manim-video, ascii-video]
---

# AI Knowledge Video Creation

Create short AI-narrated knowledge/science videos for platforms like Douyin.
Lightweight pipeline that works on Raspberry Pi (ARM) without GPU.

## When to Use

- User asks to make AI科普/知识视频,抖音视频, or similar short-form content
- User wants a free alternative to commercial AI video tools
- TextToTalk/Remotion fails on ARM and a simpler pipeline is needed

## Pipeline (4 steps)

### 1. Write Script

Structure for 60-90 second knowledge videos:
```
[0-5s]    Hook: Counterintuitive question or surprising fact
[5-15s]   Twist: "The answer is not what you think"
[15-50s]  Core: 3-4 knowledge points with simple analogies
[50-60s]  CTA: "Follow me for more" + teaser for next episode
```

Keep sentences short (one idea per sentence). AI TTS handles short sentences better.

### 2. Generate TTS Audio

Use Python `edge-tts` (NOT Node.js `msedge-tts`):

```python
import edge_tts
import asyncio

def generate_tts(text, output_path, voice="zh-CN-XiaoxiaoNeural"):
    async def _gen():
        tts = edge_tts.Communicate(text, voice)
        await tts.save(output_path)
    asyncio.run(_gen())
```

Voices: `zh-CN-XiaoxiaoNeural` (晓晓, female), `zh-CN-YunxiNeural` (云希, male), `zh-CN-YunyangNeural` (云扬, male news).

### 3. Create Video Segments with FFmpeg

For each script segment, create a colored background + text overlay + TTS audio:

```bash
ffmpeg -y \
  -f lavfi -i "color=c=#1a1a2e:s=1920x1080:d={duration}:r=30" \
  -i {audio_path} \
  -vf "drawtext=text='{title}':fontfile={font_path}:fontsize=64:fontcolor=white:x=(w-text_w)/2:y=h/2-60,drawtext=text='{subtitle}':fontfile={font_path}:fontsize=36:fontcolor=white:x=(w-text_w)/2:y=h/2+40" \
  -c:v libx264 -preset fast -crf 23 \
  -c:a aac -b:a 128k \
  -shortest -pix_fmt yuv420p \
  {output_path}
```

### 4. Concatenate Segments

```bash
# Create concat list
for f in segment_*.mp4; do echo "file '$f'" >> concat.txt; done

# Merge
ffmpeg -y -f concat -safe 0 -i concat.txt -c copy final_video.mp4
```

## Pitfalls

- **Python `edge-tts` works; Node.js `msedge-tts` gets 403 in China.** The
  Node.js library uses a WebSocket endpoint that Microsoft blocks from
  Chinese IPs. The Python library uses a different protocol and works fine.
  If a TTS engine returns 403, switch to Python `edge-tts`.

- **DejaVu fonts do NOT support CJK characters.** FFmpeg `drawtext` will
  render Chinese as empty boxes. Install a CJK font first:
  `apt-get install fonts-noto-cjk` (or any font with Chinese glyphs).
  Point `fontfile=` to the `.ttc` or `.ttf` file directly.
  **No root in container?** Use Docker to install fonts to host:
  `docker run --rm -v /home/jian/.hermes/fonts:/fonts alpine sh -c "apk add --no-cache font-noto-cjk && cp -r /usr/share/fonts/* /fonts/"`
  Or download a single font file from a mirror (e.g. TUNA).

- **Remotion + Chromium on ARM (Raspberry Pi) is unreliable.** TextToTalk
  uses Remotion 4 which downloads a Headless Shell that may not work on
  ARM64. If rendering fails with "Webpack bundle not found" or browser
  errors, fall back to the FFmpeg drawtext pipeline above.

- **Docker containers need volume mounts for output.** If running TTS or
  FFmpeg inside a container, ensure the output directory is a volume mount.
  Otherwise files written in the container layer are lost on restart.

- **edge-tts requires Python 3.10+.** Check `python3 --version` first.
  Install with `pip install edge-tts` (or `python3 -m pip install --user edge-tts`
  if no root).

- **Proactively report progress during long operations.** Do NOT wait for
  the user to ask "怎么样了". The user expects autonomous progress updates
  at meaningful milestones (task started, segment completed, error hit,
  final result). This is a standing preference for all multi-step work.

## TextToTalk (GitHub)

[TextToTalk](https://github.com/chenwr727/TextToTalk) is a full-featured
text-to-video tool with AI outline generation, storyboard preview, and
Remotion rendering. It works on x86 but has ARM compatibility issues.

- **Do NOT use `msedge-tts`** — it gets 403 in China. If using TextToTalk,
  patch `server/src/services/tts/edge.ts` to call Python `edge-tts` instead.
- **Build with Alpine mirror:** The default Tuna mirror may 403. Switch to
  `mirrors.aliyun.com/alpine` in the Dockerfile.
- **Bundle must exist before render:** Run `node scripts/bundle.mjs` in
  `server/render/` before starting the server, or Remotion will fail with
  "Webpack bundle not found".

## Video Enhancement Options

When plain color background + text looks too单调, upgrade the visuals:

**FFmpeg-only enhancements (no extra dependencies):**
- Gradient backgrounds: `gradients=s=1920x1080:d={dur}:r=30:c0={c1}:c1={c2}:c2={c3}:c3={c1}`
- Decorative elements: `drawbox=x=0:y=0:w=12:h=1080:color={accent}:t=fill` (side bar)
- Info bar: `drawbox=x=0:y=h-60:w=1920:h=60:color=black@0.5:t=fill`
- Text shadow: duplicate drawtext with offset + black color
- Multiple color themes: tech blue, fresh green, warm orange, dark red

**AI video generation APIs (with free tier):**
- 阿里云万相 (Bailian): 30s free quota, API accessible, up to 30s per clip
- 即梦 AI: web-only for free users, no API, requires membership for CLI

## Free AI Video Generation (China)

| Platform | Free Tier | API | Notes |
|----------|-----------|-----|-------|
| 阿里云万相 | 30s free on signup | ✅ DashScope API | Best for automation |
| 即梦 AI | 60 credits/day | ❌ CLI needs membership | Web only for free |
| 豆包 Seedance | 6-10/day | ❌ | Web only |
| 智谱清影 | Daily quota | ❌ | Web only |
| Vidu | 20/day | ❌ | Web only |

**即梦 CLI limitation:** The `dreamina` CLI (installed via `curl -s https://jimeng.jianying.com/cli | bash`) requires a paid membership. Free accounts get `login success, but no dreamina_cli usage permission`. Do not install unless user has membership.

## References

- `references/tts-engines.md` — TTS engine comparison, China accessibility, voice list
- `references/chinese-fonts.md` — Chinese font installation for FFmpeg drawtext
