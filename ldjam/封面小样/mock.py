import numpy as np, random
from PIL import Image, ImageDraw, ImageFont
G = "/Users/jiamulin/Desktop/程序programs/小游戏/Oscar Rush/oscar-rush/"
OUT = "/private/tmp/claude-501/-Users-jiamulin-Desktop---programs-----Oscar-Rush/b1208ebf-b004-4ff3-8aaf-28ae9a152507/scratchpad/cover/"
FONT = G + "fonts/PixelFont.ttf"
W, H = 160, 128
random.seed(4)

def layers(names, box):
    out = None
    for n in names:
        im = Image.open(G + "art/levels/" + n).convert("RGBA").crop(box)
        out = im if out is None else Image.alpha_composite(out, im)
    bg = Image.new("RGBA", out.size, (18, 13, 10, 255))
    return Image.alpha_composite(bg, out)

def sepia(im, bright=1.0):
    a = np.asarray(im.convert("RGBA")).astype(float) / 255
    l = a[..., 0] * .3 + a[..., 1] * .59 + a[..., 2] * .11
    rgb = np.stack([l * 1.08, l * .86, l * .6], -1) * bright
    out = np.concatenate([np.clip(rgb, 0, 1), a[..., 3:]], -1)
    return Image.fromarray((out * 255).astype(np.uint8))

def glow(im, c, rings, warm=(255, 196, 120)):
    """马灯光：一圈圈硬边的暖光（不用渐变）"""
    a = np.asarray(im).astype(float)
    yy, xx = np.mgrid[0:im.size[1], 0:im.size[0]]
    d = np.hypot(xx - c[0], yy - c[1])
    for r, k in rings:
        m = d < r
        a[m, :3] = a[m, :3] * (1 + k) + np.array(warm) * k * 0.25
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))

def crew(im, feet, frame=5, gap=15):
    for k, n in reversed(list(enumerate(["red", "robot", "dino", "bird"]))):
        x, y = feet[0] - k * gap, feet[1]
        f = (frame + k) % 3 + 4
        for part in ("body", "strip"):
            sp = Image.open(G + f"art/chars/{n}_{part}.png").convert("RGBA").crop((f * 16, 0, f * 16 + 16, 20))
            im.alpha_composite(sp, (x - 8, y - 20))
    # 马灯（照 crystal.gd 的形状）
    d = ImageDraw.Draw(im)
    bx, by = feet[0] + 6, feet[1] - 2
    rows = [(-9, 0, 1, 0), (-8, -1, 3, 0), (-7, -2, 5, 1), (-6, -2, 5, 1), (-6, -1, 3, 2), (-5, -2, 5, 1), (-5, -1, 3, 2), (-5, 0, 1, 3),
            (-4, -2, 5, 1), (-4, -1, 3, 2), (-4, 0, 1, 3), (-3, -2, 5, 1), (-3, -1, 3, 2), (-2, -2, 5, 1), (-1, -3, 7, 0)]
    cols = [(46, 38, 34), (84, 68, 54), (255, 211, 138), (255, 240, 200)]
    for y, x0, w, c in rows:
        d.rectangle((bx + x0, by + y, bx + x0 + w - 1, by + y), fill=cols[c] + (255,))
    return (bx, by - 5)

def glyph_mask(s):
    """字体的真实像素：按 140 号画（这款字一个像素 = 1/14 字号，140 号时正好 10×10），找对齐的格子，每格取中心。
    不能直接用 11 号不抗锯齿画：FreeType 的 hinting 会把笔画加粗、挤歪（作者看出来"字有问题"）；
    游戏里 Hud.font() 是关了 hinting 的，和这里取出来的一样"""
    F = ImageFont.truetype(FONT, 140)
    L, T, R, B = F.getbbox(s)
    big = Image.new("L", (R + 40, B + 40), 0)
    ImageDraw.Draw(big).text((20, 20), s, font=F, fill=255)
    arr = np.array(big)
    best = None
    for ox in range(10):
        for oy in range(10):
            smp = arr[oy + 5::10, ox + 5::10].astype(float)
            sc = np.mean(np.minimum(smp, 255 - smp))
            if best is None or sc < best[0]:
                best = (sc, ox, oy)
    m = arr[best[2] + 5::10, best[1] + 5::10] > 128
    ys, xs = np.nonzero(m)
    return m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def text(im, s, y, scale, fill, outline=(14, 9, 6), x=None):
    """像素字：字形照游戏（见 glyph_mask），外面一圈 1 像素暗边，整数倍放大"""
    g = glyph_mask(s)
    m = np.zeros((g.shape[0] + 2, g.shape[1] + 2), bool)
    m[1:-1, 1:-1] = g
    o = np.zeros_like(m)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            o |= np.roll(np.roll(m, dy, 0), dx, 1)
    rgba = np.zeros(m.shape + (4,), np.uint8)
    rgba[o] = outline + (255,)
    rgba[m] = fill + (255,)
    t1 = Image.fromarray(rgba)
    t1 = t1.resize((t1.width * scale, t1.height * scale), Image.NEAREST)
    im.alpha_composite(t1, (((W - t1.width) // 2) if x is None else x, y))
    return t1.width

def bands(im, top=7, bot=7, hole=(4, 3), step=10, base=(30, 22, 16), hc=(110, 92, 70), off=3):
    d = ImageDraw.Draw(im)
    for y0 in (0, H - bot):
        h = top if y0 == 0 else bot
        d.rectangle((0, y0, W - 1, y0 + h - 1), fill=base + (255,))
        for x in range(off, W, step):
            d.rectangle((x, y0 + (h - hole[1]) // 2, x + hole[0] - 1, y0 + (h - hole[1]) // 2 + hole[1] - 1), fill=hc + (255,))

def scratches(im, n=4):
    d = ImageDraw.Draw(im)
    for _ in range(n):
        x = random.randint(4, W - 4); y = random.randint(10, 60)
        d.line((x, y, x, y + random.randint(20, 50)), fill=(255, 240, 210, 70))
    for _ in range(8):
        d.point((random.randint(0, W), random.randint(8, H - 8)), fill=(10, 6, 4, 200))

def bar(im, y0, y1, a=170):
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    d.rectangle((0, y0, W, y1), fill=(8, 5, 4, a)); im.alpha_composite(ov)

def save(im, name):
    im.convert("RGB").resize((W * 4, H * 4), Image.NEAREST).save(OUT + name)

L2 = ["level2_far_0.png", "level2_mid_0.png", "level2_main_0.png"]
# ---------- A 整格胶片：片库里四个人提灯走向家的画，整张棕褐色，只有马灯是暖的
room = layers(L2, (745, 196, 905, 308))            # 160×112，地面 y=300 → 104
room = Image.fromarray((np.asarray(room).astype(float) * [1.35, 1.35, 1.35, 1]).clip(0, 255).astype(np.uint8))
a = Image.new("RGBA", (W, H), (12, 8, 6, 255))
pic = sepia(room, 0.95)
lamp = crew(pic, (62, 104))
pic = glow(pic, lamp, [(40, 0.12), (26, 0.22), (14, 0.35)])
a.alpha_composite(pic, (0, 8))
bands(a, 8, 8)
scratches(a)
bar(a, 8, 40, 150)
text(a, "SCRAP RUSH", 12, 2, (246, 226, 186))
text(a, "LUDUM DARE 60  /  OLD TECH", 31, 1, (200, 178, 140))
save(a, "A_film.png")

# ---------- B 彩色实景：第三关太空那块屏幕，四个人提灯站在月面上
L3 = ["l3_far_0.png", "l3_mid_0.png", "l3_screens_0.png", "l3_near_0.png"]
space = layers(L3, (1150, 758, 1310, 886))         # 地面 882 → 124
b = space.copy()
lamp = crew(b, (70, 124))
b = glow(b, lamp, [(36, 0.10), (22, 0.2), (12, 0.35)])
bar(b, 0, 34, 150)
text(b, "SCRAP RUSH", 5, 2, (255, 214, 140))
text(b, "LUDUM DARE 60  /  OLD TECH", 24, 1, (220, 214, 230))
save(b, "B_color.png")

# ---------- C 胶片 + 彩色：中间一格彩色（片库里提灯的四个人），两边是棕褐色的旧胶片，左边那格在烧
c = Image.new("RGBA", (W, H), (8, 6, 5, 255))
mid = layers(L2, (735, 200, 851, 300))             # 116×100，地面 → 100
mid = Image.fromarray((np.asarray(mid).astype(float) * [1.25, 1.25, 1.25, 1]).clip(0, 255).astype(np.uint8))
lamp = crew(mid, (52, 99))
mid = glow(mid, lamp, [(34, 0.12), (22, 0.22), (12, 0.38)])
left = sepia(layers(["scene1_far.png", "scene1_beams.png", "scene1_machines.png", "scene1_truss.png", "scene1_near.png"], (430, 150, 546, 250)).resize((116, 100)), 1.1)
right = sepia(Image.open(G + "art/boss/hometown.png").convert("RGBA").crop((150, 60, 266, 160)), 0.95)
c.alpha_composite(left, (22 - 116 - 6, 18))
c.alpha_composite(mid, (22, 18))
c.alpha_composite(right, (22 + 116 + 6, 18))
# 左边那格烧着：一条锯齿火边
d = ImageDraw.Draw(c)
for y in range(18, 118):
    e = 14 + int(3 * np.sin(y * 0.7)) + random.randint(0, 2)
    d.line((0, y, e - 4, y), fill=(8, 6, 5, 255))
    d.line((e - 4, y, e - 2, y), fill=(255, 120, 40, 255))
    d.line((e - 1, y, e, y), fill=(255, 220, 120, 255))
bands(c, 16, 10, hole=(5, 4), step=11)
text(c, "SCRAP RUSH", 1, 1, (255, 214, 140))
save(c, "C_mix_small_title.png")
c2 = c.copy()
bar(c2, 16, 44, 140)
text(c2, "SCRAP RUSH", 20, 2, (255, 214, 140))
# 盖掉上面那行小标题
d = ImageDraw.Draw(c2); d.rectangle((0, 0, W, 15), fill=(30, 22, 16, 255))
for x in range(3, W, 11):
    d.rectangle((x, 6, x + 4, 9), fill=(110, 92, 70, 255))
save(c2, "C_mix.png")

# ---------- A2 胶片 + Red 立绘：棕褐色的片库，右边 Red 的立绘（彩色、原大），左下四个人提灯走（彩色）
room2 = layers(L2, (612, 196, 772, 308))
room2 = Image.fromarray((np.asarray(room2).astype(float) * [1.35, 1.35, 1.35, 1]).clip(0, 255).astype(np.uint8))
a2 = Image.new("RGBA", (W, H), (12, 8, 6, 255))
pic = sepia(room2, 0.8)
lamp = crew(pic, (66, 104))
pic = glow(pic, lamp, [(40, 0.12), (26, 0.22), (14, 0.35)])
a2.alpha_composite(pic, (0, 8))
red = Image.open(G + "art/chars/red_portrait.png").convert("RGBA")
a2.alpha_composite(red, (W - 96 + 6, H - 8 - 96 + 6))
bands(a2, 8, 8)
scratches(a2, 3)
bar(a2, 8, 38, 140)
text(a2, "SCRAP RUSH", 11, 2, (246, 226, 186))
text(a2, "LUDUM DARE 60  /  OLD TECH", 30, 1, (200, 178, 140))
save(a2, "A2_red.png")

# ---------- A3 同 A2，标题拆两行放左边，Red 的脸不被字挡
a3 = Image.new("RGBA", (W, H), (12, 8, 6, 255))
a3.alpha_composite(pic, (0, 8))
scratches(a3, 3)                               # 划痕、灰点画在立绘后面，不划脸
a3.alpha_composite(red, (W - 96 + 8, H - 8 - 96 + 4))
bands(a3, 8, 8)
ov = Image.new("RGBA", (W, H), (0, 0, 0, 0)); dd = ImageDraw.Draw(ov)
for i, x in enumerate(range(0, 92, 2)):        # 左边一片往右变淡的暗底（2 像素一阶）
    dd.rectangle((x, 8, x + 1, 74), fill=(8, 5, 4, int(170 * (1 - i / 46))))
a3.alpha_composite(ov)
text(a3, "SCRAP", 12, 3, (246, 226, 186), x=4)
text(a3, "RUSH", 41, 3, (246, 226, 186), x=4)
text(a3, "LUDUM DARE 60", 70, 1, (214, 190, 150), x=5)
text(a3, "OLD TECH", 81, 1, (214, 190, 150), x=5)
save(a3, "A3_red.png")

# ---------- A4 / A5：不要 Ludum Dare；Red 挪到右边、只露一部分（不像 galgame），四个提灯的小人放到画面中间偏左
def base_room(x0):
    r = layers(L2, (x0, 196, x0 + 160, 308))
    r = Image.fromarray((np.asarray(r).astype(float) * [1.35, 1.35, 1.35, 1]).clip(0, 255).astype(np.uint8))
    pc = sepia(r, 0.8)
    lp = crew(pc, (78, 104))
    return glow(pc, lp, [(44, 0.12), (28, 0.22), (15, 0.38)])

def finish_frame(im):
    bands(im, 8, 8)

# A4：一行标题横在上面，Red 在右下角、头在标题下面
a4 = Image.new("RGBA", (W, H), (12, 8, 6, 255))
a4.alpha_composite(base_room(600), (0, 8))
scratches(a4, 3)
a4.alpha_composite(red, (W - 70, 34))
finish_frame(a4)
ov = Image.new("RGBA", (W, H), (0, 0, 0, 0)); dd = ImageDraw.Draw(ov)
for i, y in enumerate(range(8, 40, 2)):
    dd.rectangle((0, y, W, y + 1), fill=(8, 5, 4, int(170 * (1 - i / 16))))
a4.alpha_composite(ov)
text(a4, "SCRAP RUSH", 12, 2, (246, 226, 186))
save(a4, "A4.png")

# A5：标题两行放左上，Red 贴着右边、切掉一半
a5 = Image.new("RGBA", (W, H), (12, 8, 6, 255))
a5.alpha_composite(base_room(600), (0, 8))
scratches(a5, 3)
a5.alpha_composite(red, (W - 58, 30))
finish_frame(a5)
ov = Image.new("RGBA", (W, H), (0, 0, 0, 0)); dd = ImageDraw.Draw(ov)
for i, x in enumerate(range(0, 110, 2)):
    dd.rectangle((x, 8, x + 1, 70), fill=(8, 5, 4, int(160 * (1 - i / 55))))
a5.alpha_composite(ov)
text(a5, "SCRAP", 14, 3, (246, 226, 186), x=5)
text(a5, "RUSH", 42, 3, (246, 226, 186), x=5)
save(a5, "A5.png")

# ---------- A6（A5 的改版，作者 10-19：Red 褪色一点融进场景；四个小人大一些；标题改 REWIND RUSH）
def faded(im, k=0.5, dark=0.88):
    """彩色和棕褐色按 k 混（k=1 全彩），再压暗一点"""
    c = np.asarray(im).astype(float)
    sp = np.asarray(sepia(im, 1.0)).astype(float)
    out = c * k + sp * (1 - k)
    out[..., :3] *= dark
    out[..., 3] = c[..., 3]
    return Image.fromarray(out.clip(0, 255).astype(np.uint8))

def crew2x(im, feet, gap=13):
    """四个小人和马灯先按原大画在一张透明小图上，再整体放大 2 倍贴上去（场景还是 1 倍）"""
    lay = Image.new("RGBA", (80, 24), (0, 0, 0, 0))
    lamp = crew(lay, (66, 22), gap=gap)
    lay = lay.resize((160, 48), Image.NEAREST)
    ox, oy = feet[0] - 132, feet[1] - 44
    im.alpha_composite(lay, (ox, oy))
    return (ox + lamp[0] * 2, oy + lamp[1] * 2)

room6 = layers(L2, (600, 196, 760, 308))
room6 = Image.fromarray((np.asarray(room6).astype(float) * [1.35, 1.35, 1.35, 1]).clip(0, 255).astype(np.uint8))
pic6 = sepia(room6, 0.8)
a6 = Image.new("RGBA", (W, H), (12, 8, 6, 255))
a6.alpha_composite(pic6, (0, 8))
scratches(a6, 3)
lamp6 = crew2x(Image.new("RGBA", (W, H)), (94, 114))   # 只为了算马灯在哪
a6 = glow(a6, lamp6, [(58, 0.14), (40, 0.26), (24, 0.42)])   # 光只打在场景上，不把 Red 的手照白
a6.alpha_composite(faded(red, 0.5, 0.88), (W - 58, 42))
crew2x(a6, (94, 114))
bands(a6, 8, 8)
ov = Image.new("RGBA", (W, H), (0, 0, 0, 0)); dd = ImageDraw.Draw(ov)
for i, y in enumerate(range(8, 46, 2)):
    dd.rectangle((0, y, W, y + 1), fill=(8, 5, 4, int(150 * (1 - i / 19))))
for i, x in enumerate(range(0, 100, 2)):
    dd.rectangle((x, 46, x + 1, 74), fill=(8, 5, 4, int(110 * (1 - i / 50))))
a6.alpha_composite(ov)
text(a6, "REWIND", 12, 3, (246, 226, 186), x=4)
text(a6, "RUSH", 41, 3, (246, 226, 186), x=4)
save(a6, "A6.png")
print("ok")
