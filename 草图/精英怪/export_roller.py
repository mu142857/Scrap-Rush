"""蒸汽压路机的游戏动画帧（照 elites.py 里定稿的 roller 草图，加上轮子转动、蒸汽、速度线、晕眩）。

    python3 export_roller.py     # 写到 oscar-rush/art/enemies/roller.png，同时在本文件夹出一张放大预览

画布 54×38，原图朝左，地面是最后一行。5 帧：
0、1 开动（后轮辐条转半格，两帧来回）
2 蓄力（烟囱冒汽，红灯更亮一格）
3 冲撞（烟囱喷汽 + 身后速度线）
4 晕（撞墙以后：头顶三颗转圈的火星，烟囱歪着冒一小口）
红灯在 (7, 15)，烟囱口在 (11, 3)。
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image

from elites import G

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "oscar-rush" / "art" / "enemies"
W, H = 54, 38
OX, OY = 2, 4


def body(g, spoke_phase=0.0):
    ox, oy = OX, OY
    # 后轮（大轮，带辐条），辐条按 spoke_phase 转
    g.disk(ox + 38, oy + 24, 8.5, 6)
    g.disk(ox + 38, oy + 24, 7.5, 2)
    for k in range(8):
        a = spoke_phase + k * math.pi / 4
        g.line(ox + 38, oy + 24, round(ox + 38 + 7 * math.cos(a)), round(oy + 24 + 7 * math.sin(a)), 4)
    g.disk(ox + 38, oy + 24, 1.6, 7)
    for a in range(0, 360, 30):                                       # 轮缘上的抓地齿
        rad = math.radians(a) + spoke_phase
        x = round(ox + 38 + 8.6 * math.cos(rad))
        y = round(oy + 24 + 8.6 * math.sin(rad))
        g.put(x, y, 7 if y < oy + 24 else 5)
    # 驾驶棚
    g.rect(ox + 26, oy + 1, ox + 47, oy + 2, 8)
    g.rect(ox + 26, oy + 1, ox + 47, oy + 1, 9)
    g.rect(ox + 28, oy + 3, ox + 28, oy + 16, 5)
    g.rect(ox + 45, oy + 3, ox + 45, oy + 15, 4)
    g.disk(ox + 36, oy + 10, 3.5, 5, ring=1)
    g.disk(ox + 36, oy + 10, 0.8, 7)
    # 锅炉
    for y, c in [(oy + 8, 9), (oy + 9, 8), (oy + 10, 7), (oy + 11, 6), (oy + 12, 6), (oy + 13, 5), (oy + 14, 5),
                 (oy + 15, 4), (oy + 16, 3)]:
        g.rect(ox + 7, y, ox + 31, y, c)
    for x in (ox + 15, ox + 24):
        g.rect(x, oy + 8, x, oy + 16, 7)
        for y in range(oy + 9, oy + 16, 2):
            g.put(x, y, 9)
    # 烟箱 + 红灯
    g.box(ox + 4, oy + 8, ox + 7, oy + 16, base=3, top=8, left=6, right=4, bottom=2)
    g.led(ox + 5, oy + 11)
    # 烟囱
    g.rect(ox + 10, oy + 0, ox + 12, oy + 7, 5)
    g.rect(ox + 10, oy + 0, ox + 10, oy + 7, 7)
    g.rect(ox + 9, oy - 1, ox + 13, oy, 8)
    g.rect(ox + 9, oy - 1, ox + 13, oy - 1, 9)
    # 前滚筒和叉架；滚筒上的亮点跟着转
    g.rect(ox + 7, oy + 17, ox + 9, oy + 20, 5)
    g.rect(ox + 4, oy + 17, ox + 12, oy + 17, 7)
    g.disk(ox + 8, oy + 25, 7.6, 5)
    g.disk(ox + 8, oy + 25, 7.6, 8, ring=1)
    for y in range(oy + 25, oy + 33):
        for x in range(ox, ox + 17):
            if g.a[y, x] == 8:
                g.a[y, x] = 4
    g.disk(ox + 8, oy + 25, 5.0, 3, ring=1)
    g.disk(ox + 8, oy + 25, 1.5, 7)
    a = spoke_phase * 2
    g.put(round(ox + 8 + 3.2 * math.cos(a)), round(oy + 25 + 3.2 * math.sin(a)), 7)


def puffs(g, n):
    ox, oy = OX, OY
    for cx, cy, r in [(ox + 11, oy - 3, 1.6), (ox + 14, oy - 4, 2.0), (ox + 18, oy - 4, 1.5)][:n]:
        g.disk(cx, cy, r, "s")
    if n >= 2:
        g.pts([(ox + 12, oy - 4), (ox + 15, oy - 5)], "S")


def frame(kind):
    g = G(W, H)
    if kind == "driveA":
        body(g, 0.0)
    elif kind == "driveB":
        body(g, math.pi / 8)
    elif kind == "windup":
        body(g, 0.0)
        puffs(g, 2)
        g.put(OX + 4, OY + 11, "L")
        g.put(OX + 5, OY + 12, "l")
    elif kind == "charge":
        body(g, math.pi / 8)
        puffs(g, 3)
        for y, x0 in [(OY + 12, 47), (OY + 18, 49), (OY + 22, 48), (OY + 28, 49)]:
            for x in range(x0, W, 2):
                g.put(x, y, 6)
    elif kind == "stun":
        body(g, 0.0)
        g.disk(OX + 9, OY - 3, 1.2, "s")
        for x, y in [(OX + 20, OY + 3), (OX + 24, OY + 1), (OX + 28, OY + 4)]:  # 头顶转圈的火星
            g.put(x, y, "S")
            g.put(x + 1, y, 9)
    return g.rgba()


def main():
    frames = [frame(k) for k in ("driveA", "driveB", "windup", "charge", "stun")]
    sheet = np.concatenate(frames, axis=1)
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(sheet).save(OUT / "roller.png")
    big = Image.fromarray(sheet).resize((sheet.shape[1] * 6, sheet.shape[0] * 6), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (104, 102, 110, 255))
    bg.alpha_composite(big)
    bg.save(HERE / "_preview_roller.png")
    print("roller", W, H, len(frames), "帧")


if __name__ == "__main__":
    main()
