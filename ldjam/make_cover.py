import sys
from PIL import Image, ImageDraw, ImageFont
import numpy as np
S, OUT = sys.argv[1], sys.argv[2]
FONT = "/Users/jiamulin/Desktop/程序programs/小游戏/meme/meme/Shared/PixelFont.ttf"
CX, FLOOR = 24, 405          # crop left edge and floor line in scene coords
W, H = 160, 128              # native canvas, x4 -> 640x512

scene = np.array(Image.open(f"{S}/scene_clean.png").convert("RGB")).astype(float)
crop = scene[FLOOR - 108:FLOOR + 20, CX:CX + W]

# darken, then stepped warm lantern glow (hard bands, no gradients)
lx, ly = 50, 104
yy, xx = np.mgrid[0:H, 0:W]
d = np.hypot((xx - lx) * 0.9, yy - ly)
img = crop * 0.42
warm = np.array([255, 196, 120])
for r, k in [(70, 0.10), (46, 0.22), (28, 0.38), (14, 0.55)]:
    m = d < r
    img[m] = img[m] * (1 - k * 0.35) + crop[m] * k + warm * k * 0.18
img = np.clip(img, 0, 255).astype(np.uint8)
canvas = Image.fromarray(img).convert("RGBA")

# crew: big row of the character sheet, standing on the floor
chars = Image.open(f"{S}/chars.png").convert("RGBA")
spans = [(4, 11), (18, 31), (33, 46), (50, 62)]
x = 40
for x0, x1 in spans:
    sp = chars.crop((x0, 29, x1, 48))
    canvas.alpha_composite(sp, (x, FLOOR - 298 - 19 + 1 + 6))
    x += (x1 - x0) + 4

# lantern: a tiny warm block in the red figure's hand
dr = ImageDraw.Draw(canvas)
dr.rectangle((47, 105, 49, 108), fill=(255, 214, 140, 255))
dr.point((48, 104), fill=(90, 70, 50, 255))

def text_layer(s, size, scale, fill, shadow):
    f = ImageFont.truetype(FONT, size)
    l, t, r, b = f.getbbox(s)
    im = Image.new("RGBA", (r - l + 2, b - t + 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im); d.fontmode = "1"
    d.text((1 - l, 1 - t), s, font=f, fill=shadow)
    d.text((-l, -t), s, font=f, fill=fill)
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)

title = text_layer("SCRAP RUSH", 11, 2, (240, 200, 130, 255), (20, 14, 12, 255))
canvas.alpha_composite(title, ((W - title.width) // 2, 10))
sub = text_layer("LUDUM DARE 60 / OLD TECH", 11, 1, (150, 140, 130, 255), (20, 14, 12, 255))
canvas.alpha_composite(sub, ((W - sub.width) // 2, 10 + title.height + 3))

canvas.convert("RGB").resize((W * 4, H * 4), Image.NEAREST).save(OUT)
print(canvas.size, title.size, sub.size)
