# TTS Engines Comparison

## China Accessibility

| Engine | Library | Works in China | Free | Notes |
|--------|---------|---------------|------|-------|
| Edge TTS (Python) | `edge-tts` | ✅ Yes | ✅ Free | Recommended |
| Edge TTS (Node.js) | `msedge-tts` | ❌ 403 | ✅ Free | Blocked by Microsoft |
| DashScope CosyVoice | `dashscope` | ✅ Yes | 100h/month | Needs Aliyun account |
| Qwen-Audio-TTS | `dashscope` | ✅ Yes | 100h/month | Needs Aliyun account |
| Seed-TTS | volcengine | ✅ Yes | Limited | Needs Volcengine account |

## Edge Voices (Python edge-tts)

| Voice ID | Label | Style |
|----------|-------|-------|
| `zh-CN-XiaoxiaoNeural` | 晓晓 (female) | Warm, natural |
| `zh-CN-YunxiNeural` | 云希 (male) | Calm, professional |
| `zh-CN-YunyangNeural` | 云扬 (male) | News anchor |
| `zh-CN-XiaoyiNeural` | 晓伊 (female) | Energetic, lively |
| `zh-CN-liaoning-XiaobeiNeural` | 晓北 (male) | Northeastern dialect |

## Installation

```bash
python3 -m pip install --user edge-tts
```

## Usage

```python
import asyncio
import edge_tts

tts = edge_tts.Communicate("Hello, world!", "zh-CN-XiaoxiaoNeural")
await tts.save("output.mp3")
```
