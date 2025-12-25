# HiAnime Streaming API - Implementation Documentation

## Overview

This document explains how the HiAnime API extracts and provides video streaming URLs. Use this as context when integrating with Flutter or any video player.

---

## API Endpoint

```
GET /api/stream/{episode_id}?server_type={sub|dub|all}&include_proxy_url={true|false}
```

### Parameters:
- `episode_id`: Episode ID from HiAnime (e.g., "2142" from `?ep=2142`)
- `server_type`: `sub` (default), `dub`, or `all`
- `include_proxy_url`: If `true`, adds proxy URLs that bypass Cloudflare

---

## Response Structure

```json
{
  "success": true,
  "episode_id": "2142",
  "server_type": "sub",
  "total_streams": 3,
  "streams": [
    {
      "name": "HD-1 (SUB)",
      "server_name": "HD-1",
      "server_type": "sub",
      "sources": [
        {
          "file": "https://sunburst93.live/.../master.m3u8",
          "type": "hls",
          "quality": "auto",
          "isM3U8": true,
          "host": "sunburst93.live",
          "headers": {
            "Referer": "https://megacloud.blog/",
            "Origin": "https://megacloud.blog",
            "User-Agent": "Mozilla/5.0..."
          },
          "proxy_url": "/api/proxy/m3u8?url=...&ref=..."
        }
      ],
      "subtitles": [
        {
          "file": "https://mgstatics.xyz/.../eng-2.vtt",
          "label": "English",
          "kind": "captions"
        }
      ],
      "skips": {
        "intro": { "start": 31, "end": 111 },
        "outro": { "start": 1376, "end": 1447 }
      },
      "headers": {
        "Referer": "https://hianime.to/",
        "User-Agent": "Mozilla/5.0..."
      }
    }
  ]
}
```

---

## ⚠️ CRITICAL: Per-Source Headers

**Each source has its own `headers` object that MUST be used for playback.**

Different CDNs require different `Referer` headers:

| CDN Domain | Required Referer | Without Header |
|------------|------------------|----------------|
| `sunburst*.live` | `https://megacloud.blog/` | ❌ 403 Forbidden |
| `rainveil*.xyz` | `https://megacloud.blog/` | ❌ 403 Forbidden |
| `netmagcdn.com` | `https://megacloud.blog/` | ✅ Works (but use anyway) |
| `douvid.xyz` | `https://megacloud.blog/` | ⚠️ May redirect |

### Why Per-Source Headers?

The API extracts streams from multiple servers. Each server may use a different CDN with different security requirements. The `source.headers` contains the **correct headers for that specific CDN**.

---

## How Video Extraction Works

```
┌─────────────────────────────────────────────────────────────────────┐
│  EXTRACTION FLOW                                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. GET /ajax/v2/episode/servers?episodeId=2142                     │
│     → Returns HTML with server buttons (HD-1, HD-2, HD-3)           │
│     → Each button has data-id (server ID)                           │
│                                                                     │
│  2. For each server:                                                │
│     GET /ajax/v2/episode/sources?id={server_id}                     │
│     → Returns: {"link": "https://megacloud.blog/embed-2/..."}       │
│                                                                     │
│  3. Extract actual stream from embed URL:                           │
│     Call extraction API with megacloud embed URL                    │
│     → Decrypts and returns actual .m3u8 URL                         │
│     → Also returns subtitles, intro/outro skip times                │
│                                                                     │
│  4. Return formatted response with:                                 │
│     - Direct m3u8 URLs                                              │
│     - Per-source headers (IMPORTANT!)                               │
│     - Subtitle tracks                                               │
│     - Skip timestamps                                               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Available Servers

For each episode, the API returns up to 6 servers:

| Server | Type | Typical CDN |
|--------|------|-------------|
| HD-1 | SUB | sunburst/rainveil (fast, requires Referer) |
| HD-2 | SUB | netmagcdn (reliable) |
| HD-3 | SUB | douvid (backup) |
| HD-1 | DUB | sunburst/rainveil |
| HD-2 | DUB | netmagcdn |
| HD-3 | DUB | douvid |

---

## Flutter Integration Requirements

### 1. StreamSource Model MUST Include Headers

```dart
class StreamSource {
  final String file;           // The m3u8 URL
  final String? proxyUrl;      // Proxy URL (fallback)
  final String type;           // "hls" or "mp4"
  final String quality;        // "auto", "1080p", etc.
  final bool isM3U8;           // true for HLS streams
  final String host;           // CDN domain
  final Map<String, String> headers;  // ⬅️ REQUIRED!

  StreamSource({
    required this.file,
    this.proxyUrl,
    required this.type,
    required this.quality,
    required this.isM3U8,
    required this.host,
    required this.headers,     // ⬅️ REQUIRED!
  });

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    return StreamSource(
      file: json['file']?.toString() ?? '',
      proxyUrl: json['proxy_url']?.toString(),
      type: json['type']?.toString() ?? 'hls',
      quality: json['quality']?.toString() ?? 'auto',
      isM3U8: json['isM3U8'] ?? true,
      host: json['host']?.toString() ?? '',
      headers: Map<String, String>.from(json['headers'] ?? {}),  // ⬅️ ADD THIS!
    );
  }
}
```

### 2. Video Player MUST Use Source-Level Headers

```dart
// ❌ WRONG - Using stream-level headers
final headers = stream.headers;

// ✅ CORRECT - Using source-level headers
final source = stream.sources.first;
final headers = source.headers;

// Play with correct headers
await player.open(
  Media(
    source.file,
    httpHeaders: source.headers,  // ⬅️ Use source.headers!
  ),
);
```

### 3. Fallback Strategy

```dart
// Try sources in order:
// 1. Direct URL with source headers
// 2. Proxy URL (if direct fails)
// 3. Next server

for (final source in stream.sources) {
  try {
    // Try direct URL first
    await player.open(Media(source.file, httpHeaders: source.headers));
    return; // Success!
  } catch (e) {
    // Try proxy URL
    if (source.proxyUrl != null) {
      try {
        await player.open(Media('$baseUrl${source.proxyUrl}'));
        return; // Success!
      } catch (_) {}
    }
  }
}
// All sources failed, try next server...
```

---

## Subtitles

Subtitles are provided as VTT files:

```json
"subtitles": [
  {
    "file": "https://mgstatics.xyz/subtitle/.../eng-2.vtt",
    "label": "English",
    "kind": "captions"
  }
]
```

Load directly in video player - no special headers needed for subtitle files.

---

## Skip Intro/Outro

The API provides timestamps for intro and outro:

```json
"skips": {
  "intro": { "start": 31, "end": 111 },    // Skip from 0:31 to 1:51
  "outro": { "start": 1376, "end": 1447 }  // Skip from 22:56 to 24:07
}
```

Use these to show "Skip Intro" / "Skip Outro" buttons in your player.

---

## Error Handling

If a server fails:
1. Try the next source in the same server
2. Try the proxy URL
3. Move to the next server (HD-1 → HD-2 → HD-3)
4. Try the other type (SUB → DUB or DUB → SUB)

---

## Testing

Test the API with curl:

```bash
# Get all streams
curl "http://localhost:8000/api/stream/2142?server_type=all"

# Get SUB streams only
curl "http://localhost:8000/api/stream/2142?server_type=sub"

# Get streams with proxy URLs
curl "http://localhost:8000/api/stream/2142?server_type=sub&include_proxy_url=true"
```

Test a stream URL with headers:

```bash
curl -I "https://sunburst93.live/.../master.m3u8" \
  -H "Referer: https://megacloud.blog/" \
  -H "User-Agent: Mozilla/5.0"
# Should return 200 OK
```

---

## Summary

| Component | Location | Notes |
|-----------|----------|-------|
| m3u8 URL | `stream.sources[].file` | Direct video URL |
| **Headers** | `stream.sources[].headers` | **MUST use for playback!** |
| Proxy URL | `stream.sources[].proxy_url` | Fallback if direct fails |
| Subtitles | `stream.subtitles[].file` | VTT format |
| Skip times | `stream.skips.intro/outro` | Start/end in seconds |
| Server info | `stream.server_name` | HD-1, HD-2, HD-3 |
| Type | `stream.server_type` | sub or dub |

**The most important thing: Always use `source.headers` (not `stream.headers`) when playing video!**
