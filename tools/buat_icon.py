"""Atur ukuran gambar di icon launcher.

Cara pakai (dari folder project):
  1. Ubah nilai SKALA di bawah
  2. python3 tools/buat_icon.py
  3. fvm dart run flutter_launcher_icons
  4. Uninstall app di HP, terus fvm flutter run

SKALA = seberapa penuh gambar ngisi kotak icon:
  1.0  = full menuhin kotak (pinggiran bisa kepotong di launcher bundar)
  0.66 = pas di "safe zone" (aman ga kepotong, tapi ada ruang putih)
"""
from PIL import Image, ImageChops

SKALA = 1.0

DIR = "assets/icon"
SIZE = 1024

src = Image.open(f"{DIR}/icon.png").convert("RGB")

# Cari batas gambar (buang pinggiran putih) biar skala-nya akurat
white = Image.new("RGB", src.size, (255, 255, 255))
diff = ImageChops.difference(src, white).convert("L")
bbox = diff.point(lambda p: 255 if p > 12 else 0).getbbox()
char = src.crop(bbox)

target = round(SIZE * SKALA)
w, h = char.size
scale = min(target / w, target / h) if SKALA < 1.0 else max(SIZE / w, SIZE / h)
scaled = char.resize((round(w * scale), round(h * scale)), Image.LANCZOS)

canvas = Image.new("RGB", (SIZE, SIZE), (255, 255, 255))
if SKALA >= 1.0:
    # Mode full: crop tengah kalau kegedean
    left = (scaled.width - SIZE) // 2
    top = (scaled.height - SIZE) // 2
    canvas = scaled.crop((left, top, left + SIZE, top + SIZE))
else:
    canvas.paste(
        scaled, ((SIZE - scaled.width) // 2, (SIZE - scaled.height) // 2)
    )

canvas.save(f"{DIR}/icon.png")
canvas.convert("RGBA").save(f"{DIR}/icon_fg.png")
Image.new("RGB", (SIZE, SIZE), (255, 255, 255)).save(f"{DIR}/icon_bg.png")
print(f"OK: icon di-generate dengan SKALA={SKALA}")
