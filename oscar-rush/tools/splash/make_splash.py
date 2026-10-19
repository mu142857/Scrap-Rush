"""启动画面 art/ui/boot_splash.png（2026-10-19，游戏细节讨论会话）。
Godot 的启动画面、网页加载页的底图、网页版"点击开始"那屏，三处是同一张。

作者从封面小样里挑了 A6（ldjam/封面小样/mock.py 画的 640×512）："上下胶片齿孔带框住，大字 REWIND RUSH，
四个船员小人加马灯站一排，右边红衣立绘，暖褐色胶片调"。这里用同一套画法出 16:9：240×135 的底，整 4 倍放大成 960×540
（游戏 480×270 的 2 倍，像素和 A6 一样粗）。画法函数从 mock.py 搬来，只改了画布大小和位置。

下面那条齿孔带的孔画成亮的暖黄：网页加载时 shell.html 把还没下载到的孔盖成暗的，下载完全亮 = 这张图本身，
所以接着出来的 Godot 启动画面、"点击开始"那屏和加载页一模一样，不跳。孔的位置（BAND_Y、HOLE_X0、HOLE_STEP、HOLE）
shell.html 里抄了一份，改了这里要一起改。

用法：python3 tools/splash/make_splash.py
"""
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

G = Path(__file__).resolve().parent.parent.parent
OUT = G / "art" / "ui" / "boot_splash.png"
FONT = G / "fonts" / "PixelFont.ttf"
W, H = 240, 135
SCALE = 4
BAND = 8
BAND_Y = H - BAND               # 下面那条齿孔带的上沿
HOLE_X0, HOLE_STEP = 3, 10
HOLE = (4, 3)
HOLE_DIM = (110, 92, 70)
HOLE_LIT = (255, 211, 138)      # 和加载页、游戏里标题的暖黄一样（#ffd38a）
random.seed(4)
L2 = ["level2_far_0.png", "level2_mid_0.png", "level2_main_0.png"]


def layers(names, box):
    out = None
    for n in names:
        im = Image.open(G / "art" / "levels" / n).convert("RGBA").crop(box)
        out = im if out is None else Image.alpha_composite(out, im)
    return Image.alpha_composite(Image.new("RGBA", out.size, (18, 13, 10, 255)), out)


def sepia(im, bright=1.0):
    a = np.asarray(im.convert("RGBA")).astype(float) / 255
    l = a[..., 0] * .3 + a[..., 1] * .59 + a[..., 2] * .11
    rgb = np.stack([l * 1.08, l * .86, l * .6], -1) * bright
    return Image.fromarray((np.concatenate([np.clip(rgb, 0, 1), a[..., 3:]], -1) * 255).astype(np.uint8))


def faded(im, k=0.5, dark=0.88):
    c = np.asarray(im).astype(float)
    sp = np.asarray(sepia(im, 1.0)).astype(float)
    out = c * k + sp * (1 - k)
    out[..., :3] *= dark
    out[..., 3] = c[..., 3]
    return Image.fromarray(out.clip(0, 255).astype(np.uint8))


def glow(im, c, rings, warm=(255, 196, 120)):
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
            sp = Image.open(G / "art" / "chars" / f"{n}_{part}.png").convert("RGBA").crop((f * 16, 0, f * 16 + 16, 20))
            im.alpha_composite(sp, (x - 8, y - 20))
    d = ImageDraw.Draw(im)
    bx, by = feet[0] + 6, feet[1] - 2
    rows = [(-9, 0, 1, 0), (-8, -1, 3, 0), (-7, -2, 5, 1), (-6, -2, 5, 1), (-6, -1, 3, 2), (-5, -2, 5, 1), (-5, -1, 3, 2), (-5, 0, 1, 3),
            (-4, -2, 5, 1), (-4, -1, 3, 2), (-4, 0, 1, 3), (-3, -2, 5, 1), (-3, -1, 3, 2), (-2, -2, 5, 1), (-1, -3, 7, 0)]
    cols = [(46, 38, 34), (84, 68, 54), (255, 211, 138), (255, 240, 200)]
    for y, x0, w, c in rows:
        d.rectangle((bx + x0, by + y, bx + x0 + w - 1, by + y), fill=cols[c] + (255,))
    return (bx, by - 5)


def crew2x(im, feet, gap=13):
    lay = Image.new("RGBA", (80, 24), (0, 0, 0, 0))
    lamp = crew(lay, (66, 22), gap=gap)
    lay = lay.resize((160, 48), Image.NEAREST)
    ox, oy = feet[0] - 132, feet[1] - 44
    im.alpha_composite(lay, (ox, oy))
    return (ox + lamp[0] * 2, oy + lamp[1] * 2)


def glyph_mask(s):
    """字体的真实像素（见 mock.py 的说明：按 140 号画、找对齐的格子取中心，不让 hinting 把笔画挤歪）"""
    F = ImageFont.truetype(str(FONT), 140)
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


def bands(im, lit_bottom=True):
    d = ImageDraw.Draw(im)
    for y0 in (0, BAND_Y):
        d.rectangle((0, y0, W - 1, y0 + BAND - 1), fill=(30, 22, 16, 255))
        hc = HOLE_LIT if (y0 == BAND_Y and lit_bottom) else HOLE_DIM
        hy = y0 + (BAND - HOLE[1]) // 2
        for x in range(HOLE_X0, W, HOLE_STEP):
            d.rectangle((x, hy, x + HOLE[0] - 1, hy + HOLE[1] - 1), fill=hc + (255,))


def scratches(im, n=4):
    d = ImageDraw.Draw(im)
    for _ in range(n):
        x = random.randint(4, W - 4); y = random.randint(10, 70)
        d.line((x, y, x, y + random.randint(20, 50)), fill=(255, 240, 210, 70))
    for _ in range(10):
        d.point((random.randint(0, W), random.randint(8, H - 8)), fill=(10, 6, 4, 200))


def main() -> None:
    # 场景：第二关的片库，比 A6 左右各多取 40、上面多取 7（地面还在离下沿一样高的地方）
    room = layers(L2, (560, 189, 800, 308))
    room = Image.fromarray((np.asarray(room).astype(float) * [1.35, 1.35, 1.35, 1]).clip(0, 255).astype(np.uint8))
    pic = sepia(room, 0.8)
    im = Image.new("RGBA", (W, H), (12, 8, 6, 255))
    im.alpha_composite(pic, (0, BAND))
    scratches(im, 4)
    # 人和立绘照 A6 的相对位置，整体往右挪：Red 贴右边切掉一半，四个人站在她左边
    feet = (W - 66, H - 14)
    lamp = crew2x(Image.new("RGBA", (W, H)), feet)
    im = glow(im, lamp, [(62, 0.14), (42, 0.26), (25, 0.42)])
    red = Image.open(G / "art" / "chars" / "red_portrait.png").convert("RGBA")
    im.alpha_composite(faded(red, 0.5, 0.88), (W - 58, H - 86))
    crew2x(im, feet)
    bands(im)
    # 标题底下压暗（上面一条、左边一块），字在亮的场景上也清楚
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0)); dd = ImageDraw.Draw(ov)
    for i, y in enumerate(range(BAND, 50, 2)):
        dd.rectangle((0, y, W, y + 1), fill=(8, 5, 4, int(150 * (1 - i / 21))))
    for i, x in enumerate(range(0, 110, 2)):
        dd.rectangle((x, 50, x + 1, 80), fill=(8, 5, 4, int(110 * (1 - i / 55))))
    im.alpha_composite(ov)
    text(im, "REWIND", 14, 3, (246, 226, 186), x=5)
    text(im, "RUSH", 43, 3, (246, 226, 186), x=5)
    im.convert("RGB").resize((W * SCALE, H * SCALE), Image.NEAREST).save(OUT)
    print(f"wrote {OUT} ({W * SCALE}x{H * SCALE})")


if __name__ == "__main__":
    main()
