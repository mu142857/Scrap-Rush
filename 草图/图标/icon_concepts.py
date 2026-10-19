"""REWIND RUSH 游戏图标的三个小方案（64×64），挑一个再细画。"""
import math
import sys
import numpy as np
from PIL import Image

BG = [(10, 9, 12), (16, 14, 18), (22, 19, 24)]
GLOW = [(36, 26, 22), (58, 40, 28), (92, 60, 34), (132, 88, 44)]
IRON = [(30, 24, 22), (46, 38, 34), (66, 54, 44), (84, 68, 54), (112, 92, 70), (140, 116, 86)]
GLASS = [(214, 150, 72), (255, 211, 138), (255, 240, 200)]
REW = (150, 92, 44)
TAPE = [(20, 18, 22), (32, 29, 36), (48, 44, 54), (70, 64, 78)]


def new(n=64):
    a = np.zeros((n, n, 3), np.uint8)
    a[:] = BG[0]
    return a


def rect(a, x0, y0, x1, y1, c):
    a[max(0, y0):y1 + 1, max(0, x0):x1 + 1] = c


def disc(a, cx, cy, r, c):
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                a[y, x] = c


def glow(a, cx, cy, rs):
    for r, c in zip(rs, GLOW):
        disc(a, cx, cy, r, c)


def rewind(a, cx, cy, h, c):
    """◀◀：两个往左的实心三角，高 h（奇数）。"""
    half = h // 2
    for k in range(2):
        tip = cx - half - 1 + k * (half + 1)
        for dy in range(-half, half + 1):
            w = half - abs(dy)
            rect(a, tip + (half - w) - half + half - (half - w), cy + dy, tip + half, cy + dy, c) if False else None
            x0 = tip + abs(dy)
            rect(a, x0, cy + dy, tip + half, cy + dy, c)


def lantern(a, cx, top, s=1):
    """马灯：提环、顶盖、玻璃罩（四根铁框）、底座。s 是倍数（1 = 64 图里的尺寸）。"""
    gw, gh = 16 * s, 18 * s
    gx0, gy0 = cx - gw // 2, top + 9 * s
    # 提环
    for t in range(0, 181, 3):
        x = cx + round(6 * s * math.cos(math.radians(t)))
        y = top + 4 * s - round(4 * s * math.sin(math.radians(t)))
        rect(a, x, y, x + s - 1, y + s - 1, IRON[4] if t > 90 else IRON[2])
    # 顶盖：梯形
    for i in range(5 * s):
        w = 4 * s + i * 2
        rect(a, cx - w // 2, top + 4 * s + i, cx + w // 2 - 1, top + 4 * s + i, IRON[3] if i < 2 * s else IRON[2])
    rect(a, gx0 - 2 * s, gy0 - s, gx0 + gw + 2 * s - 1, gy0 - 1, IRON[4])
    # 玻璃
    rect(a, gx0, gy0, gx0 + gw - 1, gy0 + gh - 1, GLASS[1])
    disc(a, cx, gy0 + gh / 2, 5 * s, GLASS[2])
    rect(a, gx0, gy0, gx0 + gw - 1, gy0 + s - 1, GLASS[0])
    # 铁框
    for x in (gx0, gx0 + gw - s):
        rect(a, x, gy0, x + s - 1, gy0 + gh - 1, IRON[3] if x == gx0 else IRON[1])
    # 底座
    rect(a, gx0 - 2 * s, gy0 + gh, gx0 + gw + 2 * s - 1, gy0 + gh + 2 * s - 1, IRON[3])
    rect(a, gx0 - 2 * s, gy0 + gh, gx0 + gw + 2 * s - 1, gy0 + gh, IRON[4])
    rect(a, gx0 - 3 * s, gy0 + gh + 2 * s, gx0 + gw + 3 * s - 1, gy0 + gh + 3 * s - 1, IRON[1])
    return gx0, gy0, gw, gh


def concept_a():
    a = new()
    glow(a, 32, 33, [30, 24, 18, 13])
    gx0, gy0, gw, gh = lantern(a, 32, 8)
    rewind(a, 32, gy0 + gh // 2, 7, REW)
    return a


def cassette(a, x0, y0, w, h):
    rect(a, x0, y0, x0 + w - 1, y0 + h - 1, TAPE[2])
    rect(a, x0, y0, x0 + w - 1, y0, TAPE[3])
    rect(a, x0 + 3, y0 + 3, x0 + w - 4, y0 + 7, (200, 150, 86))             # 标签
    rect(a, x0 + 5, y0 + 5, x0 + w - 6, y0 + 5, (150, 100, 56))
    rect(a, x0 + 6, y0 + 10, x0 + w - 7, y0 + h - 5, TAPE[0])                 # 窗
    for cx in (x0 + 13, x0 + w - 14):
        disc(a, cx, y0 + 14.5, 4, TAPE[3])
        disc(a, cx, y0 + 14.5, 1.6, TAPE[0])


def concept_b():
    a = new()
    glow(a, 32, 22, [24, 18, 13, 9])
    cassette(a, 6, 38, 52, 22)
    lantern_small = np.zeros_like(a)
    gx0, gy0, gw, gh = lantern(a, 32, 2, 1) if False else (0, 0, 0, 0)
    # 小一号马灯（站在磁带上）
    lantern(a, 32, 4, 1)
    return a


def concept_c():
    """马灯 + 从玻璃里往两边扯出来的一条磁带（像在倒带），磁带上 ◀◀。"""
    a = new()
    glow(a, 32, 30, [28, 22, 16, 11])
    for x in range(2, 62):
        y = 52 + round(3 * math.sin(x / 6.0))
        rect(a, x, y, x, y + 3, TAPE[2])
        a[y, x] = TAPE[3]
    gx0, gy0, gw, gh = lantern(a, 32, 6)
    rewind(a, 32, gy0 + gh // 2, 7, REW)
    rewind(a, 50, 57, 5, (200, 150, 86))
    return a


def main(out):
    ims = [concept_a(), concept_b(), concept_c()]
    S = 6
    sheet = Image.new("RGB", (3 * (64 * S + 20) + 20 + 3 * 40, 64 * S + 40), (40, 40, 44))
    for i, a in enumerate(ims):
        im = Image.fromarray(a)
        sheet.paste(im.resize((64 * S, 64 * S), Image.NEAREST), (20 + i * (64 * S + 60), 20))
        sheet.paste(im.resize((32, 32), Image.NEAREST), (20 + i * (64 * S + 60) + 64 * S + 4, 20))
        sheet.paste(im.resize((16, 16), Image.NEAREST), (20 + i * (64 * S + 60) + 64 * S + 4, 60))
    sheet.save(out)


main(sys.argv[1])
