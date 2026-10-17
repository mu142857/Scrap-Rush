"""第三关场景 v3「有趣」组：天气预报、夜游乐园、森林、海底、太空、地铁车厢重画（2026-10-17）。

作者的反馈：屏幕放大以后（大屏玻璃约 444×245），旧场景里东西太少，空得像没画完。
这一版的做法：
- 按屏幕大小分三档（tier）：大屏放全部几组东西，中屏放一半，小屏只放最有代表性的一两样。
  rw = 屏幕宽，wall_h = 地面到屏幕顶的高度。
- 东西按"几组"摆，有疏有密，不用固定间隔排满整个宽度。
- 主角 13 格高、跳 45 格高 62 格远：大屏里 2~4 个单向平台，高度在地面以上 18~45 格，
  相邻平台横向不超过 60 格。地面往上 14 格以内只放暗、平的东西，怪在那里走要看得清。
- 画法沿用 crt_wall_v2 / l3_scenes：不描边，大块平面，色块按光照分（朝光亮偏暖、背光暗偏冷），低饱和。
- 注意：crt_level3 画每块屏幕时会把 k.scr / k.XX / k.YY 换成一张小画布，所以这里一律现取 k.XX、S()，
  不在模块顶层存它们。
"""
import random

import numpy as np

import crt_wall_v2 as k
import l3_scenes as sc
from crt_wall_v2 import shade, box, floor_shadow
from l3_scenes import S, plat, bands_v, ground, canopy

from oscarkit.light import smooth_noise, polygonal


# ================================================================ 小工具
def tier(tv):
    """屏幕档位：2 大屏（≈444×245），1 中屏（≈270×190），0 小屏（≈130×100）。"""
    rw, wall_h = tv.sx1 - tv.sx0, tv.fy - tv.sy0
    if rw >= 380 and wall_h >= 190:
        return 2
    if rw >= 220 and wall_h >= 140:
        return 1
    return 0


def at(tv, f):
    """屏幕宽度上第 f（0~1）处的 x。"""
    return int(round(tv.sx0 + f * (tv.sx1 - tv.sx0)))


def _rgba(c):
    return np.array(list(c[:3]) + [255], np.uint8)


def fill(pts, c):
    """多边形，只在包围盒里算（Canvas.poly 每次算整张画布，东西一多就慢）。"""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    bx0, bx1 = max(0, int(min(xs)) - 1), min(k.W - 1, int(max(xs)) + 1)
    by0, by1 = max(0, int(min(ys)) - 1), min(k.H - 1, int(max(ys)) + 1)
    if bx1 < bx0 or by1 < by0:
        return
    Y, X = np.mgrid[by0:by1 + 1, bx0:bx1 + 1]
    X, Y = X + 0.5, Y + 0.5
    inside = np.zeros(X.shape, bool)
    n = len(pts)
    for i in range(n):
        (xa, ya), (xb, yb) = pts[i], pts[(i + 1) % n]
        if ya == yb:
            continue
        cond = ((ya <= Y) & (Y < yb)) | ((yb <= Y) & (Y < ya))
        xint = xa + (Y - ya) * (xb - xa) / (yb - ya)
        inside ^= cond & (X < xint)
    S().a[by0:by1 + 1, bx0:bx1 + 1][inside] = _rgba(c)


def ell(cx, cy, rx, ry, c, clip=None):
    """椭圆（整像素）。clip=(y_min, y_max) 只画这几行之间。"""
    bx0, bx1 = max(0, int(cx - rx) - 1), min(k.W - 1, int(cx + rx) + 1)
    by0, by1 = max(0, int(cy - ry) - 1), min(k.H - 1, int(cy + ry) + 1)
    if clip:
        by0, by1 = max(by0, clip[0]), min(by1, clip[1])
    if bx1 < bx0 or by1 < by0:
        return
    Y, X = np.mgrid[by0:by1 + 1, bx0:bx1 + 1]
    m = ((X - cx) / max(rx, 0.5)) ** 2 + ((Y - cy) / max(ry, 0.5)) ** 2 <= 1.0
    S().a[by0:by1 + 1, bx0:bx1 + 1][m] = _rgba(c)


def rct(xa, ya, xb, yb, c):
    S().rect(int(xa), int(ya), int(xb), int(yb), c)


def ln(xa, ya, xb, yb, c):
    S().line(int(round(xa)), int(round(ya)), int(round(xb)), int(round(yb)), c)


def pt(x, y, c):
    S().put(int(round(x)), int(round(y)), c)


def thick(pts, c, w=2):
    """粗线：一条折线往下叠 w 行。"""
    for d in range(w):
        S().polyline([(int(round(x)), int(round(y)) + d) for x, y in pts], c)


def recolor(mask, kk):
    """把 mask 里的每种颜色都往亮 / 暗挪 kk 档（光柱、阴影），保留原来的分档。"""
    a = S().a
    px = a[..., :3][mask]
    if len(px) == 0:
        return
    keys, inv = np.unique(px, axis=0, return_inverse=True)
    new = np.array([shade(tuple(int(v) for v in c), kk) for c in keys], np.uint8)
    a[..., :3][mask] = new[inv.ravel()]


def catenary(xa, ya, xb, yb, sag):
    n = max(2, int(abs(xb - xa)))
    return [(xa + (xb - xa) * t, ya + (yb - ya) * t + sag * 4 * t * (1 - t)) for t in np.linspace(0, 1, n + 1)]


BULBS = [(252, 226, 150), (246, 150, 150), (160, 230, 236), (196, 240, 160)]   # 发光色（最亮通道 ≥ 240），色调屏里也亮


def bulbs(pts, step, wire=(34, 28, 48), phase=0):
    """一串小灯：电线 + 每隔 step 格一颗灯泡，颜色轮换。"""
    S().polyline([(int(round(x)), int(round(y))) for x, y in pts], wire)
    for i in range(phase, len(pts), step):
        x, y = pts[i]
        pt(x, y + 1, BULBS[(i // step) % 4])


# 3×5 小字：天气预报的台标、滚动字幕、摊位招牌用
FONT = {
    "A": [".#.", "#.#", "###", "#.#", "#.#"], "C": [".##", "#..", "#..", "#..", ".##"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."], "E": ["###", "#..", "##.", "#..", "###"],
    "F": ["###", "#..", "##.", "#..", "#.."], "G": [".##", "#..", "#.#", "#.#", ".##"],
    "H": ["#.#", "#.#", "###", "#.#", "#.#"], "I": ["###", ".#.", ".#.", ".#.", "###"],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "O": ["###", "#.#", "#.#", "#.#", "###"], "P": ["##.", "#.#", "##.", "#..", "#.."],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"], "S": [".##", "#..", ".#.", "..#", "##."],
    "T": ["###", ".#.", ".#.", ".#.", ".#."], "U": ["#.#", "#.#", "#.#", "#.#", "###"],
    "V": ["#.#", "#.#", "#.#", "#.#", ".#."], "W": ["#.#", "#.#", "###", "###", "#.#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["###", "..#", "###", "#..", "###"], "3": ["###", "..#", ".##", "..#", "###"],
    "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "###", "..#", "###"],
    "6": ["###", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "###"],
    ":": ["...", ".#.", "...", ".#.", "..."], "-": ["...", "...", "###", "...", "..."],
    "°": ["##.", "##.", "...", "...", "..."], ".": ["...", "...", "...", "...", ".#."],
}


def text(x, y, s, c, scale=1):
    x, y = int(x), int(y)
    for i, ch in enumerate(s):
        for yy, row in enumerate(FONT.get(ch, [])):
            for xx, v in enumerate(row):
                if v == "#":
                    px, py = x + (i * 4 + xx) * scale, y + yy * scale
                    S().rect(px, py, px + scale - 1, py + scale - 1, c)


def text_w(s, scale=1):
    return (len(s) * 4 - 1) * scale


# ================================================================ 天气预报
SEA_DEEP, SEA, SHELF = (64, 98, 152), (72, 108, 162), (94, 132, 180)
LAND, HILL, MOUNT = (124, 162, 112), (146, 160, 110), (170, 160, 124)
CLOUD = [(178, 186, 206), (214, 220, 232), (238, 240, 244)]          # 底面、身子、朝光的顶
STORM = [(112, 116, 142), (144, 148, 172), (172, 176, 198)]


def w_cloud(cx, cy, w, cols=CLOUD):
    """天气图标的云：三团圆叠在一条平底上；顶上朝光的一层亮，底下一道冷灰。返回云顶的 y。"""
    h = max(4, int(w * 0.32))
    lo, mid_, hi = cols
    base = cy + h // 2
    ell(cx - w * 0.22, base - h * 0.55, w * 0.26, h * 0.62, mid_)
    ell(cx + w * 0.08, base - h * 0.85, w * 0.30, h * 0.9, mid_)
    ell(cx + w * 0.32, base - h * 0.45, w * 0.2, h * 0.5, mid_)
    rct(cx - w * 0.45, base - h * 0.45, cx + w * 0.48, base, mid_)
    ell(cx - w * 0.26, base - h * 0.75, w * 0.17, h * 0.35, hi)        # 左上朝光
    ell(cx + w * 0.02, base - h * 1.15, w * 0.2, h * 0.5, hi)
    rct(cx - w * 0.42, base - 1, cx + w * 0.46, base, lo)               # 平底的阴影
    rct(cx + w * 0.1, base - h * 0.3, cx + w * 0.46, base - 1, lo)
    return int(base - h * 1.75)


def w_sun(cx, cy, r):
    ray = (240, 196, 104)
    for a in np.linspace(0, 2 * np.pi, 8, endpoint=False):
        ln(cx + (r + 2) * np.cos(a), cy + (r + 2) * np.sin(a), cx + (r + 2 + max(2, r * 0.6)) * np.cos(a),
           cy + (r + 2 + max(2, r * 0.6)) * np.sin(a), ray)
    ell(cx, cy, r, r, (236, 184, 96))
    ell(cx - r * 0.15, cy - r * 0.15, r * 0.8, r * 0.8, (248, 208, 116))
    ell(cx - r * 0.35, cy - r * 0.35, r * 0.4, r * 0.4, (252, 230, 160))


def w_icon(kind, cx, cy, s, y_max=99999):
    """一个天气图标，s = 图标宽度。返回顶上的 y（云当平台用）。y_max 以下不画雨雪闪电（别画进地面那一条）。"""
    if kind == "sun":
        w_sun(cx, cy, max(2, s // 4))
        return None
    if kind == "partly":
        w_sun(cx + s * 0.22, cy - s * 0.18, max(2, s // 5))
        return w_cloud(cx - s * 0.06, cy + s * 0.06, s * 0.8)
    if kind == "storm":
        top = w_cloud(cx, cy, s, STORM)
        b = cy + s * 0.2
        if b + s * 0.5 > y_max:
            return top
        fill([(cx + 1, b), (cx + s * 0.18, b), (cx + 2, b + s * 0.2), (cx + s * 0.16, b + s * 0.2),
              (cx - s * 0.06, b + s * 0.5), (cx - 1, b + s * 0.26), (cx - s * 0.12, b + s * 0.26)], (246, 212, 110))
        return top
    top = w_cloud(cx, cy, s, CLOUD)
    b = int(cy + s * 0.2)
    if b + 5 > y_max:
        return top
    for i in range(max(2, s // 8)):
        dx = int(cx - s * 0.3 + i * 8 * s / max(1, s) * (s / 32 + 0.6))
        if kind == "rain":
            ln(dx, b + 1 + (i % 2), dx - 2, b + 4 + (i % 2), (150, 192, 236))
        elif kind == "snow":
            y = b + 2 + (i % 2) * 2
            pt(dx, y, (244, 246, 252)); pt(dx - 1, y, (220, 228, 244)); pt(dx + 1, y, (220, 228, 244))
            pt(dx, y - 1, (220, 228, 244)); pt(dx, y + 1, (220, 228, 244))
    return top


def temp_tag(x, y, t, scale=1):
    """城市的气温：小色块里一个白数字，暖的砖红、冷的灰蓝。"""
    warm = not t.startswith("-") and int(t) >= 15
    c = (184, 106, 90) if warm else (88, 118, 178)
    w = text_w(t + "°", scale)
    rct(x - 1, y - 1, x + w + 1, y + 5 * scale, c)
    rct(x - 1, y + 5 * scale, x + w + 1, y + 5 * scale, shade(c, -2))
    text(x, y, t + "°", (246, 244, 236), scale)


def city(x, y):
    rct(x - 1, y - 1, x + 1, y + 1, (238, 236, 226))
    pt(x + 1, y + 1, (196, 194, 190))


def front(pts, kind, step, size):
    """冷锋：蓝线 + 一串朝前的三角；暖锋：红线 + 一串半圆。"""
    c = (92, 132, 206) if kind == "cold" else (204, 92, 86)
    path = []
    for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
        n = max(1, int(np.hypot(xb - xa, yb - ya)))
        path += [(xa + (xb - xa) * t / n, ya + (yb - ya) * t / n) for t in range(n)]
    thick(path, c, 2)
    for i in range(step // 2, len(path) - 3, step):
        (xa, ya), (xb, yb) = path[i], path[min(len(path) - 1, i + 3)]
        tx, ty = (xb - xa), (yb - ya)
        L = max(1e-3, np.hypot(tx, ty))
        tx, ty = tx / L, ty / L
        nx, ny = ty, -tx                                   # 朝东北（锋面推进的方向）
        if nx < 0:
            nx, ny = -nx, -ny
        if kind == "cold":
            fill([(xa - tx * size, ya - ty * size), (xa + tx * size, ya + ty * size), (xa + nx * size * 1.4, ya + ny * size * 1.4)], c)
        else:
            ell(xa + nx * 0.5, ya + ny * 0.5, size, size, c)
    return path


def sc_weather(tv):
    """天气预报（电视画面本身，平面、不加透视）：
    一张完整的天气地图——海岸线、大陆和几座岛、高地、冷锋暖锋、高低气压、城市圆点和气温、
    云 / 雨 / 雪 / 雷 / 太阳图标；左上角台标，右上角时钟，底下一条滚动字幕当地面。
    大屏下方一组三朵云（雨云、雷云、雪云）是能站的平台，像台阶一样错开。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    T = tier(tv)
    rw, wh = x1 - x0, fy - y0
    m = tv.screen_mask()
    X, Y = k.XX, k.YY

    # --- 地图：几块椭圆陆地叠一层低频噪声，再按三角网格切成直线段，海岸线就是剪纸那样的折线
    u, v = (X - x0) / rw, (Y - y0) / wh
    blobs = [(0.14, 0.46, 0.24, 0.44), (0.36, 0.66, 0.08, 0.15), (0.56, -0.04, 0.22, 0.2),   # 西大陆、半岛、北边
             (0.80, 0.52, 0.10, 0.22), (0.66, 0.58, 0.03, 0.05), (0.70, 0.70, 0.02, 0.035),    # 东岛、两座小岛
             (0.95, 0.88, 0.06, 0.09), (0.47, 0.86, 0.025, 0.04), (0.90, 0.16, 0.05, 0.06)]
    if T == 0:
        blobs = blobs[:4]
    F = np.full(X.shape, -1.0)
    for bu, bv, ru, rv in blobs:
        F = np.maximum(F, 1 - ((u - bu) / ru) ** 2 - ((v - bv) / rv) ** 2)
    F = F + 0.32 * smooth_noise(*X.shape, sx=max(12, rw / 9), sy=max(10, wh / 7), seed=5)
    F = polygonal(F, max(5, rw / 60), max(5, wh / 40), seed=3)
    S().fill_mask(m, SEA)
    S().fill_mask(m & (F < -0.9), SEA_DEEP)
    S().fill_mask(m & (F > -0.18), SHELF)                      # 近岸浅水：一圈浅蓝
    land = m & (F > 0)
    S().fill_mask(land, LAND)
    S().fill_mask(m & (F > 0.55), HILL)
    S().fill_mask(m & (F > 0.85), MOUNT)

    # 国界：陆地上的虚线
    for path in ([(0.05, 0.3), (0.16, 0.36), (0.22, 0.5), (0.3, 0.62)], [(0.08, 0.66), (0.2, 0.62)], [(0.76, 0.42), (0.86, 0.56)])[: 1 + T]:
        pp = [(x0 + a * rw, y0 + b * wh) for a, b in path]
        for (xa, ya), (xb, yb) in zip(pp, pp[1:]):
            n = int(np.hypot(xb - xa, yb - ya))
            for t in range(0, n, 1):
                xx, yy = int(xa + (xb - xa) * t / n), int(ya + (yb - ya) * t / n)
                if (t // 2) % 2 == 0 and 0 <= yy < k.H and 0 <= xx < k.W and land[yy, xx]:
                    S().put(xx, yy, shade(tuple(S().a[yy, xx, :3]), -2))

    # 等压线：高压周围两三圈不规则的细线，比底下亮一档
    hx, hy = x0 + 0.74 * rw, y0 + 0.26 * wh
    if T >= 1:
        th = np.arctan2(Y - hy, X - hx)
        d = np.hypot((X - hx) / (rw * 0.11), (Y - hy) / (wh * 0.17))
        for i, rr in enumerate((1.0, 1.7, 2.5)[: 1 + T]):
            wob = rr * (1 + 0.1 * np.sin(3 * th + i * 1.7) + 0.05 * np.sin(5 * th + i))
            ring = m & (np.abs(d - wob) < 0.5 / (rw * 0.11) * 1.2) & (Y < fy - 16)
            recolor(ring, 2)

    # 雨区（雷达回波）：冷锋后面一片，亮一档，里面再加一层斜线；边是三角网格切出来的直线段
    if T >= 1:
        rd = np.hypot((X - (x0 + 0.3 * rw)) / (rw * 0.1), (Y - (y0 + 0.5 * wh)) / (wh * 0.2))
        rd = polygonal(rd + 0.45 * smooth_noise(*X.shape, sx=rw / 12, sy=wh / 9, seed=9), max(5, rw / 50), max(5, wh / 36), seed=4)
        rain = m & (rd < 1) & (Y < fy - 18)
        recolor(rain, 1)
        recolor(rain & (rd < 0.6) & ((X + Y) % 5 == 0), 1)
    # 风向箭头：海上几支，方向不一
    for au, av, ang, need in ((0.5, 0.62, -0.5, 1), (0.62, 0.78, -0.2, 2), (0.9, 0.3, 2.6, 2), (0.27, 0.8, 0.3, 2)):
        if T < need:
            continue
        ax, ay, L = x0 + au * rw, y0 + av * wh, [6, 8, 11][T]
        bx_, by_ = ax + L * np.cos(ang), ay + L * np.sin(ang)
        ln(ax, ay, bx_, by_, (214, 222, 238))
        for da in (2.5, -2.5):
            ln(bx_, by_, bx_ + 3 * np.cos(ang + da), by_ + 3 * np.sin(ang + da), (214, 222, 238))

    # --- 冷锋、暖锋，从低压中心伸出来
    lx, ly = x0 + 0.42 * rw, y0 + 0.3 * wh
    sz = [2, 3, 4][T]
    if T >= 1:
        front([(lx, ly), (lx - 0.04 * rw, ly + 0.14 * wh), (lx - 0.1 * rw, ly + 0.27 * wh), (lx - 0.17 * rw, ly + 0.36 * wh)], "cold", [9, 12, 14][T], sz)
        front([(lx, ly), (lx + 0.07 * rw, ly + 0.07 * wh), (lx + 0.16 * rw, ly + 0.1 * wh)], "warm", [9, 12, 14][T], sz - 1)
    sL = [1, 2, 3][T]
    text(lx - text_w("L", sL) // 2, ly - 6 * sL - 2, "L", (214, 96, 90), sL)
    if T >= 1:
        text(hx - text_w("H", sL) // 2, hy - 2 * sL, "H", (110, 148, 222), sL)

    # --- 城市、气温、图标（避开左上台标、右上时钟、下面 18 格）
    s = [14, 20, 26][T]
    spots = [  # (u, v, 图标, 气温, 档位下限)
        (0.17, 0.30, "sun", "28", 0), (0.26, 0.48, "rain", "17", 1), (0.56, 0.16, "snow", "-3", 1),
        (0.83, 0.42, "partly", "21", 0), (0.94, 0.70, "sun", "30", 2), (0.49, 0.20, "storm", "12", 2),
        (0.10, 0.62, "partly", "24", 2), (0.68, 0.30, "rain", "15", 2), (0.31, 0.12, "sun", "26", 2)]
    for su, sv, kind, t, need in spots:
        if T < need:
            continue
        cx, cy = x0 + su * rw, y0 + sv * wh
        if T == 0:
            cx, cy = x0 + (0.2 if kind == "sun" else 0.78) * rw, y0 + (0.36 if kind == "sun" else 0.3) * wh
        w_icon(kind, int(cx), int(cy), s)
        city(int(cx - s * 0.1), int(cy + s * 0.5 + 3))
        temp_tag(int(cx + s * 0.1), int(cy + s * 0.5 + 1), t, 1)

    # --- 能站的云：一组三朵，台阶一样错开（大屏 3 朵，中屏 2 朵，小屏 1 朵）
    # 云身子整个在地面往上 14 格以外（白云别压在怪走的那一条上）
    steps = [(0.50, 30, "rain"), (0.61, 43, "storm"), (0.72, 32, "snow")][: [1, 2, 3][T]]
    if T == 1:
        steps = [(0.50, 28, "rain"), (0.61, 40, "storm")]
    if T == 0:
        steps = [(0.55, 26, "rain")]
    cw = [22, 26, 30][T]
    for f, hgt, kind in steps:
        cx = at(tv, f)
        top_y = fy - hgt
        # w_cloud 的顶在 base - h*1.75，反推中心 y，让云顶正好在平台高度
        h = max(4, int(cw * 0.32))
        cy = int(top_y + h * 1.75 - h // 2)
        w_icon(kind, cx, cy, cw, y_max=fy - 15)
        plat(cx - cw * 0.42, cx + cw * 0.42, top_y)

    # --- 左上台标：红色方块里一个 7，旁边深蓝条写 WEATHER；右上时钟
    lsx, lsy = x0 + 10, y0 + 8
    sq = [8, 11, 14][T]
    rct(lsx, lsy, lsx + sq, lsy + sq, (190, 82, 74))
    rct(lsx, lsy + sq, lsx + sq, lsy + sq, (150, 62, 60))
    text(lsx + sq // 2 - text_w("7", max(1, T)) // 2 + 1, lsy + sq // 2 - 5 * max(1, T) // 2, "7", (248, 240, 226), max(1, T))
    if T >= 1:
        bw_ = text_w("WEATHER") + 6
        rct(lsx + sq + 1, lsy + 2, lsx + sq + bw_, lsy + sq - 2, (34, 44, 92))
        text(lsx + sq + 4, lsy + sq // 2 - 2, "WEATHER", (236, 236, 240))
        rct(lsx + sq + 1, lsy + sq - 2, lsx + sq + bw_, lsy + sq - 2, (240, 200, 110))
    if T >= 1:
        ck = "18:30"
        cxr = x1 - 10 - text_w(ck)
        rct(cxr - 3, y0 + 8, x1 - 7, y0 + 16, (34, 44, 92))
        text(cxr, y0 + 10, ck, (236, 236, 240))
        if T == 2:
            rct(cxr - 22, y0 + 8, cxr - 5, y0 + 16, (190, 82, 74))
            text(cxr - 20, y0 + 10, "LIVE", (248, 240, 226))

    # --- 底下一条滚动字幕：深蓝底，左边红签，白字；它就是地面
    band = m & (Y > fy)
    S().fill_mask(band, (30, 38, 84))
    S().line(x0, fy, x1, fy, (176, 156, 104))
    S().line(x0, fy + 1, x1, fy + 1, (44, 54, 104))
    ty = fy + 3
    tag = "NEWS"
    rct(x0, fy + 2, x0 + 6 + text_w(tag) + 3, tv.sy1, (176, 76, 70))
    text(x0 + 6, ty, tag, (248, 240, 226))
    msg = "COLD FRONT MOVES EAST - SNOW IN THE NORTH - SUNNY 30° SUNDAY - STORMS NEAR THE COAST"
    text(x0 + 16 + text_w(tag), ty, msg, (220, 224, 238))
    k.finish_room(tv, ((x0 + x1) // 2, y0 + 30))


# ================================================================ 夜里的游乐园
NIGHT = [(34, 30, 58), (40, 34, 68), (48, 40, 78), (58, 46, 88), (72, 54, 98), (90, 64, 108)]
SIL = (44, 36, 70)          # 远处的剪影


def coaster(xa, xb, hz, hmax, rr):
    """远处过山车：一条起伏的轨道，底下一排疏密不匀的支架和交叉撑，全是剪影色；轨道顶上一道亮一档的边。"""
    xs = np.arange(int(xa), int(xb))
    t = (xs - xa) / max(1, xb - xa)
    g = lambda c, w: np.exp(-((t - c) / w) ** 2)
    ys = hz - (hmax * 0.3 + hmax * 0.7 * g(0.22, 0.09) + hmax * 0.45 * g(0.55, 0.08) + hmax * 0.3 * g(0.82, 0.06)
               - hmax * 0.1 * g(0.38, 0.05))
    x = int(xa) + 3
    posts = []
    while x < xb - 2:
        posts.append(x)
        x += rr.randint(7, 12)
    for a, b in zip(posts, posts[1:]):
        ya, yb = ys[a - int(xa)], ys[b - int(xa)]
        ln(a, ya, b, hz, SIL); ln(b, yb, a, hz, SIL)
    for p in posts:
        ln(p, ys[p - int(xa)], p, hz, SIL)
    pts = list(zip(xs, ys))
    thick(pts, SIL, 3)
    S().polyline([(int(x_), int(round(y_)) - 1) for x_, y_ in pts], (74, 60, 104))
    # 一列车停在第二个坡上，三节，每节一颗小灯
    i0 = int(0.5 * len(xs))
    for j in range(3):
        i = i0 + j * 7
        if i < len(xs):
            cx, cy = xs[i], int(ys[i])
            rct(cx, cy - 4, cx + 5, cy - 1, (64, 52, 92))
            pt(cx + 2, cy - 3, BULBS[j])


def person(x, foot, h, c):
    """远处的人：头 2×2、身子比头宽一点，一个色块。"""
    rct(x, foot - h + 3, x + 2, foot, c)
    rct(x, foot - h, x + 1, foot - h + 1, c)
    pt(x - 1, foot - h + 4, c)


def crowd(xa, xb, foot, rr, n, balloon=False):
    cols = [(40, 33, 60), (48, 38, 68), (36, 30, 54), (52, 42, 74)]
    for i in range(n):
        x = int(xa + (xb - xa) * (i + rr.random() * 0.8) / n)
        h = rr.randint(7, 10)
        person(x, foot + rr.randint(-1, 1), h, rr.choice(cols))
        if balloon and i == n // 2:
            ln(x + 1, foot - h, x + 3, foot - h - 9, (90, 80, 110))
            ell(x + 3, foot - h - 11, 2, 2.5, (214, 110, 120))


def ferris_wheel(cx, cy, r, fy, plats):
    """摩天轮：A 字形支架（左腿朝光亮，右腿暗），两圈轮辋、辐条、轮辋之间的锯齿撑，
    一圈彩灯；吊舱挂在 15°+30°n 的位置，这样最低的几个吊舱顶正好落在能跳上去的高度。"""
    leg_l, leg_r = (150, 128, 170), (110, 94, 134)
    lw = max(2, r // 28)
    for side, c in ((-1, leg_l), (1, leg_r)):
        fx = cx + side * r * 0.45
        fill([(cx - lw, cy), (cx + lw, cy), (fx + lw + side, fy), (fx - lw + side, fy)], c)
    ln(cx - r * 0.3, fy - r * 0.35, cx + r * 0.3, fy - r * 0.35, leg_r)
    rim, rim_d = (166, 146, 186), (124, 108, 148)
    X, Y = k.XX, k.YY
    d = np.hypot(X - cx, Y - cy)
    S().fill_mask((np.abs(d - r) < 1.0) & (Y < fy), rim)
    S().fill_mask((np.abs(d - r * 0.88) < 0.6) & (Y < fy), rim_d)
    n_sp = 16
    for i, a in enumerate(np.linspace(0, 2 * np.pi, n_sp, endpoint=False)):
        ln(cx, cy, cx + r * 0.88 * np.cos(a), cy + r * 0.88 * np.sin(a), rim_d)
        b = a + np.pi / n_sp
        ln(cx + r * 0.88 * np.cos(a), cy + r * 0.88 * np.sin(a), cx + r * np.cos(b), cy + r * np.sin(b), rim_d)
    ell(cx, cy, max(3, r // 14), max(3, r // 14), (176, 156, 192))
    ell(cx - 1, cy - 1, max(1, r // 30), max(1, r // 30), (214, 200, 222))
    for i, a in enumerate(np.linspace(0, 2 * np.pi, 40 if r > 50 else 24, endpoint=False)):
        pt(cx + r * np.cos(a), cy + r * np.sin(a), BULBS[i % 4])
    gw = max(4, min(14, r // 6))        # 吊舱要装得下人：大屏 14 格，比主角高一点
    cabin = [(150, 98, 108), (92, 120, 160), (176, 150, 100), (100, 140, 110)]
    for i, a in enumerate(np.radians(np.arange(15, 375, 30))):
        px, py = cx + r * np.cos(a), cy + r * np.sin(a)
        if py + gw + 3 > fy:
            continue
        c = cabin[i % 4]
        ln(px, py, px, py + 1, rim_d)
        top = int(py) + 2
        fill([(px - gw / 2 - 1, top + 2), (px + gw / 2 + 1, top + 2), (px + gw / 2 - 1, top), (px - gw / 2 + 1, top)], shade(c, 1))
        rct(px - gw / 2, top + 2, px + gw / 2, top + gw, c)
        rct(px - gw / 2 + 1, top + 3, px + gw / 2 - 1, top + gw // 2 + 1, (236, 206, 150))   # 亮着灯的窗
        if gw >= 10:
            rct(px - 1, top + 3, px, top + gw // 2 + 1, shade(c, -1))                          # 窗棂
        rct(px + gw / 2 - 1, top + 2, px + gw / 2, top + gw, shade(c, -2))
        if plats is not None and 18 <= fy - top <= 45 and np.cos(a) > 0:
            plats.append((px - gw / 2 - 1, px + gw / 2 + 1, top))
    box(cx - r * 0.18, fy - 5, cx + r * 0.18, fy - 1, (96, 82, 112), depth=0.04, cap=3)   # 上下客的小台子


def snack_stall(sx, fy, w=44, sign="SNACK"):
    """小吃摊：红白竖条的柜台、里面暖光、爆米花机、一个摊主，上面一块红白条的雨棚（棚顶能站）。返回棚顶 y。"""
    floor_shadow(sx - w // 2, sx + w // 2, fy, 3)
    hw = w // 2
    rct(sx - hw + 2, fy - 32, sx + hw - 2, fy - 15, (196, 158, 118))      # 里面暖光照着的后墙
    rct(sx - hw + 2, fy - 32, sx + hw - 2, fy - 29, (168, 132, 104))
    rct(sx - hw + 5, fy - 28, sx - hw + 5 + text_w(sign) + 3, fy - 22, (232, 220, 196))
    text(sx - hw + 7, fy - 27, sign, (150, 76, 72))
    rct(sx + hw - 14, fy - 27, sx + hw - 5, fy - 15, (238, 212, 140))     # 爆米花机：玻璃柜
    rct(sx + hw - 14, fy - 20, sx + hw - 5, fy - 15, (250, 240, 200))
    rct(sx + hw - 15, fy - 28, sx + hw - 4, fy - 27, (150, 76, 72))
    rct(sx - 4, fy - 24, sx - 2, fy - 22, (60, 48, 66)); rct(sx - 5, fy - 21, sx - 1, fy - 15, (70, 56, 80))   # 摊主
    for i, xx in enumerate(range(sx - hw, sx + hw, 5)):                   # 柜台：红白竖条
        rct(xx, fy - 15, min(sx + hw, xx + 4), fy, (124, 70, 80) if i % 2 == 0 else (156, 142, 142))   # 地面那一条：压暗
    rct(sx - hw, fy - 15, sx + hw, fy - 14, (184, 170, 160))
    rct(sx - hw, fy - 2, sx + hw, fy, (110, 70, 76))
    for px_ in (sx - hw, sx + hw - 1):
        rct(px_, fy - 36, px_ + 1, fy - 15, (176, 156, 160))
    top = fy - 38
    fill([(sx - hw - 3, top + 7), (sx + hw + 4, top + 7), (sx + hw + 1, top), (sx - hw, top)], (220, 206, 186))
    for i in range(0, w + 6, 8):
        xa = sx - hw - 3 + i
        fill([(xa, top + 7), (xa + 4, top + 7), (xa + 3.5, top), (xa + 0.5, top)], (176, 84, 84))
    for i in range(0, w + 6, 4):                                          # 雨棚下沿一排小扇边
        ell(sx - hw - 1 + i, top + 8, 1.6, 1.4, (176, 84, 84) if (i // 4) % 2 else (220, 206, 186))
    rct(sx + hw - 2, top + 1, sx + hw + 3, top + 7, (130, 66, 72))          # 背光的一侧
    for xx in range(sx - hw, sx + hw, 6):
        pt(xx, top + 10, BULBS[(xx // 6) % 4])
    return top


def ticket_booth(bx, fy):
    """售票亭：紫色小亭子，亮着的窗口里坐着售票员，平顶（能站），顶上一块 TICKET 招牌，沿边一排灯。返回顶 y。"""
    c = (112, 96, 136)
    floor_shadow(bx - 12, bx + 12, fy, 3)
    box(bx - 11, fy - 28, bx + 11, fy, c, depth=0.05, cap=3)
    rct(bx - 7, fy - 23, bx + 7, fy - 15, (236, 202, 146))
    rct(bx - 7, fy - 23, bx + 7, fy - 22, (250, 228, 176))
    rct(bx - 2, fy - 20, bx + 1, fy - 18, (70, 56, 80)); rct(bx - 3, fy - 17, bx + 2, fy - 15, (82, 64, 92))
    rct(bx - 9, fy - 14, bx + 9, fy - 13, shade(c, 1))
    rct(bx - 10, fy - 6, bx + 10, fy - 6, shade(c, -1))
    top = fy - 31
    box(bx - 14, top, bx + 14, top + 2, shade(c, 1), depth=0.05, cap=2)
    for xx in range(bx - 13, bx + 14, 4):
        pt(xx, top + 3, BULBS[(xx // 4) % 4])
    sw = text_w("TICKET") + 4
    rct(bx - 1, top - 4, bx, top - 1, (90, 76, 104))
    rct(bx - sw // 2, top - 11, bx - sw // 2 + sw, top - 4, (226, 210, 180))
    text(bx - sw // 2 + 2, top - 10, "TICKET", (150, 76, 72))
    return top


def balloon_cart(bx, fy, rr):
    """气球摊：一辆小推车，一个卖气球的人，头顶一大串气球（每个左上一颗高光）。"""
    floor_shadow(bx - 8, bx + 8, fy, 2)
    box(bx - 7, fy - 9, bx + 7, fy - 3, (104, 88, 114), depth=0.04, cap=2)
    ell(bx - 4, fy - 2, 2, 2, (60, 50, 70)); ell(bx + 4, fy - 2, 2, 2, (60, 50, 70))
    person(bx + 10, fy, 13, (66, 54, 84))
    cols = [(206, 120, 128), (120, 160, 206), (220, 196, 120), (140, 190, 150), (180, 140, 200)]
    hx, hy = bx + 11, fy - 14
    spots = [(-8, -34), (-2, -38), (4, -35), (9, -30), (-5, -28), (2, -29), (-11, -26), (7, -24)]
    for (dx, dy) in spots:
        ln(hx, hy, hx + dx, hy + dy + 3, (150, 140, 160))
    for i, (dx, dy) in enumerate(spots):
        c = cols[i % len(cols)]
        ell(hx + dx, hy + dy, 3, 3.5, c)
        ell(hx + dx + 1, hy + dy + 1, 2, 2.5, shade(c, -1))
        ell(hx + dx - 1, hy + dy - 1, 1.5, 1.5, shade(c, 1))
        pt(hx + dx - 1, hy + dy - 2, shade(c, 3))


def teacups(tc, fy, rx=34):
    """旋转杯：一块圆台子（顶面亮、前沿暗），中间一根柱子撑着一顶平顶的条纹棚（顶能站），四只杯子前后错开。返回棚顶 y。"""
    base = (120, 100, 142)
    ell(tc, fy - 3, rx + 2, 5, shade(base, -2))
    ell(tc, fy - 6, rx, 5, base)
    ell(tc - rx * 0.3, fy - 7, rx * 0.5, 3, shade(base, 1))
    for i, a in enumerate(np.linspace(0, np.pi, 9)):
        pt(tc + (rx + 1) * np.cos(a), fy - 3 + 4 * np.sin(a), BULBS[i % 4])
    rct(tc - 1, fy - 28, tc + 1, fy - 7, (170, 150, 180))
    top = fy - 36
    rct(tc - 10, top, tc + 10, top + 2, (206, 196, 184))                    # 平顶
    rct(tc - 10, top, tc + 10, top, (230, 222, 210))
    for i in range(6):
        xa = tc - 21 + i * 7
        c = (180, 92, 98) if i % 2 == 0 else (216, 204, 190)
        fill([(xa, top + 8), (xa + 7, top + 8), (tc - 10 + (i + 1) * 20 / 6, top + 3), (tc - 10 + i * 20 / 6, top + 3)], c)
    fill([(tc + 4, top + 3), (tc + 10, top + 3), (tc + 22, top + 8), (tc + 8, top + 8)], shade((180, 92, 98), -2))
    for i in range(0, 44, 4):
        ell(tc - 21 + i, top + 9, 1.6, 1.2, (180, 92, 98) if (i // 4) % 2 else (216, 204, 190))
    for xx in (tc - 8, tc, tc + 8):
        pt(xx, top - 1, BULBS[(xx // 8) % 4])
    # 杯子在地面那一条里：用夜里压暗的颜色，别太花
    cups = [(-22, -8, (112, 96, 140), 0.8), (14, -9, (98, 132, 124), 0.8), (-12, -3, (150, 104, 118), 1.0), (22, -2, (156, 140, 100), 1.0)]
    for dx, dy, c, s in cups:
        cx, by = tc + dx, fy + dy
        w2 = 7 * s
        ell(cx, by, w2 + 2, 2, shade(c, -2))
        fill([(cx - w2, by - 10 * s), (cx + w2, by - 10 * s), (cx + w2 * 0.7, by), (cx - w2 * 0.7, by)], c)
        fill([(cx + w2 * 0.2, by - 10 * s), (cx + w2, by - 10 * s), (cx + w2 * 0.7, by), (cx + w2 * 0.1, by)], shade(c, -1))
        ell(cx, by - 10 * s, w2, 1.6, shade(c, 2))
        ell(cx, by - 10 * s + 0.5, w2 - 2, 1, shade(c, -3))
        rct(cx + w2, by - 8 * s, cx + w2 + 2, by - 7 * s, shade(c, -1)); rct(cx + w2 + 2, by - 7 * s, cx + w2 + 2, by - 4 * s, shade(c, -1))
        rct(cx - w2 * 0.6, by - 7 * s, cx - w2 * 0.2, by - 6 * s, shade(c, 2))
    return top


def lamp_post(x, fy, h, pool=True):
    if pool:
        ell(x, fy + 2, 16, 3, (84, 68, 92))
        ell(x, fy + 2, 9, 2, (98, 80, 102))
    rct(x, fy - h, x + 1, fy, (52, 44, 70))
    rct(x - 2, fy - h - 4, x + 3, fy - h - 1, (252, 236, 190))
    rct(x - 3, fy - h - 5, x + 4, fy - h - 5, (60, 50, 78))


def sc_ferris(tv):
    """夜里的游乐园：分档的夜空、月牙、远处过山车的剪影和成群的游人剪影；
    左边一座大摩天轮（低处的吊舱能站），中间售票亭和气球摊，右边旋转杯和小吃摊；
    几段彩灯串在灯杆之间（不拉满整个宽度）。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    T = tier(tv)
    rw, wh = x1 - x0, fy - y0
    rr = random.Random(31 + rw)
    hz = fy - [12, 18, 22][T]                      # 远处广场的地平线
    bands_v(tv, y0, hz, NIGHT)
    for _ in range(rw * wh // 1400):
        pt(rr.randint(x0, x1), rr.randint(y0, y0 + int(wh * 0.5)), rr.choice([(214, 210, 236), (186, 184, 220)]))
    mx, my, mr = x1 - int(rw * 0.14), y0 + int(wh * 0.14), [5, 7, 9][T]
    ell(mx, my, mr, mr, (232, 226, 206)); ell(mx - 1, my - 1, mr * 0.6, mr * 0.6, (244, 240, 224))
    ell(mx + mr * 0.5, my - mr * 0.3, mr * 0.85, mr * 0.85, NIGHT[0])
    # 烟花：天上一两朵，一圈放射的虚线，芯亮、梢暗
    for fu, fv, fr, c in ([(0.5, 0.16, 22, (226, 150, 170)), (0.63, 0.26, 14, (170, 210, 226)), (0.4, 0.3, 9, (232, 214, 150))] if T == 2 else
                          [(0.62, 0.18, 14, (226, 150, 170))] if T == 1 else []):
        fx_, fy_ = at(tv, fu), y0 + int(wh * fv)
        for i, a in enumerate(np.linspace(0, 2 * np.pi, 18, endpoint=False)):
            for j in range(2, fr, 2):
                cc = c if j < fr * 0.6 else shade(c, -3)
                pt(fx_ + j * np.cos(a + j * 0.012), fy_ + j * np.sin(a + j * 0.012) + j * j * 0.012, cc)
        pt(fx_, fy_, (252, 246, 230))
        for j in range(4, 22, 3):                                       # 往上蹿的那道尾巴
            pt(fx_ - j * 0.15, fy_ + fr + j, shade(c, -4))

    # 远景：过山车剪影、远处的帐篷尖顶
    if T >= 1:
        coaster(at(tv, 0.50 if T == 2 else 0.56), x1 + 4, hz, wh * (0.62 if T == 2 else 0.5), rr)
    for f, hh in ([(0.36, 20), (0.43, 14)] if T == 2 else [(0.45, 14)] if T == 1 else []):
        tx = at(tv, f)
        fill([(tx - hh * 0.8, hz), (tx + hh * 0.8, hz), (tx, hz - hh * 1.4)], SIL)
        rct(tx, hz - hh * 1.4 - 4, tx, hz - hh * 1.4, SIL)
    S().fill_mask(tv.screen_mask() & (k.YY >= hz) & (k.YY < fy), (58, 48, 74))   # 远处的广场
    S().fill_mask(tv.screen_mask() & (k.YY == hz), (70, 58, 88))
    # 远处的人群：几簇，疏密不一
    for f0, f1, n, bal in ([(0.30, 0.40, 9, True), (0.55, 0.62, 6, False), (0.86, 0.97, 8, True)] if T == 2 else
                           [(0.40, 0.52, 6, True), (0.80, 0.92, 5, False)] if T == 1 else [(0.62, 0.78, 4, False)]):
        crowd(at(tv, f0), at(tv, f1), hz + 1, rr, n, bal)
    ground(tv, [(78, 64, 90), (64, 52, 78), (56, 46, 68)])

    plats = []
    # 摩天轮
    # 摩天轮的高度：大屏、中屏让最低的吊舱底停在地面往上 14 格（别垂到怪走的那一条里），
    # 右边 75° 那个吊舱顶就落在地面往上 28 格，能跳上去；小屏轮子小，照旧压低一点
    r = int(min(84, wh * 0.36))
    cx = at(tv, [0.36, 0.25, 0.2][T])
    cy = fy - (30 if T >= 1 else 22) - int(r * 0.966)
    ferris_wheel(cx, cy, r, fy, plats if T >= 1 else None)
    # 彩灯串：只在摊位和杆子之间拉几段
    if T == 2:
        # 吊舱 → 售票亭顶 → 旋转杯的棚顶 → 小吃摊雨棚，一路横向都不超过 60 格
        bx, tc, sx, lp = at(tv, 0.42), at(tv, 0.6), at(tv, 0.8), at(tv, 0.705)
        lamp_post(lp, fy, 46)
        lamp_post(at(tv, 0.97), fy, 46, pool=False)
        bulbs(catenary(cx + r * 0.2, cy - r * 0.2, lp + 1, fy - 50, 18), 5)
        bulbs(catenary(sx + 22, fy - 40, at(tv, 0.97), fy - 50, 6), 5, phase=1)
        top = ticket_booth(bx, fy)
        plats.append((bx - 14, bx + 14, top))
        balloon_cart(at(tv, 0.48), fy, rr)
        top = teacups(tc, fy)
        plats.append((tc - 10, tc + 10, top))
        top = snack_stall(sx, fy)
        plats.append((sx - 25, sx + 26, top))
    elif T == 1:
        sx = at(tv, 0.75)
        lamp_post(at(tv, 0.6), fy, 40)
        bulbs(catenary(cx + r * 0.2, cy - r * 0.2, at(tv, 0.6) + 1, fy - 44, 12), 5)
        balloon_cart(at(tv, 0.52), fy, rr)
        top = snack_stall(sx, fy)
        plats.append((sx - 25, sx + 26, top))
    else:
        bulbs(catenary(x0, y0 + 8, x1, y0 + 12, 10), 5)
    for p in plats:
        plat(*p)
    k.finish_room(tv, (cx, cy))


# ================================================================ 森林
F_SKY = [(204, 218, 192), (194, 210, 182), (184, 202, 174), (174, 194, 166)]
F_FAR0, F_FAR1, F_FAR2, F_MID = (172, 192, 166), (150, 174, 150), (126, 152, 130), (92, 122, 100)
BARK_NEAR, LEAF_NEAR = (70, 60, 58), (58, 86, 70)


def pine(x, base, h, c, rr):
    """远处的松树剪影：三四层三角叠起来，每层边缘不齐。"""
    layers = rr.randint(3, 4)
    w = h * 0.17
    for i in range(layers):
        yb = base - h * i / layers * 0.85
        ww = w * (1 - i / (layers + 1))
        fill([(x - ww, yb), (x + ww, yb), (x + rr.uniform(-1, 1), yb - h / layers * 1.4)], c)
    rct(x, base - 3, x, base, c)


def round_tree(x, base, h, r, c, seed):
    rct(x - 1, base - h, x + 1, base, c)
    canopy(x, base - h, r, c, n=6, seed=seed)


def big_trunk(x, w, fy, top, bark, rr):
    """近处的大树干：根部往两边张开，左边一道朝光的亮边、右边一道暗面，树皮上几条斜纹。"""
    fill([(x - w * 0.5, fy), (x + w * 1.5, fy), (x + w, fy - 8), (x + w, top), (x, top), (x, fy - 8)], bark)
    fill([(x + w * 0.62, top), (x + w, top), (x + w, fy - 8), (x + w * 1.5, fy), (x + w * 0.7, fy)], shade(bark, -2))
    rct(x, top, x + max(1, w // 6), fy - 6, shade(bark, 1))
    for ky in range(int(top) + 8, fy - 10, rr.randint(10, 16)):
        ln(x + 2, ky, x + w * 0.55, ky + 3, shade(bark, -1))


def log(xa, xb, ytop, r, bark=(104, 82, 70)):
    """倒下的树干：横着的圆柱（顶上一道亮面 + 一条青苔），右端露出年轮。"""
    fill([(xa, ytop), (xb, ytop), (xb, ytop + 2 * r), (xa, ytop + 2 * r)], bark)
    rct(xa, ytop, xb, ytop + r * 0.5, shade(bark, 2))
    rct(xa, ytop + r * 1.4, xb, ytop + 2 * r, shade(bark, -2))
    for i in range(int(xa) + 3, int(xb) - 4, 11):
        ln(i, ytop + r * 0.7, i + 6, ytop + r * 0.9, shade(bark, -1))
    for i in range(int(xa) + 2, int(xb) - 6):                              # 青苔
        if (i * 7) % 13 < 7:
            pt(i, ytop, (110, 150, 92))
            if (i * 5) % 7 < 3:
                pt(i, ytop - 1, (130, 170, 104))
    ell(xb, ytop + r, r * 0.55, r, (188, 160, 120))
    ell(xb, ytop + r, r * 0.3, r * 0.55, (164, 136, 104))
    pt(xb, ytop + r, (140, 112, 90))


def stump(x, fy, w, h, bark=(96, 78, 66)):
    """断掉的树桩：顶上一圈浅色木头断面（能站），一侧比另一侧高一截，像被风折断。"""
    fill([(x - w * 0.5 - 3, fy), (x + w * 0.5 + 4, fy), (x + w * 0.5, fy - 6), (x + w * 0.5, fy - h), (x - w * 0.5, fy - h), (x - w * 0.5, fy - 6)], bark)
    rct(x + w * 0.15, fy - h, x + w * 0.5, fy - 4, shade(bark, -2))
    rct(x - w * 0.5, fy - h, x - w * 0.5 + 1, fy - 5, shade(bark, 1))
    ell(x, fy - h, w * 0.5, 2, (190, 164, 124))
    ell(x, fy - h, w * 0.28, 1, (166, 140, 108))
    fill([(x + w * 0.1, fy - h - 1), (x + w * 0.5, fy - h - 1), (x + w * 0.4, fy - h - 9), (x + w * 0.25, fy - h - 5)], bark)
    fill([(x + w * 0.3, fy - h - 1), (x + w * 0.5, fy - h - 1), (x + w * 0.4, fy - h - 9)], shade(bark, -2))


def bush(cx, fy, r, seed, c=(66, 98, 76)):
    canopy(cx, fy - r * 0.45, r, c, n=6, seed=seed)


def mushrooms(x, fy, rr, n=3):
    for i in range(n):
        mx = x + i * rr.randint(3, 5)
        h = rr.randint(2, 4)
        rct(mx, fy - h, mx, fy, (214, 206, 186))
        rct(mx - 1, fy - h - 1, mx + 2, fy - h, (176, 90, 80))
        pt(mx, fy - h - 2, (176, 90, 80)); pt(mx + 1, fy - h - 2, (150, 74, 70)); pt(mx - 1, fy - h - 1, (206, 120, 104))


def fern(x, fy, s, c=(84, 124, 86)):
    for d_ in (-5, -3, -1, 1, 3, 5):
        ln(x, fy, x + d_ * s, fy - (6 - abs(d_) // 2) * s, c if d_ < 0 else shade(c, -1))


def sc_forest(tv):
    """森林，远中近三层：
    远：雾里两层浅色的树影（松树尖 + 圆树冠），一道斜光；中：几棵细树干和树冠；
    近：两侧粗树干框住画面，顶上压一层暗树冠；林间一条小路从远处弯过来。
    能站的：树干上的大层孔菌、倒下的树干、断树桩、右边大树伸出的一根粗枝。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    T = tier(tv)
    rw, wh = x1 - x0, fy - y0
    rr = random.Random(53 + rw)
    hz = fy - [12, 20, 26][T]
    bands_v(tv, y0, fy, F_SKY)
    sm = tv.screen_mask()

    # 远 0：最远的一层雾里的树冠，挂在顶上，底边参差（不让上半屏空着），一簇一簇
    x = x0 - 10
    while x < x1 + 10:
        r_ = rr.randint(14, 24) * (0.5 + 0.25 * T)
        canopy(x, y0 + rr.randint(-4, int(wh * 0.08)), r_, F_FAR0, n=7, seed=x)
        x += int(r_ * rr.uniform(0.9, 1.6)) + (rr.randint(10, 40) if rr.random() < 0.3 else 0)
    # 远 1：细高的松树剪影，分几簇，簇之间留空
    x = x0 - 6
    while x < x1 + 6:
        for _ in range(rr.randint(3, 7)):
            pine(x, hz - 4, rr.randint(int(wh * 0.22), int(wh * 0.5)), F_FAR1, rr)
            x += rr.randint(5, 10)
        x += rr.randint(8, 30)
    S().fill_mask(sm & (k.YY >= hz - 8) & (k.YY < hz), F_FAR1)
    # 斜光（从左上的树冠缝里打下来）
    lx = at(tv, 0.6)
    sh = sm & (k.YY < hz + 4) & (np.abs(k.XX - (lx + (k.YY - y0) * 0.35)) < 5 + (k.YY - y0) * 0.06)
    recolor(sh, 2)
    if T == 2:
        sh2 = sm & (k.YY < hz + 4) & (np.abs(k.XX - (at(tv, 0.3) + (k.YY - y0) * 0.35)) < 2 + (k.YY - y0) * 0.03)
        recolor(sh2, 1)
    # 远 2：圆树冠的树，几簇
    x = x0 + rr.randint(0, 20)
    while x < x1:
        for _ in range(rr.randint(2, 4)):
            th = rr.randint(int(wh * 0.3), int(wh * 0.55))
            round_tree(x, hz, th, rr.randint(10, 16) * (0.6 + 0.2 * T), F_FAR2, x)
            x += rr.randint(10, 20)
        x += rr.randint(24, 60)
    # 林地远处一层 + 小路（远处窄、近处宽，弯一下）
    S().fill_mask(tv.screen_mask() & (k.YY >= hz) & (k.YY < fy), (122, 140, 102))
    S().fill_mask(tv.screen_mask() & (k.YY == hz), (138, 156, 116))
    ground(tv, [(110, 128, 94), (96, 112, 84), (84, 98, 76)])
    px0, px1 = at(tv, 0.64), at(tv, 0.53 if T == 2 else 0.46)
    for y in range(hz, tv.sy1 + 1):
        t = (y - hz) / max(1, fy - hz)
        c = px0 + (px1 - px0) * t ** 1.6 + 4 * np.sin(t * 3)
        hw = 1.5 + [10, 14, 18][T] * t
        S().line(int(c - hw), y, int(c + hw), y, (168, 156, 120) if y < fy else (150, 138, 108))
        if y % 3 == 0:
            pt(c + hw * 0.4, y, (150, 140, 108))

    # 中景：几棵中等的树，树干偏暖灰，树冠大、几团叠在一起，分两簇
    mids = {2: [0.2, 0.27, 0.45, 0.68, 0.74], 1: [0.25, 0.4, 0.7], 0: [0.42]}[T]
    for f in mids:
        tx = at(tv, f) + rr.randint(-5, 5)
        tw = rr.randint(4, 6)
        top = y0 + rr.randint(int(wh * 0.12), int(wh * 0.3))
        fill([(tx - 2, hz + 5), (tx + tw + 2, hz + 5), (tx + tw, hz), (tx + tw, top), (tx, top), (tx, hz)], (98, 104, 92))
        rct(tx + tw - 1, top, tx + tw, hz + 4, (86, 92, 84))
        ln(tx + tw // 2, top + 20, tx - 10, top + 8, (98, 104, 92))
        r_ = rr.randint(18, 26) * (0.55 + 0.22 * T)
        canopy(tx + tw // 2, top, r_, F_MID, n=10, seed=tx)
        canopy(tx - r_ * 0.6, top + r_ * 0.5, r_ * 0.6, F_MID, n=6, seed=tx + 1)

    plats = []
    # 近景：左边大树 + 层孔菌（大屏），右边大树 + 粗枝
    if T >= 1:
        lt = at(tv, 0.06)
        big_trunk(lt, 16, fy, y0 - 2, BARK_NEAR, rr)
        bush(lt - 6, fy, 12, 3)
        if T == 2:
            fx = lt + 16
            for j, (yy, ww) in enumerate([(fy - 40, 9), (fy - 47, 6), (fy - 30, 5)]):   # 几片小层孔菌，只是装饰
                fill([(fx, yy), (fx + ww, yy), (fx + ww - 2, yy + 3), (fx, yy + 4)], (200, 176, 130))
                ln(fx, yy, fx + ww, yy, (220, 200, 156))
                ln(fx + 1, yy + 3, fx + ww - 2, yy + 3, (160, 138, 104))
    rt = at(tv, [0.8, 0.84, 0.86][T])
    big_trunk(rt, [10, 16, 20][T], fy, y0 - 2, BARK_NEAR, rr)
    if T >= 1:
        by = fy - [0, 38, 42][T]
        blen = [0, 30, 50][T]
        fill([(rt + 2, by - 3), (rt + 2, by + 4), (rt - blen, by + 2), (rt - blen, by)], BARK_NEAR)
        ln(rt - blen, by, rt + 2, by - 3, shade(BARK_NEAR, 2))
        canopy(rt - blen - 2, by - 7, 9, (72, 106, 84), n=6, seed=rt)
        plats.append((rt - blen, rt + 1, by))
    bush(rt + 14, fy, 14, 9)
    # 顶上一层暗树冠，压住两个角（不拉满）
    canopy(at(tv, 0.04), y0 + 4, wh * 0.2 + 6, LEAF_NEAR, n=12, seed=4)
    canopy(at(tv, 0.92), y0 + 2, wh * 0.22 + 6, LEAF_NEAR, n=12, seed=8)
    if T == 2:
        canopy(at(tv, 0.2), y0 - 2, 26, LEAF_NEAR, n=8, seed=12)
    # 从顶上树冠垂下来的几根藤，两三根一组
    for f, n in ([(0.1, 3), (0.76, 2)] if T == 2 else [(0.78, 2)] if T == 1 else []):
        for j in range(n):
            vx = at(tv, f) + j * rr.randint(4, 7)
            vl = rr.randint(int(wh * 0.15), int(wh * 0.3))
            for yy in range(y0 + int(wh * 0.12), y0 + int(wh * 0.12) + vl):
                xx = vx + 1.5 * np.sin(yy / 7 + j)
                pt(xx, yy, (64, 96, 74))
                if yy % 5 == 0:
                    pt(xx + (1 if yy % 10 else -1), yy, (84, 120, 88))

    # 倒下的树干（能站）、断树桩（能站）
    if T >= 1:
        la, lb = at(tv, [0, 0.2, 0.17][T]), at(tv, [0, 0.36, 0.32][T])
        ell(lb - 6, fy - 4, 8, 5, (128, 128, 120)); ell(lb - 8, fy - 6, 5, 3, (150, 150, 140))   # 垫着的石头
        ell(la + 5, fy - 2, 6, 3, (120, 120, 112))
        log(la, lb, fy - 21, 6)
        plats.append((la, lb, fy - 21))
        mushrooms(lb - 18, fy, rr, 3)
    sx = at(tv, [0.3, 0.55, 0.45][T])
    sw, sh_ = [12, 14, 16][T], [16, 28, 32][T]
    stump(sx, fy, sw, sh_)
    if T >= 1:
        plats.append((sx - sw // 2, sx + sw // 2, fy - sh_))
    mushrooms(sx + sw // 2 + 6, fy, rr, 2)
    if T == 2:                                                             # 长青苔的大石头（顶能站），接上右边的粗枝
        bx_ = at(tv, 0.6)
        floor_shadow(bx_ - 14, bx_ + 18, fy, 3)
        fill([(bx_ - 16, fy), (bx_ - 14, fy - 14), (bx_ - 7, fy - 22), (bx_ + 9, fy - 22), (bx_ + 16, fy - 12), (bx_ + 18, fy)], (146, 146, 132))
        fill([(bx_ + 3, fy - 22), (bx_ + 9, fy - 22), (bx_ + 16, fy - 12), (bx_ + 18, fy), (bx_ + 4, fy)], (120, 122, 112))
        fill([(bx_ - 16, fy), (bx_ - 14, fy - 14), (bx_ - 7, fy - 22), (bx_ - 4, fy - 22), (bx_ - 9, fy)], (168, 166, 148))
        fill([(bx_ - 7, fy - 22), (bx_ + 9, fy - 22), (bx_ + 11, fy - 19), (bx_ + 4, fy - 17), (bx_ - 4, fy - 18), (bx_ - 9, fy - 19)], (116, 150, 96))   # 顶上一层青苔
        rct(bx_ - 6, fy - 22, bx_ + 8, fy - 22, (138, 170, 108))
        for xx in range(bx_ - 12, bx_ + 14, 4):
            pt(xx, fy - 16 + (xx % 3), (100, 136, 88))
        plats.append((bx_ - 7, bx_ + 9, fy - 22))
        fern(bx_ + 16, fy, 1)
    # 灌木、蕨：几簇
    for f, r_ in ([(0.24, 12), (0.27, 8), (0.42, 8), (0.69, 13), (0.73, 8)] if T == 2 else [(0.64, 11), (0.68, 7)] if T == 1 else [(0.62, 8)]):
        bush(at(tv, f), fy, r_, int(f * 100))
    for f in ([0.12, 0.38, 0.58, 0.75] if T == 2 else [0.12, 0.66] if T == 1 else [0.12]):
        fern(at(tv, f), fy, 1 + (T == 2))
    for _ in range(4 + 5 * T):                                              # 萤火虫（离地面远一点）
        pt(rr.randint(x0 + 10, x1 - 10), rr.randint(y0 + int(wh * 0.35), fy - 20), (240, 248, 176))
    for p in plats:
        plat(*p)
    k.finish_room(tv, (lx + 10, y0 + 6))


# ================================================================ 海底
WATER = [(98, 152, 190), (86, 140, 182), (74, 126, 172), (64, 112, 160), (56, 100, 148), (48, 88, 136)]


def kelp(x, fy, h, rr, c=(80, 132, 98)):
    """一根海带：弯弯的茎，每隔几格一片斜着的叶子，朝光的一侧亮。"""
    ph = rr.uniform(0, 6)
    prev = None
    for y in range(int(fy), int(fy - h), -1):
        xx = x + 2.2 * np.sin((fy - y) / 9 + ph)
        rct(xx, y, xx + 1, y, c)
        pt(xx, y, shade(c, 1))
        if (fy - y) % 7 == 3 and fy - y > 4:
            side = 1 if ((fy - y) // 7) % 2 else -1
            fill([(xx, y), (xx + side * 6, y - 4), (xx + side * 5, y - 1)], c if side < 0 else shade(c, -1))
        prev = xx
    ell(prev, fy - h, 1.5, 2.5, shade(c, 1))


def rock(cx, by, rx, ry, c=(104, 108, 128)):
    """礁石：一块圆石头，左上亮、右下暗。"""
    ell(cx, by - ry, rx, ry, shade(c, -1))
    ell(cx - rx * 0.2, by - ry * 1.15, rx * 0.75, ry * 0.75, c)
    ell(cx - rx * 0.4, by - ry * 1.35, rx * 0.35, ry * 0.35, shade(c, 1))


def branch_coral(x, fy, h, c, rr):
    """鹿角珊瑚：几根分叉往上长，枝头亮一档。"""
    def grow(x_, y_, ang, L, d):
        x2, y2 = x_ + L * np.cos(ang), y_ - L * np.sin(ang)
        thick([(x_, y_), (x2, y2)], c if np.cos(ang) <= 0.1 else shade(c, -1), 2)
        if d < 3:
            for da in (-0.5, 0.45):
                grow(x2, y2, ang + da + rr.uniform(-0.15, 0.15), L * 0.7, d + 1)
        else:
            pt(x2, y2 - 1, shade(c, 2))
    grow(x, fy, np.pi / 2, h * 0.4, 0)


def fan_coral(x, fy, r, c):
    """扇珊瑚：一把扇子，里面网格，下面一根短柄。"""
    ell(x, fy - r, r, r * 0.9, c, clip=(0, int(fy - r * 0.4)))
    for i in range(-r, r + 1, 3):
        ln(x, fy - 2, x + i, fy - r * 1.8 + abs(i) * 0.7, shade(c, -1))
    ln(x - r * 0.9, fy - r * 1.2, x + r * 0.9, fy - r * 1.2, shade(c, -1))
    rct(x, fy - r * 0.6, x + 1, fy, shade(c, -2))


def brain_coral(x, fy, r, c=(176, 168, 120)):
    ell(x, fy, r, r * 0.7, shade(c, -1), clip=(0, int(fy)))
    ell(x - r * 0.2, fy - 1, r * 0.75, r * 0.5, c, clip=(0, int(fy)))
    for i in range(-r + 2, r - 1, 3):
        ln(x + i, fy - 1, x + i * 0.7, fy - r * 0.55, shade(c, -2))


def tube_coral(x, fy, rr, c=(178, 136, 104)):
    for i in range(4):
        tx = x + i * 3 + rr.randint(0, 1)
        h = rr.randint(6, 13)
        rct(tx, fy - h, tx + 1, fy, c if i % 2 == 0 else shade(c, -1))
        pt(tx, fy - h, shade(c, 3)); pt(tx + 1, fy - h, shade(c, -3))


def table_coral(x, top, stem, w, c=(176, 146, 136)):
    """桌形珊瑚：从礁石上长出一丛往上张开的短枝，顶着一块不规则的平盘；
    平盘顶面亮一档、下沿是一排参差的暗齿（顶面能站）。"""
    base = top + stem
    for d in (-5, -2, 1, 4):
        thick([(x + d * 0.4, base), (x + d * 1.6, top + 4)], shade(c, -2) if d > 0 else shade(c, -1), 2)
    hw = w // 2
    fill([(x - hw, top + 1), (x - hw + 3, top - 1), (x + hw - 4, top - 1), (x + hw, top + 1), (x + hw - 2, top + 4), (x - hw + 2, top + 4)], c)
    rct(x - hw + 3, top - 1, x + hw - 4, top - 1, shade(c, 2))
    for i in range(-hw + 2, hw - 2, 3):                                   # 下沿参差的齿
        rct(x + i, top + 4, x + i + 1, top + 5 + (i * 7) % 3, shade(c, -3))


def bubbles(x, y_from, y_to, rr):
    """一串气泡：往上越来越大，间隔不匀，左右晃；串不拉到顶，飘一段就没了。"""
    y_to = y_to + (y_from - y_to) * rr.uniform(0.3, 0.6)
    y = y_from
    i = 0
    while y > y_to:
        xx = x + 2 * np.sin(i * 1.3)
        s = 1 if y > y_from - 30 else 2
        if s == 1:
            pt(xx, y, (180, 216, 234))
        else:
            ell(xx, y, 1.5, 1.5, (170, 210, 232)); pt(xx - 1, y - 1, (226, 244, 250))
        y -= rr.randint(6, 15)
        i += 1


def fish_school(cx, cy, rx, ry, n, rr, c=(54, 92, 130), tilt=-0.18):
    """远处的鱼群：几十条小鱼挤成一个斜着的梭形，都朝同一个方向，剪影色（比水暗一档）。"""
    for i in range(n):
        u = rr.uniform(-1, 1)
        v = rr.uniform(-1, 1) * ry * np.sqrt(max(0.0, 1 - u * u))
        x, y = cx + u * rx, cy + v + u * rx * tilt
        rct(x, y, x + 2, y, c); pt(x - 1, y - 1, c); pt(x - 1, y + 1, c)


def jelly(x, y, r, rr, c=(196, 170, 204)):
    """水母：半透明感的伞（顶亮、下沿暗一档），下面几根弯弯的触须。"""
    ell(x, y, r, r * 0.8, c, clip=(0, int(y)))
    ell(x - r * 0.25, y - r * 0.3, r * 0.45, r * 0.35, shade(c, 2))
    rct(x - r, y, x + r, y, shade(c, -2))
    for i in range(4):
        tx = x - r * 0.7 + i * r * 0.47
        ph = rr.uniform(0, 6)
        for j in range(int(r * 2.2)):
            pt(tx + 1.2 * np.sin(j / 3 + ph), y + 1 + j, shade(c, -1) if j < r else shade(c, -3))


def turtle(x, y, s=1.0):
    """海龟：一块椭圆龟壳（上亮下暗、几块甲片），前鳍长、后鳍短，头朝右。"""
    shell, skin = (116, 124, 92), (138, 146, 112)
    fill([(x - 4 * s, y + 2 * s), (x - 16 * s, y + 9 * s), (x - 6 * s, y + 5 * s)], shade(skin, -2))
    fill([(x + 6 * s, y + 2 * s), (x + 2 * s, y + 13 * s), (x + 10 * s, y + 4 * s)], skin)
    ell(x + 15 * s, y - 1 * s, 4 * s, 3 * s, skin)
    pt(x + 17 * s, y - 2 * s, (40, 44, 50))
    ell(x, y, 13 * s, 7 * s, shell)
    ell(x - 2 * s, y - 2 * s, 9 * s, 4 * s, shade(shell, 1))
    rct(x - 12 * s, y + 4 * s, x + 12 * s, y + 6 * s, shade(shell, -2))
    for dx in (-6, 0, 6):
        ln(x + dx * s, y - 5 * s, x + dx * s + 2, y + 3 * s, shade(shell, -1))


def fish(x, y, c, flip=False):
    d = -1 if flip else 1
    rct(x, y, x + 5 * d if d > 0 else x, y + 2, c) if d > 0 else rct(x - 5, y, x, y + 2, c)
    pt(x + 6 * d, y - 1, c); pt(x + 6 * d, y + 3, c); pt(x + 6 * d, y + 1, c)
    pt(x + 1 * d, y, shade(c, 2)); pt(x + 1 * d, y + 1, (40, 40, 60))
    pt(x + 3 * d, y + 2, shade(c, -2))


def wreck(xa, xb, fy, rr):
    """沉船：一条斜着埋进沙里的木船，甲板是平的（能站），右端断开露出肋骨，
    一根断了的桅杆斜着，舷窗两三个，甲板上一个小舱房（顶也能站）。返回 (甲板 y, 舱房 (x0, x1, y))。"""
    wood = (98, 92, 104)                    # 水下的木头偏蓝灰
    deck = fy - 30
    L = xb - xa
    hull = [(xa, deck), (xb, deck), (xb - 4, deck + 6), (xb - 10, fy + 2), (xa + 18, fy + 2), (xa + 4, deck + 12)]
    fill(hull, wood)
    fill([(xa + 18, fy + 2), (xb - 10, fy + 2), (xb - 6, deck + 12), (xa + 8, deck + 16)], shade(wood, -1))
    for yy in range(deck + 4, fy, 4):                                      # 船板
        ln(xa + 4 + (yy - deck) * 0.6, yy, xb - 4 - (yy - deck) * 0.25, yy, shade(wood, -2))
    rct(xa, deck, xb, deck + 1, shade(wood, 2))                            # 甲板沿
    rct(xa, deck + 2, xb, deck + 2, shade(wood, -2))
    for i, f in enumerate((0.18, 0.32, 0.46)):                             # 舷窗
        wx = xa + int(L * f)
        ell(wx, deck + 9, 2.5, 2.5, (150, 156, 150)); ell(wx, deck + 9, 1.5, 1.5, (40, 56, 80))
    # 右端断口：黑洞 + 几根肋骨
    bx = xb - int(L * 0.18)
    fill([(bx, deck + 3), (xb - 2, deck + 3), (xb - 8, fy), (bx + 4, fy)], (40, 52, 74))
    for i in range(3):
        rx_ = bx + 3 + i * 5
        ln(rx_, deck + 2, rx_ + 2, fy - 2, shade(wood, 1))
    # 舱房
    hx0, hx1 = xa + int(L * 0.55), xa + int(L * 0.55) + 18
    box(hx0, deck - 14, hx1, deck - 1, shade(wood, 1), depth=0.05, cap=2)
    rct(hx0 + 4, deck - 10, hx0 + 8, deck - 1, (44, 58, 82))
    ell(hx1 - 5, deck - 8, 2, 2, (44, 58, 82))
    # 断桅杆：从甲板斜着上去，顶上断掉，挂着一片破帆
    mx = xa + int(L * 0.3)
    mtop = (mx + 26, deck - 78)
    thick([(mx, deck), mtop], shade(wood, 1), 2)
    ln(mx + 10, deck - 30, mx + 30, deck - 36, shade(wood, 1))
    fill([(mx + 12, deck - 34), (mx + 26, deck - 38), (mx + 22, deck - 16), (mx + 16, deck - 20)], (138, 150, 156))
    fill([(mx + 20, deck - 36), (mx + 26, deck - 38), (mx + 22, deck - 16)], (120, 132, 144))
    ln(mtop[0], mtop[1], xb - 6, deck, (80, 96, 120))                      # 垂下来的缆绳
    return deck, (hx0 - 1, hx1 + 1, deck - 15)


def sc_aquarium(tv):
    """海底：一层层变深的水和水面的波纹，几道斜光；远处礁石和鱼群的剪影；
    左边一丛海带和珊瑚，中间一堆礁石（顶能站）上长着桌形珊瑚（顶也能站），
    右边一条沉船（甲板和舱房顶能站），几串气泡往上冒，几条彩色的小鱼。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    T = tier(tv)
    rw, wh = x1 - x0, fy - y0
    rr = random.Random(71 + rw)
    hz = fy - [8, 14, 18][T]
    bands_v(tv, y0, hz, WATER)
    m = tv.screen_mask()
    # 水面波纹
    wave = m & (k.YY < y0 + 5 + 2 * np.sin(k.XX / 7.0) + np.sin(k.XX / 3.1))
    S().fill_mask(wave, (124, 176, 204))
    S().fill_mask(m & (k.YY < y0 + 2), (150, 196, 216))
    # 几道斜光：宽窄不一，不等距
    for f, w0, w1 in ([(0.14, 3, 12), (0.4, 5, 20), (0.5, 2, 6), (0.78, 4, 16)] if T == 2 else [(0.25, 3, 12), (0.62, 4, 14)] if T >= 1 else [(0.4, 2, 9)]):
        bx = at(tv, f)
        t = (k.YY - y0) / max(1, hz - y0)
        recolor(m & (k.YY < hz) & (np.abs(k.XX - (bx + t * wh * 0.25)) < w0 + (w1 - w0) * t), 1)
    # 远处礁石剪影：几块高低不一的礁岩，比水暗两档
    far = (50, 86, 124)
    for f, rx_, ry_ in ([(0.02, 34, 70), (0.1, 20, 40), (0.56, 26, 30), (0.63, 16, 52), (0.98, 30, 60)] if T == 2 else
                        [(0.03, 24, 46), (0.66, 20, 34)] if T == 1 else [(0.9, 16, 24)]):
        cx_ = at(tv, f)
        fill([(cx_ - rx_, hz + 2), (cx_ - rx_ * 0.6, hz - ry_ * 0.7), (cx_ - rx_ * 0.2, hz - ry_), (cx_ + rx_ * 0.3, hz - ry_ * 0.85),
              (cx_ + rx_ * 0.7, hz - ry_ * 0.4), (cx_ + rx_, hz + 2)], far)
        fill([(cx_ - rx_ * 0.2, hz - ry_), (cx_ + rx_ * 0.3, hz - ry_ * 0.85), (cx_ + rx_ * 0.7, hz - ry_ * 0.4), (cx_ + rx_, hz + 2), (cx_ + rx_ * 0.1, hz + 2)], shade(far, -1))
    # 中景礁盘：一道矮矮的礁坡，上面一排珊瑚的剪影（水里的蓝灰），中屏以上
    if T >= 1:
        reef = (70, 100, 130)
        ra, rb = at(tv, 0.14 if T == 2 else 0.1), at(tv, 0.56 if T == 2 else 0.52)
        top = hz - [0, 26, 40][T]
        fill([(ra, hz + 2), (ra + 20, top + 10), (ra + 50, top), ((ra + rb) / 2 + 20, top + 4), (rb - 20, top + 14), (rb, hz + 2)], reef)
        for i, xx in enumerate(range(ra + 24, rb - 20, 13)):
            hh = 6 + (i * 7) % 11
            yy = top + (4 if xx > (ra + rb) / 2 else 0)
            if i % 3 == 0:
                ell(xx, yy, 5, hh * 0.6, reef, clip=(0, int(yy)))
            else:
                for d in (-3, 0, 3):
                    ln(xx, yy, xx + d, yy - hh + abs(d), reef)
    if T >= 1:
        fish_school(at(tv, 0.64), y0 + wh * 0.3, 36 if T == 2 else 24, 10 if T == 2 else 7, 70 if T == 2 else 34, rr)
    if T == 2:
        fish_school(at(tv, 0.22), y0 + wh * 0.2, 22, 6, 30, rr, c=(66, 108, 146), tilt=0.1)
        for jx, jy, jr in ((0.42, 0.22, 6), (0.48, 0.34, 4), (0.86, 0.16, 5)):
            jelly(at(tv, jx), y0 + int(wh * jy), jr, rr)
        turtle(at(tv, 0.33), y0 + int(wh * 0.46), 1.0)
    elif T == 1:
        jelly(at(tv, 0.44), y0 + int(wh * 0.22), 5, rr)
    # 沙地：远处偏蓝、近处暖
    # 沙地压低一点：绿荧光屏按亮度分档，沙子太亮会变成整屏最亮的一条，怪站在上面反而糊
    S().fill_mask(m & (k.YY >= hz) & (k.YY < fy), (136, 144, 136))
    S().fill_mask(m & (k.YY >= hz + (fy - hz) // 2) & (k.YY < fy), (152, 152, 132))
    ground(tv, [(176, 166, 134), (162, 152, 124), (148, 140, 116), (136, 128, 108)])
    for _ in range(rw // 12):
        sx = rr.randint(x0, x1)
        sy = rr.randint(fy + 2, tv.sy1)
        ln(sx, sy, sx + rr.randint(3, 7), sy, (160, 150, 122))

    plats = []
    # 左边：海带一丛 + 珊瑚
    kel = {2: [(0.03, 6), (0.12, 4), (0.86, 3)], 1: [(0.04, 4), (0.9, 2)], 0: [(0.08, 3)]}[T]
    for f, n in kel:
        for j in range(n):
            kelp(at(tv, f) + j * rr.randint(4, 7), fy, rr.randint(int(wh * 0.3), int(wh * 0.7)), rr,
                 c=(80, 132, 98) if j % 2 == 0 else (70, 120, 92))
    if T == 2:
        fan_coral(at(tv, 0.2), fy, 12, (132, 108, 146))
        branch_coral(at(tv, 0.17), fy, 20, (196, 128, 124), rr)
        tube_coral(at(tv, 0.24), fy, rr)
    # 中间：礁石堆（顶能站） + 一根礁柱上长着桌形珊瑚（顶也能站）
    rx = at(tv, [0.45, 0.36, 0.33][T])
    if T >= 1:
        rock(rx - 24, fy, 16, 9, (98, 102, 124)); rock(rx + 20, fy, 18, 10, (92, 96, 120))
    rock(rx - 8, fy, 15, 9); rock(rx + 6, fy, 12, 7, (96, 100, 122))
    if T >= 1:
        rock(rx - 14, fy - 12, 11, 6, (110, 112, 132)); rock(rx + 6, fy - 13, 12, 6, (104, 106, 128))
        rtop = fy - 24
        fill([(rx - 13, rtop), (rx + 10, rtop), (rx + 14, rtop + 5), (rx - 16, rtop + 5)], (118, 120, 138))
        rct(rx - 12, rtop, rx + 9, rtop, (142, 144, 158))
        rct(rx + 6, rtop + 2, rx + 13, rtop + 5, (100, 102, 122))
        plats.append((rx - 13, rx + 10, rtop))
        brain_coral(rx - 26, fy - 16, 7)
        branch_coral(rx - 6, rtop + 1, 16, (196, 134, 122), rr)
        branch_coral(rx + 22, fy - 18, 12, (184, 144, 116), rr)
        tube_coral(rx - 36, fy, rr)
        if T == 2:
            px_ = rx + 38                                                  # 礁柱：一根往上收的石柱，左亮右暗
            fill([(px_ - 9, fy), (px_ + 10, fy), (px_ + 6, fy - 30), (px_ - 4, fy - 33)], (102, 106, 128))
            fill([(px_ + 1, fy), (px_ + 10, fy), (px_ + 6, fy - 30), (px_ + 1, fy - 32)], (88, 92, 116))
            rct(px_ - 6, fy - 26, px_ - 5, fy - 4, (124, 126, 144))
            table_coral(px_ + 2, fy - 42, 10, 30)
            plats.append((px_ - 12, px_ + 15, fy - 42))
            fan_coral(px_ + 18, fy, 9, (140, 108, 138))
            tube_coral(px_ - 16, fy, rr, c=(166, 128, 104))
    else:
        brain_coral(rx + 10, fy - 6, 5)
    # 右边：沉船
    if T >= 1:
        wa, wb = at(tv, [0, 0.58, 0.58][T]), at(tv, [0, 0.98, 0.9][T])
        deck, (ha, hb, hy) = wreck(wa, wb, fy, rr)
        plats.append((wa + 2, ha - 2, deck))
        if T == 2:
            plats.append((ha, hb, hy))
        bubbles(wb - 12, fy - 12, y0 + 6, rr)
    else:
        tube_coral(at(tv, 0.7), fy, rr)
    # 气泡串、彩色小鱼
    for f in ([0.09, 0.53] if T == 2 else [0.5] if T == 1 else [0.55]):
        bubbles(at(tv, f), fy - 16, y0 + 8, rr)
    fcols = [(232, 150, 92), (236, 206, 112), (214, 112, 112), (150, 196, 214)]
    for f, v, n in ([(0.3, 0.42, 3), (0.72, 0.5, 2), (0.9, 0.3, 2)] if T == 2 else [(0.5, 0.45, 2)] if T == 1 else [(0.6, 0.45, 1)]):
        for j in range(n):
            fish(at(tv, f) + j * 9, int(y0 + v * wh) + j * 5 - (j % 2) * 8, fcols[(j + int(f * 10)) % 4], flip=f > 0.6)
    for p in plats:
        plat(*p)
    k.finish_room(tv, ((x0 + x1) // 2, y0 + 10))


# ================================================================ 太空
SPACE = [(14, 14, 30), (18, 18, 38), (22, 22, 46), (28, 26, 54)]
MOON = [(198, 196, 204), (168, 166, 178), (140, 140, 154), (118, 118, 134), (98, 98, 116)]   # 亮 → 暗


def nebula(cx, cy, rx, ry, m, seed):
    """星云：一大团低频噪声按阈值分三档（暗紫、紫灰、灰蓝绿），档边是三角网格切出来的直线段。"""
    X, Y = k.XX, k.YY
    d = ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2
    F = 1 - d + 0.55 * smooth_noise(*X.shape, sx=rx / 2.5, sy=ry / 2, seed=seed)
    F = polygonal(F, 9, 7, seed=seed)
    for th, c in ((0.15, (34, 28, 58)), (0.45, (48, 36, 74)), (0.75, (66, 50, 90)), (1.15, (70, 74, 104))):
        S().fill_mask(m & (F > th), c)


def ringed_planet(px, py, r):
    base = (196, 140, 104)
    X, Y = k.XX, k.YY
    p = ((X - px) ** 2 + (Y - py) ** 2) <= r * r
    ell(px, py, r, r, shade(base, -2))
    for kk, (ox, rr_) in enumerate([(-r * 0.15, 0.85), (-r * 0.3, 0.62), (-r * 0.45, 0.38)]):
        ell(px + ox, py + ox * 0.6, r * rr_, r * rr_, shade(base, kk))
    S().fill_mask(p & (np.abs(Y - py - r * 0.15) < 1), shade(base, -1))
    ring = ((X - px) / (r * 1.75)) ** 2 + ((Y - py) / (r * 0.33)) ** 2
    rm = (ring <= 1) & (ring > 0.62) & ~(p & (Y < py))
    S().fill_mask(rm, (214, 196, 166))
    S().fill_mask(rm & (X > px + r * 0.5), (170, 152, 136))


def station(cx, cy, s):
    """空间站：一根横桁架，两头各一对太阳能板（灰蓝、格子），中间几节舱段（左上亮、底下暗），一个小天线锅。"""
    L = int(70 * s)
    truss = (150, 150, 166)
    rct(cx - L, cy, cx + L, cy + 1, truss)
    for x in range(cx - L, cx + L, 4):
        ln(x, cy - 1, x + 2, cy + 2, shade(truss, -2))
    for ex in (cx - L + 4, cx + L - 18):
        for sgn in (-1, 1):
            ya, yb = (cy - int(28 * s), cy - 3) if sgn < 0 else (cy + 4, cy + int(28 * s) + 3)
            rct(ex, ya, ex + 14, yb, (70, 84, 124))
            for gy in range(ya, yb, 4):
                ln(ex, gy, ex + 14, gy, (92, 108, 150))
            ln(ex + 7, ya, ex + 7, yb, (54, 64, 100))
            rct(ex, ya, ex, yb, (110, 124, 164))
    mods = [(-22, 14, 6), (-6, 16, 7), (12, 12, 5)]
    for dx, w, h in mods:
        x = cx + int(dx * s)
        ww, hh = int(w * s), max(3, int(h * s))
        rct(x, cy - hh, x + ww, cy + hh, (176, 176, 186))
        rct(x, cy - hh, x + ww, cy - hh + max(1, hh // 2), (210, 210, 216))
        rct(x, cy + hh - 1, x + ww, cy + hh, (130, 130, 146))
        rct(x + ww, cy - hh + 1, x + ww, cy + hh - 1, (120, 120, 136))
    rct(cx + int(4 * s), cy - int(16 * s), cx + int(10 * s), cy - int(8 * s), (220, 220, 226))   # 散热板
    ell(cx + int(28 * s), cy - 6, 3, 2, (196, 196, 204)); ln(cx + int(28 * s), cy - 4, cx + int(28 * s), cy, truss)
    pt(cx - L, cy, (240, 110, 100)); pt(cx + L, cy, (140, 240, 150))


def satellite(cx, cy):
    rct(cx - 3, cy - 3, cx + 3, cy + 3, (196, 170, 110)); rct(cx - 3, cy - 3, cx + 3, cy - 2, (226, 204, 140))
    for sgn in (-1, 1):
        rct(cx + sgn * 5, cy - 2, cx + sgn * 16, cy + 2, (70, 84, 124)) if sgn > 0 else rct(cx - 16, cy - 2, cx - 5, cy + 2, (70, 84, 124))
        ln(cx + sgn * 4, cy, cx + sgn * 5, cy, (150, 150, 166))
    ln(cx, cy - 4, cx + 2, cy - 8, (180, 180, 190)); pt(cx + 2, cy - 9, (240, 240, 240))


def boulder(cx, fy, w, h, rr):
    """月面大石头：顶面最亮、左边朝光、右边背光，石头底下一块影子往右拖。"""
    ell(cx + w * 0.3, fy, w * 0.75, 2, MOON[4], clip=(fy - 2, fy + 3))
    pts = [(cx - w / 2, fy), (cx - w / 2 + 2, fy - h * 0.6), (cx - w * 0.2, fy - h), (cx + w * 0.25, fy - h), (cx + w / 2, fy - h * 0.45), (cx + w / 2 + 1, fy)]
    fill(pts, MOON[2])
    fill([(cx - w / 2, fy), (cx - w / 2 + 2, fy - h * 0.6), (cx - w * 0.2, fy - h), (cx - w * 0.05, fy - h * 0.55), (cx - w * 0.1, fy)], MOON[1])
    fill([(cx + w * 0.1, fy - h * 0.5), (cx + w * 0.25, fy - h), (cx + w / 2, fy - h * 0.45), (cx + w / 2 + 1, fy), (cx + w * 0.2, fy)], MOON[3])
    rct(cx - w * 0.2, fy - h, cx + w * 0.25, fy - h + 1, MOON[0])
    pt(cx - w * 0.1, fy - h * 0.3, MOON[3]); pt(cx + w * 0.3, fy - h * 0.25, MOON[4])


def crater(cx, cy, rx, ry):
    """坑：光从左上来，坑里左边的内壁在影子里、右边的内壁被照亮，外沿一圈亮边。"""
    ell(cx, cy, rx + 1, ry + 1, MOON[1])
    ell(cx, cy, rx, ry, MOON[3])
    ell(cx + rx * 0.25, cy + ry * 0.15, rx * 0.7, ry * 0.7, MOON[2])
    ell(cx - rx * 0.3, cy, rx * 0.5, ry * 0.7, MOON[4])


def lander(lx, fy):
    """登月舱下降段：八角形的金箔舱体（几块金色分档，像皱的箔纸），四条斜腿和脚垫，前腿一架梯子。
    上升段已经飞走了，顶上是平的（能站）。返回顶 y。"""
    top = fy - 34
    gold = [(150, 124, 76), (184, 156, 96), (212, 184, 120), (232, 210, 150)]
    for sgn in (-1, 1):                                                    # 后面两条腿（暗）
        ln(lx + sgn * 8, top + 14, lx + sgn * 22, fy - 1, (110, 104, 100))
    fill([(lx - 15, top + 3), (lx - 11, top), (lx + 11, top), (lx + 15, top + 3), (lx + 15, top + 13), (lx + 11, top + 16), (lx - 11, top + 16), (lx - 15, top + 13)], gold[1])
    fill([(lx - 15, top + 3), (lx - 11, top), (lx - 4, top), (lx - 6, top + 16), (lx - 11, top + 16), (lx - 15, top + 13)], gold[2])
    fill([(lx - 13, top + 4), (lx - 9, top + 2), (lx - 8, top + 8), (lx - 12, top + 10)], gold[3])
    fill([(lx + 6, top), (lx + 11, top), (lx + 15, top + 3), (lx + 15, top + 13), (lx + 11, top + 16), (lx + 4, top + 16)], gold[0])
    fill([(lx - 2, top + 6), (lx + 4, top + 4), (lx + 3, top + 12), (lx - 3, top + 11)], gold[2])
    rct(lx - 11, top, lx + 11, top, (226, 222, 214))
    rct(lx - 11, top + 1, lx + 11, top + 1, (180, 176, 176))
    for sgn, c in ((-1, (196, 192, 190)), (1, (140, 136, 140))):            # 前面两条腿
        thick([(lx + sgn * 13, top + 12), (lx + sgn * 27, fy - 1)], c, 2)
        ln(lx + sgn * 10, top + 16, lx + sgn * 22, fy - 6, c)
        ell(lx + sgn * 27, fy, 4, 1.2, c)
    for yy in range(top + 18, fy - 2, 3):                                  # 梯子
        t = (yy - top - 12) / (fy - top - 12)
        xx = lx - 13 - 14 * t
        ln(xx, yy, xx + 3, yy, (196, 192, 190))
    return top


def rover(rx, fy):
    """月球车：平板底盘（能站）、两只网轮挡着挡泥板、两个座椅靠背、前面一根杆子顶着伞形天线。返回底盘顶 y。"""
    top = fy - 18
    body = (176, 172, 168)
    for wx in (rx - 12, rx + 12):
        ell(wx, fy - 5, 5, 5, (70, 70, 84))
        ell(wx, fy - 5, 3, 3, (112, 112, 126))
        pt(wx - 1, fy - 6, (150, 150, 160))
        fill([(wx - 7, fy - 9), (wx + 7, fy - 9), (wx + 6, fy - 12), (wx - 6, fy - 12)], (190, 170, 120))
    rct(rx - 18, fy - 12, rx + 18, fy - 9, (130, 128, 136))
    box(rx - 16, top, rx + 16, top + 5, body, depth=0.04, cap=2)
    rct(rx - 16, top, rx + 16, top, (210, 208, 206))
    for sx_ in (rx - 6, rx + 2):                                           # 座椅靠背（矮）
        rct(sx_, top - 4, sx_ + 1, top - 1, (110, 120, 150))
    rct(rx + 14, top - 16, rx + 14, top, (150, 150, 160))                  # 天线杆 + 伞
    fill([(rx + 8, top - 15), (rx + 20, top - 15), (rx + 14, top - 20)], (220, 218, 214))
    fill([(rx + 14, top - 15), (rx + 20, top - 15), (rx + 14, top - 20)], (176, 174, 176))
    rct(rx - 18, top - 3, rx - 15, top, (90, 90, 104))                     # 后面的电视摄像机
    return top


def sc_space(tv):
    """太空：分档的黑夜、一大团星云、稀疏的星星（几颗十字亮星），带环的行星、小地球、空间站，
    他们那艘喷着火的旧飞船；下面是月面：远处一道起伏的山脊，近处平地上几个坑和几块大石头，
    一架登月舱和一辆月球车。能站的：登月舱顶、月球车底盘、一块大石头。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    T = tier(tv)
    rw, wh = x1 - x0, fy - y0
    rr = random.Random(97 + rw)
    m = tv.screen_mask()
    bands_v(tv, y0, fy, SPACE)
    if T >= 1:
        nebula(at(tv, 0.62), y0 + wh * 0.3, rw * 0.26, wh * 0.26, m, seed=2)
    for _ in range(rw * wh // 230):
        pt(rr.randint(x0, x1), rr.randint(y0, fy - 20), rr.choice([(226, 226, 240), (200, 200, 226), (150, 160, 200), (236, 220, 170)]))
    for _ in range(3 + 3 * T):
        sx_, sy_ = rr.randint(x0 + 10, x1 - 10), rr.randint(y0 + 8, int(fy - wh * 0.4))
        pt(sx_, sy_, (250, 250, 250))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            pt(sx_ + dx, sy_ + dy, (170, 176, 210))
    ringed_planet(at(tv, [0.72, 0.8, 0.84][T]), y0 + int(wh * 0.2), [10, 15, 20][T])
    ex, ey = at(tv, [0.3, 0.3, 0.32][T]), y0 + int(wh * 0.14)
    ell(ex, ey, 2 + 2 * T, 2 + 2 * T, (80, 130, 186)); ell(ex - 1, ey - 1, 1 + 1.5 * T, 1 + 1.5 * T, (106, 156, 204))
    rct(ex - 1 - T, ey - 1 - T, ex, ey, (116, 170, 120))
    if T == 2:
        station(at(tv, 0.5), y0 + int(wh * 0.2), 1.0)
    elif T == 1:
        satellite(at(tv, 0.55), y0 + int(wh * 0.18))
    sc.ship(at(tv, [0.12, 0.12, 0.08][T]), y0 + int(wh * [0.45, 0.42, 0.4][T]), [0.6, 0.8, 1.0][T], flame=True)

    # 月面：两层山脊。远的一层高、暗，山峰成簇；近的一层矮、亮一点，顶边被左上的太阳照亮一道
    hz = fy - [10, 18, 24][T]
    X = k.XX
    u = (X - x0) / rw
    g = lambda c, w: np.exp(-((u - c) / w) ** 2)
    for layer, (peaks, col, lit, base) in enumerate((
            ([(0.1, 0.22, 0.06), (0.18, 0.14, 0.05), (0.56, 0.3, 0.07), (0.64, 0.2, 0.05), (0.9, 0.18, 0.08)], (66, 66, 86), (88, 88, 108), 0.06),
            ([(0.3, 0.1, 0.1), (0.78, 0.12, 0.09), (0.98, 0.08, 0.05)], (92, 92, 110), (122, 122, 138), 0.03))):
        hgt = base + sum(a * g(c, w) for c, a, w in peaks) + 0.012 * np.sin(X / 5.0 + layer)
        ridge = polygonal((hz - wh * hgt).astype(float), 10, 8, seed=layer + 1)
        rm = m & (k.YY >= ridge) & (k.YY < hz)
        S().fill_mask(rm, col)
        # 朝左上太阳的那面坡（往右升高）整面亮一档，背面保持暗：山就有了体积
        sm_h = polygonal((hz - wh * (base + sum(a * g(c, w) for c, a, w in peaks))).astype(float), 10, 8, seed=layer + 1)
        S().fill_mask(rm & (np.gradient(sm_h, axis=1) < -0.08) & (k.YY < ridge + wh * 0.12), shade(col, 1))
        S().fill_mask(rm & (k.YY < ridge + 2) & (np.gradient(ridge, axis=1) <= 0.05), lit)   # 朝左（往右升高）的坡亮
    S().fill_mask(m & (k.YY >= hz) & (k.YY < fy), MOON[2])
    S().fill_mask(m & (k.YY == hz), MOON[1])
    ground(tv, [MOON[1], MOON[2], MOON[3], MOON[3]])
    # 远处的坑（扁）、近处的坑（在地面那一条里，只用暗的灰，不花）
    for f, rx_ in ([(0.08, 14), (0.24, 8), (0.62, 12), (0.9, 9)] if T == 2 else [(0.15, 10), (0.7, 9)] if T == 1 else [(0.3, 7)]):
        crater(at(tv, f), hz + (fy - hz) * 0.5, rx_, max(1.5, (fy - hz) * 0.15))
    for f, rx_ in ([(0.18, 12), (0.47, 9), (0.83, 14)] if T == 2 else [(0.4, 10)] if T >= 1 else []):
        crater(at(tv, f), fy + 5, rx_, 2)

    plats = []
    if T == 2:
        lx = at(tv, 0.33)
        top = lander(lx, fy)
        plats.append((lx - 11, lx + 11, top))
        fx = lx + 34                                                       # 旗子
        rct(fx, fy - 26, fx, fy, (210, 210, 214))
        rct(fx + 1, fy - 26, fx + 11, fy - 20, (196, 84, 76)); rct(fx + 1, fy - 22, fx + 11, fy - 20, (160, 66, 64))
        rvx = at(tv, 0.52)
        top = rover(rvx, fy)
        plats.append((rvx - 16, rvx + 16, top))
        bx = at(tv, 0.68)
        boulder(bx, fy, 30, 28, rr)
        plats.append((bx - 6, bx + 7, fy - 28))
        boulder(bx + 26, fy, 14, 10, rr); boulder(at(tv, 0.08), fy, 18, 12, rr)
        boulder(at(tv, 0.92), fy, 22, 16, rr)
    elif T == 1:
        rvx = at(tv, 0.4)
        top = rover(rvx, fy)
        plats.append((rvx - 16, rvx + 16, top))
        bx = at(tv, 0.62)
        boulder(bx, fy, 26, 28, rr)
        plats.append((bx - 5, bx + 6, fy - 28))
        boulder(at(tv, 0.86), fy, 14, 10, rr)
    else:
        boulder(at(tv, 0.7), fy, 20, 14, rr)
        rct(at(tv, 0.3), fy - 16, at(tv, 0.3), fy, (210, 210, 214))
        rct(at(tv, 0.3) + 1, fy - 16, at(tv, 0.3) + 8, fy - 12, (196, 84, 76))
    for p in plats:
        plat(*p)
    k.finish_room(tv, (x0 + 20, y0 + 10))


# ================================================================ 地铁车厢
SUB_WALL = [(212, 204, 186), (198, 190, 172), (182, 174, 158), (164, 156, 144), (146, 138, 128)]
SUB_FLOOR = [(130, 122, 116), (116, 108, 104), (104, 96, 94), (92, 86, 86)]


def car_door(dx, fy, top, w=24):
    """一对推拉门：两扇门板（左扇朝光亮一点），每扇一块竖长窗（外面是黑的隧道），中缝一道橡胶条，
    门上一盏指示灯，门框挤出一点厚度，门前地上一条防滑踏板。"""
    frame = (150, 144, 136)
    box(dx - 3, top - 4, dx + 2 * w + 2, fy, frame, depth=0.03, cap=2)
    for i, c in enumerate(((196, 190, 178), (180, 174, 164))):
        x = dx + i * w
        rct(x, top, x + w - 1, fy, c)
        wx0, wx1 = x + 5, x + w - 6
        rct(wx0, top + 8, wx1, fy - 34, (40, 38, 46))
        rct(wx0, top + 8, wx1, top + 9, (60, 56, 64))
        ln(wx0 + 1, fy - 40, wx0 + 4, fy - 46, (70, 66, 74))                # 玻璃上一道反光
    rct(dx + w - 1, top, dx + w, fy, (70, 64, 66))                         # 中缝
    rct(dx, fy - 2, dx + 2 * w - 1, fy, (120, 112, 106))
    rct(dx + w - 3, top - 3, dx + w + 2, top - 2, (252, 230, 160))           # 门灯
    return dx - 3, dx + 2 * w + 2


def tunnel_window(wx0, wx1, wy0, wy1, rr):
    """车窗：外面是黑的隧道，一条电缆、两三盏拉成短线的隧道灯（不等距）。窗框亮一档，下沿一道窗台。"""
    rct(wx0 - 2, wy0 - 2, wx1 + 2, wy1 + 3, (164, 158, 148))
    rct(wx0, wy0, wx1, wy1, (36, 34, 42))
    rct(wx0, wy0, wx1, wy0 + (wy1 - wy0) // 3, (44, 40, 48))
    cy = wy0 + int((wy1 - wy0) * rr.uniform(0.55, 0.7))
    ln(wx0, cy, wx1, cy, (56, 52, 58)); ln(wx0, cy + 3, wx1, cy + 3, (52, 48, 54))
    ly = wy0 + int((wy1 - wy0) * 0.3)
    x = wx0 + rr.randint(2, 10)
    while x < wx1 - 4:
        L = rr.randint(5, 12)
        ln(x, ly, min(wx1, x + L), ly, (248, 214, 140))
        ln(x + 2, ly + 1, min(wx1, x + L - 2), ly + 1, (150, 120, 84))
        x += L + rr.randint(14, 28)
    ln(wx0 + 2, wy1 - 3, wx0 + 8, wy1 - 9, (66, 62, 70))
    rct(wx0 - 3, wy1 + 3, wx1 + 3, wy1 + 4, (190, 184, 172))


def seat_bench(xa, xb, fy):
    """一段长椅：靠背（顶能站）+ 坐垫，按人分格；两头一块隔板（玻璃屏风）。"""
    back, cush = (128, 96, 86), (156, 112, 96)
    rct(xa, fy - 26, xb, fy - 13, back)
    rct(xa, fy - 26, xb, fy - 25, shade(back, 2))
    n = max(1, (xb - xa) // 15)
    for i in range(1, n):
        x = xa + (xb - xa) * i // n
        ln(x, fy - 24, x, fy - 14, shade(back, -2))
    rct(xa, fy - 13, xb, fy - 9, cush)
    rct(xa, fy - 13, xb, fy - 13, shade(cush, 2))
    for i in range(1, n):
        x = xa + (xb - xa) * i // n
        pt(x, fy - 12, shade(cush, -2)); pt(x, fy - 11, shade(cush, -2))
    rct(xa, fy - 8, xb, fy, (96, 88, 88))
    for gx in range(xa + 6, xb - 6, 20):                                   # 座位下面的暖风口
        rct(gx, fy - 5, gx + 8, fy - 3, (80, 74, 76))
    for ex in (xa - 4, xb + 1):
        rct(ex, fy - 36, ex + 3, fy - 9, (188, 194, 196))
        rct(ex, fy - 36, ex + 3, fy - 36, (214, 218, 220))
        rct(ex + 1, fy - 34, ex + 2, fy - 12, (166, 172, 176))


def pole(x, top, fy):
    rct(x, top, x + 1, fy, (226, 222, 214))
    rct(x + 1, top, x + 1, fy, (176, 170, 164))
    rct(x - 1, fy - 1, x + 2, fy, (150, 144, 138))


def straps(xa, xb, rail_y, n, L=10):
    """一组吊环：横杆下面挂 n 个，带子 + 一个三角形的环（环里透出后面的东西）。"""
    for i in range(n):
        x = int(xa + (xb - xa) * (i + 0.5) / n)
        rct(x, rail_y + 1, x, rail_y + L, (120, 112, 106))
        y = rail_y + L + 1
        fill([(x - 3, y + 5), (x + 4, y + 5), (x + 0.5, y)], (226, 220, 206))
        fill([(x - 1, y + 4), (x + 2, y + 4), (x + 0.5, y + 2)], (70, 66, 72))
        rct(x - 3, y + 5, x + 3, y + 5, (176, 170, 160))


def ad_card(x, y, w, h, kind):
    """车厢广告牌：浅色框里一张小画（太阳和海 / 一杯饮料 / 一张笑脸 / 一行大字）。"""
    rct(x - 1, y - 1, x + w + 1, y + h + 1, (150, 144, 136))
    rct(x, y, x + w, y + h, (226, 220, 206))
    if kind == 0:
        rct(x + 1, y + h // 2, x + w - 1, y + h - 1, (110, 140, 176))
        ell(x + w * 0.7, y + h * 0.45, h * 0.22, h * 0.22, (236, 180, 100))
    elif kind == 1:
        rct(x + w // 2 - 3, y + 3, x + w // 2 + 3, y + h - 3, (176, 100, 90))
        rct(x + w // 2 - 3, y + 3, x + w // 2 + 3, y + 4, (236, 228, 214))
        rct(x + 3, y + h - 4, x + w // 2 - 6, y + h - 3, (120, 110, 104))
    elif kind == 2:
        ell(x + w * 0.3, y + h * 0.5, h * 0.32, h * 0.32, (230, 196, 120))
        pt(x + w * 0.3 - 2, y + h * 0.45, (90, 70, 60)); pt(x + w * 0.3 + 2, y + h * 0.45, (90, 70, 60))
        rct(x + w * 0.55, y + 4, x + w - 3, y + 5, (120, 110, 104)); rct(x + w * 0.55, y + 8, x + w - 6, y + 9, (120, 110, 104))
    else:
        text(x + 3, y + h // 2 - 2, "SALE", (176, 84, 80))


def sc_subway(tv):
    """地铁车厢（琥珀 / 黑白屏）：
    天花板是往里收的一块面：近处一排、远处一排日光灯（门上方断开），几条朝灭点收的板缝；
    车厢被两对推拉门分成三段，每段一排长椅（靠背顶能站）、一两扇车窗（外面黑的隧道和几盏隧道灯）、
    车窗上面一排广告牌、一根横杆挂着两组吊环；门两边各一根竖扶杆，门上一条线路指示灯。
    中屏一对门两段，小屏一段长椅加一对门。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    T = tier(tv)
    rw, wh = x1 - x0, fy - y0
    rr = random.Random(113 + rw)
    sm = tv.screen_mask()
    k.room_base(tv, SUB_WALL, SUB_FLOOR, ((x0 + x1) // 2, y0 + 6),
                lamps=[(at(tv, 0.3), y0 + 4), (at(tv, 0.75), y0 + 4)] if T == 2 else None)
    ceil = fy - int(min(128, wh * 0.62))
    door_top = max(ceil + 6, fy - [58, 80, 96][T])
    win_t = door_top + [4, 8, 8][T]
    win_b = fy - [32, 40, 40][T]
    dw = [16, 22, 22][T]
    doors = {2: [at(tv, 0.27), at(tv, 0.69)], 1: [at(tv, 0.55)], 0: [at(tv, 0.68)]}[T]
    segs, xa = [], x0 + 2
    for d in doors:
        segs.append((xa, d - 4))
        xa = d + 2 * dw + 4
    segs.append((xa, x1 - 2))

    # --- 天花板：一块面（比墙暗一档），近处亮、往墙那边暗一点；墙顶一道檐
    VPX = (x0 + x1) / 2
    S().fill_mask(sm & (k.YY < ceil), (170, 162, 152))
    S().fill_mask(sm & (k.YY < ceil) & (k.YY >= ceil - (ceil - y0) // 3), (158, 150, 142))
    rct(x0, ceil - 1, x1, ceil + 2, (196, 188, 176))
    rct(x0, ceil + 3, x1, ceil + 3, (140, 132, 124))
    # 门上方的板缝：从墙顶往屏幕上沿，朝灭点反方向张开
    for d in (doors if T >= 1 else []):
        for ex in (d - 5, d + 2 * dw + 5):
            ln(ex, ceil - 1, ex + (ex - VPX) * 0.35, y0, (146, 138, 130))
    # 两排日光灯：远的一排细、靠近墙；近的一排粗、靠近屏幕上沿；门上方断开
    if ceil - y0 > 14:
        far_y, near_y = ceil - (ceil - y0) // 4, y0 + (ceil - y0) // 3
        for a, b in segs:
            if b - a < 24:
                continue
            rct(a + 8, far_y, b - 8, far_y + 1, (252, 244, 214))
            rct(a + 8, far_y + 2, b - 8, far_y + 2, (150, 142, 134))
            ka, kb = a + 8 + (a + 8 - VPX) * 0.25, b - 8 + (b - 8 - VPX) * 0.25
            rct(ka, near_y, kb, near_y + 3, (252, 246, 222))
            rct(ka, near_y + 4, kb, near_y + 5, (140, 132, 124))
            for vx in range(int(ka) + 10, int(kb) - 10, 26):               # 灯边上的风口
                rct(vx, near_y + 9, vx + 10, near_y + 10, (140, 132, 124))
        # 中吊广告：从天花板中线吊下来的几张海报，离镜头近，所以比墙上的广告大；每段一两张，位置错开
        if T >= 1:
            hy = near_y + 14
            cw, chh = [0, 30, 40][T], [0, 13, 18][T]
            for i, (a, b) in enumerate(segs):
                if b - a < 60 or hy + chh > ceil - 4:
                    continue
                n = 2 if b - a > 130 else 1
                for j in range(n):
                    cx_ = int(a + (b - a) * (j + 0.5) / n - cw / 2 + (8 if (i + j) % 2 else -8))
                    for wx in (cx_ + 4, cx_ + cw - 4):
                        rct(wx, y0, wx, hy - 2, (120, 112, 106))
                    rct(cx_ - 1, hy - 2, cx_ + cw + 1, hy - 1, (96, 90, 88))
                    ad_card(cx_, hy, cw, chh, (i + j + 2) % 4)
                    rct(cx_ - 1, hy + chh + 2, cx_ + cw + 1, hy + chh + 2, (140, 132, 124))

    # --- 广告牌：墙顶下面一排，只在座位段，一段一两张
    ad_h = [0, 11, 14][T]
    if ad_h and win_t - ceil > ad_h + 12:
        for i, (a, b) in enumerate(segs):
            if b - a < 50:
                continue
            n = 2 if b - a > 120 else 1
            cw = 34 if T == 2 else 26
            for j in range(n):
                cx_ = a + (b - a) * (j + 0.5) / n - cw / 2 + (j * 2 - 1) * 6 * (n > 1)
                ad_card(int(cx_), ceil + 7, cw, ad_h, (i * 2 + j) % 4)
    # --- 车窗：每段两扇（窄段一扇），宽窄看段长
    for a, b in segs:
        span = b - a - 18
        if span < 24 or win_b - win_t < 8:
            continue
        nwin = 2 if span > 100 else 1
        gap = 12
        ww = (span - gap * (nwin - 1)) // nwin
        for j in range(nwin):
            wx = a + 9 + j * (ww + gap)
            tunnel_window(wx, wx + ww, win_t, win_b, rr)
    # 线路图：大屏中间那段的窗下
    if T == 2:
        a, b = segs[1]
        mx = (a + b) // 2 - 30
        rct(mx, win_b + 7, mx + 60, win_b + 13, (232, 226, 210))
        ln(mx + 4, win_b + 10, mx + 56, win_b + 10, (176, 84, 80))
        for sx_ in range(mx + 6, mx + 56, 9):
            rct(sx_, win_b + 9, sx_ + 1, win_b + 11, (246, 246, 246))
        rct(mx + 33, win_b + 9, mx + 34, win_b + 11, (236, 180, 90))
    # --- 门、门上的指示灯条
    for d in doors:
        car_door(d, fy, door_top, dw)
        if T >= 1:
            rct(d + 2, door_top - 12, d + 2 * dw - 3, door_top - 7, (54, 48, 52))
            for i, lx_ in enumerate(range(d + 5, d + 2 * dw - 5, 4)):
                pt(lx_, door_top - 10, (250, 214, 130) if i == 3 else (120, 100, 80))
    # --- 长椅（靠背顶能站）、扶杆、横杆和吊环
    plats = []
    for a, b in segs:
        sa, sb = a + (7 if a <= x0 + 2 else 3), b - (7 if b >= x1 - 2 else 3)    # 门两边的长椅贴近门，靠背之间不超过 60 格
        if sb - sa < 20:
            continue
        seat_bench(sa, sb, fy)
        plats.append((sa, sb, fy - 26))
    for d in doors:                                                        # 竖扶杆贴着长椅端头的隔板
        pole(d - 6, ceil + 3, fy)
        pole(d + 2 * dw + 5, ceil + 3, fy)
    if T >= 1:
        rail_y = win_t - [0, 4, 6][T]
        for a, b in segs:
            if b - a < 40:
                continue
            rct(a + 6, rail_y, b - 6, rail_y, (220, 216, 206))
            rct(a + 6, rail_y + 1, b - 6, rail_y + 1, (150, 144, 136))
            for xx in (a + 8, b - 8):
                rct(xx, ceil + 3, xx, rail_y, (190, 184, 174))
            mid_ = (a + b) // 2
            n = max(2, min(4, (b - a) // 40))
            straps(a + 12, mid_ - 8, rail_y, n, L=[0, 7, 10][T])
            straps(mid_ + 8, b - 12, rail_y, n, L=[0, 7, 10][T])
    for p in plats:
        plat(*p)
    k.finish_room(tv, ((x0 + x1) // 2, y0 + 8))


SCENES_V3 = {
    "weather": sc_weather,
    "ferris": sc_ferris,
    "forest": sc_forest,
    "aquarium": sc_aquarium,
    "space": sc_space,
    "subway": sc_subway,
}
