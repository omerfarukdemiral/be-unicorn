# Audio Asset Licenses

Tüm ses dosyaları **CC0 1.0 Universal** (Public Domain Dedication) altında dağıtılır.
Hiçbir attribution zorunluluğu yoktur; aşağıdaki krediler şeffaflık ve teşekkür amaçlıdır.

CC0 metni: https://creativecommons.org/publicdomain/zero/1.0/

## Sound Effects (Sources/Audio/sfx_*.wav)

| Dosya | Kaynak Paketi | Orijinal Dosya | Yazar |
|---|---|---|---|
| `sfx_tap.wav` | Kenney — Interface Sounds | `click_002.ogg` | Kenney (kenney.nl) |
| `sfx_select.wav` | Kenney — Interface Sounds | `tick_002.ogg` | Kenney (kenney.nl) |
| `sfx_decision.wav` | Kenney — Interface Sounds | `question_002.ogg` | Kenney (kenney.nl) |
| `sfx_success.wav` | Kenney — Interface Sounds | `confirmation_002.ogg` | Kenney (kenney.nl) |
| `sfx_close.wav` | Kenney — Music Jingles (Pizzicato) | `jingles_PIZZI03.ogg` | Kenney (kenney.nl) |
| `sfx_celebrate.wav` | Kenney — Music Jingles (Hit) | `jingles_HIT07.ogg` | Kenney (kenney.nl) |
| `sfx_warning.wav` | Kenney — Interface Sounds | `error_001.ogg` | Kenney (kenney.nl) |
| `sfx_failure.wav` | Kenney — Interface Sounds | `error_006.ogg` | Kenney (kenney.nl) |

**Kenney paketleri:**
- Interface Sounds — https://kenney.nl/assets/interface-sounds (CC0)
- Music Jingles — https://kenney.nl/assets/music-jingles (CC0)

Kenney tüm asset'lerini "Creative Commons CC0" olarak dağıtır
(https://kenney.nl/license).

## Background Music (Sources/Audio/music_loop.m4a)

| Dosya | Kaynak | Orijinal Dosya | Yazar |
|---|---|---|---|
| `music_loop.m4a` | OpenGameArt — Sunset Walk / Ambient / Quiet / Sweet / Loop | `SunsetWalk.ogg` | Kilua Boy |

URL: https://opengameart.org/content/sunset-walk-ambient-quiet-sweet-loop
Lisans: CC0 (Public Domain dedication; yazar attribution'u "isteğe bağlı" olarak belirtmiş).

## Dönüştürme

OGG kaynaklarından iOS uyumlu formatlara dönüştürme:

- SFX: `ffmpeg -i <src.ogg> -acodec pcm_s16le -ar 44100 sfx_*.wav` (16-bit PCM, 44.1kHz)
- Music: `ffmpeg -i SunsetWalk.ogg -c:a aac -b:a 96k -ar 44100 music_loop.m4a` (AAC 96 kbps)

## Notlar

- AVAudioSession kategorisi `.ambient` + `mixWithOthers`: sessiz anahtarına saygı,
  kullanıcının başka müzikleri kesilmez.
- Müzik volume'u 0.32'ye düşürülmüştür (ambient/arka plan dengesi için).
- Tüm SFX dosyaları 44.1 kHz, 16-bit, mono PCM WAV.
- Tüm dosyalar `Sources/Audio/` altında ve xcodegen tarafından otomatik olarak
  uygulama bundle'ına resource olarak gömülür.
