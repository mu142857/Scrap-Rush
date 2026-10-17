"""第三关的场景库：每个函数在一块屏幕里画一个场景（tv.sx0..sx1, tv.sy0..sy1，地面 tv.fy）。
画法沿用 crt_wall_v2.py（光照色块 + 体积）。排布在 crt_level3.py。
"""
import random

import numpy as np

import crt_wall_v2 as k
from crt_wall_v2 import (KHAKI, WOOD, GREY, PLUM, RECESS, GLARE, LED_RED, LED_GRN, TV)
from crt_wall_v2 import shade, box as kbox, extrude, floor_shadow, panel

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


# ================================================================ 大件：树冠、飞船、房子
def canopy(cx, cy, r, base, n=9, seed=0):
    """树冠：一团不规则的多边形色块，左上朝光的亮、右下背光的暗，暗的先画、亮的盖在上面。"""
    rr = random.Random(seed)
    blobs = []
    for _ in range(n):
        a = rr.uniform(0, 2 * np.pi)
        d = rr.uniform(0, r * 0.6)
        bx, by = cx + d * np.cos(a), cy + d * np.sin(a) * 0.8
        br = rr.uniform(r * 0.35, r * 0.6)
        lit = -((bx - cx) + (by - cy)) / r * 1.6
        blobs.append((lit, bx, by, br))
    for lit, bx, by, br in sorted(blobs):
        pts = []
        for j in range(7):
            t = 2 * np.pi * j / 7 + rr.uniform(-0.3, 0.3)
            rad = br * rr.uniform(0.75, 1.1)
            pts.append((bx + rad * np.cos(t), by + rad * np.sin(t) * 0.85))
        S().poly(pts, shade(base, int(np.clip(round(lit), -2, 2))))
    for _ in range(int(r)):                                             # 叶尖的亮点
        a = rr.uniform(np.pi, 1.6 * np.pi)
        S().put(int(cx + r * 0.8 * np.cos(a) * rr.uniform(0.6, 1)), int(cy + r * 0.7 * np.sin(a) * rr.uniform(0.6, 1)), shade(base, 3))


def tree(x, fy, h, r, leaf=(70, 104, 86), bark=(96, 70, 64), seed=0):
    floor_shadow(x - r // 2, x + r, fy, 3)
    S().poly([(x - 2, fy), (x + 4, fy), (x + 3, fy - h), (x, fy - h)], bark)
    S().poly([(x + 2, fy), (x + 4, fy), (x + 3, fy - h), (x + 2, fy - h)], shade(bark, -2))
    S().line(x + 1, fy - h // 2, x - 6, fy - h // 2 - 8, bark)
    canopy(x + 1, fy - h - r * 0.4, r, leaf, seed=seed)


def ship(sx, sy, scale=1.0, flame=False):
    """他们那艘旧飞船：机身挤出厚度，舱窗有反光，侧面一排铆钉。"""
    s_ = scale
    hull = [(sx, sy), (sx + 40 * s_, sy - 4 * s_), (sx + 52 * s_, sy + 4 * s_), (sx + 40 * s_, sy + 12 * s_), (sx, sy + 12 * s_)]
    extrude(hull, (170, 168, 176), depth=0.05, cap=5)
    S().poly([(sx, sy + 7 * s_), (sx + 46 * s_, sy + 7 * s_), (sx + 40 * s_, sy + 12 * s_), (sx, sy + 12 * s_)], (140, 138, 150))
    S().line(sx + 2, sy + 1, sx + 38 * s_, sy - 3 * s_, (206, 204, 210))
    for rx in range(int(sx + 4), int(sx + 36 * s_), 5):
        S().put(rx, int(sy + 9 * s_), (110, 108, 120))
    S().rect(int(sx + 26 * s_), int(sy), int(sx + 35 * s_), int(sy + 4 * s_), (96, 140, 196))
    S().line(int(sx + 27 * s_), int(sy + 1), int(sx + 29 * s_), int(sy + 1), (190, 220, 246))
    kbox(int(sx - 4), int(sy + 2), int(sx), int(sy + 10 * s_), (120, 118, 130), depth=0.03)
    S().rect(int(sx + 6), int(sy + 2), int(sx + 12), int(sy + 5), (206, 72, 64))   # 红色编号牌
    if flame:
        S().poly([(sx - 4, sy + 3), (sx - 14 * s_, sy + 6), (sx - 4, sy + 9)], (246, 170, 90))
        S().poly([(sx - 4, sy + 5), (sx - 9 * s_, sy + 6), (sx - 4, sy + 7)], (252, 236, 180))


def house(hx, gy, w=64, wall_h=36, gable=26, wall=(222, 206, 180), roof=(160, 86, 76)):
    """家：正面是墙加三角山墙，朝灭点挤出侧墙和屋顶的斜面；屋顶一行行瓦，烟囱冒烟，
    窗户透出暖光照在地上，门开着，门口两级台阶和一盏门灯。返回门口的位置。"""
    top = gy - wall_h
    front = [(hx, gy), (hx + w, gy), (hx + w, top), (hx + w // 2, top - gable), (hx, top)]
    floor_shadow(hx - 10, hx + w, gy, 4)
    extrude(front, wall, depth=0.12, cap=16, top=roof, side=shade(wall, -3))
    # 瓦：屋顶色的像素每隔 3 行暗一档，再在瓦檐上压一道亮边
    sub = S().a
    ys, xs = np.nonzero((sub[..., 0] == roof[0]) & (sub[..., 1] == roof[1]) & (sub[..., 2] == roof[2]))
    for y, x in zip(ys, xs):
        if (y - top) % 3 == 0:
            sub[y, x, :3] = shade(roof, -1)
        elif (x + y) % 9 == 0:
            sub[y, x, :3] = shade(roof, 1)
    # 屋檐：沿两条山墙边各一道 2 格粗的檐板，伸出墙外
    for (ax, ay), (bx, by) in [((hx - 4, top + 3), (hx + w // 2, top - gable - 1)), ((hx + w // 2, top - gable - 1), (hx + w + 4, top + 3))]:
        S().line(ax, ay, bx, by, shade(roof, -2)); S().line(ax, ay - 1, bx, by - 1, roof); S().line(ax, ay + 1, bx, by + 1, shade(roof, -3))
    # 山墙上的小圆窗
    disc(hx + w // 2, top - gable // 2 + 2, 3, (250, 214, 140)); S().put(hx + w // 2 - 1, top - gable // 2 + 1, (255, 240, 200))
    # 烟囱 + 烟
    kbox(hx + w - 18, top - gable + 2, hx + w - 11, top - 6, (150, 116, 108), depth=0.1, cap=6)
    kbox(hx + w - 19, top - gable, hx + w - 10, top - gable + 2, (126, 98, 94), depth=0.1, cap=6)
    for i, (dx, r_) in enumerate([(0, 2), (3, 3), (7, 3), (12, 4)]):
        disc(hx + w - 15 + dx, top - gable - 4 - i * 5, r_, (196, 186, 200) if i % 2 else (176, 168, 186))
    # 墙上的护墙板横线
    for yy in range(top + 4, gy, 4):
        S().line(hx + 1, yy, hx + w - 1, yy, shade(wall, -1))
    # 窗：窗框挤出来，玻璃暖光，窗台，地上一块光
    for wx in (hx + 7, hx + w - 19):
        S().poly([(wx - 2, gy + 1), (wx + 14, gy + 1), (wx + 20, gy + 7), (wx - 8, gy + 7)], (130, 168, 120))
        kbox(wx - 1, top + 8, wx + 12, top + 22, (240, 236, 226), depth=0.05, cap=3)
        S().rect(wx + 1, top + 10, wx + 10, top + 20, (252, 214, 140))
        S().rect(wx + 1, top + 10, wx + 10, top + 11, (255, 236, 186))
        S().line(wx + 5, top + 10, wx + 5, top + 20, (200, 150, 110)); S().line(wx + 1, top + 15, wx + 10, top + 15, (200, 150, 110))
        S().rect(wx + 6, top + 16, wx + 9, top + 19, (226, 170, 120))         # 窗帘一角
        kbox(wx - 2, top + 23, wx + 13, top + 24, (240, 236, 226), depth=0.05, cap=3)
        for fx in range(wx, wx + 12, 3):                                  # 窗台花箱
            S().put(fx, top + 22, random.choice([(230, 110, 120), (246, 214, 120), (180, 120, 200)]))
    # 门：开着，里面暖光；门框、两级台阶、门灯的光晕
    dx0 = hx + w // 2 - 6
    halo = (k.XX - (dx0 + 15)) ** 2 + (k.YY - (top + 6)) ** 2
    for rad, kk in [(12, 1), (7, 2)]:
        S().fill_mask((halo <= rad * rad) & (S().a[..., 0] == wall[0]) & (S().a[..., 1] == wall[1]), shade(wall, kk))
    kbox(dx0 - 2, top + 6, dx0 + 13, gy, (176, 120, 100), depth=0.04, cap=3)
    S().rect(dx0, top + 8, dx0 + 11, gy, (252, 226, 160))
    S().rect(dx0 + 4, top + 12, dx0 + 8, gy - 4, (236, 196, 140))            # 屋里一个小身影的剪影：等着他们回家
    S().put(dx0 + 6, top + 11, (236, 196, 140))
    S().poly([(dx0, top + 8), (dx0 - 4, top + 6), (dx0 - 4, gy + 1), (dx0, gy)], (120, 80, 70))   # 打开的门板
    kbox(dx0 - 4, gy, dx0 + 15, gy + 1, (176, 160, 150), depth=0.05, cap=3)
    kbox(dx0 - 7, gy + 2, dx0 + 18, gy + 3, (160, 146, 138), depth=0.05, cap=3)
    S().rect(dx0 + 15, top + 4, dx0 + 16, top + 5, (150, 110, 70)); S().put(dx0 + 15, top + 6, (255, 244, 200)); S().put(dx0 + 16, top + 6, (246, 220, 150))
    plat(hx - 4, hx + w // 2, top - 2)
    return (dx0 + 5, gy)


def fence(x0, x1, y_at, c=(176, 150, 130)):
    """栅栏：每根桩子挤出一点厚度，两道横杆。y_at(x) 给出那一格的地面高度。"""
    for fx in range(int(x0), int(x1), 7):
        gy = int(y_at(fx))
        kbox(fx, gy - 9, fx + 1, gy, c, depth=0.03, cap=2)
        S().put(fx, gy - 10, shade(c, 2))
    for dy in (6, 3):
        pts = [(fx, int(y_at(fx)) - dy) for fx in range(int(x0), int(x1), 7)]
        S().polyline(pts, shade(c, -1))


# ================================================================ 新场景
def sc_rain_street(tv):
    """雨夜街道（黑白）：远近两排楼、亮着的窗、路灯照出的一圈地面、积水倒影、斜着的雨。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    bands_v(tv, y0, fy, [(22, 24, 36), (28, 30, 44), (36, 38, 54)])
    for layer, (cols, hmin, hmax, wl) in enumerate([([(58, 60, 78), (64, 66, 84)], 0.55, 0.85, 0.22),
                                                    ([(92, 94, 112), (104, 104, 122), (84, 86, 104)], 0.25, 0.6, 0.4)]):
        x = x0 - 4 - layer * 9
        while x < x1:
            bw = random.randint(22, 40)
            bh = random.randint(int((fy - y0) * hmin), int((fy - y0) * hmax))
            c = random.choice(cols)
            S().rect(x, fy - bh, x + bw, fy, c)
            S().line(x, fy - bh, x + bw, fy - bh, tuple(min(255, v + 18) for v in c))
            if layer == 1 and random.random() < 0.5:
                S().rect(x + bw // 2 - 1, fy - bh - 6, x + bw // 2, fy - bh, c)       # 楼顶天线
            for wy in range(fy - bh + 5, fy - 10, 8):
                for wx in range(x + 4, x + bw - 4, 7):
                    if random.random() < wl:
                        S().rect(wx, wy, wx + 3, wy + 4, (224, 206, 146) if layer else (150, 140, 110))
            x += bw + random.randint(1, 8)
    ground(tv, [(110, 112, 128), (70, 72, 88), (60, 62, 78), (52, 54, 70)])
    for lx in range(x0 + 34, x1 - 10, 74):
        S().rect(lx, fy - 40, lx + 1, fy, (40, 42, 54))
        S().rect(lx - 3, fy - 42, lx + 4, fy - 40, (40, 42, 54))
        S().rect(lx - 2, fy - 39, lx + 3, fy - 39, (246, 236, 196))
        S().poly([(lx - 2, fy - 38), (lx + 3, fy - 38), (lx + 7, fy - 30), (lx - 6, fy - 30)], (120, 120, 132))
        for r_, c in [(18, (130, 132, 146)), (10, (176, 176, 186))]:              # 地上一圈光
            disc(lx, fy + 2, r_, c, 2)
        plat(lx - 3, lx + 4, fy - 42)
    for _ in range((x1 - x0) * (fy - y0) // 300):
        rx, ry = random.randint(x0, x1), random.randint(y0, fy + 6)
        S().line(rx, ry, rx - 1, ry + 3, (150, 160, 180))
    finish(tv, (x0 + 34, fy - 40))


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
    """雪夜的院子：后面一栋雪顶的小房子亮着窗，雪人、松树、栅栏、飘雪。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    bands_v(tv, y0, fy, [(46, 54, 96), (56, 66, 112), (70, 82, 128), (86, 98, 142)])
    hx = x0 + (x1 - x0) // 2 - 22
    house(hx, fy - 2, w=44, wall_h=26, gable=18, wall=(170, 150, 160), roof=(226, 230, 240))
    ground(tv, [(232, 236, 244), (214, 222, 236), (196, 206, 226), (180, 190, 214)])
    for sx_ in range(x0, x1, 9):                                            # 雪堆起伏
        disc(sx_, fy + 1, 6, (240, 242, 250), 2)
    fence(x0 + 2, x0 + 40, lambda x: fy, c=(140, 112, 110))
    sx = x0 + 52                                                             # 雪人
    floor_shadow(sx - 6, sx + 6, fy, 2)
    disc(sx, fy - 6, 7, (240, 242, 248)); disc(sx + 2, fy - 4, 5, (214, 222, 236))
    disc(sx, fy - 17, 5, (240, 242, 248)); disc(sx + 2, fy - 16, 3, (214, 222, 236))
    S().put(sx - 2, fy - 18, (40, 40, 50)); S().put(sx + 1, fy - 18, (40, 40, 50)); S().put(sx + 3, fy - 17, (240, 150, 80))
    S().rect(sx - 5, fy - 13, sx + 5, fy - 12, (206, 72, 64)); S().rect(sx + 3, fy - 12, sx + 4, fy - 8, (176, 56, 56))
    tx = x1 - 22                                                             # 松树：每层左亮右暗，边上压雪
    for i in range(4):
        yb = fy - 6 - i * 10
        S().poly([(tx - 12 + i * 2, yb), (tx + 12 - i * 2, yb), (tx, yb - 16)], (44, 80, 72))
        S().poly([(tx - 12 + i * 2, yb), (tx, yb), (tx, yb - 16)], (60, 104, 88))
        S().line(tx - 11 + i * 2, yb - 1, tx - 1, yb - 1, (226, 230, 240))
    S().rect(tx - 1, fy - 6, tx + 1, fy, (90, 70, 66))
    for _ in range((x1 - x0) * (fy - y0) // 70):
        S().put(random.randint(x0, x1), random.randint(y0, fy), (236, 238, 246))
    finish(tv, (hx + 22, fy - 18))


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
    S().poly([(ux + 9, fy - 30), (ux + 26, fy - 30), (ux + 1, fy - 44)], (196, 90, 90))
    for sx_ in range(ux - 24, ux + 26, 2):
        S().put(sx_, fy - 29, shade((230, 110, 100), -3))
    S().poly([(ux - 20, fy - 5), (ux + 24, fy - 5), (ux + 30, fy - 2), (ux - 14, fy - 2)], (196, 166, 124))   # 伞的影子
    plat(ux - 24, ux + 26, fy - 30)
    px = x1 - 30                                                             # 棕榈树
    for i in range(30):
        S().rect(px + round(i * i / 90), fy - 6 - i * 2, px + 3 + round(i * i / 90), fy - 5 - i * 2, (120, 86, 70))
    top = (px + 10, fy - 66)
    for dx, dy in [(-22, 12), (-14, 18), (20, 14), (12, 20), (-4, -6), (16, -4)]:
        S().line(top[0], top[1], top[0] + dx, top[1] + dy, (70, 120, 90))
        S().line(top[0], top[1] + 1, top[0] + dx, top[1] + dy + 1, (56, 100, 80))
    kbox(x0 + 74, fy - 12, x0 + 86, fy - 6, (220, 186, 130), depth=0.06); kbox(x0 + 77, fy - 18, x0 + 83, fy - 13, (226, 194, 140), depth=0.06)
    S().put(x0 + 79, fy - 19, (226, 194, 140)); S().put(x0 + 81, fy - 19, (226, 194, 140)); S().line(x0 + 80, fy - 24, x0 + 80, fy - 19, (150, 120, 100)); S().put(x0 + 81, fy - 23, (206, 72, 64))
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
    """太空：星星、一颗被左边照亮的带环行星、一颗蓝绿小星球、他们那艘喷着火的旧飞船；地面是月球表面。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    bands_v(tv, y0, fy, [(14, 16, 32), (20, 22, 42), (28, 28, 54)])
    for _ in range((x1 - x0) * (fy - y0) // 60):
        S().put(random.randint(x0, x1), random.randint(y0, fy), random.choice([(236, 236, 246), (246, 226, 170), (170, 190, 246)]))
    px, py, r = x0 + int((x1 - x0) * 0.66), y0 + 30, 18
    base = (196, 140, 104)
    p = disc(px, py, r, shade(base, -2))
    for kk, (ox, rr_) in enumerate([(-3, 0.85), (-6, 0.62), (-9, 0.38)]):  # 球面：亮面偏左上，一圈圈往里亮
        disc(px + ox, py + ox * 0.6, r * rr_, shade(base, kk))
    S().fill_mask(p & (np.abs(k.YY - py - 3) < 1), shade(base, -1))
    ring = ((k.XX - px) / 32) ** 2 + ((k.YY - py) / 6) ** 2
    S().fill_mask((ring <= 1) & (ring > 0.62) & ~(p & (k.YY < py)), (226, 206, 170))
    S().fill_mask((ring <= 1) & (ring > 0.62) & ~(p & (k.YY < py)) & (k.XX > px + 10), (180, 160, 140))
    disc(x0 + 26, y0 + 22, 6, (90, 150, 200)); disc(x0 + 25, y0 + 21, 4, (110, 170, 214)); S().rect(x0 + 23, y0 + 19, x0 + 26, y0 + 21, (120, 190, 120))
    ship(x0 + 40, y0 + 52, 0.8, flame=True)
    ground(tv, [(170, 170, 180), (146, 146, 158), (126, 126, 140), (110, 110, 124)])
    for cx in range(x0 + 14, x1 - 6, 31):
        disc(cx, fy + 4, 6, (126, 126, 140), 2); disc(cx + 1, fy + 5, 4, (110, 110, 124), 1)
        S().line(cx - 5, fy + 2, cx + 5, fy + 2, (190, 190, 200))
    S().rect(x1 - 26, fy - 14, x1 - 25, fy, (200, 200, 210))
    S().rect(x1 - 24, fy - 14, x1 - 16, fy - 9, (206, 72, 64)); S().rect(x1 - 24, fy - 10, x1 - 16, fy - 9, (176, 56, 56))
    finish(tv, (px - 10, py - 10))


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
    wy0, wy1 = y0 + 24, y0 + int((fy - y0) * 0.58)
    for wx in range(x0 + 12, x1 - 30, 46):
        S().rect(wx, wy0, wx + 32, wy1, (36, 34, 44))
        for ly in range(wy0 + 4, wy1 - 2, 7):
            off = random.randint(0, 16)
            S().line(wx + off, ly, min(wx + 32, wx + off + random.randint(6, 16)), ly, (226, 186, 110))
        S().rect(wx - 2, wy0 - 2, wx + 34, wy0 - 1, (150, 140, 132)); S().rect(wx - 2, wy1 + 1, wx + 34, wy1 + 2, (150, 140, 132))
    S().rect(x0 + 4, fy - 26, x1 - 4, fy - 13, (120, 70, 62))                # 长椅靠背
    for sx in range(x0 + 4, x1 - 4, 12):
        S().line(sx, fy - 26, sx, fy - 13, (96, 56, 52))
    S().rect(x0 + 4, fy - 12, x1 - 4, fy - 9, (150, 86, 74))                 # 坐垫
    S().line(x0 + 4, fy - 12, x1 - 4, fy - 12, (190, 120, 96))
    S().rect(x0 + 4, fy - 8, x1 - 4, fy, (66, 54, 54))
    plat(x0 + 4, x1 - 4, fy - 12)
    for px in range(x0 + 52, x1 - 20, 92):
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
    floor_shadow(tx - 22, tx + 22, fy, 3)
    kbox(tx - 20, fy - 24, tx + 20, fy, (110, 80, 110), depth=0.05)
    kbox(tx - 22, fy - 3, tx + 22, fy, (150, 120, 140), depth=0.05)
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
    """森林：远处一层淡的树影，中间几棵粗细不一的树，树冠是一团团色块；
    一道光柱从树缝里打下来，小路、蕨草、蘑菇、萤火虫。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    bands_v(tv, y0, fy, [(170, 196, 170), (150, 178, 152), (128, 156, 134), (110, 136, 118)])
    rr = random.Random(x0)
    for tx in range(x0 - 10, x1 + 10, 14):                                 # 远处的树影
        th = rr.randint(int((fy - y0) * 0.5), int((fy - y0) * 0.9))
        S().rect(tx, fy - th, tx + 2, fy, (126, 154, 132))
        canopy(tx + 1, fy - th, rr.randint(8, 12), (120, 150, 126), n=5, seed=tx)
    lx = x0 + int((x1 - x0) * 0.4)
    S().poly([(lx, y0), (lx + 12, y0), (lx + 34, fy), (lx + 14, fy)], (206, 222, 190))
    S().poly([(lx + 4, y0), (lx + 8, y0), (lx + 26, fy), (lx + 20, fy)], (226, 236, 206))
    ground(tv, [(110, 132, 96), (96, 116, 86), (84, 102, 78)])
    S().fill_mask(tv.screen_mask() & (k.YY >= fy) & (np.abs(k.XX - (lx + 24)) < 8 + (k.YY - fy) * 3), (168, 156, 120))
    xs = sorted(rr.sample(range(x0 + 8, x1 - 16), min(5, max(2, (x1 - x0) // 40))))
    for i, tx in enumerate(xs):                                            # 近处的树
        if abs(tx - lx - 16) < 18:
            continue
        tw = rr.randint(4, 8)
        floor_shadow(tx - 6, tx + tw + 6, fy, 3)
        bark = (92, 76, 66)
        S().poly([(tx - 2, fy), (tx + tw + 2, fy), (tx + tw, fy - 6), (tx + tw, y0), (tx, y0), (tx, fy - 6)], bark)
        S().rect(tx + tw - 2, y0, tx + tw, fy - 1, shade(bark, -2))
        S().rect(tx, y0, tx + 1, fy - 1, shade(bark, 1))
        for ky in range(y0 + 10, fy - 6, rr.randint(9, 15)):
            S().line(tx + 2, ky, tx + tw - 3, ky + 2, shade(bark, -1))
        canopy(tx + tw // 2, y0 + rr.randint(4, 14), rr.randint(16, 24), (78, 118, 90), n=10, seed=tx * 3)
    for fx in range(x0 + 4, x1 - 4, rr.randint(9, 13)):                    # 蕨草
        for d_ in (-4, -2, 0, 2, 4):
            S().line(fx, fy, fx + d_, fy - 5 + abs(d_) // 2, (96, 146, 100) if d_ < 0 else (80, 124, 88))
    for mx in (x0 + 16, x1 - 20):
        S().rect(mx, fy - 3, mx + 1, fy, (226, 220, 200)); kbox(mx - 2, fy - 6, mx + 3, fy - 4, (206, 90, 80), depth=0.04, cap=1)
        S().put(mx - 1, fy - 6, (246, 230, 220))
    for _ in range(12):
        S().put(rr.randint(x0, x1), rr.randint(y0 + 20, fy - 4), (236, 246, 170))
    finish(tv, (lx + 10, y0 + 6))


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
    floor_shadow(wx - 2, wx + 22, fy, 3)
    kbox(wx, fy - 46, wx + 20, fy - 26, (140, 100, 86), depth=0.06)
    for by in (fy - 42, fy - 32):
        S().line(wx, by, wx + 20, by, shade((140, 100, 86), -2))
    S().poly([(wx - 2, fy - 46), (wx + 22, fy - 46), (wx + 10, fy - 54)], (120, 86, 76))
    S().poly([(wx + 10, fy - 46), (wx + 22, fy - 46), (wx + 10, fy - 54)], shade((120, 86, 76), -2))
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
        kbox(bx, by - bh, bx + bw, by, (186, 146, 104), depth=0.08)
        S().rect(bx + bw // 2 - 1, by - bh, bx + bw // 2 + 1, by - bh + 5, (214, 196, 160))
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
    floor_shadow(bx0 + 10, bx0 + 40, fy, 3)
    kbox(bx0 + 10, fy - 14, bx0 + 40, fy, (150, 104, 82))
    panel(bx0 + 13, fy - 11, bx0 + 24, fy - 3, (150, 104, 82))
    kbox(bx0 + 30, fy - 18, bx0 + 36, fy - 15, (226, 214, 180), depth=0.03)   # 讲台上的一摞作业本
    plat(bx0 + 10, bx0 + 40, fy - 14)
    for dx in range(bx0 + 54, x1 - 10, 24):
        floor_shadow(dx, dx + 14, fy, 2)
        S().rect(dx + 1, fy - 8, dx + 2, fy, (118, 82, 70)); S().rect(dx + 12, fy - 8, dx + 13, fy, (118, 82, 70))
        kbox(dx, fy - 10, dx + 14, fy - 9, (184, 136, 104))
        S().rect(dx + 16, fy - 6, dx + 21, fy - 5, (96, 136, 214)); S().rect(dx + 20, fy - 14, dx + 21, fy, (96, 136, 214))
        plat(dx, dx + 14, fy - 10)
    finish(tv, (x1 - 30, y0 + 20))


def sc_hometown(tv):
    """终点：家乡。暮色里的两个月亮、一层层的山，山坡上一座亮着灯的房子，门开着，门口亮着灯。
    一条石板小路从左边绕到门口，路边是栅栏和一棵挂着秋千的大树，左边停着那艘旧飞船。
    走到门口就是结局。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    w = x1 - x0
    bands_v(tv, y0, fy, [(46, 50, 96), (62, 62, 112), (86, 76, 126), (120, 92, 136), (166, 116, 140), (210, 148, 140), (238, 186, 150)])
    for _ in range(70):
        S().put(random.randint(x0, x1), random.randint(y0, y0 + 80), random.choice([(226, 226, 246), (200, 206, 240)]))
    mx, my = x0 + 70, y0 + 34                                                # 两个月亮：一个弯的，一个圆的
    disc(mx, my, 12, (240, 236, 220)); disc(mx - 3, my - 3, 8, (252, 248, 236)); disc(mx + 5, my - 3, 10, (62, 62, 112))
    disc(x1 - 120, y0 + 22, 6, (230, 210, 200)); disc(x1 - 122, y0 + 20, 3, (246, 232, 222))
    for i, (c, base, amp, f) in enumerate([((126, 100, 150), 0.5, 14, 0.021), ((104, 92, 142), 0.62, 12, 0.03), ((84, 98, 124), 0.74, 10, 0.017)]):
        top = y0 + (fy - y0) * base + amp * np.sin(k.XX * f + i * 2)
        m = tv.screen_mask() & (k.YY >= top) & (k.YY < fy)
        S().fill_mask(m, c)
        S().fill_mask(m & (k.YY < top + 2), shade(c, 2))                     # 山脊被暮光照亮的一道边
    hc = x0 + int(w * 0.68)
    hill_top = fy - 30 - 22 * np.exp(-((k.XX - hc) / (w * 0.22)) ** 2)
    grass = (86, 120, 100)
    m = tv.screen_mask() & (k.YY >= hill_top) & (k.YY < fy)
    S().fill_mask(m, grass)
    S().fill_mask(m & (k.YY < hill_top + 2) & (k.XX < hc), shade(grass, 2))
    S().fill_mask(m & (k.YY >= hill_top + 5), shade(grass, -1))
    ground(tv, [(96, 132, 104), (80, 114, 92), (70, 100, 84), (62, 88, 78)])
    for _ in range(w // 3):                                                 # 草尖
        gx = random.randint(x0, x1)
        gy = int(max(hill_top[0, gx], y0)) + random.randint(2, 20)
        if gy < fy + 2:
            S().put(gx, gy, shade(grass, random.choice([2, -2])))
    door = house(hc - 42, int(fy - 20), w=84, wall_h=46, gable=32)
    # 石板小路：从左边弯到台阶
    for i in range(0, 46):
        t = i / 45
        px = x0 + 30 + (door[0] - x0 - 30) * t
        py = fy - 1 - (fy - door[1] - 4) * t ** 2.2
        if i % 2 == 0:
            r_ = 3 - t * 1.2
            disc(px, py, r_ + 1, (176, 160, 130), max(1, r_ * 0.5))
            S().put(int(px - 1), int(py - 1), (206, 192, 160))
    fence(hc - 110, hc - 48, lambda x: hill_top[0, x] + 8 if hill_top[0, x] + 8 < fy else fy)
    tx = hc + 84                                                            # 大树 + 秋千
    tree(tx, fy, 52, 22, seed=3)
    S().line(tx - 8, fy - 44, tx - 8, fy - 14, (190, 180, 170)); S().line(tx + 2, fy - 44, tx + 2, fy - 14, (190, 180, 170))
    kbox(tx - 9, fy - 14, tx + 3, fy - 13, (150, 104, 82), depth=0.04, cap=2)
    plat(tx - 9, tx + 3, fy - 14)
    tree(x1 - 40, fy, 30, 14, leaf=(80, 96, 100), seed=5)
    ship(x0 + 46, fy - 14, 1.0)
    S().line(x0 + 54, fy - 2, x0 + 50, fy, (120, 118, 130)); S().line(x0 + 80, fy - 2, x0 + 84, fy, (120, 118, 130))
    plat(x0 + 46, x0 + 86, fy - 18)
    for _ in range(22):
        S().put(random.randint(x0 + 20, x1 - 20), random.randint(fy - 70, fy - 4), (236, 246, 170))
    finish(tv, (door[0], door[1] - 10))
    k.LIGHTS.append((door[0], door[1] - 10, 70, (255, 220, 160), 0.55))
    return door


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




# ================================================================ 新加的四个场景（2026-10-17 地图加大）
def sc_bathroom(tv):
    """浴室：瓷砖墙、浴缸和浴帘、洗手台和镜子、一只小黄鸭。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw = x1 - x0
    lamp = (x0 + int(rw * 0.55), y0 + 14)
    k.room_base(tv, [(206, 222, 220), (188, 206, 206), (166, 186, 190), (144, 164, 172), (124, 140, 154)], k.TILE_FLOOR, lamp)
    tile = tv.screen_mask() & (k.YY < fy - 1) & (k.YY > y0 + int((fy - y0) * 0.35))
    S().fill_mask(tile & (((k.XX - x0) % 8 == 0) | ((k.YY - y0) % 8 == 0)), (150, 170, 176))
    S().fill_mask(tv.screen_mask() & (k.YY == y0 + int((fy - y0) * 0.35)), (226, 236, 236))
    bx0 = x0 + 8                                                             # 浴缸
    floor_shadow(bx0, bx0 + 50, fy, 4)
    kbox(bx0, fy - 16, bx0 + 50, fy - 2, (236, 236, 232))
    S().rect(bx0 + 2, fy - 16, bx0 + 48, fy - 15, (150, 196, 214))
    for fx in (bx0 + 3, bx0 + 46):
        S().rect(fx, fy - 2, fx + 2, fy, (200, 180, 120))
    S().line(bx0 - 2, y0 + 16, bx0 + 52, y0 + 16, (180, 180, 186))          # 浴帘杆和半拉开的浴帘
    for i in range(6):
        cx = bx0 + 34 + i * 3
        S().rect(cx, y0 + 17, cx + 2, fy - 18, (206, 130, 150) if i % 2 else (230, 160, 176))
    S().rect(bx0 + 10, fy - 20, bx0 + 14, fy - 17, (246, 214, 100)); S().put(bx0 + 15, fy - 19, (240, 150, 80)); S().put(bx0 + 12, fy - 21, (246, 214, 100))
    plat(bx0, bx0 + 50, fy - 16)
    sx = x1 - 44                                                             # 洗手台 + 镜子
    floor_shadow(sx, sx + 26, fy, 3)
    kbox(sx + 10, fy - 18, sx + 16, fy, (226, 226, 222))
    kbox(sx, fy - 24, sx + 26, fy - 18, (236, 236, 232))
    S().rect(sx + 12, fy - 27, sx + 13, fy - 25, (180, 184, 196))
    kbox(sx + 1, fy - 56, sx + 25, fy - 32, (170, 180, 186), depth=0.03)
    S().rect(sx + 3, fy - 54, sx + 23, fy - 34, (190, 214, 226))
    S().line(sx + 6, fy - 50, sx + 12, fy - 44, (230, 240, 246)); S().line(sx + 8, fy - 50, sx + 14, fy - 44, (230, 240, 246))
    for i, c in enumerate([(206, 72, 64), (190, 140, 96), (96, 136, 214), (110, 180, 100)]):   # 四支牙刷
        S().line(sx + 4 + i * 2, fy - 31, sx + 4 + i * 2, fy - 27, c)
    kbox(sx + 2, fy - 27, sx + 11, fy - 25, (226, 214, 200), depth=0.03)
    plat(sx, sx + 26, fy - 24)
    finish(tv, lamp)


def sc_workshop(tv):
    """工作间：洞洞板上挂着工具、长工作台和台钳、红色工具箱、一辆自行车、一盏吊着的灯泡。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw = x1 - x0
    lamp = (x0 + int(rw * 0.76), y0 + 34)             # 吊在洞洞板右边的空墙前面，不和工具挤在一起
    k.room_base(tv, [(176, 168, 150), (160, 150, 134), (142, 132, 120), (122, 112, 104), (104, 96, 92)],
                [(130, 124, 118), (116, 110, 106), (102, 96, 94), (90, 84, 84)], lamp)
    px0, px1 = x0 + 10, x0 + int(rw * 0.62)
    kbox(px0, y0 + 18, px1, fy - 24, (190, 160, 120), depth=0.02)
    for hy in range(y0 + 21, fy - 25, 4):
        for hx in range(px0 + 2, px1 - 1, 4):
            S().put(hx, hy, (150, 120, 92))
    tools = [((80, 84, 96), 4, 16), ((176, 96, 80), 3, 12), ((80, 84, 96), 8, 4), ((96, 136, 180), 3, 14), ((80, 84, 96), 6, 10)]
    tx = px0 + 6
    while tx < px1 - 10:
        c, tw, th = random.choice(tools)
        S().rect(tx, y0 + 24, tx + tw, y0 + 24 + th, c); S().line(tx, y0 + 24, tx, y0 + 24 + th, shade(c, 2))
        tx += tw + 5
    floor_shadow(px0 - 4, px1 + 4, fy, 4)
    kbox(px0 - 4, fy - 20, px1 + 4, fy - 17, (150, 110, 80))                 # 工作台
    for lx in (px0 - 2, px1):
        kbox(lx, fy - 16, lx + 2, fy, (110, 84, 66))
    kbox(px0 + 4, fy - 26, px0 + 12, fy - 21, (90, 96, 110))                  # 台钳
    kbox(px1 - 20, fy - 28, px1 - 4, fy - 21, (200, 76, 66))                  # 工具箱
    S().line(px1 - 15, fy - 30, px1 - 9, fy - 30, (60, 50, 50))
    plat(px0 - 4, px1 + 4, fy - 20)
    bx = x1 - 34                                                              # 自行车
    for wx in (bx, bx + 22):
        ring = np.abs(np.hypot(k.XX - wx, k.YY - (fy - 7)) - 6.5) < 0.8
        S().fill_mask(ring & tv.screen_mask(), (60, 60, 70))
        S().put(wx, fy - 7, (180, 180, 190))
    S().polyline([(bx, fy - 7), (bx + 8, fy - 16), (bx + 18, fy - 16), (bx + 22, fy - 7), (bx + 11, fy - 7), (bx + 8, fy - 16)], (206, 72, 64))
    S().line(bx + 18, fy - 16, bx + 17, fy - 20, (60, 60, 70)); S().line(bx + 15, fy - 20, bx + 20, fy - 20, (60, 60, 70))
    S().rect(bx + 6, fy - 18, bx + 10, fy - 17, (60, 50, 50))
    S().line(lamp[0], y0, lamp[0], lamp[1] - 5, (70, 60, 60))
    S().poly([(lamp[0] - 6, lamp[1]), (lamp[0] + 7, lamp[1]), (lamp[0] + 2, lamp[1] - 5), (lamp[0] - 1, lamp[1] - 5)], (110, 116, 124))
    S().line(lamp[0] - 6, lamp[1], lamp[0] + 6, lamp[1], (70, 74, 84))           # 铁灯罩
    S().rect(lamp[0] - 2, lamp[1] + 1, lamp[0] + 2, lamp[1] + 3, (255, 244, 200))  # 灯泡
    finish(tv, lamp)


def sc_harbor(tv):
    """夜里的港口：灯塔一道光扫过海面，几条小船，栈桥木板是地面，码头上的木箱。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    hz = fy - int((fy - y0) * 0.32)
    bands_v(tv, y0, hz, [(30, 36, 70), (40, 48, 86), (54, 62, 102), (72, 80, 120)])
    for _ in range(40):
        S().put(random.randint(x0, x1), random.randint(y0, hz - 10), (220, 224, 246))
    lx = x1 - 40                                                              # 灯塔
    beam = [(lx, y0 + 26), (x0, y0 + 10), (x0, y0 + 40)]
    S().poly(beam, (90, 96, 128))
    S().poly([(lx, y0 + 26), (x0 + (lx - x0) // 2, y0 + 20), (x0 + (lx - x0) // 2, y0 + 30)], (120, 124, 150))
    lh = hz - (y0 + 30)
    pts = [(lx - 7, hz), (lx + 7, hz), (lx + 4, y0 + 30), (lx - 4, y0 + 30)]
    extrude(pts, (226, 222, 214), depth=0.05, cap=4)
    for i in range(3):
        yb = y0 + 34 + i * lh // 3
        S().fill_mask(S().poly(pts) & (k.YY >= yb) & (k.YY < yb + lh // 6), (200, 80, 76))
    kbox(lx - 6, y0 + 22, lx + 6, y0 + 29, (60, 60, 76), depth=0.04)
    S().rect(lx - 4, y0 + 23, lx + 4, y0 + 28, (252, 236, 170))
    S().poly([(lx - 7, y0 + 22), (lx + 7, y0 + 22), (lx, y0 + 15)], (180, 70, 70))
    bands_v(tv, hz, fy, [(40, 56, 96), (34, 48, 86), (28, 40, 76)])
    for y in range(hz + 2, fy, 3):
        for xx in range(x0 + (y * 5) % 13, x1, 17):
            S().line(xx, y, xx + 5, y, (70, 90, 130))
    for i, bx in enumerate((x0 + 20, x0 + 70)):                               # 小船
        by = hz + 8 + i * 4
        extrude([(bx, by), (bx + 26, by), (bx + 21, by + 6), (bx + 4, by + 6)], [(196, 120, 96), (110, 150, 180)][i], depth=0.04, cap=3)
        S().line(bx + 12, by, bx + 12, by - 18, (190, 180, 170))
        S().poly([(bx + 13, by - 17), (bx + 13, by - 2), (bx + 22, by - 2)], (230, 226, 214))
    S().fill_mask(tv.screen_mask() & (k.YY >= fy), (130, 98, 80))             # 栈桥
    for xx in range(x0, x1, 6):
        S().line(xx, fy, xx, tv.sy1, (104, 76, 66))
    S().line(x0, fy, x1, fy, (170, 130, 100))
    for px in range(x0 + 8, x1, 30):
        kbox(px, fy - 6, px + 3, fy, (110, 80, 68), depth=0.04, cap=2)
    for cx_, ch in [(x0 + 40, 12), (x0 + 54, 8)]:
        kbox(cx_, fy - ch, cx_ + 12, fy, (176, 140, 100), depth=0.06)
        S().line(cx_, fy - ch, cx_ + 12, fy, shade((176, 140, 100), -2))
        plat(cx_, cx_ + 12, fy - ch)
    finish(tv, (lx, y0 + 26))


def sc_desert(tv):
    """白天的沙漠：大太阳、一层层沙丘、仙人掌、石头，沙里埋着半台旧电视。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    bands_v(tv, y0, fy, [(240, 214, 170), (236, 196, 150), (230, 178, 140), (222, 162, 136)])
    disc(x0 + int((x1 - x0) * 0.7), y0 + 24, 12, (252, 240, 200))
    for i, (c, base, amp, f) in enumerate([((214, 160, 120), 0.55, 8, 0.04), ((204, 146, 108), 0.7, 9, 0.03), ((222, 172, 124), 0.84, 6, 0.05)]):
        top = y0 + (fy - y0) * base + amp * np.sin(k.XX * f + i)
        m = tv.screen_mask() & (k.YY >= top) & (k.YY < fy)
        S().fill_mask(m, c)
        S().fill_mask(m & (k.YY < top + 2) & (np.cos(k.XX * f + i) > 0), shade(c, 2))   # 沙丘迎光的一面
    ground(tv, [(232, 188, 136), (220, 176, 126), (208, 164, 118)])
    for cx_, h in [(x0 + 24, 30), (x1 - 30, 22)]:                            # 仙人掌
        floor_shadow(cx_ - 3, cx_ + 8, fy, 2)
        kbox(cx_, fy - h, cx_ + 4, fy, (96, 150, 104), depth=0.05, cap=2)
        kbox(cx_ - 6, fy - h + 8, cx_ - 4, fy - h + 16, (96, 150, 104), depth=0.05, cap=2); S().rect(cx_ - 6, fy - h + 15, cx_, fy - h + 16, (96, 150, 104))
        kbox(cx_ + 7, fy - h + 4, cx_ + 9, fy - h + 12, (96, 150, 104), depth=0.05, cap=2); S().rect(cx_ + 4, fy - h + 11, cx_ + 9, fy - h + 12, (96, 150, 104))
        for sy_ in range(fy - h + 2, fy, 4):
            S().put(cx_ + 1, sy_, (160, 200, 150))
        plat(cx_, cx_ + 4, fy - h)
    tvx = x0 + (x1 - x0) // 2 - 14                                           # 半埋的旧电视
    S().poly([(tvx - 2, fy - 18), (tvx + 26, fy - 22), (tvx + 30, fy), (tvx, fy)], (176, 168, 150))
    S().poly([(tvx + 3, fy - 15), (tvx + 22, fy - 18), (tvx + 24, fy - 2), (tvx + 4, fy - 1)], (50, 52, 70))
    S().line(tvx + 6, fy - 13, tvx + 10, fy - 14, (90, 92, 116))
    disc(tvx + 14, fy + 1, 18, (226, 182, 130), 3)
    plat(tvx - 2, tvx + 26, fy - 20)
    for rx in (x0 + 50, x1 - 60):
        disc(rx, fy - 2, 6, (160, 120, 100), 4); disc(rx - 2, fy - 3, 3, (190, 150, 124), 2)
    finish(tv, (x0 + int((x1 - x0) * 0.7), y0 + 24))
