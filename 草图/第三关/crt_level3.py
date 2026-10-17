"""第三关「显像管仓库」整张地图：1440×720，1 倍像素（第一关是 1006×426）。

一整面堆起来的电视墙，三层。每块屏幕是一个能走进去的场景，屏幕大小不一：
最小的不到 100 宽，像一条通风管；最大的 420 宽，是终点"家乡"。
屏幕里不只是房间：街道、海底、海滩、太空、地铁、摩天轮、森林、屋顶、天气预报、测试卡、满屏雪花……

路线（红线，见 预览L3_路线.png）：
  左下仓库地面进 → 第一层往右走 8 个屏幕 → 右端钻洞上第二层 → 往左走 8 个 → 左端钻洞上第三层
  → 往右走 → 终点：最大的那块屏幕，里面是家乡，房子的门亮着。
另外有两个往下的近路洞（教室→地铁、摩天轮→客厅）。

画法沿用 crt_wall_v2.py（作者 2026-10-17 认可"色调无敌"），这里只加新场景和排布。
输出：
  l3_far.png / l3_mid.png / l3_screens.png / l3_near.png   1440×720 分层
  l3_layout.json   每块屏幕、地面高度、通道、洞、单向平台、起点、终点（给 Godot 接碰撞用）
  预览L3_原图.png、预览L3_游戏.png、预览L3_路线.png（1 倍），预览L3_游戏_2x.png
跑法："~/Desktop/程序programs/AI Oscar/.venv/bin/python" crt_level3.py
"""
import json
import random
from pathlib import Path

import numpy as np
from PIL import Image

import crt_wall_v2 as k
from crt_wall_v2 import (KHAKI, WOOD, GREY, PLUM, RECESS, GLARE, WALL, FLOOR_C, CABLE, PCB, COPPER,
                         LED_RED, LED_GRN, TINT_LIGHT, TV, Canvas, facet)

OUT = Path(__file__).parent
W, H, FLOOR = 1440, 720, 700
k.setup(W, H, FLOOR)
random.seed(11)
k.rng = np.random.default_rng(11)

PLATFORMS = []   # 屏幕里能站的东西：(x0, x1, y)，单向平台


def S():
    return k.scr


def M():
    return k.mid


def plat(x0, x1, y):
    PLATFORMS.append((int(x0), int(x1), int(y)))


def bands_v(tv, y0, y1, cols, step=None, jag=1.5):
    """竖直方向分档：天空、水。档与档的边界带一点台阶，不是直线。"""
    m = tv.screen_mask() & (k.YY >= y0) & (k.YY < y1)
    step = step or max(1, (y1 - y0) / len(cols))
    t = ((k.YY - y0) + ((k.XX // 6) % 3) * jag) / step
    idx = np.clip(t.astype(int), 0, len(cols) - 1)
    for i, c in enumerate(cols):
        S().fill_mask(m & (idx == i), c)


def ground(tv, cols):
    m = tv.screen_mask() & (k.YY >= tv.fy)
    idx = np.clip(((k.YY - tv.fy) / 3).astype(int), 0, len(cols) - 1)
    for i, c in enumerate(cols):
        S().fill_mask(m & (idx == i), c)
    S().line(tv.sx0, tv.fy, tv.sx1, tv.fy, cols[0])


def disc(cx, cy, r, c, ry=None):
    ry = ry or r
    m = ((k.XX - cx) / r) ** 2 + ((k.YY - cy) / ry) ** 2 <= 1
    S().fill_mask(m, c)
    return m


def digits(x, y, text, c):
    font = {"0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
            "2": ["###", "..#", "###", "#..", "###"], "3": ["###", "..#", ".##", "..#", "###"],
            "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "###", "..#", "###"],
            "7": ["###", "..#", ".#.", ".#.", ".#."], "8": ["###", "#.#", "###", "#.#", "###"],
            "9": ["###", "#.#", "###", "..#", "###"], ":": ["...", ".#.", "...", ".#.", "..."],
            "°": ["##.", "##.", "...", "...", "..."]}
    for i, ch in enumerate(text):
        for yy, row in enumerate(font.get(ch, ["..."] * 5)):
            for xx, v in enumerate(row):
                if v == "#":
                    S().put(x + i * 4 + xx, y + yy, c)


def finish(tv, light_at, k_light=0.35):
    k.finish_room(tv, light_at)


# ================================================================ 新场景
def sc_rain_street(tv):
    """雨夜街道（黑白）：楼、亮着的窗、路灯、积水、斜着的雨。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    bands_v(tv, y0, fy, [(40, 44, 60), (48, 52, 70), (58, 62, 82)])
    x = x0 - 4
    while x < x1:
        bw = random.randint(22, 40)
        bh = random.randint(int((fy - y0) * 0.35), int((fy - y0) * 0.8))
        c = random.choice([(70, 72, 90), (62, 64, 82), (78, 78, 96)])
        S().rect(x, fy - bh, x + bw, fy, c)
        for wy in range(fy - bh + 5, fy - 10, 8):
            for wx in range(x + 4, x + bw - 4, 7):
                if random.random() < 0.35:
                    S().rect(wx, wy, wx + 3, wy + 4, (224, 206, 146))
        x += bw + random.randint(0, 6)
    ground(tv, [(96, 98, 112), (66, 68, 84), (56, 58, 74), (50, 52, 66)])
    for lx in range(x0 + 30, x1 - 10, 70):
        S().rect(lx, fy - 44, lx + 1, fy, (44, 46, 58))
        S().rect(lx - 3, fy - 46, lx + 4, fy - 44, (44, 46, 58))
        S().rect(lx - 2, fy - 43, lx + 3, fy - 42, (246, 236, 196))
        for i, (w2, c) in enumerate([(16, (78, 80, 98)), (10, (92, 94, 112))]):
            S().poly([(lx - 2, fy - 42), (lx + 3, fy - 42), (lx + 3 + w2, fy), (lx - 2 - w2, fy)], c)
        S().rect(lx - 12, fy + 2, lx + 13, fy + 3, (150, 150, 168))           # 积水里的倒影
        plat(lx - 3, lx + 4, fy - 46)
    for _ in range((x1 - x0) * (fy - y0) // 110):
        rx, ry = random.randint(x0, x1), random.randint(y0, fy + 6)
        S().line(rx, ry, rx - 2, ry + 4, (150, 160, 180))
    finish(tv, (x0 + 30, fy - 42))


def sc_aquarium(tv):
    """海底：一层层变深的水、光柱、海草、小鱼、气泡、沙地。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    bands_v(tv, y0, fy, [(80, 140, 190), (64, 122, 176), (52, 104, 160), (42, 86, 142), (34, 70, 124)])
    for i in range(3):
        bx = x0 + 14 + i * (x1 - x0) // 3
        S().poly([(bx, y0), (bx + 8, y0), (bx + 26, fy), (bx + 16, fy)], (96, 156, 200))
    ground(tv, [(214, 196, 150), (196, 178, 134), (176, 158, 120), (156, 138, 108)])
    for sx in range(x0 + 6, x1 - 4, 13):
        h = random.randint(14, 34)
        for y in range(fy - h, fy):
            S().put(sx + round(1.5 * np.sin(y / 3 + sx)), y, (70, 150, 104) if y % 4 else (96, 176, 120))
    for rx in (x0 + 20, x1 - 30):
        disc(rx, fy - 2, 9, (110, 110, 130), 6); disc(rx - 2, fy - 4, 5, (134, 134, 152), 3)
    plat(x1 - 39, x1 - 21, fy - 8)
    for _ in range(5):
        fx, fy2 = random.randint(x0 + 10, x1 - 14), random.randint(y0 + 10, fy - 16)
        c = random.choice([(246, 160, 80), (246, 214, 110), (230, 110, 110)])
        S().rect(fx, fy2, fx + 4, fy2 + 2, c); S().put(fx + 5, fy2 - 1, c); S().put(fx + 5, fy2 + 3, c)
        S().put(fx + 1, fy2 + 1, (40, 40, 60))
    for _ in range(9):
        bx, by = random.randint(x0 + 5, x1 - 5), random.randint(y0 + 5, fy - 5)
        S().put(bx, by, (190, 224, 240)); S().put(bx + 1, by - 2, (160, 206, 230))
    finish(tv, ((x0 + x1) // 2, y0 + 10))


def sc_test_card(tv):
    """彩条测试卡：彩条是墙，下面一条深色带是地面。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    bars = [(206, 204, 196), (206, 196, 128), (126, 194, 190), (128, 184, 128), (190, 128, 180), (194, 116, 116), (116, 120, 196)]
    m = tv.screen_mask()
    bw = (x1 - x0 + 1) / len(bars)
    for i, c in enumerate(bars):
        S().fill_mask(m & (k.XX >= x0 + int(i * bw)) & (k.YY < fy - 8), c)
    S().fill_mask(m & (k.YY >= fy - 8), (46, 44, 64))
    for i, c in enumerate([(116, 120, 196), (46, 44, 64), (206, 204, 196), (46, 44, 64)]):
        S().fill_mask(m & (k.YY >= fy - 8) & (k.YY < fy) & (k.XX >= x0 + int(i * bw * 1.6)) & (k.XX < x0 + int((i + 1) * bw * 1.6)), c)
    cx, cy, r = (x0 + x1) // 2, (y0 + fy) // 2 - 4, min(x1 - x0, fy - y0) // 3
    ring = (((k.XX - cx) ** 2 + (k.YY - cy) ** 2) <= r * r) & (((k.XX - cx) ** 2 + (k.YY - cy) ** 2) > (r - 2) ** 2)
    S().fill_mask(ring & m, (236, 236, 236))
    S().line(cx - r, cy, cx + r, cy, (236, 236, 236)); S().line(cx, cy - r, cx, cy + r, (236, 236, 236))
    ground(tv, [(30, 30, 44), (26, 26, 38)])
    finish(tv, (cx, cy))


def sc_snow_yard(tv):
    """雪夜的院子：后面一栋亮着窗的房子、雪人、松树、栅栏、飘雪。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    bands_v(tv, y0, fy, [(46, 54, 96), (56, 66, 112), (70, 82, 128), (86, 98, 142)])
    hx = x0 + (x1 - x0) // 2 - 4
    S().rect(hx, fy - 30, hx + 40, fy, (150, 130, 140))
    S().poly([(hx - 5, fy - 30), (hx + 45, fy - 30), (hx + 20, fy - 46)], (226, 230, 240))
    for wx in (hx + 6, hx + 26):
        S().rect(wx, fy - 22, wx + 8, fy - 14, (246, 206, 130))
    S().rect(hx + 17, fy - 12, hx + 23, fy, (110, 80, 80))
    plat(hx - 5, hx + 45, fy - 30)
    ground(tv, [(232, 236, 244), (214, 222, 236), (196, 206, 226), (180, 190, 214)])
    for fx in range(x0 + 2, x1, 6):                                          # 栅栏
        S().rect(fx, fy - 9, fx + 1, fy, (120, 96, 96)); S().put(fx, fy - 10, (226, 230, 240))
    S().line(x0, fy - 6, x1, fy - 6, (120, 96, 96))
    sx = x0 + 18                                                             # 雪人
    disc(sx, fy - 6, 7, (240, 242, 248)); disc(sx, fy - 17, 5, (240, 242, 248))
    S().put(sx - 2, fy - 18, (40, 40, 50)); S().put(sx + 1, fy - 18, (40, 40, 50)); S().put(sx + 3, fy - 17, (240, 150, 80))
    S().rect(sx - 5, fy - 13, sx + 5, fy - 12, (206, 72, 64))
    tx = x1 - 22                                                             # 松树
    for i in range(4):
        S().poly([(tx - 12 + i * 2, fy - 6 - i * 10), (tx + 12 - i * 2, fy - 6 - i * 10), (tx, fy - 22 - i * 10)], (54, 96, 84))
        S().line(tx - 10 + i * 2, fy - 7 - i * 10, tx - 2, fy - 7 - i * 10, (226, 230, 240))
    for _ in range((x1 - x0) * (fy - y0) // 70):
        S().put(random.randint(x0, x1), random.randint(y0, fy), (236, 238, 246))
    finish(tv, (hx + 20, fy - 18))


def sc_beach(tv):
    """黄昏海滩：分档的晚霞、半个太阳、海面上的金色倒影、沙滩伞、棕榈树、小螃蟹。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    hz = fy - int((fy - y0) * 0.3)
    bands_v(tv, y0, hz, [(110, 90, 140), (150, 108, 150), (200, 132, 150), (236, 164, 140), (250, 198, 150)])
    sx = x0 + int((x1 - x0) * 0.62)
    sun = disc(sx, hz, 18, (252, 228, 170)) & (k.YY < hz)
    bands_v(tv, hz, fy - 6, [(116, 120, 170), (96, 104, 160), (80, 90, 148)])
    for y in range(hz + 2, fy - 6, 3):
        half = 14 - (y - hz) // 3
        S().line(sx - half - random.randint(0, 4), y, sx + half + random.randint(0, 4), y, (246, 196, 140))
    m = tv.screen_mask() & (k.YY >= fy - 6)
    S().fill_mask(m, (226, 196, 150))
    S().fill_mask(m & (k.YY >= fy + 1), (210, 178, 134))
    S().line(x0, fy - 6, x1, fy - 6, (246, 236, 220))
    ux = x0 + 40                                                             # 沙滩伞
    S().line(ux, fy - 34, ux + 2, fy - 6, (120, 90, 80))
    S().poly([(ux - 24, fy - 30), (ux + 26, fy - 30), (ux + 1, fy - 44)], (230, 110, 100))
    S().poly([(ux - 8, fy - 30), (ux + 9, fy - 30), (ux + 1, fy - 44)], (244, 232, 214))
    plat(ux - 24, ux + 26, fy - 30)
    px = x1 - 30                                                             # 棕榈树
    for i in range(30):
        S().rect(px + round(i * i / 90), fy - 6 - i * 2, px + 3 + round(i * i / 90), fy - 5 - i * 2, (120, 86, 70))
    top = (px + 10, fy - 66)
    for dx, dy in [(-22, 12), (-14, 18), (20, 14), (12, 20), (-4, -6), (16, -4)]:
        S().line(top[0], top[1], top[0] + dx, top[1] + dy, (70, 120, 90))
        S().line(top[0], top[1] + 1, top[0] + dx, top[1] + dy + 1, (56, 100, 80))
    S().rect(x0 + 74, fy - 12, x0 + 86, fy - 6, (220, 186, 130)); S().rect(x0 + 77, fy - 17, x0 + 83, fy - 12, (220, 186, 130))
    S().rect(x0 + 100, fy - 8, x0 + 103, fy - 6, (220, 80, 70))
    finish(tv, (sx, hz))


def sc_weather(tv):
    """天气预报：蓝底地图、绿色陆地、云和太阳的图标、气温；底下一条滚动字幕当地面。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    m = tv.screen_mask()
    S().fill_mask(m, (70, 110, 176))
    S().poly([(x0 + 6, y0 + 30), (x0 + 40, y0 + 14), (x0 + 70, y0 + 24), (x0 + 64, fy - 14), (x0 + 22, fy - 8), (x0 + 4, fy - 30)], (112, 170, 116))
    S().poly([(x1 - 30, y0 + 10), (x1 + 2, y0 + 12), (x1 + 2, fy - 20), (x1 - 24, fy - 30)], (112, 170, 116))
    S().poly([(x0 + 10, y0 + 34), (x0 + 30, y0 + 28), (x0 + 44, y0 + 40), (x0 + 22, y0 + 52)], (96, 152, 104))
    disc(x0 + 30, y0 + 22, 6, (250, 214, 110))
    for cx, cy in [(x0 + 58, y0 + 40), (x1 - 18, y0 + 30)]:
        disc(cx, cy, 8, (236, 238, 244), 5); disc(cx - 6, cy + 2, 5, (236, 238, 244), 4); S().rect(cx - 10, cy + 4, cx + 8, cy + 5, (190, 196, 210))
        for d in range(3):
            S().line(cx - 6 + d * 5, cy + 8, cx - 7 + d * 5, cy + 11, (150, 196, 240))
    digits(x0 + 20, y0 + 32, "23°", (250, 250, 250)); digits(x1 - 24, y0 + 44, "9°", (250, 250, 250))
    S().fill_mask(m & (k.YY >= fy - 2), (30, 40, 96))
    S().line(x0, fy - 2, x1, fy - 2, (246, 214, 110))
    for tx in range(x0 + 4, x1 - 6, 9):
        S().rect(tx, fy + 2, tx + 5, fy + 4, (226, 228, 240))
    finish(tv, ((x0 + x1) // 2, y0 + 30))


def sc_space(tv):
    """太空：星星、带环的大行星、他们那艘旧飞船；地面是月球表面。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    bands_v(tv, y0, fy, [(14, 16, 32), (20, 22, 42), (28, 28, 54)])
    for _ in range((x1 - x0) * (fy - y0) // 60):
        S().put(random.randint(x0, x1), random.randint(y0, fy), random.choice([(236, 236, 246), (246, 226, 170), (170, 190, 246)]))
    px, py, r = x0 + int((x1 - x0) * 0.66), y0 + 30, 18
    p = disc(px, py, r, (206, 150, 110))
    S().fill_mask(p & (k.YY > py + 4), (180, 124, 96)); S().fill_mask(p & (k.YY < py - 8), (226, 178, 132))
    ring = ((k.XX - px) / 32) ** 2 + ((k.YY - py) / 6) ** 2
    S().fill_mask((ring <= 1) & (ring > 0.62) & ~(p & (k.YY < py)), (226, 206, 170))
    disc(x0 + 26, y0 + 22, 6, (110, 170, 214)); S().rect(x0 + 23, y0 + 19, x0 + 26, y0 + 21, (120, 190, 120))
    sx, sy = x0 + 40, y0 + 52                                                # 旧飞船
    S().poly([(sx, sy), (sx + 22, sy - 2), (sx + 28, sy + 3), (sx + 22, sy + 8), (sx, sy + 7)], (170, 168, 176))
    S().rect(sx + 14, sy + 1, sx + 18, sy + 3, (120, 170, 220))
    S().poly([(sx, sy + 1), (sx - 8, sy + 3), (sx, sy + 6)], (246, 170, 90))
    ground(tv, [(170, 170, 180), (146, 146, 158), (126, 126, 140), (110, 110, 124)])
    for cx in range(x0 + 14, x1 - 6, 31):
        disc(cx, fy + 4, 6, (126, 126, 140), 2)
    S().rect(x1 - 26, fy - 14, x1 - 25, fy, (200, 200, 210)); S().rect(x1 - 24, fy - 14, x1 - 16, fy - 9, (206, 72, 64))  # 插了一面旗
    finish(tv, (px, py))


def sc_subway(tv):
    """地铁车厢（琥珀单色屏）：窗外隧道灯拉成线、长椅、扶杆、吊环、线路图。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    k.room_base(tv, [(206, 196, 176), (190, 180, 162), (170, 160, 146), (146, 138, 128), (124, 116, 110)],
                [(140, 130, 124), (124, 114, 110), (110, 100, 98), (96, 88, 88)], ((x0 + x1) // 2, y0 + 6))
    S().rect(x0, y0, x1, y0 + 6, (120, 112, 106))
    S().rect(x0 + 6, y0 + 10, x1 - 6, y0 + 15, (232, 226, 210))              # 线路图
    S().line(x0 + 10, y0 + 12, x1 - 10, y0 + 12, (206, 72, 64))
    for sx in range(x0 + 14, x1 - 10, 18):
        S().rect(sx, y0 + 11, sx + 2, y0 + 13, (246, 246, 246))
    wy0, wy1 = y0 + 22, fy - 26
    for wx in range(x0 + 10, x1 - 30, 44):
        S().rect(wx, wy0, wx + 32, wy1, (36, 34, 44))
        for ly in range(wy0 + 4, wy1 - 2, 6):
            off = random.randint(0, 16)
            S().line(wx + off, ly, min(wx + 32, wx + off + random.randint(6, 16)), ly, (226, 186, 110))
        S().rect(wx - 2, wy0 - 2, wx + 34, wy0 - 1, (150, 140, 132)); S().rect(wx - 2, wy1 + 1, wx + 34, wy1 + 2, (150, 140, 132))
    S().rect(x0 + 4, fy - 12, x1 - 4, fy - 9, (176, 96, 80))                 # 长椅
    S().rect(x0 + 4, fy - 9, x1 - 4, fy - 7, (140, 76, 66))
    S().rect(x0 + 4, fy - 24, x1 - 4, fy - 13, (196, 112, 90))
    plat(x0 + 4, x1 - 4, fy - 12)
    for px in range(x0 + 30, x1 - 20, 44):
        S().rect(px, y0 + 6, px + 1, fy, (220, 218, 214))
        for hx in (px - 10, px + 10):
            S().line(hx, y0 + 6, hx, y0 + 16, (200, 196, 190)); S().rect(hx - 1, y0 + 17, hx + 1, y0 + 19, (200, 196, 190))
    finish(tv, ((x0 + x1) // 2, y0 + 8))


def sc_static(tv):
    """整屏雪花，中间一道慢慢滚的暗条。雪花幽灵从这里出来。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    m = tv.screen_mask()
    ys, xs = np.nonzero(m)
    tones = [(80, 86, 104), (120, 128, 146), (170, 176, 196), (216, 220, 232)]
    pick = k.rng.choice(4, size=len(ys), p=[0.36, 0.32, 0.22, 0.1])
    for y, x, t in zip(ys, xs, pick):
        S().put(x, y, tones[t])
    a = S().a[..., :3].astype(float)
    band = m & (k.YY >= y0 + 24) & (k.YY < y0 + 34)
    a[band] *= 0.6
    a[m & (k.YY >= fy)] *= 0.75
    S().a[..., :3] = a.astype(np.uint8)
    S().line(x0, fy, x1, fy, (196, 200, 214))
    k.vignette(x0, y0, x1, tv.sy1, 5)
    k.glare(x0, y0, x1, tv.sy1)
    k.LIGHTS.append(((x0 + x1) / 2, (y0 + fy) / 2, (x1 - x0) * 1.2, (170, 180, 210), 0.55))


def sc_ferris(tv):
    """夜里的游乐园：摩天轮一圈彩灯、旋转木马的帐篷、头顶一串小灯、一只气球。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    bands_v(tv, y0, fy, [(40, 34, 70), (54, 44, 86), (72, 56, 104), (96, 70, 118)])
    for _ in range(30):
        S().put(random.randint(x0, x1), random.randint(y0, y0 + 60), (230, 226, 246))
    cx, cy = x0 + int((x1 - x0) * 0.36), y0 + int((fy - y0) * 0.44)
    r = int(min(x1 - x0, fy - y0) * 0.36)
    S().line(cx, cy, cx - r // 2, fy, (120, 104, 140)); S().line(cx, cy, cx + r // 2, fy, (120, 104, 140))
    S().line(cx + 1, cy, cx - r // 2 + 1, fy, (96, 82, 118)); S().line(cx + 1, cy, cx + r // 2 + 1, fy, (96, 82, 118))
    for a in np.linspace(0, 2 * np.pi, 12, endpoint=False):
        S().line(cx, cy, cx + round(r * np.cos(a)), cy + round(r * np.sin(a)), (140, 122, 160))
    rim = np.abs(np.hypot(k.XX - cx, k.YY - cy) - r) < 0.9
    S().fill_mask(rim & tv.screen_mask(), (176, 156, 190))
    lights = [(246, 206, 120), (240, 120, 140), (130, 210, 220), (170, 230, 140)]
    for i, a in enumerate(np.linspace(0, 2 * np.pi, 24, endpoint=False)):
        S().put(cx + round(r * np.cos(a)), cy + round(r * np.sin(a)), lights[i % 4])
    for i, a in enumerate(np.linspace(0, 2 * np.pi, 8, endpoint=False)):
        gx, gy = cx + round(r * np.cos(a)), cy + round(r * np.sin(a))
        S().rect(gx - 3, gy + 2, gx + 3, gy + 6, [(206, 96, 96), (96, 136, 214), (230, 196, 110), (110, 180, 110)][i % 4])
        S().line(gx, gy, gx, gy + 1, (176, 156, 190))
        if gy + 2 < fy - 10:
            plat(gx - 3, gx + 3, gy + 2)
    tx = x0 + int((x1 - x0) * 0.76)                                          # 旋转木马帐篷
    S().rect(tx - 20, fy - 24, tx + 20, fy, (110, 80, 110))
    for i in range(8):
        c = (226, 96, 96) if i % 2 == 0 else (244, 232, 214)
        S().poly([(tx - 24 + i * 6, fy - 24), (tx - 18 + i * 6, fy - 24), (tx, fy - 44)], c)
    for hx in range(tx - 16, tx + 17, 8):
        S().rect(hx, fy - 16, hx + 4, fy - 12, (236, 222, 200)); S().line(hx + 2, fy - 24, hx + 2, fy - 17, (220, 196, 140))
    plat(tx - 22, tx + 22, fy - 24)
    for i in range(0, x1 - x0, 2):                                          # 一串小灯
        y = y0 + 6 + round(8 * np.sin(np.pi * i / (x1 - x0)))
        S().put(x0 + i, y, (60, 50, 70))
        if i % 8 == 0:
            S().put(x0 + i, y + 1, lights[(i // 8) % 4])
    ground(tv, [(80, 66, 90), (66, 54, 78), (56, 46, 68)])
    bx = x1 - 14
    disc(bx, y0 + 30, 4, (240, 110, 120), 5); S().line(bx, y0 + 35, bx - 1, y0 + 46, (200, 190, 200))
    finish(tv, (cx, cy))


def sc_forest(tv):
    """森林（绿荧光）：几层树干从远到近、光柱、小路、萤火虫、蘑菇。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    bands_v(tv, y0, fy, [(150, 170, 150), (130, 150, 132), (110, 130, 116)])
    for depth, (c, wmin) in enumerate([((120, 140, 124), 4), ((96, 112, 100), 6), ((70, 82, 76), 9)]):
        for tx in range(x0 - 4 + depth * 9, x1, 22 + depth * 6):
            tw = wmin + random.randint(0, 3)
            S().rect(tx, y0, tx + tw, fy, c)
    S().poly([(x0 + 40, y0), (x0 + 52, y0), (x0 + 80, fy), (x0 + 60, fy)], (186, 206, 176))
    ground(tv, [(110, 120, 96), (96, 104, 86), (84, 92, 78)])
    S().fill_mask(tv.screen_mask() & (k.YY >= tv.fy) & (np.abs(k.XX - (x0 + x1) / 2) < 14 + (k.YY - tv.fy) * 3), (160, 150, 120))
    for _ in range(10):
        S().put(random.randint(x0, x1), random.randint(y0 + 20, fy - 4), (236, 246, 170))
    for mx in (x0 + 16, x1 - 20):
        S().rect(mx, fy - 3, mx + 1, fy, (226, 220, 200)); S().rect(mx - 2, fy - 5, mx + 3, fy - 4, (206, 90, 80))
    finish(tv, (x0 + 60, y0 + 20))


def sc_rooftop(tv):
    """黄昏的屋顶：远处城市剪影、水塔、一排老电视天线、晾衣绳上四件衣服。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    bands_v(tv, y0, fy, [(96, 90, 140), (140, 110, 150), (196, 136, 140), (236, 170, 140)])
    x = x0
    while x < x1:
        bw, bh = random.randint(10, 24), random.randint(16, 46)
        S().rect(x, fy - 8 - bh, x + bw, fy - 8, (90, 76, 108))
        for wy in range(fy - 4 - bh, fy - 12, 6):
            if random.random() < 0.4:
                S().put(x + random.randint(2, max(2, bw - 2)), wy, (246, 214, 150))
        x += bw + 1
    S().fill_mask(tv.screen_mask() & (k.YY >= fy - 8), (130, 106, 110))
    S().rect(x0, fy - 10, x1, fy - 8, (160, 132, 130))
    ground(tv, [(150, 124, 124), (124, 102, 106), (108, 90, 96)])
    wx = x0 + 24                                                             # 水塔
    S().rect(wx, fy - 46, wx + 20, fy - 26, (140, 100, 86))
    S().poly([(wx - 2, fy - 46), (wx + 22, fy - 46), (wx + 10, fy - 54)], (120, 86, 76))
    for lx in (wx + 2, wx + 17):
        S().line(lx, fy - 26, lx - 2, fy, (96, 76, 80))
    plat(wx - 2, wx + 22, fy - 46)
    for ax in range(x0 + 64, x1 - 10, 26):                                  # 天线
        S().line(ax, fy - 10, ax, fy - 40, (70, 60, 76))
        for j, l in enumerate((10, 8, 6)):
            S().line(ax - l, fy - 38 + j * 4, ax + l, fy - 38 + j * 4, (70, 60, 76))
    ly = fy - 30
    S().line(x0 + 50, ly, x1 - 50, ly + 2, (200, 190, 200))
    for i, c in enumerate([(206, 72, 64), (190, 140, 96), (96, 136, 214), (110, 180, 100)]):
        cx = x0 + 60 + i * 14
        S().rect(cx, ly + 1, cx + 8, ly + 9, c); S().rect(cx - 2, ly + 1, cx + 10, ly + 3, c)
    finish(tv, ((x0 + x1) // 2, fy - 20))


def sc_attic(tv):
    """阁楼（琥珀）：斜屋顶的梁、圆窗打进来的一道光、纸箱、木马、旧箱子。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    cx = (x0 + x1) // 2
    k.room_base(tv, [(190, 160, 130), (170, 140, 116), (150, 122, 104), (126, 104, 92), (106, 88, 82)],
                [(150, 110, 86), (132, 96, 76), (114, 82, 68), (98, 70, 60)], (cx, y0 + 20))
    S().poly([(x0 - 2, y0 - 2), (cx, y0 - 2), (x0 - 2, fy - 20)], (78, 58, 54))
    S().poly([(cx, y0 - 2), (x1 + 2, y0 - 2), (x1 + 2, fy - 20)], (78, 58, 54))
    for i in range(1, 4):
        S().line(x0 + i * 10, y0, x0, y0 + i * 18, (110, 84, 72)); S().line(x1 - i * 10, y0, x1, y0 + i * 18, (110, 84, 72))
    disc(cx, y0 + 18, 7, (246, 226, 170)); S().line(cx - 7, y0 + 18, cx + 7, y0 + 18, (110, 84, 72)); S().line(cx, y0 + 11, cx, y0 + 25, (110, 84, 72))
    S().poly([(cx - 5, y0 + 22), (cx + 5, y0 + 22), (cx + 26, fy), (cx + 6, fy)], (214, 182, 140))
    for bx, bw, bh in [(x0 + 8, 18, 14), (x0 + 10, 14, 10), (x1 - 30, 20, 16)]:
        by = fy if bh != 10 else fy - 14
        S().rect(bx, by - bh, bx + bw, by, (186, 146, 104)); S().line(bx, by - bh, bx + bw, by - bh, (206, 168, 120))
        S().line(bx + bw // 2, by - bh, bx + bw // 2, by - bh + 4, (150, 116, 86))
        plat(bx, bx + bw, by - bh)
    hx = cx - 26                                                             # 木马
    S().rect(hx, fy - 12, hx + 12, fy - 8, (200, 160, 120)); S().rect(hx + 10, fy - 17, hx + 13, fy - 10, (200, 160, 120))
    S().line(hx - 2, fy, hx + 14, fy, (150, 110, 86)); S().line(hx + 1, fy - 8, hx, fy - 1, (150, 110, 86)); S().line(hx + 10, fy - 8, hx + 11, fy - 1, (150, 110, 86))
    for _ in range(14):
        S().put(random.randint(cx - 4, cx + 22), random.randint(y0 + 26, fy - 4), (250, 236, 200))
    finish(tv, (cx, y0 + 18))


def sc_classroom(tv):
    """教室：黑板上用粉笔画着四个小人和一座房子、讲台、几排课桌、挂钟、窗。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    k.room_base(tv, [(220, 214, 180), (204, 198, 166), (184, 178, 152), (160, 156, 136), (136, 132, 120)],
                k.WARM_FLOOR, (x1 - 30, y0 + 20), wainscot=((140, 150, 120), (176, 186, 150)))
    bx0, bx1 = x0 + 22, x0 + int((x1 - x0) * 0.62)
    S().rect(bx0 - 3, y0 + 14, bx1 + 3, y0 + 54, (126, 96, 80))
    S().rect(bx0, y0 + 16, bx1, y0 + 51, (56, 92, 74))
    S().rect(bx0, y0 + 48, bx1, y0 + 49, (70, 108, 88))
    chalk = (226, 232, 220)
    for i in range(4):
        fx = bx0 + 10 + i * 9
        S().put(fx + 1, y0 + 28, chalk); S().line(fx + 1, y0 + 29, fx + 1, y0 + 34, chalk)
        S().line(fx, y0 + 31, fx + 2, y0 + 31, chalk); S().line(fx + 1, y0 + 34, fx, y0 + 37, chalk); S().line(fx + 1, y0 + 34, fx + 2, y0 + 37, chalk)
    hx = bx1 - 34
    S().polyline([(hx, y0 + 40), (hx, y0 + 30), (hx + 8, y0 + 23), (hx + 16, y0 + 30), (hx + 16, y0 + 40), (hx, y0 + 40)], chalk)
    S().rect(hx + 6, y0 + 34, hx + 9, y0 + 40, chalk)
    digits(bx0 + 4, y0 + 19, "1", chalk)
    k.wall_clock(x1 - 24, y0 + 18, 6)
    k.window(x1 - 38, y0 + 30, 22, 22)
    S().rect(bx0 + 10, fy - 14, bx0 + 40, fy, (150, 104, 82)); S().line(bx0 + 10, fy - 14, bx0 + 40, fy - 14, (184, 136, 104))
    plat(bx0 + 10, bx0 + 40, fy - 14)
    for dx in range(bx0 + 54, x1 - 10, 24):
        S().rect(dx, fy - 10, dx + 14, fy - 9, (184, 136, 104)); S().rect(dx + 1, fy - 8, dx + 2, fy, (118, 82, 70)); S().rect(dx + 12, fy - 8, dx + 13, fy, (118, 82, 70))
        S().rect(dx + 16, fy - 6, dx + 21, fy - 5, (96, 136, 214)); S().rect(dx + 20, fy - 14, dx + 21, fy, (96, 136, 214))
        plat(dx, dx + 14, fy - 10)
    finish(tv, (x1 - 30, y0 + 20))


def sc_hometown(tv):
    """终点：家乡。暮色里的两个月亮、一层层的山、山坡上一座亮着灯的房子，门口的灯亮着。
    一条小路从左边弯弯绕到门口，左边停着那艘旧飞船。走到门口就是结局。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    bands_v(tv, y0, fy, [(46, 50, 96), (62, 62, 112), (86, 76, 126), (120, 92, 136), (166, 116, 140), (210, 148, 140), (238, 186, 150)])
    for _ in range(60):
        S().put(random.randint(x0, x1), random.randint(y0, y0 + 70), (226, 226, 246))
    disc(x0 + 70, y0 + 34, 12, (240, 236, 220)); disc(x0 + 75, y0 + 31, 10, (62, 62, 112))
    disc(x1 - 120, y0 + 22, 6, (230, 210, 200))
    w = x1 - x0
    for i, (c, base, amp, f) in enumerate([((126, 100, 150), 0.52, 14, 0.021), ((100, 90, 140), 0.64, 12, 0.03), ((80, 96, 120), 0.76, 10, 0.017)]):
        top = y0 + (fy - y0) * base + amp * np.sin(k.XX * f + i * 2)
        S().fill_mask(tv.screen_mask() & (k.YY >= top) & (k.YY < fy), c)
    hill_top = fy - 30 - 22 * np.exp(-((k.XX - (x0 + w * 0.68)) / (w * 0.22)) ** 2)
    S().fill_mask(tv.screen_mask() & (k.YY >= hill_top) & (k.YY < fy), (86, 120, 100))
    S().fill_mask(tv.screen_mask() & (k.YY >= hill_top + 4) & (k.YY < fy), (74, 106, 92))
    ground(tv, [(96, 132, 104), (80, 114, 92), (70, 100, 84), (62, 88, 78)])
    hx = x0 + int(w * 0.68) - 26                                             # 房子
    hy = int(fy - 52)
    S().rect(hx, hy, hx + 52, hy + 30, (222, 206, 180))
    S().rect(hx + 44, hy, hx + 52, hy + 30, (196, 178, 160))
    S().poly([(hx - 6, hy), (hx + 58, hy), (hx + 26, hy - 22)], (160, 86, 76))
    S().poly([(hx + 26, hy - 22), (hx + 58, hy), (hx + 40, hy)], (136, 72, 68))
    S().rect(hx + 38, hy - 22, hx + 44, hy - 10, (140, 110, 104))
    for i in range(4):
        S().put(hx + 41 + i, hy - 25 - i * 3, (200, 190, 200)); S().put(hx + 40 + i, hy - 26 - i * 3, (200, 190, 200))
    for wx in (hx + 6, hx + 32):
        S().rect(wx, hy + 8, wx + 10, hy + 18, (252, 214, 140)); S().line(wx + 5, hy + 8, wx + 5, hy + 18, (200, 150, 110))
    S().rect(hx + 20, hy + 12, hx + 28, hy + 30, (252, 226, 160))           # 开着的门，里面亮
    S().rect(hx + 19, hy + 9, hx + 29, hy + 10, (150, 100, 90))
    S().put(hx + 30, hy + 10, (255, 246, 200)); S().put(hx + 18, hy + 10, (255, 246, 200))
    path = []
    for i in range(0, 101):                                                  # 小路
        t = i / 100
        px = x0 + 20 + (hx + 24 - x0 - 20) * t
        py = fy - 1 - (fy - (hy + 30)) * t ** 2.2
        path.append((round(px), round(py)))
    for px, py in path:
        S().rect(px - 2, py, px + 2, py + 1, (190, 170, 130))
    tx = hx + 80                                                             # 大树和秋千
    S().rect(tx, fy - 54, tx + 5, fy, (96, 70, 64))
    for cx, cy, r in [(tx + 2, fy - 64, 16), (tx - 10, fy - 56, 11), (tx + 14, fy - 56, 12)]:
        disc(cx, cy, r, (70, 104, 86)); disc(cx - 3, cy - 3, r - 5, (86, 124, 96))
    S().line(tx - 6, fy - 46, tx - 6, fy - 14, (180, 170, 160)); S().line(tx + 4, fy - 46, tx + 4, fy - 14, (180, 170, 160))
    S().rect(tx - 7, fy - 14, tx + 5, fy - 13, (150, 104, 82))
    plat(tx - 7, tx + 5, fy - 14)
    sx, sy = x0 + 46, fy - 14                                               # 旧飞船停在左边
    S().poly([(sx, sy), (sx + 40, sy - 4), (sx + 52, sy + 4), (sx + 40, sy + 12), (sx, sy + 12)], (170, 168, 176))
    S().poly([(sx + 40, sy + 12), (sx + 52, sy + 4), (sx + 40, sy - 4)], (146, 144, 156))
    S().rect(sx + 26, sy, sx + 34, sy + 4, (120, 170, 220))
    S().line(sx + 8, sy + 12, sx + 4, fy, (120, 118, 130)); S().line(sx + 34, sy + 12, sx + 38, fy, (120, 118, 130))
    plat(sx, sx + 40, sy - 2)
    for _ in range(16):
        S().put(random.randint(x0 + 20, x1 - 20), random.randint(fy - 60, fy - 4), (236, 246, 170))
    finish(tv, (hx + 24, hy + 20))
    k.LIGHTS.append((hx + 24, hy + 24, 60, (255, 220, 160), 0.5))
    return (hx + 24, hy + 30)


# 原来的房间也记一下能站的家具
def room(fn, tv):
    fn(tv)
    x0, x1, fy = tv.sx0, tv.sx1, tv.fy
    rw = x1 - x0
    if fn is k.room_kitchen:
        plat(x0 + 6, x0 + 50, fy - 18); plat(x1 - 34, x1 - 14, fy - 46); plat((x0 + x1) // 2 - 4, (x0 + x1) // 2 + 32, fy - 14)
    elif fn is k.room_living:
        plat(x0 + int(rw * 0.22), x0 + int(rw * 0.58), fy - 11)
    elif fn is k.room_bedroom:
        plat(x0 + 8, x0 + 62, fy - 12); plat(x1 - 38, x1 - 10, fy - 54)
    elif fn is k.room_kids:
        plat(x0 + 10, x0 + 56, fy - 36)
    elif fn is k.room_study:
        plat(x0 + 8, x0 + 42, fy - 58); plat(x0 + 44, x0 + 70, fy - 46)


# ================================================================ 电视墙排布
# 每层：电视的下沿都在同一条线上，所以屏幕地面齐平，相邻的可以打通直接走过去。
# (x, 宽, 高, 外壳, 控制条, 显示方式, 顶部, 场景)
ROW1_BOTTOM = FLOOR                      # 第一层下沿 = 仓库地面
ROWS = [
    (ROW1_BOTTOM, [
        (110, 170, 150, WOOD, "speaker", "color", None, ("kitchen", k.room_kitchen)),
        (280, 110, 104, GREY, "buttons", "color", None, ("aquarium", sc_aquarium)),
        (390, 240, 196, KHAKI, "meter", "bw", "vents", ("rain_street", sc_rain_street)),
        (630, 96, 84, PLUM, "buttons", "color", None, ("test_card", sc_test_card)),
        (726, 200, 160, KHAKI, "meter", "color", "vents", ("living", k.room_living)),
        (926, 150, 128, WOOD, "buttons", "color", None, ("snow_yard", sc_snow_yard)),
        (1076, 250, 210, GREY, "speaker", "color", "vents", ("beach", sc_beach)),
        (1326, 114, 110, PLUM, "meter", "color", None, ("weather", sc_weather)),
    ]),
    (490, [
        (110, 170, 170, PLUM, "buttons", "green", None, ("kids", k.room_kids)),
        (280, 130, 120, GREY, "meter", "color", None, ("space", sc_space)),
        (410, 200, 180, KHAKI, "speaker", "amber", "vents", ("subway", sc_subway)),
        (610, 100, 96, WOOD, "buttons", "color", None, ("static", sc_static)),
        (710, 220, 200, KHAKI, "meter", "color", "vents", ("ferris", sc_ferris)),
        (930, 150, 140, GREY, "buttons", "bw", None, ("bedroom", k.room_bedroom)),
        (1080, 140, 120, WOOD, "speaker", "green", None, ("forest", sc_forest)),
        (1220, 200, 176, KHAKI, "meter", "amber", "vents", ("study", k.room_study)),
    ]),
    (290, [
        (110, 160, 150, GREY, "speaker", "color", None, ("rooftop", sc_rooftop)),
        (270, 120, 110, WOOD, "buttons", "amber", None, ("attic", sc_attic)),
        (390, 180, 160, KHAKI, "meter", "color", "vents", ("classroom", sc_classroom)),
        (570, 100, 90, GREY, "buttons", "color", None, ("test_card2", sc_test_card)),
        (670, 180, 170, WOOD, "speaker", "color", None, ("entry", k.room_entry)),
        (850, 420, 250, KHAKI, "meter", "color", "vents", ("hometown", sc_hometown)),
    ]),
]


# ================================================================ 空隙：录像机、磁带、纸箱、关着的小电视
def vcr(x0, y0, w, h):
    m = M()
    m.rect(x0, y0, x0 + w, y0 + h, (54, 52, 62)); m.line(x0, y0, x0 + w, y0, (78, 74, 86))
    m.line(x0 + w, y0, x0 + w, y0 + h, (40, 38, 48))
    if h >= 8:
        m.rect(x0 + 4, y0 + 3, x0 + w // 2, y0 + 4, (30, 28, 36))
        m.rect(x0 + w - 18, y0 + 2, x0 + w - 6, y0 + h - 2, (24, 34, 30))
        for i, ch in enumerate((1, 2, 0, 0)):
            m.put(x0 + w - 16 + i * 3, y0 + 3, (120, 214, 130))   # 一闪一闪的 12:00
        m.put(x0 + 3, y0 + h - 2, LED_RED)


def tape_stack(x0, y0, w, h):
    m = M()
    y = y0 + h
    while y > y0:
        th = min(4, y - y0)
        c = random.choice([(40, 38, 46), (60, 56, 66), (196, 186, 166)])
        m.rect(x0 + random.randint(0, 2), y - th, x0 + w - random.randint(0, 2), y - 1, c)
        m.put(x0 + w // 2, y - 2, (206, 196, 176) if c != (196, 186, 166) else (90, 80, 80))
        y -= th


def box(x0, y0, w, h):
    m = M()
    m.rect(x0, y0, x0 + w, y0 + h, (150, 118, 90)); m.rect(x0 + w - 3, y0, x0 + w, y0 + h, (126, 98, 78))
    m.line(x0, y0, x0 + w, y0, (176, 142, 108)); m.rect(x0 + w // 2 - 2, y0, x0 + w // 2 + 2, y0 + h // 3, (186, 170, 140))


def dead_tv(x0, y0, w, h):
    P = random.choice([KHAKI, GREY, PLUM, WOOD])
    k.body(x0, y0, x0 + w, y0 + h, P, lip=3)
    sx0, sy0, sx1, sy1 = x0 + 4, y0 + 4, x0 + w - 6, y0 + h - 6
    if sx1 - sx0 > 8 and sy1 - sy0 > 6:
        k.recess(sx0, sy0, sx1, sy1, 2)
        d = k.ring_depth(sx0, sy0, sx1, sy1, 2)
        span = max(1, min(sx1 - sx0, sy1 - sy0) // 2)
        for i, c in enumerate([(34, 34, 50), (42, 42, 60), (50, 50, 70)]):
            M().fill_mask(d >= int(span * (0, 0.2, 0.5)[i]), c)


def fill_gap(x0, x1, top, bottom):
    """把 (x0..x1, top..bottom) 这块空隙从下往上塞满杂物，最上面一件刚好顶住上面那台电视。"""
    y = bottom
    while y > top:
        room_h = y - top
        h = room_h if room_h < 24 else random.randint(10, min(40, room_h))
        inset = random.randint(0, 6)
        xa, xb = x0 + inset, x1 - random.randint(0, 6)
        if xb - xa < 10:
            xa, xb = x0, x1
        kind = random.random()
        if h < 8:
            k.mid.rect(xa, y - h, xb, y - 1, (54, 52, 62)); k.mid.line(xa, y - h, xb, y - h, (78, 74, 86))
        elif kind < 0.3:
            for vx in range(xa, xb - 20, 64):
                vcr(vx, y - h, min(62, xb - vx), h - 1)
        elif kind < 0.55 and h >= 18:
            dead_tv(xa, y - h, min(xb - xa, int(h * 1.4)), h - 1)
            if xb - xa - int(h * 1.4) > 14:
                box(xa + int(h * 1.4) + 1, y - min(h, 20), xb - xa - int(h * 1.4) - 2, min(h, 20) - 1)
        elif kind < 0.75:
            for tx in range(xa, xb - 8, 16):
                tape_stack(tx, y - h, min(14, xb - tx), h - 1)
        else:
            for bx in range(xa, xb - 10, 40):
                box(bx, y - h, min(38, xb - bx), h - 1)
        y -= h


# ================================================================ 画
def build_far():
    f = k.far
    f.rect(0, 0, W - 1, H - 1, WALL[1])
    f.rect(0, 0, W - 1, 24, WALL[0])
    for x in range(0, W, 80):
        f.rect(x + 30, 0, x + 36, 24, WALL[2])
    for rx in range(-20, W, 140):                                           # 远处的货架
        f.rect(rx, 60, rx + 2, FLOOR, WALL[3]); f.rect(rx + 110, 60, rx + 112, FLOOR, WALL[3])
        for sy in range(110, FLOOR, 50):
            f.rect(rx, sy, rx + 112, sy + 2, WALL[3])
            x = rx + 4
            while x < rx + 100:
                tw, th = random.choice([14, 18, 22]), random.choice([12, 16, 20])
                if x + tw > rx + 108:
                    break
                f.rect(x, sy - th, x + tw, sy - 1, WALL[2]); f.line(x, sy - th, x + tw, sy - th, WALL[3])
                f.rect(x + 2, sy - th + 2, x + tw - 5, sy - 4, (52, 58, 82) if random.random() < 0.2 else (36, 36, 50))
                x += tw + random.choice([1, 2, 4])
    f.rect(0, FLOOR - 6, W - 1, H - 1, WALL[2])


def build_floor():
    m = k.mid
    m.rect(0, FLOOR, W - 1, H - 1, FLOOR_C[2])
    m.line(0, FLOOR, W - 1, FLOOR, FLOOR_C[0]); m.line(0, FLOOR + 1, W - 1, FLOOR + 1, FLOOR_C[1])
    m.rect(0, FLOOR + 7, W - 1, H - 1, FLOOR_C[3])


build_far()
build_floor()

tvs = []
for bottom, row in ROWS:
    trow = []
    for (x, w, h, P, ctrl, tintname, top, scene) in row:
        tv = TV(x, bottom - h, w, h, P, ctrl, tintname, top=top)
        tv.scene = scene
        trow.append(tv)
    tvs.append(trow)

# 先塞空隙（上层电视下面、下层电视上面）
for lower, upper in [(tvs[0], tvs[1]), (tvs[1], tvs[2])]:
    for u in upper:
        for l in lower:
            a, b = max(u.x0, l.x0), min(u.x1, l.x1)
            if b - a > 4 and l.y0 > u.y1 + 1:
                fill_gap(a, b, u.y1 + 1, l.y0)

for row in tvs:
    for tv in row:
        tv.draw_shell()

END = None
for row in tvs:
    for tv in row:
        name, fn = tv.scene
        if fn in (k.room_kitchen, k.room_living, k.room_bedroom, k.room_kids, k.room_study, k.room_entry):
            room(fn, tv)
        else:
            r = fn(tv)
            if name == "hometown":
                END = r

PASSAGES, HOLES = [], []


def passage(l, r):
    k.side_passage(l, r)
    PASSAGES.append({"x0": l.sx1 - 2, "x1": r.sx0 + 2, "y0": l.fy - 24, "floor": l.fy})


def hole(upper, lower, x):
    k.drop_hole(upper, lower, x)
    HOLES.append({"x0": x, "x1": x + 22, "top": upper.fy, "bottom": lower.fy, "ladder_x": x + 11})


for row in tvs:
    for l, r in zip(row, row[1:]):
        if l.x1 + 1 >= r.x0:
            passage(l, r)

r1, r2, r3 = tvs
hole(r2[7], r1[7], 1380)      # 第一层右端 → 第二层
hole(r3[0], r2[0], 150)       # 第二层左端 → 第三层
hole(r3[2], r2[2], 480)       # 近路：教室 ↓ 地铁
hole(r2[4], r1[4], 820)       # 近路：摩天轮 ↓ 客厅

# 起点：仓库地面左边，第一台电视左侧外壳砸开一个口，门口垫两个纸箱当台阶
a = r1[0]
k.mid.rect(a.x0 - 1, a.fy - 24, a.sx0 + 2, a.fy + 2, RECESS[0])
k.mid.rect(a.x0 - 1, a.fy - 24, a.sx0 + 2, a.fy - 23, RECESS[1])
for y in range(a.fy - 24, a.fy + 3):
    for x in range(a.sx0 - 2, a.sx0 + 4):
        k.scr.clear(x, y)
box(a.x0 - 34, FLOOR - 14, 30, 13)
box(a.x0 - 20, FLOOR - 26, 18, 11)
PASSAGES.append({"x0": a.x0 - 1, "x1": a.sx0 + 2, "y0": a.fy - 24, "floor": a.fy})
PLATFORMS.append((a.x0 - 34, a.x0 - 4, FLOOR - 14)); PLATFORMS.append((a.x0 - 20, a.x0 - 2, FLOOR - 26))
START = (40, FLOOR)

# 顶上的兔耳天线、垂下来的线
for tv in r3:
    if tv.top is None and tv.x1 - tv.x0 < 200:
        cx = (tv.x0 + tv.x1) // 2
        k.mid.line(cx, tv.y0, cx - 18, tv.y0 - 16, PLUM[5]); k.mid.line(cx + 1, tv.y0, cx + 20, tv.y0 - 14, PLUM[5])
        k.mid.rect(cx - 2, tv.y0 - 2, cx + 3, tv.y0 - 1, PLUM[4])
for (ax, bx, sag) in [(-10, 300, 40), (260, 700, 30), (640, 1000, 20), (1240, 1450, 160), (1280, 1440, 300)]:
    k.cable([(ax, 4), (bx, 8)], sag, 2)

mid = facet(k.mid, cell=11, min_area=60, grad=0.6, seed=5,
            keep=tuple(RECESS) + tuple(FLOOR_C) + (GLARE,) + tuple(PCB))
k.mid = mid

for name, c in [("l3_far", k.far), ("l3_mid", k.mid), ("l3_screens", k.scr), ("l3_near", k.near)]:
    Image.fromarray(c.a).save(OUT / f"{name}.png")

# ---------------------------------------------------------------- 布局 JSON
layout = {
    "size": [W, H], "warehouse_floor": FLOOR, "start": START, "end": END,
    "screens": [{"name": tv.scene[0], "row": ri + 1, "tint": tv.tint,
                 "casing": [tv.x0, tv.y0, tv.x1, tv.y1], "screen": [tv.sx0, tv.sy0, tv.sx1, tv.sy1], "floor": tv.fy}
                for ri, row in enumerate(tvs) for tv in row],
    "passages": PASSAGES, "holes": HOLES,
    "platforms": [{"x0": a_, "x1": b_, "y": y_} for a_, b_, y_ in PLATFORMS],
    "note": "外壳是实心墙；屏幕里地面在 floor；passages 是左右通道（齐地面）；holes 是上下的洞，ladder_x 是电线梯子；platforms 是单向平台。",
}
(OUT / "l3_layout.json").write_text(json.dumps(layout, ensure_ascii=False, indent=1))


# ---------------------------------------------------------------- 预览
def over(dst, src):
    m_ = src[..., 3] > 0
    dst[m_] = src[m_]
    return dst


raw = np.zeros((H, W, 4), np.uint8)
for c in (k.far, k.mid, k.scr, k.near):
    over(raw, c.a)
chars = OUT.parents[1] / "oscar-rush/art/chars"
hero = over(np.array(Image.open(chars / "red_body.png").convert("RGBA"))[:, 0:16],
            np.array(Image.open(chars / "red_strip.png").convert("RGBA"))[:, 0:16])
hx, hy = 60, FLOOR - hero.shape[0]
over(raw[hy:hy + hero.shape[0], hx:hx + 16], hero)
Image.fromarray(raw).save(OUT / "预览L3_原图.png")

DARK = np.array([0.36, 0.35, 0.41])
light = np.ones((H, W, 3)) * DARK
k.LIGHTS.append((hx + 8, hy + 6, 60, (255, 200, 140), 0.7))
for (lx, ly, r, col, kk) in k.LIGHTS:
    x0_, x1_ = int(max(0, lx - r - 2)), int(min(W, lx + r + 2))
    y0_, y1_ = int(max(0, ly - r - 2)), int(min(H, ly + r + 2))
    if x1_ <= x0_ or y1_ <= y0_:
        continue
    d = np.hypot(k.XX[y0_:y1_, x0_:x1_] - lx, (k.YY[y0_:y1_, x0_:x1_] - ly) * 1.15) / r
    band = np.floor(np.clip(1 - d, 0, 1) * 4) / 4
    light[y0_:y1_, x0_:x1_] += band[..., None] * (np.array(col) / 255.0) * kk
lit = raw[..., :3] * np.clip(light, 0, 1.15)
unshaded = k.scr.a[..., 3] > 0
lit[unshaded] = raw[..., :3][unshaded]
lit = np.clip(lit, 0, 255).astype(np.uint8)
game = Image.fromarray(lit)
game.save(OUT / "预览L3_游戏.png")
game.resize((W * 2, H * 2), Image.NEAREST).save(OUT / "预览L3_游戏_2x.png")

# 路线图：红线
route = Canvas(W, H, np.dstack([lit, np.full((H, W), 255, np.uint8)]))
RED = (236, 60, 60)


def rline(p, q):
    route.line(p[0], p[1], q[0], q[1], RED); route.line(p[0], p[1] - 1, q[0], q[1] - 1, RED)


y1, y2, y3 = r1[0].fy - 6, r2[0].fy - 6, r3[0].fy - 6
pts = [(START[0], FLOOR - 6), (a.x0 - 30, FLOOR - 20), (a.sx0 + 4, y1), (1391, y1), (1391, y2), (150 + 11, y2),
       (161, y3), (END[0], y3)]
for p, q in zip(pts, pts[1:]):
    rline(p, q)
for hx_, ytop, ybot in [(491, r3[2].fy, r2[2].fy), (831, r2[4].fy, r1[4].fy)]:   # 近路：虚线
    for y in range(ytop, ybot, 6):
        route.line(hx_, y, hx_, y + 2, (246, 160, 160))
route.rect(START[0] - 3, FLOOR - 12, START[0] + 3, FLOOR - 6, (120, 230, 140))
route.rect(END[0] - 3, END[1] - 12, END[0] + 3, END[1] - 6, (250, 230, 110))
route.save(OUT / "预览L3_路线.png")
print("ok", len(PASSAGES), "passages", len(HOLES), "holes", len(PLATFORMS), "platforms", "end", END)
