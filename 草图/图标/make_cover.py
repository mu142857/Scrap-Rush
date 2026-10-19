"""REWIND RUSH 的 itch 封面 630×500（放映机会话，10-19）。

    "/Users/jiamulin/Desktop/程序programs/AI Oscar/.venv/bin/python" make_cover.py

在 315×250 的 1 倍画布上画，最后整 2 倍最近邻放大（像素方正）：
- 上面：标题 REWIND RUSH（游戏字体，暖黄，下面一道暗影），下面一行"倒带冲刺"。
- 中间：三盘录像带横排，每盘一块游戏里的场景（不缩放，原样裁）：
  第一盘 · 蒸汽 = 第一关锅炉房的机器（art/levels/scene1.png）；
  第二盘 · 信号 = 第二关胶片天桥上的一格胶片（art/levels/level2_film.png）；
  第三盘 · 雪花 = 第三关的电视墙（草图/第三关/l3v2_screens.png）。
  每盘外面一圈录像带壳（黑色塑料、两个卷盘孔），下面一行 TAPE 1 · STEAM 之类的小字。
- 前面：一盏大马灯（和图标同一套画法，放大 2 倍），玻璃里 ◀◀，外面一圈圈暖光压在三盘带子上。
输出 Oscar Rush/itch素材/cover_630x500.png。
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import make_icon as I

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT / "oscar-rush"
FONT = GAME / "fonts/PixelFont.ttf"
W, H = 315, 250
TITLE = (255, 211, 138)
TITLE_SH = (96, 58, 30)
SUB = (196, 168, 132)
LABEL = (150, 138, 124)
SHELL = [(16, 15, 18), (26, 24, 30), (40, 37, 46), (58, 54, 66)]


def load(p):
    return np.asarray(Image.open(p).convert("RGB"))


def text(a, s, x, y, size, col, shadow=None, center=False):
    """游戏字体，按 1 倍像素画（阈值成硬边，不要抗锯齿）。"""
    f = ImageFont.truetype(str(FONT), size)
    bbox = f.getbbox(s)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    if center:
        x = x - tw // 2
    m = Image.new("L", (tw + 4, th + 4), 0)
    ImageDraw.Draw(m).text((2 - bbox[0], 2 - bbox[1]), s, fill=255, font=f)
    m = np.asarray(m) > 110
    ys, xs = np.nonzero(m)
    for dx, dy, c in ([(1, 1, shadow), (0, 2, shadow)] if shadow else []) + [(0, 0, col)]:
        yy, xx = ys + y - 2 + dy, xs + x - 2 + dx
        ok = (yy >= 0) & (yy < a.shape[0]) & (xx >= 0) & (xx < a.shape[1])
        a[yy[ok], xx[ok]] = c
    return tw, th


def tape(a, x0, y0, pic, label):
    """一盘录像带：黑色塑料壳（顶上亮一道），中间一个窗放场景，窗下两个卷盘孔，再下面一行标签字。"""
    ph, pw = pic.shape[:2]
    w, h = pw + 10, ph + 22
    I.rect(a, x0, y0, x0 + w - 1, y0 + h - 1, SHELL[1])
    I.rect(a, x0, y0, x0 + w - 1, y0, SHELL[3])
    I.rect(a, x0, y0 + 1, x0, y0 + h - 1, SHELL[2])
    I.rect(a, x0 + w - 1, y0 + 1, x0 + w - 1, y0 + h - 1, SHELL[0])
    a[y0 + 5:y0 + 5 + ph, x0 + 5:x0 + 5 + pw] = pic
    for cx in (x0 + w // 2 - 14, x0 + w // 2 + 13):          # 两个卷盘孔
        I.disc(a, cx, y0 + ph + 13, 4, SHELL[3])
        I.disc(a, cx, y0 + ph + 13, 2.2, SHELL[0])
    I.rect(a, x0 + w // 2 - 8, y0 + ph + 11, x0 + w // 2 + 7, y0 + ph + 15, SHELL[0])   # 中间的磁带窗
    text(a, label, x0 + w // 2, y0 - 13, 12, LABEL, center=True)     # 游戏字体 12 号正好一格一像素
    return w, h


def dim(pic, k=0.82):
    return (pic.astype(float) * k).astype(np.uint8)


def main():
    a = np.zeros((H, W, 3), np.uint8)
    a[:] = I.BG
    # 三盘录像带
    t1 = dim(load(GAME / "art/levels/scene1.png")[40:126, 760:846], 1.0)
    t2 = dim(load(GAME / "art/levels/level2_film.png")[2:88, 2:88], 0.9)
    t3 = dim(load(GAME / "art/levels/l3_screens_0.png")[512:598, 1744:1830], 0.9)
    xs = [10, 112, 214]
    for x, pic, lab in zip(xs, (t1, t2, t3), ("1 STEAM", "2 SIGNAL", "3 STATIC")):
        tape(a, x, 78, pic, lab)
    # 马灯的暖光：压在带子上（只把暗的地方提亮成暖色，不盖住画面）
    glow = np.zeros((H, W), np.uint8)
    ys, xs_ = np.mgrid[0:H, 0:W]
    d = np.sqrt((xs_ + 0.5 - 157.5) ** 2 + (ys + 0.5 - 196) ** 2)
    for r, k in ((70, 1), (54, 2), (40, 3), (28, 4)):
        glow[d <= r] = k
    for k in range(1, 5):
        m = glow == k
        a[m] = np.maximum(a[m], I.GLOW[k - 1])
    # 大马灯：画在 64 的画布上再放大 2 倍贴上去（深色底当透明）
    lc = np.zeros((64, 64, 3), np.uint8)
    lc[:] = I.BG
    I.lantern64(lc, 32, 6)
    big = np.kron(lc, np.ones((2, 2, 1), np.uint8))
    mask = np.any(big != np.array(I.BG, np.uint8), axis=-1)
    ox, oy = 157 - 64, 250 - 128 + 14
    sub = a[oy:oy + 128, ox:ox + 128]
    hh, ww = sub.shape[:2]
    sub[mask[:hh, :ww]] = big[:hh, :ww][mask[:hh, :ww]]
    # 标题
    text(a, "REWIND RUSH", W // 2, 14, 32, TITLE, shadow=TITLE_SH, center=True)
    text(a, "倒带冲刺", W // 2, 46, 16, SUB, center=True)
    text(a, "LUDUM DARE 60", 52, 234, 12, LABEL, center=True)
    text(a, "OLD TECH", W - 44, 234, 12, LABEL, center=True)
    out = np.kron(a, np.ones((2, 2, 1), np.uint8))
    for d_ in (ROOT / "itch素材",):
        d_.mkdir(parents=True, exist_ok=True)
        Image.fromarray(out).save(d_ / "cover_630x500.png")
    print("ok", out.shape)


if __name__ == "__main__":
    main()
