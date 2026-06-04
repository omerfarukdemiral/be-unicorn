#!/usr/bin/env python3
"""App Store ekran görüntüsü üretici: ham simülatör çekimlerini 1284×2778'e
narration banner'ıyla composite eder. Bağımlılık: Pillow."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1284, 2778
RAW = "/tmp/unishots_raw"
OUT = os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)

# Arial Rounded Bold'da Türkçe ş/ğ glifleri eksik (tofu) → tam destekli Arial Bold.
TITLE_FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
SUB_FONT   = "/System/Library/Fonts/Supplemental/Arial.ttf"

# Sıra + içerik: (ham dosya, çıktı adı, başlık, alt başlık, üst-arka renk)
SHOTS = [
    ("garage",   "01_garage",   "Garajda bir\nfikirle başla",        "Küçük başla, runway'ini koru",            (46, 35, 80)),
    ("growth",   "02_growth",   "Kullanıcını ve\ngelirini büyüt",     "ARPU, CAC ve viral büyümeyi dengele",     (38, 30, 74)),
    ("decision", "03_decision", "Her karar\nşirketini şekillendirir", "Tek doğru cevap yok — bedeli sen seç",    (52, 28, 66)),
    ("team",     "04_team",     "Doğru ekibi kur",                    "Mühendislik, ürün, satış — hepsi dengede", (34, 36, 78)),
    ("unicorn",  "05_unicorn",  "Hedef: 1 milyar\ndolarlık Unicorn",  "Garajdan zirveye uzanan yolculuk",        (60, 36, 86)),
]

def vgrad(top, bottom):
    base = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / (H - 1)
        base.putpixel((0, y), tuple(int(top[i] + (bottom[i]-top[i])*t) for i in range(3)))
    return base.resize((W, H))

def rounded(img, r):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0], img.size[1]], radius=r, fill=255)
    out = Image.new("RGBA", img.size, (0,0,0,0))
    out.paste(img, (0,0), mask)
    return out

def wrap_center(draw, text, font, max_w):
    # \n zaten elle sarılı; her satırı olduğu gibi döndür
    return text.split("\n")

BOTTOM = (16, 12, 26)
TITLE_COLOR = (245, 243, 252)
SUB_COLOR = (185, 175, 220)
ACCENT = (255, 143, 184)

for raw, name, title, sub, top in SHOTS:
    canvas = vgrad(top, BOTTOM).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # --- üst aksan şeridi ---
    draw.rounded_rectangle([(W-120)//2, 96, (W+120)//2, 110], radius=7, fill=ACCENT)

    # --- başlık ---
    tf = ImageFont.truetype(TITLE_FONT, 96)
    sf = ImageFont.truetype(SUB_FONT, 46)
    y = 168
    for line in title.split("\n"):
        w = draw.textlength(line, font=tf)
        draw.text(((W - w)//2, y), line, font=tf, fill=TITLE_COLOR)
        y += 112
    y += 14
    w = draw.textlength(sub, font=sf)
    draw.text(((W - w)//2, y), sub, font=sf, fill=SUB_COLOR)

    # --- cihaz görüntüsü ---
    shot = Image.open(os.path.join(RAW, f"{raw}.png")).convert("RGB")
    # simülatör kenar artefaktını kırp (4px)
    shot = shot.crop((4, 4, shot.width-4, shot.height-4))
    top_area = 560
    avail_h = H - top_area - 70
    scale = avail_h / shot.height
    nw, nh = int(shot.width*scale), int(shot.height*scale)
    if nw > W - 150:
        scale = (W - 150) / shot.width
        nw, nh = int(shot.width*scale), int(shot.height*scale)
    shot = shot.resize((nw, nh), Image.LANCZOS)
    shot = rounded(shot, 56)

    # yumuşak gölge
    shadow = Image.new("RGBA", canvas.size, (0,0,0,0))
    sd = ImageDraw.Draw(shadow)
    px = (W - nw)//2
    py = top_area
    sd.rounded_rectangle([px, py+18, px+nw, py+nh+18], radius=56, fill=(0,0,0,150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(shot, (px, py))

    canvas.convert("RGB").save(os.path.join(OUT, f"{name}.png"), "PNG")
    print(f"{name}.png  {W}x{H}")

print("DONE ->", OUT)
