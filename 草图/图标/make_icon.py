"""REWIND RUSH / 倒带冲刺 的游戏图标（放映机会话，10-19）。

    "/Users/jiamulin/Desktop/程序programs/AI Oscar/.venv/bin/python" make_icon.py

图案：游戏里那盏马灯（铁框、暖黄玻璃），玻璃里透出一个 ◀◀ 倒带符号，外面一圈圈台阶状的暖光，深色底。
- 16、32：一格一格手点（ICON16、ICON32），不是缩小来的。
- 64：单独画（lantern64），细节多一点：提环、顶盖、四根铁框、底座、灯芯的白光。
- 128、256、512：64 的 2、4、8 倍最近邻放大（像素方正）。
输出 oscar-rush/art/icon/icon_<n>.png 和 Oscar Rush/itch素材/icon_<n>.png（RGBA：深色圆角方块，四边留透明边）。
颜色和游戏里的马灯（scripts/crystal/crystal.gd）同一套：铁 (46,38,34)/(84,68,54)，玻璃 (255,211,138)，灯芯 (255,240,200)。
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUTS = [ROOT / "oscar-rush/art/icon", ROOT / "itch素材"]

BG = (12, 10, 14)
GLOW = [(30, 22, 20), (50, 35, 27), (80, 54, 33), (118, 80, 42)]
IRON = [(28, 23, 21), (46, 38, 34), (64, 52, 43), (84, 68, 54), (112, 92, 70), (146, 120, 88)]
GLASS = [(214, 150, 72), (255, 211, 138), (255, 240, 200)]
REW = (156, 94, 44)

KEY = {".": None, "a": IRON[0], "b": IRON[1], "c": IRON[2], "d": IRON[3], "e": IRON[4], "f": IRON[5],
       "G": GLASS[0], "H": GLASS[1], "I": GLASS[2], "r": REW}


def canvas(n):
    a = np.zeros((n, n, 3), np.uint8)
    a[:] = BG
    return a


def disc(a, cx, cy, r, c):
    ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    m = (xs + 0.5 - cx) ** 2 + (ys + 0.5 - cy) ** 2 <= r * r
    a[m] = c


def glow(a, cx, cy, rs):
    for r, c in zip(rs, GLOW):
        disc(a, cx, cy, r, c)


def stamp(a, rows, x0, y0):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            c = KEY[ch]
            if c is not None:
                a[y0 + y, x0 + x] = c


# ---------------------------------------------------------------- 16：手点
ICON16 = [
    "....dd....",
    "...e..c...",
    "...eddc...",
    "..eddddc..",
    "fddddddddb",
    "eHHHHHHHHb",
    "eHHHrHHrHb",
    "eHHrrHrrHb",
    "eHrrrrrrHb",
    "eHHrrHrrHb",
    "eHHHrHHrHb",
    "eGGGGGGGGb",
    "fddddddddb",
    "acccccccca",
]


def icon16():
    a = canvas(16)
    glow(a, 8, 8.5, [8, 6.5, 5.2])
    stamp(a, ICON16, 3, 1)
    return a


# ---------------------------------------------------------------- 32：手点
ICON32 = [
    "......dddd......",
    ".....e....c.....",
    "....e......c....",
    "....e......c....",
    ".....eddddc.....",
    "....eddddddc....",
    "...eddddddddb...",
    ".eeddddddddddbb.",
    ".edHHHHHHHHHHba.",
    ".edHHHHHHHHHHba.",
    ".edHHHHrHHHrHba.",
    ".edHHHrrHHrrHba.",
    ".edHHrrrHrrrHba.",
    ".edHrrrrrrrrHba.",
    ".edHHrrrHrrrHba.",
    ".edHHHrrHHrrHba.",
    ".edHHHHrHHHrHba.",
    ".edHHHHHHHHHHba.",
    ".edGGGGGGGGGGba.",
    ".eeddddddddddbb.",
    "..cccccccccccc..",
    ".bbbbbbbbbbbbbb.",
]


def icon32():
    a = canvas(32)
    glow(a, 16, 16.5, [16, 13, 10, 7.5])
    stamp(a, ICON32, 8, 3)
    return a


# ---------------------------------------------------------------- 64：单独画
def rect(a, x0, y0, x1, y1, c):
    a[max(0, y0):y1 + 1, max(0, x0):x1 + 1] = c


def rewind(a, x0, cy, h, c):
    """◀◀：两个往左的实心三角，高 h（奇数），每个宽 (h+1)/2，两个之间不留缝。x0 是左边那个尖。"""
    half = h // 2
    w = half + 1
    for k in range(2):
        tip = x0 + k * w
        for dy in range(-half, half + 1):
            rect(a, tip + abs(dy), cy + dy, tip + half, cy + dy, c)


def lantern64(a, cx, top):
    gw, gh = 22, 24
    gx0, gy0 = cx - gw // 2, top + 13
    # 提环：半圆，左边受光亮一档
    for t in range(0, 181, 2):
        x = cx + round(8 * math.cos(math.radians(t))) - 1
        y = top + 6 - round(6 * math.sin(math.radians(t)))
        rect(a, x, y, x + 1, y + 1, IRON[4] if t > 100 else IRON[2])
    # 顶盖：两级的梯形（上窄下宽），左亮右暗
    for i in range(7):
        w = 8 + i * 2
        for x in range(cx - w // 2, cx + w // 2):
            c = IRON[4] if x < cx - w // 2 + 3 else (IRON[1] if x > cx + w // 2 - 4 else IRON[3])
            a[top + 5 + i, x] = c
    rect(a, gx0 - 3, gy0 - 2, gx0 + gw + 2, gy0 - 1, IRON[3])
    rect(a, gx0 - 3, gy0 - 2, gx0 + gw + 2, gy0 - 2, IRON[5])
    # 玻璃 + 灯芯的光
    rect(a, gx0, gy0, gx0 + gw - 1, gy0 + gh - 1, GLASS[1])
    disc(a, cx, gy0 + gh / 2, 8.5, GLASS[2])
    rect(a, gx0, gy0 + gh - 3, gx0 + gw - 1, gy0 + gh - 1, GLASS[0])
    rewind(a, cx - 7, gy0 + gh // 2, 9, REW)
    # 四根铁框：两边各一根粗的（左亮右暗），中间两根细的竖条只在玻璃上下露头
    rect(a, gx0, gy0, gx0 + 1, gy0 + gh - 1, IRON[4])
    rect(a, gx0 + gw - 2, gy0, gx0 + gw - 1, gy0 + gh - 1, IRON[1])
    for x in (gx0 + 7, gx0 + gw - 8):
        rect(a, x, gy0, x, gy0 + 1, IRON[2])
        rect(a, x, gy0 + gh - 2, x, gy0 + gh - 1, IRON[2])
    # 底座：一块板 + 下面一圈更宽的暗边
    rect(a, gx0 - 3, gy0 + gh, gx0 + gw + 2, gy0 + gh + 2, IRON[3])
    rect(a, gx0 - 3, gy0 + gh, gx0 + gw + 2, gy0 + gh, IRON[5])
    rect(a, gx0 + gw - 1, gy0 + gh + 1, gx0 + gw + 2, gy0 + gh + 2, IRON[1])
    rect(a, gx0 - 4, gy0 + gh + 3, gx0 + gw + 3, gy0 + gh + 4, IRON[1])


def icon64():
    a = canvas(64)
    glow(a, 32, 33, [32, 26, 20, 15])
    lantern64(a, 32, 6)
    return a


def tile_alpha(a, margin, radius):
    """透明底的圆角方块：四边留 margin 格透明，四个角按 radius 切圆（游戏细节讨论会话 10-19 约的：
    RGBA 透明底、四边留 1~2 像素、浅色和深色的浏览器标签上都看得清 → 深色方块本身就是底）。"""
    n = a.shape[0]
    al = np.zeros((n, n), np.uint8)
    al[margin:n - margin, margin:n - margin] = 255
    for cy, cx in ((margin, margin), (margin, n - margin - 1), (n - margin - 1, margin), (n - margin - 1, n - margin - 1)):
        for dy in range(radius):
            for dx in range(radius):
                y = cy + (dy if cy == margin else -dy)
                x = cx + (dx if cx == margin else -dx)
                if (radius - dx - 0.5) ** 2 + (radius - dy - 0.5) ** 2 > radius ** 2:
                    al[y, x] = 0
    return np.dstack([a, al])


def main():
    sizes = {16: tile_alpha(icon16(), 1, 2), 32: tile_alpha(icon32(), 1, 3), 64: tile_alpha(icon64(), 2, 5)}
    for k in (2, 4, 8):
        sizes[64 * k] = np.kron(sizes[64], np.ones((k, k, 1), np.uint8))
    for out in OUTS:
        out.mkdir(parents=True, exist_ok=True)
        for n, a in sizes.items():
            Image.fromarray(a).save(out / f"icon_{n}.png")
    # 预览：各尺寸 1 倍并排 + 放大
    prev = Image.new("RGB", (16 * 8 + 32 * 4 + 64 * 2 + 40, 140), (44, 44, 50))
    x = 10
    for n, s in ((16, 8), (32, 4), (64, 2)):
        im = Image.fromarray(sizes[n]).resize((n * s, n * s), Image.NEAREST)
        prev.paste(im, (x, 4), im)
        x += n * s + 10
    prev.save(HERE / "icon_preview.png")
    print("ok", sorted(sizes))


if __name__ == "__main__":
    main()
