"""第三关 v3 室外场景（2026-10-17 重画）：rooftop 黄昏屋顶、rain_street 雨夜街道、harbor 夜港、
snow_yard 雪夜院子、beach 黄昏海滩、desert 沙漠。

作者的反馈：背景乱、东西太少太小；屋顶的天线按固定间隔排成一排像栅栏；楼太矮太小。
这一版的做法：
- 远、中、近三层：远景是贴着天色的淡剪影（低对比），中景是主体（有体积、有光），近景是地上的小东西。
- 按正常比例摆：主角 13 高，路灯约 45，门约 48。大屏靠更多东西、更多层铺满，不是把东西放大。
- 同一样东西不按固定间隔排：楼的宽高按一条慢变的包络 + 随机，窗户按"一户一户"成片亮；
  天线、路灯、栅栏成组（两三根挨着，然后空一大段）。
- 按屏幕大小放几组：大屏（宽 >= 360）全放、给 3~4 个单向平台；中屏放一半；小屏只放最有代表性的。
  平台高度在地面以上 18~45 格，相邻平台横向间隔不超过 60 格。
- 地面往上 14 格以内不放太亮太花的东西（怪在地上走，要看得清）。
画法：远景平涂，中景用 crt_wall_v2 的 box / extrude 挤出体积，迎光面亮、背光面偏冷。
每个场景最后调 k.finish_room（室外不会加光照色块）。
"""
import random

import numpy as np

import crt_wall_v2 as k
import l3_scenes as sc
from crt_wall_v2 import shade, box as kbox, extrude, floor_shadow
from l3_scenes import S, plat, bands_v, ground, disc

CREW = [(186, 84, 78), (178, 134, 98), (98, 126, 182), (106, 158, 106)]     # 四个船员的颜色：每个场景都藏一处


# ================================================================ 小工具
def size_of(tv):
    """0 = 小屏，1 = 中屏，2 = 大屏。"""
    rw = tv.sx1 - tv.sx0
    if rw >= 360:
        return 2
    if rw >= 200:
        return 1
    return 0


def R(x0, y0, x1, y1, c):
    """含端点的矩形，直接写像素（比 Canvas.rect 快，画几百个窗户用）。"""
    a = S().a
    H, W = a.shape[:2]
    x0, x1 = max(0, int(round(x0))), min(W - 1, int(round(x1)))
    y0, y1 = max(0, int(round(y0))), min(H - 1, int(round(y1)))
    if x0 <= x1 and y0 <= y1:
        a[y0:y1 + 1, x0:x1 + 1] = (*c[:3], 255)


def V(x, y0, y1, c):
    R(x, min(y0, y1), x, max(y0, y1), c)


def HL(x0, x1, y, c):
    R(min(x0, x1), y, max(x0, x1), y, c)


def P(x, y, c):
    S().put(int(round(x)), int(round(y)), c)


def seg(xa, ya, xb, yb, c):
    """一像素的直线，直接写像素。"""
    n = int(max(abs(xb - xa), abs(yb - ya))) + 1
    for i in range(n + 1):
        t = i / max(1, n)
        P(xa + (xb - xa) * t, ya + (yb - ya) * t, c)


def sag(xa, ya, xb, yb, dip, c):
    """两点之间垂下来的一根线（电线、晾衣绳）。"""
    prev = None
    for x in range(int(xa), int(xb) + 1):
        t = (x - xa) / max(1, xb - xa)
        y = int(round(ya + (yb - ya) * t + dip * 4 * t * (1 - t)))
        if prev is not None and abs(y - prev) > 1:
            V(x, prev + (1 if y > prev else -1), y, c)
        P(x, y, c)
        prev = y


def tone(mask, kk):
    """把 mask 里已经画好的颜色整体挪 kk 档（灯下的一圈光、影子）。保持色块，不碎。"""
    a = S().a
    m = mask & (a[..., 3] > 0)
    if not m.any():
        return
    px = a[..., :3][m]
    keys, inv = np.unique(px, axis=0, return_inverse=True)
    new = np.array([shade(tuple(int(v) for v in c), kk) for c in keys], np.uint8)
    a[..., :3][m] = new[inv.ravel()]


def ellipse_mask(cx, cy, rx, ry):
    return ((k.XX - cx) / max(rx, 0.5)) ** 2 + ((k.YY - cy) / max(ry, 0.5)) ** 2 <= 1


def skyline(tv, rnd, base, hmin, hmax, col, wr=(10, 26), gap=(0, 3), win=None, win_n=1.0,
            wpitch=(3, 4), wsz=(0, 1), rim=None, sun_x=None, tops=0.4, masts=0.0, x_from=None, x_to=None, dk=None):
    """一层城市剪影。楼高 = 慢变的包络（一片高、一片矮）× 随机，偶尔冒一栋高楼；
    窗户按一户一户成片亮（同一层挨着的两三扇），不是满墙均匀撒。rim：朝太阳那一侧和楼顶压一道亮边。
    masts：有些楼顶上两三根小天线挨在一起（成组），大多数楼顶没有。
    dk：不给固定颜色，楼身 = 后面的天色暗 dk 档（远处的楼带着天光的渐变，越远越贴天色；
    琥珀屏、黑白屏只看亮度，固定颜色的远景会比上面的天还亮，反客为主）。"""
    if dk is not None:
        snap = S().a.copy()
        SENT = (1, 2, 3)
        out = skyline(tv, rnd, base, hmin, hmax, SENT, wr, gap, win, win_n, wpitch, wsz, rim, sun_x, tops, masts, x_from, x_to)
        a = S().a
        m = (a[..., 0] == 1) & (a[..., 1] == 2) & (a[..., 2] == 3)
        a[m] = snap[m]
        tone(m & tv_mask_cache[0], dk)
        return out
    x0, x1 = (tv.sx0 if x_from is None else x_from), (tv.sx1 if x_to is None else x_to)
    x = x0 - rnd.randint(0, wr[1])
    ph, per = rnd.uniform(0, 6.3), rnd.uniform(0.45, 0.8) * (tv.sx1 - tv.sx0)
    out = []
    while x <= x1:
        bw = rnd.randint(*wr)
        env = 0.5 + 0.5 * np.sin((x - tv.sx0) / per * 6.283 + ph)
        h = hmin + (hmax - hmin) * (0.25 + 0.75 * env) * rnd.uniform(0.6, 1.0)
        if rnd.random() < 0.12:
            h = min(hmax * 1.25, h * 1.45)
        h = int(h)
        top = base - h
        R(x, top, x + bw, base, col)
        r = rnd.random()
        if r < tops * 0.4 and bw > 9:                                   # 退台
            R(x + 2, top - 3 - h // 10, x + bw - 2 - bw // 4, top, col)
            top2 = top - 3 - h // 10
        elif r < tops * 0.7 and bw > 8:                                 # 楼顶的小机房 / 水箱
            bx = x + rnd.randint(1, max(1, bw - 7))
            R(bx, top - 4, bx + 5, top, col)
            top2 = top
        elif r < tops:                                                  # 尖顶
            V(x + bw // 2, top - rnd.randint(5, 12), top, col)
            top2 = top
        else:
            top2 = top
        if masts and rnd.random() < masts:
            mx = x + rnd.randint(1, max(1, bw - 6))
            for j in range(rnd.randint(2, 3)):
                V(mx + j * rnd.randint(2, 4), top - rnd.randint(4, 11), top, col)
        if rim is not None and sun_x is not None:
            sx_ = x + bw if sun_x > x + bw else x
            V(sx_, top, base, rim)
            HL(x, x + bw, top, rim)
        if win and win_n:
            fx, fy_ = wpitch
            floors = max(0, (h - 6) // fy_)
            cols = max(0, (bw - 2) // fx)
            for _ in range(int(win_n) + (1 if rnd.random() < win_n % 1 else 0)):
                if floors < 1 or cols < 1:
                    break
                f0 = rnd.randint(0, floors - 1)
                c0 = rnd.randint(0, cols - 1)
                for f in range(f0, min(floors, f0 + rnd.randint(1, 3))):
                    for cc in range(c0, min(cols, c0 + rnd.randint(1, 3))):
                        if rnd.random() < 0.8:
                            wx, wy = x + 2 + cc * fx, top + 4 + f * fy_
                            R(wx, wy, wx + wsz[0], wy + wsz[1], win)
        out.append((x, x + bw, top2))
        g = rnd.randint(*gap)
        x += bw + (0 if 0 < g < 3 else g)                               # 一两格的缝会变成一道竖线，不要
    return out


def tv_antenna(x, base, h, c, kind=0, lean=0, wire=None):
    """老电视天线。kind 0：鱼骨（顶上一根横梁，一排振子从前往后变短）；kind 1：三层横杆，杆头往下垂一点。"""
    top = base - h
    seg(x, base, x + lean, top, c)
    tx = x + lean
    if kind == 0:
        L = max(10, h // 2)
        HL(tx - L // 3, tx + L - L // 3, top, c)
        for i, ex in enumerate(range(tx - L // 3, tx + L - L // 3 + 1, 3)):
            e = max(1, 5 - i // 2)
            V(ex, top - e, top + e // 2, c)
    else:
        for j, l in enumerate((max(5, h // 4), max(4, h // 5), max(3, h // 7))):
            yy = top + 2 + j * 4
            HL(tx - l + 1, tx + l - 1, yy, c)
            P(tx - l, yy + 1, c); P(tx + l, yy + 1, c)
    if wire:                                                            # 拉线
        seg(x + lean // 2, base - h // 2, x - h // 3, base, wire)


def lamp_post(x, fy, h=45, c=(30, 30, 42), head=(246, 232, 190), arm=1, pool=None, plat_top=False, halo=True):
    """路灯：灯杆、往一侧伸出去的灯臂、灯罩、下面一盏亮灯；pool 给地上一圈光（挪几档）。"""
    floor_shadow(x - 2, x + 2, fy, 2)
    if halo:                                                            # 灯后面的墙被照亮一圈（雨里一团光）
        ax_ = x + arm * 7
        # 两档：外圈亮一档、里圈再亮一档（2026-10-17 夜：黑白屏里一档太弱，看不出灯后那团光）
        tone(ellipse_mask(ax_, fy - h + 8, 19, 15) & tv_mask_cache[0] & (k.YY < fy), 1)
        tone(ellipse_mask(ax_, fy - h + 6, 10, 8) & tv_mask_cache[0] & (k.YY < fy), 1)
    R(x - 1, fy - 3, x + 2, fy, c)
    R(x, fy - h, x + 1, fy, c)
    ax = x + arm * 7
    HL(min(x, ax), max(x, ax) + 1, fy - h, c)
    R(ax - 3, fy - h + 1, ax + 4, fy - h + 2, c)
    R(ax - 2, fy - h + 3, ax + 3, fy - h + 3, head)
    if pool:
        tone(ellipse_mask(ax, fy + 2, pool, 3) & tv_mask_cache[0], 1)
    if plat_top:
        plat(ax - 3, ax + 4, fy - h + 1)
    return ax


tv_mask_cache = [None]


def begin(tv):
    tv_mask_cache[0] = tv.screen_mask()
    return tv_mask_cache[0]


# ================================================================ 屋顶
DUSK = [(86, 82, 128), (104, 92, 140), (130, 104, 148), (162, 116, 148), (196, 132, 144), (224, 154, 142), (240, 180, 150)]


def water_tank(x, fy, leg, th, tw, wood=(124, 92, 86), sun_left=True):
    """木水塔：四条腿加斜撑，腿顶一圈走道（单向平台），木桶一条条竖板，两道铁箍，锥形顶，侧面一架梯子。"""
    legc = (82, 68, 82)
    floor_shadow(x - 2, x + tw + 2, fy, 3)
    for lx in (x + 2, x + tw // 2, x + tw - 3):
        R(lx, fy - leg, lx + 1, fy, legc if lx != x + tw // 2 else shade(legc, -1))
    for a_, b_ in [(x + 3, x + tw // 2), (x + tw // 2, x + tw - 3)]:
        seg(a_, fy - 2, b_, fy - leg + 2, shade(legc, -1))
        seg(a_, fy - leg + 2, b_, fy - 2, shade(legc, -1))
    R(x - 4, fy - leg - 1, x + tw + 4, fy - leg + 1, (110, 92, 100))           # 走道
    HL(x - 4, x + tw + 4, fy - leg - 1, (168, 132, 128))
    for px in range(x - 4, x + tw + 5, 6):                                     # 栏杆
        V(px, fy - leg - 7, fy - leg - 2, legc)
    HL(x - 4, x + tw + 4, fy - leg - 7, legc)
    plat(x - 4, x + tw + 4, fy - leg - 1)
    ty0, ty1 = fy - leg - th, fy - leg - 2
    kbox(x, ty0, x + tw, ty1, wood, depth=0.05, cap=4, side=shade(wood, 1 if not sun_left else -2))
    for sx_ in range(x + 2, x + tw, 4):
        V(sx_, ty0 + 1, ty1, shade(wood, -1))
    lit = x if sun_left else x + tw                                            # 朝太阳那条边
    V(lit, ty0, ty1, shade(wood, 2))
    for hy in (ty0 + th // 4, ty1 - th // 4):
        HL(x, x + tw, hy, (78, 64, 78))
    rc = (106, 78, 82)
    S().poly([(x - 3, ty0 + 1), (x + tw + 4, ty0 + 1), (x + tw // 2 + 1, ty0 - tw // 4 - 2)], rc)
    S().poly([(x + tw // 2 + 1, ty0 + 1), (x + tw + 4, ty0 + 1), (x + tw // 2 + 1, ty0 - tw // 4 - 2)], shade(rc, -2) if sun_left else shade(rc, 2))
    S().poly([(x - 3, ty0 + 1), (x + tw // 2 + 1, ty0 + 1), (x + tw // 2 + 1, ty0 - tw // 4 - 2)], shade(rc, 2) if sun_left else shade(rc, -1))
    for yy in range(ty0, fy - leg, 3):                                          # 梯子
        HL(x + tw + 1, x + tw + 3, yy, legc)
    V(x + tw + 1, ty0, fy - leg, legc); V(x + tw + 3, ty0, fy - leg, legc)


def clothesline(xa, xb, fy, h, items, c=(90, 76, 90)):
    """晾衣绳：两根 T 字杆，绳子垂下来，上面挂几件衣服（船员的颜色，逆光所以都暗一档）。"""
    for px in (xa, xb):
        R(px, fy - h, px + 1, fy, c)
        HL(px - 4, px + 5, fy - h, c)
    dip = 4 + (xb - xa) // 30
    sag(xa + 1, fy - h + 1, xb, fy - h + 1, dip, (170, 150, 160))
    n = len(items)
    for i, (kind, col) in enumerate(items):
        t = (i + 0.7) / (n + 0.4)
        cx = int(xa + (xb - xa) * t)
        cy = int(fy - h + 1 + dip * 4 * t * (1 - t)) + 1
        col = shade(col, -1)
        if kind == "shirt":
            R(cx - 3, cy, cx + 3, cy + 8, col); R(cx - 5, cy, cx + 5, cy + 2, col)
            V(cx + 3, cy + 1, cy + 8, shade(col, -1))
        elif kind == "pants":
            R(cx - 3, cy, cx + 3, cy + 2, col); R(cx - 3, cy, cx - 1, cy + 10, col); R(cx + 1, cy, cx + 3, cy + 10, shade(col, -1))
        elif kind == "towel":
            R(cx - 3, cy, cx + 3, cy + 11, col); HL(cx - 3, cx + 3, cy + 8, shade(col, 2))
        else:                                                                  # 袜子
            R(cx - 1, cy, cx, cy + 5, col); P(cx + 1, cy + 5, col)
            R(cx + 3, cy, cx + 4, cy + 4, shade(col, -1))
        P(cx - 2, cy - 1, (220, 210, 200)); P(cx + 2, cy - 1, (220, 210, 200))


def pigeon_coop(x, fy, w, leg=10, h=18, wood=(130, 104, 100)):
    floor_shadow(x, x + w, fy, 2)
    for lx in (x + 1, x + w - 2):
        R(lx, fy - leg, lx + 1, fy, (84, 70, 82))
    kbox(x, fy - leg - h, x + w, fy - leg, wood, depth=0.05, cap=3)
    R(x + 3, fy - leg - h + 3, x + w - 12, fy - leg - 3, shade(wood, -3))       # 铁丝网的笼面
    for gx in range(x + 3, x + w - 11, 3):
        V(gx, fy - leg - h + 3, fy - leg - 3, shade(wood, -1))
    for gy in range(fy - leg - h + 3, fy - leg - 2, 3):
        HL(x + 3, x + w - 12, gy, shade(wood, -1))
    R(x + w - 9, fy - leg - h + 5, x + w - 4, fy - leg - 3, shade(wood, -2))    # 小门
    P(x + w - 5, fy - leg - h // 2, (200, 170, 140))
    top = fy - leg - h
    R(x - 3, top - 2, x + w + 3, top - 1, (102, 82, 90))                        # 屋檐
    HL(x - 3, x + w + 3, top - 2, (176, 140, 134))
    plat(x - 3, x + w + 3, top - 2)
    return top - 2


def pigeon(x, y, c=(150, 146, 160), flip=False):
    d = -1 if flip else 1
    R(min(x, x + 2 * d), y, max(x, x + 2 * d), y + 1, c)
    P(x + 3 * d, y - 1, shade(c, -1))
    P(x + 1 * d, y - 1, shade(c, 2))


def flying_bird(x, y, c):
    P(x - 2, y - 1, c); P(x - 1, y, c); P(x, y + 1, c); P(x + 1, y, c); P(x + 2, y - 1, c)


def stair_hut(x, fy, w, h, wall=(140, 112, 120), sun_left=True):
    """屋顶的楼梯间：一扇门（48 高）开着一条缝透出暖光，门上一盏小灯，侧面朝太阳的那面亮。"""
    floor_shadow(x - 2, x + w, fy, 3)
    kbox(x, fy - h, x + w, fy, wall, depth=0.06, cap=6, side=shade(wall, 2) if sun_left else shade(wall, -2))
    R(x - 2, fy - h - 2, x + w + 2, fy - h, shade(wall, -1))                     # 女儿墙压顶
    HL(x - 2, x + w + 2, fy - h - 2, (196, 150, 140))
    V(x, fy - h, fy, shade(wall, 1))
    dx = x + 8
    R(dx - 2, fy - 50, dx + 19, fy, shade(wall, -2))                            # 门框
    R(dx, fy - 48, dx + 17, fy, (92, 80, 96))
    R(dx + 13, fy - 47, dx + 16, fy - 1, (236, 196, 138))                       # 门缝里的暖光
    R(dx + 1, fy - 47, dx + 12, fy - 1, (100, 86, 102))
    for py in (fy - 40, fy - 24):
        R(dx + 3, py, dx + 10, py + 10, shade((100, 86, 102), -1))
    R(dx + 6, fy - 55, dx + 11, fy - 53, (70, 60, 74))                          # 门灯
    R(dx + 7, fy - 52, dx + 10, fy - 52, (252, 226, 170))
    tone(ellipse_mask(dx + 8, fy - 46, 14, 9) & tv_mask_cache[0] & (k.YY > fy - 52) & (k.XX > x) & (k.XX < x + w), 1)
    if w > 40:                                                                  # 小窗
        wx = x + w - 16
        R(wx, fy - 44, wx + 8, fy - 34, shade(wall, -3))
        R(wx + 1, fy - 43, wx + 7, fy - 39, (176, 140, 150))
    return fy - h - 2


def ac_unit(x, fy, w=36, h=20, c=(124, 116, 134)):
    floor_shadow(x, x + w, fy, 3)
    kbox(x, fy - h, x + w, fy, c, depth=0.05, cap=4)
    cx, cy = x + w - 11, fy - h // 2
    disc(cx, cy, 7, shade(c, -3))
    disc(cx, cy, 2, shade(c, -1))
    HL(cx - 6, cx + 6, cy, shade(c, -2)); V(cx, cy - 6, cy + 6, shade(c, -2))
    for gy in range(fy - h + 4, fy - 3, 3):
        HL(x + 3, x + w - 21, gy, shade(c, -1))
    HL(x, x + w, fy - h, shade(c, 2))
    plat(x, x + w, fy - h)


def vent_pipe(x, fy, h, c=(132, 124, 140)):
    floor_shadow(x - 2, x + 5, fy, 2)
    R(x, fy - h, x + 3, fy, c); V(x + 3, fy - h, fy, shade(c, -2)); V(x, fy - h, fy, shade(c, 1))
    R(x - 3, fy - h - 4, x + 6, fy - h - 2, shade(c, -1)); HL(x - 3, x + 6, fy - h - 4, shade(c, 2))
    R(x - 1, fy - h - 1, x + 4, fy - h, shade(c, -3))


def skylight(x, fy, w, c=(120, 104, 120), glass=(164, 132, 156)):
    kbox(x, fy - 8, x + w, fy, c, depth=0.04, cap=3)
    S().poly([(x + 1, fy - 8), (x + w, fy - 8), (x + w - 5, fy - 18), (x + 6, fy - 18)], glass)
    S().poly([(x + w // 2, fy - 8), (x + w, fy - 8), (x + w - 5, fy - 18), (x + w // 2, fy - 18)], shade(glass, -1))
    for gx in range(x + 8, x + w - 4, 7):
        V(gx, fy - 17, fy - 9, c)
    HL(x + 6, x + w - 5, fy - 18, (200, 160, 150))
    plat(x + 4, x + w - 3, fy - 18)


def neighbor(x0_, x1_, fy, top, rnd, wall=(116, 86, 98), sun_right=True, side_w=8):
    """隔壁的高楼：砖墙正面在逆光里偏暗偏冷，朝太阳那条边和楼顶一道亮边，窗户一户一户亮。"""
    R(x0_, top, x1_, fy, wall)
    if sun_right:
        R(x1_ + 1, top + 2, x1_ + side_w, fy, shade(wall, 2))
        V(x1_ + side_w, top + 2, fy, shade(wall, 3))
    for by in range(top + 6, fy, 5):
        HL(x0_, x1_, by, shade(wall, -1))
    R(x0_, top - 3, x1_ + side_w + 1, top, shade(wall, -2))                    # 檐口
    HL(x0_, x1_ + side_w + 1, top - 3, (190, 146, 140))
    cols = list(range(x0_ + 5, x1_ - 8, 14))
    for fyy in range(top + 10, fy - 30, 24):
        lit_run = rnd.random() < 0.4
        for wx in cols:
            R(wx, fyy - 1, wx + 9, fyy + 13, shade(wall, -2))
            if lit_run and rnd.random() < 0.85:
                R(wx + 1, fyy, wx + 8, fyy + 12, (232, 186, 136))
                R(wx + 5, fyy, wx + 8, fyy + 12, (210, 156, 120))              # 窗帘
            else:
                R(wx + 1, fyy, wx + 8, fyy + 12, (110, 96, 128))
                P(wx + 2, fyy + 1, (150, 128, 156))
            HL(wx - 1, wx + 10, fyy + 13, shade(wall, 2))                     # 窗台


def billboard(x, base, w, leg, bh, face=(132, 102, 128), frame=(88, 72, 92)):
    """隔壁楼顶上的广告牌（中景偏远）：钢架腿、检修走道、三盏灯臂；牌面逆光偏暗，画着一台褪了色的老电视。"""
    top = base - leg - bh
    for lx in range(x + 4, x + w - 2, max(12, w // 4)):
        V(lx, base - leg, base, frame)
        seg(lx, base - 2, lx + max(12, w // 4) // 2, base - leg + 2, frame)
    R(x - 2, base - leg, x + w + 2, base - leg + 1, frame)                      # 走道
    for px in range(x - 2, x + w + 3, 5):
        V(px, base - leg - 4, base - leg, frame)
    R(x, top, x + w, base - leg - 1, face)
    R(x, top, x + w, top + 1, shade(face, 2))
    V(x, top, base - leg - 1, shade(face, 2))
    tx, ty, tw_, th_ = x + 6, top + 5, bh + 2, bh - 10                         # 画上的老电视
    R(tx, ty, tx + tw_, ty + th_, (170, 138, 140))
    R(tx + 3, ty + 3, tx + tw_ - 8, ty + th_ - 3, (110, 120, 150))
    R(tx + 4, ty + 4, tx + tw_ / 2, ty + 6, (140, 152, 176))
    for i in range(2):
        P(tx + tw_ - 4, ty + 5 + i * 5, (110, 90, 100))
    seg(tx + tw_ // 2 - 4, ty, tx + tw_ // 2 - 9, ty - 4, (110, 90, 100)); seg(tx + tw_ // 2, ty, tx + tw_ // 2 + 5, ty - 4, (110, 90, 100))
    for j in range(3):                                                          # 字（几道色条）
        HL(tx + tw_ + 6, x + w - 6 - j * 7, ty + 3 + j * 6, (196, 160, 150))
        HL(tx + tw_ + 6, x + w - 6 - j * 7, ty + 4 + j * 6, (196, 160, 150))
    for lx in (x + w // 6, x + w // 2, x + 5 * w // 6):                         # 灯臂
        seg(lx, base - leg - 2, lx - 2, base - leg - 6, frame)
        R(lx - 4, base - leg - 7, lx - 1, base - leg - 6, frame)


def sc_rooftop(tv):
    """黄昏屋顶。远景三层城市剪影（越远越淡、越贴天色），太阳压在剪影上；
    中景：左边一栋高高的隔壁楼，屋顶上空调外机、水塔、天窗、晾衣绳、鸽子笼、楼梯间（顶上一组天线）；
    近景：屋顶边的矮墙、通风管。逆光：正面都偏暗偏冷，朝太阳的边和顶上一道暖亮边。"""
    begin(tv)
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wh = x1 - x0, fy - y0
    sz = size_of(tv)
    rnd = random.Random(31 + sz)
    pw = fy - 12                                                               # 矮墙顶
    bands_v(tv, y0, pw, DUSK, jag=1)
    sun = (x0 + int(rw * (0.36 if sz else 0.62)), pw - int(wh * (0.46 if sz else 0.5)))
    tone(ellipse_mask(*sun, wh * 0.16 * 1.35, wh * 0.13 * 1.35) & (k.YY < pw), 1)   # 太阳光晕分两档，外圈淡，不再是一圈硬边
    tone(ellipse_mask(*sun, wh * 0.16 * 0.8, wh * 0.13 * 0.8) & (k.YY < pw), 1)
    disc(*sun, max(5, wh // 16), (252, 228, 180))
    skyline_sun = sun
    # 远景：三层剪影
    skyline(tv, rnd, pw, wh * 0.30, wh * 0.62, None, wr=(9, 22), gap=(0, 2), tops=0.5, masts=0.08, dk=-1)
    skyline(tv, rnd, pw, wh * 0.16, wh * 0.40, None, wr=(10, 26), gap=(0, 4), win=(222, 170, 140),
            win_n=1.2, wpitch=(3, 4), wsz=(0, 1), tops=0.5, masts=0.15, dk=-3)
    skyline(tv, rnd, pw, wh * 0.06, wh * 0.22, (116, 88, 120), wr=(14, 34), gap=(1, 6), win=(240, 196, 146),
            win_n=1.6, wpitch=(4, 5), wsz=(1, 2), rim=(170, 124, 138), sun_x=sun[0], tops=0.6, masts=0.25)
    for i in range(3 if sz else 1):                                            # 远处一群飞鸟
        flying_bird(sun[0] + 20 + i * 7 + (i % 2) * 3, sun[1] - 18 - (i % 2) * 4, (98, 84, 118))
    # 中景
    if sz == 2:
        billboard(x0 + 232, pw, 100, 34, 40)
    elif sz == 1:
        billboard(x0 + 100, pw, 74, 30, 32)
    if sz:
        nx1 = x0 + (40 if sz == 2 else 30)
        neighbor(x0 - 4, nx1, fy, fy - int(wh * (0.74 if sz == 2 else 0.68)), rnd)
    # 矮墙
    R(x0, pw, x1, fy, (118, 94, 110))
    R(x0, pw, x1, pw + 1, (146, 116, 126)); HL(x0, x1, pw, (182, 140, 138))
    HL(x0, x1, fy - 5, (108, 86, 102))
    ground(tv, [(146, 118, 124), (122, 100, 110), (108, 88, 100), (100, 82, 96)])
    for tx in range(x0 + 13, x1, 37 + (x0 % 7)):                               # 屋面上几块补过的沥青
        HL(tx, tx + 9 + tx % 5, fy + 3 + tx % 4, (110, 90, 104))
    sun_left = True
    if sz == 2:
        ac_unit(x0 + 56, fy, 38, 20)
        vent_pipe(x0 + 102, fy, 26)
        water_tank(x0 + 126, fy, 38, 42, 52, sun_left=sun_left)
        tv_antenna(x0 + 193, pw, 34, (76, 64, 82), kind=1, lean=-1)            # 一对天线，挨在一起
        tv_antenna(x0 + 203, pw, 52, (76, 64, 82), kind=0, wire=(118, 98, 116))
        clothesline(x0 + 214, x0 + 300, fy, 40, [("shirt", CREW[0]), ("pants", CREW[1]), ("towel", CREW[2]), ("sock", CREW[3])])
        skylight(x0 + 230, fy, 34)
        top = pigeon_coop(x0 + 314, fy, 40, leg=12, h=18)
        for px in (x0 + 318, x0 + 324, x0 + 341):
            pigeon(px, top - 2, flip=px > x0 + 330)
        for i, (bx, by) in enumerate([(x0 + 360, top - 26), (x0 + 372, top - 34)]):
            flying_bird(bx, by, (128, 116, 140))
        hx = x1 - 62
        roof = stair_hut(hx, fy, 58, 62, sun_left=sun_left)
        for ax, ah, kd in [(hx + 12, 30, 1), (hx + 20, 46, 0), (hx + 31, 22, 1)]:    # 楼梯间顶上一组三根
            tv_antenna(ax, roof, ah, (76, 64, 82), kind=kd, lean=1 if ah == 22 else 0, wire=(118, 98, 116) if ah == 46 else None)
        vent_pipe(hx + 48, roof, 8)
    elif sz == 1:
        water_tank(x0 + 48, fy, 38, 36, 42, sun_left=sun_left)
        clothesline(x0 + 112, x0 + 184, fy, 40, [("shirt", CREW[0]), ("towel", CREW[2]), ("pants", CREW[1])])
        skylight(x0 + 128, fy, 30)
        hx = x1 - 56
        roof = stair_hut(hx, fy, 52, 58, sun_left=sun_left)
        for ax, ah, kd in [(hx + 14, 28, 1), (hx + 22, 42, 0)]:
            tv_antenna(ax, roof, ah, (76, 64, 82), kind=kd, wire=(118, 98, 116) if ah == 42 else None)
    else:
        water_tank(x0 + 12, fy, 24, 26, 30, sun_left=sun_left)
        tv_antenna(x1 - 34, pw, 30, (76, 64, 82), kind=1)
        tv_antenna(x1 - 25, pw, 44, (76, 64, 82), kind=0, wire=(118, 98, 116))
        clothesline(x0 + 56, x1 - 44, fy, 32, [("shirt", CREW[0]), ("towel", CREW[2])])
    k.finish_room(tv, sun)



# ================================================================ 雨夜街道
NIGHT = [(12, 14, 22), (14, 16, 26), (18, 20, 30), (22, 24, 36), (28, 30, 44), (36, 38, 52)]
WARM_WIN = (230, 210, 150)


def rain(tv, rnd, n, c, y_to=None, length=3):
    """斜着的雨：直接点像素，不画整张画布的线。"""
    y_to = y_to or tv.fy + 4
    for _ in range(n):
        x, y = rnd.randint(tv.sx0, tv.sx1), rnd.randint(tv.sy0, y_to)
        for i in range(length):
            P(x - i // 2, y + i, c)


def street_building(x, w, fy, h, wall, rnd, shop="store", pitch=(16, 24), lit=0.35, roof=None, gf=58):
    """临街的楼：底层一间铺面（橱窗 + 门 + 雨棚，或者卷帘门、单元门），楼上窗户一户一户地亮。"""
    top = fy - h
    R(x, top, x + w, fy, wall)
    R(x, top - 3, x + w, top - 1, shade(wall, 1)); HL(x, x + w, top - 3, shade(wall, 2))       # 檐口
    V(x, top, fy, shade(wall, -1))
    HL(x, x + w, fy - gf, shade(wall, -2)); HL(x, x + w, fy - gf - 1, shade(wall, 1))          # 底层和楼上的分界线
    px, py = pitch
    ncol = max(1, (w - 8) // px)
    off = x + (w - (ncol - 1) * px - 8) // 2
    for wy in range(fy - gf - 8 - 14, top + 4, -py):
        apt = [rnd.random() < lit for _ in range((ncol + 1) // 2)]
        for ci in range(ncol):
            wx = off + ci * px
            R(wx - 1, wy - 1, wx + 8, wy + 13, shade(wall, -2))
            if apt[ci // 2]:
                R(wx, wy, wx + 7, wy + 12, WARM_WIN)
                R(wx + 4 + (ci % 2), wy, wx + 7, wy + 12, shade(WARM_WIN, -2))            # 窗帘
                if rnd.random() < 0.3:
                    R(wx + 1, wy + 6, wx + 3, wy + 12, shade(WARM_WIN, -4))              # 窗里的人影
            else:
                R(wx, wy, wx + 7, wy + 12, (40, 42, 56))
                P(wx + 1, wy + 1, (70, 72, 90))
            HL(wx - 1, wx + 8, wy + 13, shade(wall, 1))
    if roof == "tank":
        tx = x + w - 22
        for lx in (tx + 2, tx + 12):
            V(lx, top - 12, top - 4, shade(wall, -2))
        R(tx, top - 26, tx + 14, top - 12, shade(wall, -1)); HL(tx, tx + 14, top - 26, shade(wall, 1))
        S().poly([(tx - 1, top - 26), (tx + 15, top - 26), (tx + 7, top - 31)], shade(wall, -2))
    elif roof == "ant":
        for j, (ah, kd) in enumerate([(22, 0), (14, 1)]):
            tv_antenna(x + 8 + j * 8, top - 3, ah, (34, 36, 48), kind=kd)
    g = fy - gf
    if shop == "store":
        ax0, ax1 = x + 4, x + w - 4
        for i, sx_ in enumerate(range(ax0, ax1, 4)):                        # 雨棚：一道道深浅相间的条纹，往前斜
            c = (96, 92, 104) if i % 2 else (132, 128, 136)
            S().poly([(sx_, g + 2), (min(ax1, sx_ + 4), g + 2), (min(ax1, sx_ + 4) + 1, g + 9), (sx_ + 1, g + 9)], c)
        HL(ax0 + 1, ax1 + 1, g + 9, (70, 68, 82))
        dw = 18
        dx = x + w - dw - 8
        R(x + 6, fy - 42, dx - 6, fy - 16, shade(wall, -2))
        R(x + 7, fy - 41, dx - 7, fy - 17, (196, 186, 150))                # 亮着的橱窗
        R(x + 7, fy - 41, dx - 7, fy - 39, (226, 214, 170))
        for i, ix in enumerate(range(x + 10, dx - 10, 7)):                 # 橱窗里的旧电视、收音机
            hh = 6 + (i * 5) % 7
            R(ix, fy - 17 - hh, ix + 5, fy - 17, (120, 112, 104))
            R(ix + 1, fy - 16 - hh, ix + 3, fy - 19 - hh // 2, (160, 170, 176))
        R(x + 4, fy - 15, dx - 4, fy, shade(wall, -1))                      # 橱窗下的矮墙
        R(dx - 1, fy - 49, dx + dw + 1, fy, shade(wall, -3))
        R(dx, fy - 48, dx + dw, fy, (150, 140, 120))                       # 门开着，里面暖光
        R(dx + 2, fy - 46, dx + dw - 2, fy - 26, (186, 174, 140))
        return (x + 7, dx - 7)
    if shop == "shutter":
        R(x + 6, fy - 46, x + w - 6, fy, (58, 60, 74))
        for yy in range(fy - 44, fy, 3):
            HL(x + 6, x + w - 6, yy, (72, 74, 88))
        R(x + 4, fy - 49, x + w - 4, fy - 46, shade(wall, -2))
    elif shop == "door":
        dx = x + w // 2 - 9
        R(dx - 3, fy - 52, dx + 20, fy, shade(wall, 1))
        R(dx, fy - 48, dx + 17, fy, (52, 50, 64))
        R(dx + 2, fy - 46, dx + 8, fy - 30, (150, 146, 128)); R(dx + 10, fy - 46, dx + 15, fy - 30, (150, 146, 128))
        R(dx + 6, fy - 58, dx + 11, fy - 56, (60, 60, 72)); R(dx + 7, fy - 55, dx + 10, fy - 55, (246, 236, 196))
        for i in range(2):
            R(dx - 4 - i * 2, fy - 3 + i * 2 - 2, dx + 21 + i * 2, fy - 2 + i * 2 - 2, shade(wall, 1 - i))
    return None


def blade_sign(x, y, h, c=(70, 70, 86), lit=(220, 216, 196)):
    """竖着挑出来的店招：一个个方块字亮着（黑白屏里最亮的地方之一）。"""
    HL(x - 6, x, y + 3, c); HL(x - 6, x, y + h - 3, c)
    R(x, y, x + 9, y + h, c)
    R(x + 1, y + 1, x + 8, y + h - 1, shade(c, -2))
    for i, yy in enumerate(range(y + 3, y + h - 6, 8)):
        R(x + 2, yy, x + 7, yy + 5, lit)
        R(x + 4 - (i % 2), yy + 1, x + 5 - (i % 2), yy + 4, shade(c, -2))


def old_car(x, fy, w=76, body=(88, 92, 110)):
    """一辆老式轿车：圆鼓鼓的车身、车顶（单向平台）、车窗反着路灯的光、两个车轮。"""
    floor_shadow(x, x + w, fy, 3)
    h = 30
    S().poly([(x, fy - 6), (x + 4, fy - 16), (x + w - 4, fy - 17), (x + w, fy - 8), (x + w, fy - 4), (x, fy - 4)], body)
    rx0, rx1 = x + w // 4 - 2, x + 3 * w // 4 + 2
    S().poly([(rx0 - 6, fy - 16), (rx0, fy - h), (rx1, fy - h), (rx1 + 7, fy - 17)], shade(body, -1))
    S().poly([(rx0 - 3, fy - 17), (rx0 + 2, fy - h + 3), (x + w // 2 - 1, fy - h + 3), (x + w // 2 - 1, fy - 17)], (60, 64, 80))
    S().poly([(x + w // 2 + 2, fy - 17), (x + w // 2 + 2, fy - h + 3), (rx1 - 2, fy - h + 3), (rx1 + 4, fy - 17)], (60, 64, 80))
    seg(rx0 + 2, fy - h + 4, rx0 + 6, fy - h + 8, (130, 136, 150))
    HL(rx0, rx1, fy - h, shade(body, 2))
    HL(x + 4, x + w - 4, fy - 16, shade(body, 2))
    HL(x + 2, x + w - 2, fy - 10, shade(body, -2))
    R(x + w - 3, fy - 13, x + w, fy - 11, (226, 216, 170))                 # 车灯
    R(x, fy - 12, x + 2, fy - 11, (170, 70, 70))
    for wx in (x + 14, x + w - 16):
        disc(wx, fy - 4, 5, (36, 36, 46)); disc(wx, fy - 4, 2, (96, 96, 110))
    plat(rx0, rx1, fy - h)


def bus_shelter(x, fy, w=56, h=42, c=(60, 62, 76)):
    """公交站棚：两根柱子、平顶（单向平台）、一侧亮着的广告灯箱、一条长椅。"""
    floor_shadow(x, x + w, fy, 2)
    for px in (x + 2, x + w - 3):
        R(px, fy - h, px + 1, fy, c)
    R(x - 2, fy - h - 3, x + w + 2, fy - h, c); HL(x - 2, x + w + 2, fy - h - 3, shade(c, 3))
    R(x + 4, fy - h + 1, x + w - 5, fy - h + 2, (90, 92, 108))
    R(x + w - 18, fy - 38, x + w - 5, fy - 15, shade(c, -1))                # 灯箱
    R(x + w - 17, fy - 37, x + w - 6, fy - 16, (200, 200, 196))
    R(x + w - 15, fy - 33, x + w - 8, fy - 24, (150, 150, 156))
    R(x + 8, fy - 10, x + w - 22, fy - 9, (96, 92, 100)); V(x + 10, fy - 8, fy, c); V(x + w - 24, fy - 8, fy, c)
    plat(x - 2, x + w + 2, fy - h - 3)


def phone_booth(x, fy, c=(78, 80, 98)):
    """电话亭：里面亮着灯，下半截是实心板（地面那一条不能太亮）。"""
    floor_shadow(x, x + 18, fy, 3)
    kbox(x, fy - 54, x + 18, fy, c, depth=0.05, cap=4)
    R(x + 2, fy - 48, x + 16, fy - 16, (196, 196, 184))
    R(x + 9, fy - 48, x + 9, fy - 16, c)
    R(x + 11, fy - 40, x + 14, fy - 32, (110, 110, 118))                    # 话机
    R(x + 2, fy - 58, x + 16, fy - 55, shade(c, 2)); R(x + 4, fy - 57, x + 14, fy - 56, (226, 226, 220))


def sc_rain_street(tv):
    """雨夜街道（黑白屏）。远景：一排高楼的淡剪影，零星几户亮灯；中景：临街一排高矮宽窄不一的楼，
    底层是铺面（亮着的旧电器店橱窗、卷帘门、单元门），楼上一户一户亮灯；
    近景：老轿车、公交站棚、成组的路灯（两盏挨着，再隔很远一盏）、电话亭、水果箱；地上积水映着灯，斜雨。"""
    begin(tv)
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wh = x1 - x0, fy - y0
    sz = size_of(tv)
    rnd = random.Random(53 + sz)
    bands_v(tv, y0, fy, NIGHT, jag=1)
    skyline(tv, rnd, fy, wh * 0.50, wh * 0.88, (58, 60, 78), wr=(14, 34), gap=(0, 5), win=(130, 126, 116), win_n=0.6,
            wpitch=(4, 6), wsz=(1, 2), tops=0.6, masts=0.3)
    # 中景：临街的楼
    walls = [(92, 94, 112), (86, 88, 106), (100, 98, 116), (90, 92, 108)]
    if sz == 2:
        plan = [(-6, 70, 0.62, "door", "tank"), (66, 92, 0.80, "store", None), (176, 50, 0.50, "shutter", "ant"),
                (234, 84, 0.72, "store", None), (322, 58, 0.58, "door", None), (382, 70, 0.86, "shutter", "tank")]
    elif sz == 1:
        plan = [(-6, 64, 0.70, "door", "tank"), (60, 92, 0.86, "store", None), (164, 52, 0.56, "shutter", "ant"),
                (218, 60, 0.74, "door", None)]
    else:
        plan = [(-6, 60, 0.82, "store", None), (56, 82, 0.62, "door", "ant")]
    shopwins = []
    for i, (bx, bw, bh, shop, roof) in enumerate(plan):
        r = street_building(x0 + bx, bw - (4 if i % 2 else 0), fy, int(wh * bh), walls[i % 4], rnd, shop=shop,
                            pitch=(15 + i % 3, 22 + i % 2 * 3), lit=0.3 + 0.1 * (i % 2), roof=roof)
        if r:
            shopwins.append(r)
    if sz:
        blade_sign(x0 + plan[1][0] + 6, fy - int(wh * 0.42), 34)
    # 地面：人行道，往下是湿漉漉的马路
    ground(tv, [(112, 114, 130), (78, 80, 96), (56, 58, 74), (48, 50, 66)])
    for a, b in shopwins:                                                   # 橱窗的光落在人行道上
        tone((k.XX >= a - 4) & (k.XX <= b + 4) & (k.YY >= fy) & (k.YY <= fy + 4) & tv_mask_cache[0], 1)
    # 近景
    lamps = []
    if sz == 2:
        R(x0 + 20, fy - 14, x0 + 34, fy, (64, 70, 74)); R(x0 + 36, fy - 12, x0 + 48, fy, (58, 62, 70))    # 垃圾桶
        HL(x0 + 20, x0 + 34, fy - 14, (100, 106, 112)); HL(x0 + 36, x0 + 48, fy - 12, (96, 100, 108))
        old_car(x0 + 70, fy, 78)
        lamps = [lamp_post(x0 + 160, fy, 45, arm=-1, pool=20), lamp_post(x0 + 172, fy, 45, arm=1, pool=20)]
        bus_shelter(x0 + 188, fy, 56, 42)
        R(x0 + 252, fy - 9, x0 + 256, fy, (90, 86, 98)); R(x0 + 251, fy - 6, x0 + 257, fy - 5, (90, 86, 98))   # 消火栓
        for i, (cx_, cy_) in enumerate([(x0 + 266, fy), (x0 + 282, fy), (x0 + 272, fy - 10)]):              # 水果箱
            kbox(cx_, cy_ - 10, cx_ + 14, cy_, (110, 96, 92), depth=0.04, cap=2)
            HL(cx_ + 1, cx_ + 13, cy_ - 10, (180, 170, 150) if i % 2 else (150, 146, 136))
        plat(x0 + 264, x0 + 298, fy - 20)
        kbox(x0 + 316, fy - 24, x0 + 338, fy, (76, 80, 92), depth=0.04, cap=3)   # 电箱
        R(x0 + 320, fy - 20, x0 + 334, fy - 14, (64, 68, 80)); P(x0 + 331, fy - 18, (200, 120, 100))
        plat(x0 + 316, x0 + 339, fy - 24)
        lamps.append(lamp_post(x0 + 352, fy, 45, arm=1, pool=18))
        phone_booth(x0 + 376, fy)
        R(x0 + 414, fy - 18, x0 + 422, fy, (70, 70, 86)); R(x0 + 413, fy - 20, x0 + 423, fy - 18, (96, 96, 110))  # 邮筒
    elif sz == 1:
        old_car(x0 + 22, fy, 76)
        lamps = [lamp_post(x0 + 112, fy, 45, arm=-1, pool=18), lamp_post(x0 + 124, fy, 45, arm=1, pool=18)]
        bus_shelter(x0 + 140, fy, 52, 42)
        phone_booth(x0 + 228, fy)
    else:
        lamps = [lamp_post(x0 + 92, fy, 45, arm=-1, pool=16)]
        R(x0 + 104, fy - 18, x0 + 112, fy, (70, 70, 86)); R(x0 + 103, fy - 20, x0 + 113, fy - 18, (96, 96, 110))
    # 积水：灯在地上的倒影
    for lx in lamps:
        for i, yy in enumerate(range(fy + 2, tv.sy1, 2)):
            HL(lx - 2 + i % 2, lx + 2 - i % 2, yy, (196, 194, 180))
    for px in range(x0 + 9, x1, 31 + sz * 6):
        HL(px, px + 7 + px % 5, fy + 5 + px % 3, (96, 98, 116))
    rain(tv, rnd, rw * wh // 520, (84, 88, 108))
    rain(tv, rnd, rw * wh // 1800, (130, 134, 154), length=4)
    k.finish_room(tv, (lamps[0] if lamps else x0 + rw // 2, fy - 44))


# ================================================================ 夜港
HARBOR_SKY = [(24, 30, 60), (28, 36, 70), (34, 42, 80), (42, 50, 90), (52, 60, 100), (64, 72, 112)]


def stars(tv, rnd, n, y1, c=(214, 218, 240)):
    for _ in range(n):
        x, y = rnd.randint(tv.sx0, tv.sx1), rnd.randint(tv.sy0, y1)
        P(x, y, c)
        if rnd.random() < 0.08:
            P(x - 1, y, shade(c, -3)); P(x + 1, y, shade(c, -3)); P(x, y - 1, shade(c, -3)); P(x, y + 1, shade(c, -3))


def moon(x, y, r, sky_mask, c=(232, 230, 210)):
    tone(ellipse_mask(x, y, r * 2.3, r * 2.2) & sky_mask, 1)
    disc(x, y, r, c)
    disc(x + r // 3, y - r // 4, max(1, r // 3), shade(c, -1))
    disc(x - r // 3, y + r // 3, max(1, r // 4), shade(c, -1))


def fishing_boat(x, wl, w, hull=(78, 104, 120), cabin=(196, 190, 176)):
    """渔船：船身（水线 wl 以上），驾驶室亮着窗，桅杆上一盏灯，船尾吊杆斜着，船舷挂一排轮胎。"""
    hh = 14
    S().poly([(x, wl - hh), (x + w, wl - hh - 4), (x + w - 6, wl), (x + 6, wl)], hull)
    HL(x + 1, x + w - 1, wl - hh, shade(hull, 2))
    R(x + 4, wl - 6, x + w - 8, wl - 5, shade(hull, -2))
    HL(x + 3, x + w - 5, wl - hh + 3, CREW[0])                            # 船舷一道红漆
    for tx in range(x + 10, x + w - 12, 11):
        disc(tx, wl - hh + 7, 2, (44, 46, 58))
    cx = x + w // 2 - 4
    kbox(cx, wl - hh - 18, cx + 22, wl - hh, cabin, depth=0.04, cap=3)
    R(cx + 3, wl - hh - 14, cx + 9, wl - hh - 9, (236, 210, 150)); R(cx + 12, wl - hh - 14, cx + 18, wl - hh - 9, (236, 210, 150))
    R(cx - 2, wl - hh - 21, cx + 24, wl - hh - 19, shade(cabin, -3))
    mx = cx + 8
    V(mx, wl - hh - 52, wl - hh - 21, (150, 146, 140))
    HL(mx - 7, mx + 7, wl - hh - 42, (150, 146, 140))
    R(mx - 1, wl - hh - 54, mx + 1, wl - hh - 52, (252, 236, 180))
    seg(mx, wl - hh - 50, x + 4, wl - hh, (110, 108, 116))
    seg(mx, wl - hh - 50, x + w - 2, wl - hh - 4, (110, 108, 116))
    seg(x + w - 14, wl - hh - 2, x + w + 6, wl - hh - 30, (130, 120, 116))   # 吊杆
    for i, yy in enumerate(range(wl + 1, wl + 12, 2)):                    # 倒影
        HL(x + 8 + i * 2, x + w - 10 - i * 2, yy, (46, 64, 96))
    R(mx - 1, wl + 2, mx + 1, wl + 3, (150, 140, 120)); R(mx, wl + 6, mx + 1, wl + 6, (150, 140, 120))


def container(x, fy, w, h, c, dark=False):
    """集装箱：正面一道道竖棱，门把手，顶上亮边。"""
    floor_shadow(x, x + w, fy, 2)
    kbox(x, fy - h, x + w, fy, c, depth=0.04, cap=4)
    for cx_ in range(x + 3, x + w - 1, 3):
        V(cx_, fy - h + 2, fy - 2, shade(c, -1))
    R(x, fy - h, x + w, fy - h + 1, shade(c, 1)); HL(x, x + w, fy - h, shade(c, 2))
    R(x, fy - 2, x + w, fy, shade(c, -2))
    for cx_ in (x + w - 10, x + w - 6):
        V(cx_, fy - h + 4, fy - 4, shade(c, -3))


def portal_crane(x, fy, pw=58, jib_len=170, ang=58, c=(92, 66, 76), lit=(146, 108, 108)):
    """老式门座起重机：两条粗腿跨着地面（主角能从底下走过），门座顶是一层平台（单向平台，地面以上 45），
    上面一间机房亮着窗，一根桁架长臂斜着伸到水面上，臂头垂下钢缆和吊钩。左边朝月亮的边压一道亮边。"""
    import math
    deck = fy - 40
    for lx in (x, x + pw - 6):
        R(lx, deck, lx + 5, fy, c); V(lx + (0 if lx == x else 5), deck, fy, lit)
        R(lx - 2, fy - 3, lx + 7, fy, shade(c, -1))
    seg(x + 6, deck + 12, x + 16, deck + 1, c); seg(x + 6, deck + 13, x + 17, deck + 1, c)        # 腿和门梁之间的斜撑
    seg(x + pw - 7, deck + 12, x + pw - 17, deck + 1, c); seg(x + pw - 7, deck + 13, x + pw - 18, deck + 1, c)
    R(x - 3, deck - 5, x + pw + 3, deck, c); HL(x - 3, x + pw + 3, deck - 5, lit)
    for px in range(x - 3, x + pw + 4, 6):                                   # 门座顶的栏杆
        V(px, deck - 10, deck - 6, shade(c, -1))
    HL(x - 3, x + pw + 3, deck - 10, shade(c, -1))
    plat(x - 3, x + pw + 3, deck - 5)
    hx0, hx1, ht = x + 10, x + pw - 4, deck - 5 - 28
    px_, py_ = hx0 + 2, deck - 14                                              # 臂根
    a = math.radians(ang)
    tip = (px_ - jib_len * math.cos(a), py_ - jib_len * math.sin(a))
    n = 14
    for i in range(n + 1):                                                     # 桁架：上下两根弦杆，中间之字形腹杆
        t0 = i / n
        w0 = 8 * (1 - t0) + 3
        ux, uy = px_ + (tip[0] - px_) * t0, py_ + (tip[1] - py_) * t0
        nx, ny = math.sin(a), -math.cos(a)
        if i < n:
            t1 = (i + 1) / n
            w1 = 8 * (1 - t1) + 3
            vx, vy = px_ + (tip[0] - px_) * t1, py_ + (tip[1] - py_) * t1
            for d_ in (0, 1):
                seg(ux - nx * (w0 - d_), uy - ny * (w0 - d_), vx - nx * (w1 - d_), vy - ny * (w1 - d_), c)
                seg(ux + nx * (w0 - d_), uy + ny * (w0 - d_), vx + nx * (w1 - d_), vy + ny * (w1 - d_), c)
            seg(ux - nx * w0 - 1, uy - ny * w0, vx - nx * w1 - 1, vy - ny * w1, lit)
            if i % 2:
                seg(ux - nx * w0, uy - ny * w0, vx + nx * w1, vy + ny * w1, shade(c, -1))
            else:
                seg(ux + nx * w0, uy + ny * w0, vx - nx * w1, vy - ny * w1, shade(c, -1))
    # 机房最后画，盖住臂根
    kbox(hx0, ht, hx1, deck - 6, (118, 92, 96), depth=0.05, cap=4)
    R(hx0, ht - 2, hx1 + 3, ht, shade(c, -1)); HL(hx0, hx1 + 3, ht - 2, lit)
    for wx in (hx0 + 4, hx0 + 14):
        R(wx, ht + 6, wx + 6, ht + 12, (232, 208, 150))
    R(hx1 - 10, ht + 4, hx1 - 3, deck - 6, (100, 76, 84))                      # 机房的门
    R(hx1, ht + 8, hx1 + 8, deck - 8, shade(c, -1))                            # 配重
    mx_, my_ = hx0 + 14, ht - 26                                               # 机房顶上的人字架和拉索
    seg(hx0 + 8, ht - 2, mx_, my_, c); seg(hx0 + 22, ht - 2, mx_, my_, c)
    seg(mx_, my_, tip[0], tip[1], (124, 106, 116)); seg(mx_, my_, hx1 + 4, ht + 8, (124, 106, 116))
    R(mx_ - 1, my_ - 2, mx_ + 1, my_ - 1, (230, 96, 84)); R(tip[0] - 1, tip[1] - 2, tip[0] + 1, tip[1] - 1, (230, 96, 84))
    hook_y = int(tip[1] + 80)
    V(int(tip[0]), int(tip[1]) + 1, hook_y, (124, 106, 116))
    R(tip[0] - 3, hook_y, tip[0] + 3, hook_y + 4, c); P(tip[0] + 2, hook_y + 6, lit); P(tip[0] + 1, hook_y + 7, lit)
    return tip


def bollard(x, fy, c=(70, 72, 86)):
    R(x, fy - 6, x + 5, fy, c); R(x - 1, fy - 8, x + 6, fy - 6, shade(c, 1)); HL(x - 1, x + 6, fy - 8, shade(c, 3))


def cloud_streaks(rnd, x0, x1, ys, c, lit=None, lmin=30, lmax=90):
    """几条又长又薄的云：两三行错开的横条，底边压一道被月光照亮的边。"""
    for y in ys:
        cx_ = rnd.randint(x0, x1)
        L = rnd.randint(lmin, lmax)
        R(cx_ - L // 2, y, cx_ + L // 2, y + 1, c)
        R(cx_ - L // 2 + L // 5, y - 2, cx_ + L // 4, y - 1, c)
        R(cx_ - L // 3, y + 2, cx_ + L // 2 - L // 6, y + 2, lit or shade(c, 1))


def far_ship(x, wl, w, c=(50, 58, 94), light=(206, 186, 130)):
    """远处海平线上一条货轮的剪影，几点舷窗灯。"""
    S().poly([(x, wl - 5), (x + w, wl - 6), (x + w - 3, wl), (x + 3, wl)], c)
    R(x + w - 16, wl - 12, x + w - 6, wl - 6, c); R(x + w - 12, wl - 16, x + w - 10, wl - 12, c)
    for cx_ in range(x + 6, x + w - 20, 7):
        R(cx_, wl - 9, cx_ + 5, wl - 6, c)
    for lx in range(x + 5, x + w - 6, 9):
        P(lx, wl - 3, light)
    P(x + w - 11, wl - 17, (220, 90, 80))


def warehouse(x, fy, w, h, wall=(96, 76, 90), roof=(70, 60, 80), num="7"):
    """码头仓库（中景，压在画面一侧）：砖墙、斜屋顶、大号刷漆编号、一排高窗有一扇亮着、卷帘门。"""
    top = fy - h
    R(x, top, x + w, fy, wall)
    V(x, top, fy, shade(wall, 2))                                             # 朝月亮的边
    for by in range(top + 5, fy, 5):
        HL(x + 1, x + w, by, shade(wall, -1))
    S().poly([(x - 4, top + 1), (x + w + 4, top - 18), (x + w + 4, top - 14), (x - 4, top + 5)], roof)
    seg(x - 4, top + 1, x + w + 4, top - 18, shade(roof, 2))
    S().poly([(x, top + 4), (x + w, top - 13), (x + w, top), (x, top)], wall)
    for i, wx in enumerate(range(x + 6, x + w - 6, 12)):
        R(wx, top + 10, wx + 6, top + 18, (232, 206, 146) if i == 1 else (54, 56, 78))
    dg = {"7": ["####", "...#", "..#.", ".#..", ".#.."]}[num]
    for yy, row in enumerate(dg):
        for xx, v in enumerate(row):
            if v == "#":
                R(x + 8 + xx * 4, top + 26 + yy * 4, x + 11 + xx * 4, top + 29 + yy * 4, (176, 166, 160))
    R(x + 4, fy - 46, x + w - 2, fy, (70, 64, 80))
    for yy in range(fy - 44, fy, 3):
        HL(x + 4, x + w - 2, yy, (84, 76, 92))
    R(x + 2, fy - 49, x + w, fy - 47, shade(wall, -2))
    R(x + w // 2 - 2, fy - 54, x + w // 2 + 2, fy - 52, (60, 56, 70)); R(x + w // 2 - 1, fy - 51, x + w // 2 + 1, fy - 51, (252, 236, 186))


def sc_harbor(tv):
    """夜里的港口。远景：对岸一溜低矮的山和零星灯火，最右一座小灯塔扫出一道光；月亮、星星；
    中景：海面（月光一条碎影）、一条亮着驾驶室的渔船、岸边一架大吊车压满右半边天；
    近景：栈桥（地面）、木箱堆、油桶、两层集装箱、成组的系船桩和两盏码头灯。"""
    m_scr = begin(tv)
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wh = x1 - x0, fy - y0
    sz = size_of(tv)
    rnd = random.Random(71 + sz)
    hz = fy - int(wh * (0.30 if sz else 0.36))
    bands_v(tv, y0, hz, HARBOR_SKY, jag=1)
    stars(tv, rnd, rw * wh // 900, hz - 20)
    mx, my = x0 + int(rw * (0.70 if sz == 2 else 0.5 if sz else 0.2)), y0 + int(wh * 0.17)
    moon(mx, my, max(5, wh // 26), m_scr & (k.YY < hz))
    if sz:
        cloud_streaks(rnd, x0 + 20, x1 - 20, [y0 + int(wh * f) for f in ((0.12, 0.26, 0.34, 0.45) if sz == 2 else (0.15, 0.36))],
                      (40, 48, 86), lit=(62, 70, 108), lmin=40, lmax=110)
    # 远景：对岸
    rr = random.Random(5)
    pts = [(x0 - 2, hz)]
    xx = x0 - 2
    while xx < x1 + 10:
        xx += rr.randint(12, 34)
        pts.append((xx, hz - rr.randint(3, 6 + wh // 14)))
    pts.append((x1 + 10, hz))
    S().poly(pts, (44, 52, 86))
    for _ in range(rw // 18):                                               # 对岸的灯火，一簇一簇
        cx_ = rnd.randint(x0, x1)
        for j in range(rnd.randint(1, 4)):
            P(cx_ + j * 2 + rnd.randint(0, 1), hz - 1 - rnd.randint(0, 3), (200, 180, 130))
    if sz == 2:
        far_ship(x0 + int(rw * 0.52), hz + 1, 54)
    lhx = x1 - int(rw * 0.08)                                                # 对岸的小灯塔
    R(lhx - 1, hz - 16, lhx + 1, hz - 3, (110, 114, 140)); R(lhx - 2, hz - 19, lhx + 2, hz - 17, (240, 230, 180))
    tone(S().poly([(lhx - 2, hz - 18), (lhx - int(rw * 0.30), hz - 25), (lhx - int(rw * 0.30), hz - 17)]) & (k.YY < hz - 3) & m_scr, 1)
    # 海面
    bands_v(tv, hz, fy, [(40, 54, 92), (36, 50, 86), (32, 46, 80), (30, 42, 74)], jag=1)
    for y in range(hz + 2, fy, 3):
        for xx in range(x0 + (y * 7) % 19, x1, 23 + (y % 5)):
            HL(xx, xx + 3 + (y % 3), y, (58, 74, 112))
    for i, y in enumerate(range(hz + 1, fy, 3)):                            # 月光的碎影：一段段错开的短横
        hw = 2 + i // 3
        o = ((i * 5) % 7) - 3
        HL(mx + o - hw, mx + o - hw + 2 + (i % 3), y, (128, 136, 164))
        HL(mx + o + 1, mx + o + hw - (i % 2), y, (150, 156, 176) if i % 2 else (104, 114, 148))
    # 中景
    if sz == 2:
        warehouse(x0 + 408, fy, 44, int(wh * 0.52))
        fishing_boat(x0 + 14, fy - 4, 116)
    elif sz == 1:
        warehouse(x1 - 22, fy, 30, int(wh * 0.5))
        fishing_boat(x0 + 10, fy - 4, 100)
    else:
        fishing_boat(x0 + 8, fy - 3, 76)
    # 栈桥
    m = m_scr & (k.YY >= fy)
    S().fill_mask(m, (104, 82, 80))
    for xx in range(x0, x1, 7):
        V(xx + (xx // 7) % 2, fy + 2, tv.sy1, (88, 70, 72))
    R(x0, fy, x1, fy + 1, (136, 112, 104)); HL(x0, x1, fy, (170, 140, 120))
    if sz == 2:
        for dx_, c_ in [(x0 + 58, (96, 110, 124)), (x0 + 71, CREW[2])]:      # 油桶（矮，只是摆设）
            c_ = shade(c_, -2)
            floor_shadow(dx_, dx_ + 11, fy, 2)
            R(dx_, fy - 14, dx_ + 11, fy, c_); V(dx_ + 1, fy - 14, fy, shade(c_, 2)); V(dx_ + 10, fy - 14, fy, shade(c_, -2))
            HL(dx_, dx_ + 11, fy - 9, shade(c_, -2)); HL(dx_, dx_ + 11, fy - 14, shade(c_, 3))
        S().poly([(x0 + 84, fy), (x0 + 98, fy - 2), (x0 + 98, fy - 10), (x0 + 84, fy - 8)], (90, 82, 96))     # 倒着的一个
        disc(x0 + 98, fy - 6, 4, (110, 100, 112))
        for i, (cx_, cy_, cw) in enumerate([(x0 + 112, fy, 15), (x0 + 128, fy, 14), (x0 + 118, fy - 14, 15)]):  # 木箱堆
            kbox(cx_, cy_ - 14, cx_ + cw, cy_, (150, 118, 96), depth=0.05, cap=3)
            seg(cx_ + 1, cy_ - 13, cx_ + cw - 1, cy_ - 1, (120, 94, 82)); HL(cx_, cx_ + cw, cy_ - 14, (186, 150, 120))
        plat(x0 + 118, x0 + 134, fy - 28)
        portal_crane(x0 + 168, fy, pw=60, jib_len=190, ang=52)
        container(x0 + 252, fy, 62, 22, (128, 82, 76)); container(x0 + 316, fy, 62, 22, (82, 104, 108))
        container(x0 + 278, fy - 23, 64, 21, (120, 110, 90))
        plat(x0 + 252, x0 + 379, fy - 22); plat(x0 + 278, x0 + 343, fy - 44)
        for bx in (x0 + 152, x0 + 236):
            bollard(bx, fy)
        lamps = [lamp_post(x0 + 386, fy, 45, arm=-1, pool=18), lamp_post(x0 + 397, fy, 45, arm=1, pool=18)]
        disc(x0 + 412, fy - 3, 4, (176, 150, 120), 2); disc(x0 + 412, fy - 3, 2, (130, 108, 96), 1)            # 一卷缆绳
        disc(x0 + 412, fy - 70, 5, (220, 200, 186)); disc(x0 + 412, fy - 70, 2, (96, 76, 90))               # 救生圈挂在仓库墙上
        for a in (0, 2):
            P(x0 + 408 + a * 4, fy - 74 + a * 4, (200, 80, 70))
    elif sz == 1:
        for i, (cx_, cy_, cw) in enumerate([(x0 + 112, fy, 14), (x0 + 127, fy, 14), (x0 + 118, fy - 14, 14)]):
            kbox(cx_, cy_ - 14, cx_ + cw, cy_, (150, 118, 96), depth=0.05, cap=3)
            seg(cx_ + 1, cy_ - 13, cx_ + cw - 1, cy_ - 1, (120, 94, 82)); HL(cx_, cx_ + cw, cy_ - 14, (186, 150, 120))
        plat(x0 + 118, x0 + 133, fy - 28)
        container(x0 + 160, fy, 62, 22, (128, 82, 76))
        container(x0 + 178, fy - 23, 60, 21, (82, 104, 108))
        plat(x0 + 160, x0 + 223, fy - 22); plat(x0 + 178, x0 + 239, fy - 44)
        lamps = [lamp_post(x0 + 236, fy, 45, arm=-1, pool=16)]
        for bx in (x0 + 96, x0 + 104):
            bollard(bx, fy)
    else:
        for bx in (x0 + 90, x0 + 99):
            bollard(bx, fy)
        lamps = [lamp_post(x0 + 114, fy, 42, arm=-1, pool=12)]
    k.finish_room(tv, (mx, my))



# ================================================================ 雪夜院子
SNOW_SKY = [(36, 44, 84), (40, 50, 92), (46, 56, 100), (54, 64, 108), (62, 74, 118), (74, 86, 128)]
SNOW = [(226, 232, 244), (210, 218, 236), (194, 204, 228), (180, 190, 218)]


def pine(x, fy, h, w, c=(46, 76, 76), snow=(222, 228, 242), moon_right=True, tiers=None):
    """松树：一层层三角，朝月亮那半边亮一档、背光那半边暗一档，每层上沿压一道雪。"""
    tiers = tiers or max(3, h // 16)
    R(x - 1, fy - 6, x + 1, fy, (80, 64, 66))
    for i in range(tiers):
        t = i / tiers
        yb = fy - 5 - int(h * 0.82 * t)
        hw = int(w * (1 - t * 0.78))
        th = int(h / tiers * 1.7)
        lit_c, dark_c = shade(c, 1), shade(c, -1)
        S().poly([(x - hw, yb), (x + hw + 1, yb), (x, yb - th)], dark_c if moon_right else lit_c)
        S().poly([(x, yb), (x + hw + 1, yb), (x, yb - th)], lit_c if moon_right else dark_c)
        # 雪：每层顶上一顶雪帽（朝月亮那半亮），枝梢上零星几点
        cap = max(3, th // 3)
        cw = max(2, hw * cap // th)
        S().poly([(x - cw, yb - th + cap), (x, yb - th + cap - 2), (x, yb - th)], shade(snow, -2))
        S().poly([(x, yb - th + cap - 2), (x + cw + 1, yb - th + cap), (x, yb - th)], snow)
        P(x + hw - 1, yb - 1, snow); P(x + hw // 2, yb - 1, snow); P(x - hw + 2, yb - 1, shade(snow, -2))


def bare_tree(x, fy, h, c=(70, 66, 96), snow=(206, 214, 238), seed=3):
    """一棵落了叶的大树（中景偏后）：树干往上分叉，枝条越分越细，上沿积一道雪。"""
    import math
    rr = random.Random(seed)

    def branch(bx, by, ang, ln, th, depth):
        ex, ey = bx + ln * math.cos(ang), by - ln * math.sin(ang)
        for d_ in range(int(th)):
            seg(bx + d_ - th // 2, by, ex + d_ - th // 2, ey, c if d_ < th - 1 or th < 2 else shade(c, -1))
        if th >= 2 and abs(math.cos(ang)) > 0.35:
            seg(bx - th // 2, by - 1, ex - th // 2, ey - 1, snow)
        if depth <= 0 or ln < 5:
            return
        for da in (rr.uniform(0.25, 0.6), -rr.uniform(0.25, 0.6)) + ((rr.uniform(-0.15, 0.15),) if depth > 2 else ()):
            branch(ex, ey, ang + da, ln * rr.uniform(0.6, 0.78), max(1, th - 1 - (depth < 3)), depth - 1)

    floor_shadow(x - 6, x + 8, fy, 2)
    S().poly([(x - 5, fy), (x + 5, fy), (x + 3, fy - h * 0.42), (x - 2, fy - h * 0.42)], c)
    S().poly([(x + 1, fy), (x + 5, fy), (x + 3, fy - h * 0.42), (x + 1, fy - h * 0.42)], shade(c, 1))
    branch(x, fy - h * 0.42, math.pi / 2 + 0.25, h * 0.3, 5, 5)
    branch(x, fy - h * 0.38, math.pi / 2 - 0.5, h * 0.26, 4, 4)


def snow_shed(x, fy, w, h, wood=(120, 92, 92)):
    """工具棚：木板墙，平顶上一层厚雪（单向平台），一扇小门，一架雪橇靠在旁边。"""
    floor_shadow(x, x + w, fy, 3)
    kbox(x, fy - h, x + w, fy, wood, depth=0.05, cap=4, side=shade(wood, 1))
    for bx in range(x + 4, x + w, 5):
        V(bx, fy - h + 1, fy, shade(wood, -1))
    R(x + w // 2 - 6, fy - 26, x + w // 2 + 6, fy, shade(wood, -3))
    P(x + w // 2 + 4, fy - 13, (200, 180, 150))
    R(x - 3, fy - h - 5, x + w + 4, fy - h, SNOW[1]); HL(x - 3, x + w + 4, fy - h - 5, SNOW[0])
    for i in range(0, w + 6, 6):                                         # 雪檐垂下来一点，冰溜子
        P(x - 2 + i, fy - h + 1, SNOW[2])
        if i % 12 == 0:
            V(x + i, fy - h + 1, fy - h + 3, (200, 214, 236))
    plat(x - 3, x + w + 4, fy - h - 5)
    sx_ = x + w + 3                                                       # 雪橇
    seg(sx_, fy, sx_ + 6, fy - 18, (150, 80, 76)); seg(sx_ + 4, fy, sx_ + 10, fy - 18, (150, 80, 76))
    for yy in range(fy - 15, fy - 2, 4):
        HL(sx_ + 1 + (fy - yy) // 3, sx_ + 5 + (fy - yy) // 3, yy, (178, 104, 92))


def well(x, fy, w=36, stone=(130, 130, 150), wood=(112, 84, 86)):
    """老水井：石头井圈、两根柱子、小人字顶（雪），一只桶吊在绳上。"""
    floor_shadow(x, x + w, fy, 3)
    kbox(x, fy - 12, x + w, fy, stone, depth=0.05, cap=3)
    for bx in range(x + 2, x + w, 6):
        V(bx + (2 if bx % 12 else 0), fy - 11, fy - 6, shade(stone, -1)); V(bx + (0 if bx % 12 else 2), fy - 5, fy, shade(stone, -1))
    HL(x, x + w, fy - 6, shade(stone, -1))
    R(x - 1, fy - 14, x + w + 1, fy - 12, SNOW[0])
    for px in (x + 3, x + w - 4):
        R(px, fy - 38, px + 1, fy - 13, wood)
    HL(x + 3, x + w - 3, fy - 32, shade(wood, -1))
    rx = x + w // 2
    V(rx, fy - 31, fy - 22, (170, 160, 150)); R(rx - 2, fy - 22, rx + 2, fy - 18, (110, 104, 118))
    S().poly([(x - 4, fy - 37), (x + w + 5, fy - 37), (rx, fy - 47)], shade(wood, -1))
    S().poly([(x - 5, fy - 37), (rx, fy - 47), (rx, fy - 44), (x - 1, fy - 37)], SNOW[0])
    S().poly([(rx, fy - 47), (x + w + 6, fy - 37), (x + w + 2, fy - 37), (rx, fy - 44)], SNOW[1])
    plat(x - 4, x + w + 5, fy - 40)


def cottage(x, fy, w, wall_h, gable, wall=(150, 128, 140), roof=(98, 82, 100), moon_right=True):
    """雪里的小屋：墙、三角山墙（屋顶压着厚雪，檐下一排冰溜子），门 48 高开着透出暖光，
    两扇暖窗，门口一盏灯，烟囱冒烟。朝灭点的侧墙背着月亮，暗一档偏冷。"""
    top = fy - wall_h
    front = [(x, fy), (x + w, fy), (x + w, top), (x + w // 2, top - gable), (x, top)]
    floor_shadow(x - 6, x + w, fy, 4)
    extrude(front, wall, depth=0.10, cap=14, top=SNOW[1], side=shade(wall, -2))
    for yy in range(top + 4, fy, 5):
        HL(x + 1, x + w - 1, yy, shade(wall, -1))
    # 屋顶的雪：沿两条山墙边一道厚雪，檐口探出来
    for d_ in range(5):
        seg(x - 5, top + 2 - d_, x + w // 2, top - gable - d_, SNOW[0] if d_ < 3 else SNOW[1])
        seg(x + w // 2, top - gable - d_, x + w + 5, top + 2 - d_, SNOW[1] if d_ < 3 else SNOW[2])
    for ix in range(x - 2, x + w + 3, 4):
        V(ix, top + 3, top + 3 + (ix * 7) % 4, (196, 212, 236))
    disc(x + w // 2, top - gable // 2 + 2, 4, (246, 210, 140)); HL(x + w // 2 - 4, x + w // 2 + 4, top - gable // 2 + 2, shade(wall, -2))
    cx_ = x + w - w // 4                                                   # 烟囱 + 烟
    kbox(cx_, top - gable // 2 - 16, cx_ + 8, top - gable // 2 + 4, (120, 100, 110), depth=0.08, cap=5)
    R(cx_ - 1, top - gable // 2 - 18, cx_ + 9, top - gable // 2 - 16, SNOW[0])
    for i, (dx_, r_) in enumerate([(0, 3), (3, 4), (8, 5), (14, 5)]):
        disc(cx_ + 4 + dx_, top - gable // 2 - 23 - i * 7, r_, (120, 128, 166) if i % 2 else (108, 116, 156))
    # 门
    dx = x + w // 2 - 10
    R(dx - 3, fy - 52, dx + 22, fy, shade(wall, -3))
    R(dx, fy - 48, dx + 19, fy, (252, 214, 146))
    R(dx + 5, fy - 40, dx + 12, fy - 2, (226, 176, 122))                    # 屋里一个等人回家的影子
    P(dx + 8, fy - 42, (226, 176, 122)); R(dx + 7, fy - 44, dx + 10, fy - 41, (226, 176, 122))
    S().poly([(dx, fy - 48), (dx - 5, fy - 51), (dx - 5, fy + 1), (dx, fy)], (104, 76, 82))
    R(dx + 24, fy - 46, dx + 26, fy - 43, (90, 70, 72)); R(dx + 24, fy - 42, dx + 26, fy - 41, (255, 240, 196))
    S().poly([(dx - 2, fy + 1), (dx + 21, fy + 1), (dx + 32, fy + 6), (dx - 6, fy + 6)], (246, 226, 196))  # 门口雪地上一块光
    # 窗
    for wx in (x + 8, x + w - 26):
        if dx - 4 < wx + 18 and wx < dx + 24:
            continue
        R(wx - 2, top + 12, wx + 19, top + 31, shade(wall, -3))
        R(wx, top + 14, wx + 17, top + 29, (248, 206, 140))
        R(wx, top + 14, wx + 17, top + 15, (255, 230, 180))
        V(wx + 8, top + 14, top + 29, (180, 120, 96)); HL(wx, wx + 17, top + 21, (180, 120, 96))
        R(wx + 11, top + 16, wx + 16, top + 28, (230, 170, 120))
        R(wx - 3, top + 31, wx + 20, top + 33, SNOW[0])
        tone(S().poly([(wx - 2, fy + 1), (wx + 19, fy + 1), (wx + 26, fy + 7), (wx - 4, fy + 7)]) & tv_mask_cache[0], 1)
    return dx


def snowman(x, fy):
    floor_shadow(x - 7, x + 7, fy, 2)
    disc(x, fy - 7, 8, SNOW[0]); disc(x + 3, fy - 5, 5, SNOW[2])
    disc(x, fy - 19, 6, SNOW[0]); disc(x + 2, fy - 18, 4, SNOW[2])
    disc(x, fy - 28, 4, SNOW[0]); disc(x + 2, fy - 27, 2, SNOW[2])
    P(x - 2, fy - 29, (40, 40, 56)); P(x + 1, fy - 29, (40, 40, 56)); R(x + 3, fy - 28, x + 5, fy - 28, (232, 140, 80))
    R(x - 5, fy - 24, x + 5, fy - 23, CREW[0]); R(x + 2, fy - 23, x + 4, fy - 18, shade(CREW[0], -2))
    R(x - 4, fy - 34, x + 4, fy - 32, (60, 56, 72)); R(x - 2, fy - 38, x + 2, fy - 34, (60, 56, 72))
    seg(x - 6, fy - 19, x - 13, fy - 25, (100, 80, 76)); seg(x + 6, fy - 19, x + 12, fy - 24, (100, 80, 76))
    for yy in (fy - 20, fy - 16, fy - 11):
        P(x - 1, yy, (60, 56, 72))


def woodpile(x, fy, w, h, wood=(140, 106, 96)):
    """靠墙的一垛柴：圆木头一个个端面朝外，上面盖着雪（单向平台）。"""
    floor_shadow(x, x + w, fy, 2)
    R(x, fy - h, x + w, fy, shade(wood, -3))
    for row, yy in enumerate(range(fy - 4, fy - h + 1, -5)):
        for lx in range(x + 3 + (row % 2) * 3, x + w - 1, 6):
            disc(lx, yy, 2.6, wood); P(lx, yy, shade(wood, 2)); P(lx + 1, yy + 1, shade(wood, -1))
    R(x - 2, fy - h - 4, x + w + 2, fy - h, SNOW[1]); HL(x - 2, x + w + 2, fy - h - 4, SNOW[0])
    plat(x - 2, x + w + 2, fy - h - 4)


def bench(x, fy, w=30, wood=(118, 90, 92)):
    for lx in (x + 2, x + w - 3):
        R(lx, fy - 14, lx + 1, fy, shade(wood, -2))
    R(x, fy - 14, x + w, fy - 12, wood)
    R(x, fy - 22, x + w, fy - 20, wood); V(x + 1, fy - 22, fy - 14, shade(wood, -2)); V(x + w - 1, fy - 22, fy - 14, shade(wood, -2))
    R(x - 1, fy - 18, x + w + 1, fy - 15, SNOW[0]); HL(x - 1, x + w + 1, fy - 15, SNOW[2])
    plat(x - 1, x + w + 1, fy - 18)


def snow_fence(x0_, x1_, fy, rnd, c=(116, 92, 96)):
    """一小段栅栏：桩子间距有疏有密，有一根歪了，桩顶顶着一小团雪。"""
    xs, x = [], x0_
    while x < x1_:
        xs.append(x)
        x += rnd.choice((5, 6, 7, 9))
    for i, fx in enumerate(xs):
        lean = 1 if i == len(xs) // 2 else 0
        seg(fx, fy, fx + lean, fy - 12, c); seg(fx + 1, fy, fx + 1 + lean, fy - 12, shade(c, -1))
        R(fx - 1 + lean, fy - 14, fx + 2 + lean, fy - 13, SNOW[0])
    HL(xs[0], xs[-1] + 1, fy - 9, c); HL(xs[0], xs[-1] + 1, fy - 4, c)


def sc_snow_yard(tv):
    """雪夜院子。远景：两层雪山 / 松林剪影（贴着天色），远处一点人家的灯；
    中景：小屋（门开着透出暖光）、松树成组（一高一矮一小，另一边一棵孤树）、工具棚、水井；
    近景：柴垛、长椅、雪人、几段栅栏、路灯，雪地上的脚印，飘雪。月光从右上来。"""
    m_scr = begin(tv)
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wh = x1 - x0, fy - y0
    sz = size_of(tv)
    rnd = random.Random(97 + sz)
    bands_v(tv, y0, fy, SNOW_SKY, jag=1)
    mx, my = (x1 - int(rw * 0.16) if sz != 1 else x0 + int(rw * 0.36)), y0 + int(wh * 0.16)
    moon(mx, my, max(5, wh // 24), m_scr & (k.YY < fy))
    stars(tv, rnd, rw * wh // 1400, y0 + int(wh * 0.5), c=(200, 206, 236))
    # 远景：雪山
    for layer, (c, hmax, top_c) in enumerate([((86, 98, 142), 0.38, (120, 132, 172)), ((70, 84, 126), 0.24, (104, 116, 156))]):
        rr = random.Random(13 + layer)
        pts, xx = [(x0 - 4, fy)], x0 - 4
        while xx < x1 + 20:
            pts.append((xx, fy - int(wh * hmax * rr.uniform(0.45, 1.0))))
            xx += rr.randint(30, 70)
        pts.append((x1 + 20, fy))
        msk = S().poly(pts, c)
        up = np.zeros_like(msk); up[:-3] = msk[3:]
        S().fill_mask(msk & ~up, top_c)                                          # 山脊上一道被月光照的雪
    # 远景：松林剪影，一簇一簇
    rr = random.Random(29)
    xx = x0 - 6
    while xx < x1 + 6:
        n = rr.randint(2, 6)
        for j in range(n):
            th = rr.randint(10, 18 + wh // 12)
            px = xx + j * rr.randint(4, 7)
            S().poly([(px - th // 3, fy - 8), (px + th // 3 + 1, fy - 8), (px, fy - 8 - th)], (54, 66, 104))
        xx += n * 6 + rr.randint(10, 40)
    R(x0, fy - 10, x1, fy, (54, 66, 104))
    for _ in range(2 + sz):                                                   # 远处人家的灯
        lx = rnd.randint(x0 + 10, x1 - 10)
        R(lx, fy - 12, lx + 1, fy - 11, (230, 196, 130))
    # 雪地
    ground(tv, SNOW)
    rr = random.Random(41)
    xx = x0 - 10
    while xx < x1:                                                           # 雪堆起伏，有大有小
        r_ = rr.randint(8, 22)
        S().fill_mask(ellipse_mask(xx, fy + 1, r_, 3) & (k.YY <= fy + 1), SNOW[0])
        xx += r_ + rr.randint(10, 40)
    S().line(x0, fy, x1, fy, SNOW[0])
    # 中景 + 近景
    if sz == 2:
        bare_tree(x0 + 166, fy - 2, 150, seed=4)
    elif sz == 1:
        bare_tree(x0 + 236, fy - 2, 118, seed=6)
    if sz == 2:
        pine(x0 + 30, fy, 118, 24); pine(x0 + 64, fy, 78, 17); pine(x0 + 86, fy, 40, 10)
        snow_fence(x0 + 96, x0 + 124, fy, rnd)
        snow_shed(x0 + 128, fy, 46, 32)
        snowman(x0 + 182, fy)
        well(x0 + 198, fy, 36)
        lamp_post(x0 + 246, fy, 45, c=(60, 56, 72), head=(255, 230, 170), arm=1, pool=16, halo=False)
        dx = cottage(x0 + 266, fy, 100, 62, 36)
        bench(x0 + 272, fy, 26)
        woodpile(x0 + 336, fy, 34, 20)
        snow_fence(x0 + 378, x0 + 412, fy, rnd)
        pine(x0 + 428, fy, 74, 16, tiers=4)
    elif sz == 1:
        pine(x0 + 22, fy, 96, 20); pine(x0 + 50, fy, 56, 13)
        snowman(x0 + 76, fy)
        dx = cottage(x0 + 100, fy, 92, 60, 32)
        bench(x0 + 104, fy, 24)
        woodpile(x0 + 160, fy, 30, 20)
        snow_fence(x0 + 232, x0 + 262, fy, rnd)
        lamp_post(x0 + 238, fy, 45, c=(60, 56, 72), head=(255, 230, 170), arm=-1, pool=14, halo=False)
    else:
        pine(x0 + 20, fy, 70, 15); pine(x0 + 40, fy, 40, 10)
        snowman(x0 + 66, fy)
        snow_fence(x0 + 82, x1 - 6, fy, rnd)
        dx = None
    for i in range(10 + sz * 6):                                              # 脚印
        fx = x0 + 10 + i * (rw - 20) // (10 + sz * 6)
        P(fx, fy + 2 + (i % 2) * 2, SNOW[3])
    for _ in range(rw * wh // 150):                                           # 飘雪：远的小、近的大
        sx_, sy_ = rnd.randint(x0, x1), rnd.randint(y0, fy + 4)
        P(sx_, sy_, (226, 230, 244))
        if rnd.random() < 0.12:
            P(sx_ + 1, sy_, (226, 230, 244)); P(sx_, sy_ + 1, (226, 230, 244)); P(sx_ + 1, sy_ + 1, (200, 208, 232))
    k.finish_room(tv, (mx, my))



# ================================================================ 黄昏海滩
BEACH_SKY = [(100, 94, 146), (122, 102, 152), (152, 114, 154), (186, 128, 150), (214, 144, 146), (234, 166, 146), (244, 190, 154)]
SAND = [(222, 190, 150), (208, 174, 138), (196, 162, 130), (186, 152, 124)]


def palm(x, fy, h, lean, rnd, trunk=(124, 92, 82), leaf=(78, 112, 96), sun_right=True):
    """棕榈树：弯弯的树干一节一节（每节朝太阳那边亮一点），顶上一蓬下垂的叶子，几个椰子。"""
    pts = []
    for i in range(0, h, 3):
        t = i / h
        pts.append((x + lean * t * t, fy - i))
    for j, (px, py) in enumerate(pts):
        w = 3 if j < len(pts) * 0.7 else 2
        R(px - w // 2 - 1, py - 3, px + w // 2, py, trunk)
        P(px + w // 2 if sun_right else px - w // 2 - 1, py - 2, shade(trunk, 2))
        P(px - w // 2 - 1, py, shade(trunk, -2))
    tx, ty = pts[-1][0], pts[-1][1] - 2
    fronds = [(-30, 12), (-24, 20), (-13, 24), (28, 12), (20, 21), (8, 25), (-20, -3), (18, -5), (-2, -9)]
    for dx, dy in sorted(fronds, key=lambda d: -d[1]):                  # 往上翘的叶子后画，压在下垂的上面
        c_ = shade(leaf, 1) if (dx > 0) == sun_right else shade(leaf, -1)
        if dy < 0:
            c_ = shade(c_, 1)
        top, bot = [], []
        for q in range(0, 11):
            t = q / 10
            bx_ = tx + dx * t
            by_ = ty + dy * t * t - 6 * t * (1 - t) * (1 if dy > 0 else 0.3)   # 先往上拱一点，再垂下去
            wdt = 3.2 * (1 - t) + 0.6
            top.append((bx_, by_ - wdt * 0.4))
            bot.append((bx_, by_ + wdt))
        S().poly(top + bot[::-1], c_)
        S().polyline([(int(a), int(b)) for a, b in top], shade(c_, 1))
        for q in range(2, 10, 2):                                         # 叶缘的小缺口：底边几颗暗点
            a, b = bot[q]
            P(a, b, shade(c_, -2))
    for cx_ in (tx - 2, tx + 2):
        disc(cx_, ty + 3, 2, (96, 74, 66))


def lifeguard(x, fy, w=52, leg=38, wood=(196, 170, 150), roof=(198, 96, 88)):
    """救生员瞭望台：高脚、交叉撑、斜梯，台面（单向平台，地面以上 38），上面一间小亭子挂着红旗。"""
    floor_shadow(x, x + w + 8, fy, 3)
    legc = shade(wood, -2)
    for lx in (x + 3, x + w - 4):
        R(lx, fy - leg, lx + 2, fy, legc)
    seg(x + 4, fy - 4, x + w - 4, fy - leg + 4, shade(legc, -1)); seg(x + 4, fy - leg + 4, x + w - 4, fy - 4, shade(legc, -1))
    for i in range(0, 34, 5):                                            # 斜梯
        HL(x - 16 + i // 2, x - 10 + i // 2, fy - 2 - i, legc)
    seg(x - 17, fy, x - 1, fy - leg, legc); seg(x - 11, fy, x + 5, fy - leg, legc)
    R(x - 3, fy - leg - 2, x + w + 3, fy - leg, shade(wood, -1)); HL(x - 3, x + w + 3, fy - leg - 2, shade(wood, 2))
    plat(x - 3, x + w + 3, fy - leg - 2)
    for px in range(x - 3, x + w + 4, 6):                                 # 栏杆
        V(px, fy - leg - 8, fy - leg - 3, legc)
    HL(x - 3, x + w + 3, fy - leg - 8, legc)
    hx0, hx1 = x + 10, x + w - 8
    kbox(hx0, fy - leg - 26, hx1, fy - leg - 3, wood, depth=0.05, cap=3, side=shade(wood, 2))
    R(hx0 + 4, fy - leg - 21, hx1 - 4, fy - leg - 13, (110, 104, 140))
    R(hx0 + 4, fy - leg - 21, hx1 - 4, fy - leg - 20, (232, 180, 150))
    S().poly([(hx0 - 5, fy - leg - 26), (hx1 + 5, fy - leg - 26), (hx1 - 3, fy - leg - 33), (hx0 + 3, fy - leg - 33)], roof)
    S().poly([((hx0 + hx1) // 2, fy - leg - 26), (hx1 + 5, fy - leg - 26), (hx1 - 3, fy - leg - 33), ((hx0 + hx1) // 2, fy - leg - 33)], shade(roof, 1))
    fx = hx1 - 2
    V(fx, fy - leg - 50, fy - leg - 33, (90, 80, 90))
    S().poly([(fx + 1, fy - leg - 50), (fx + 12, fy - leg - 47), (fx + 1, fy - leg - 43)], CREW[0])


def umbrella(x, fy, w, h, c=(214, 116, 104), c2=(236, 220, 200), reg=True):
    """沙滩伞：伞面一瓣红一瓣白，朝太阳那瓣亮；伞沿下面一条暗边，沙上一块影子（往背光那边拖）。"""
    S().poly([(x - w // 2 - 6, fy - 2), (x + w // 2 - 10, fy - 2), (x + w // 2 - 4, fy + 2), (x - w // 2, fy + 2)], SAND[2])
    seg(x, fy, x + 2, fy - h, (110, 86, 84))
    top = fy - h - 12
    brim = fy - h
    n = 5
    for i in range(n):
        a_, b_ = x - w // 2 + i * w // n, x - w // 2 + (i + 1) * w // n
        col = (c if i % 2 == 0 else c2)
        col = shade(col, 1 if i >= n // 2 else -1)
        S().poly([(a_, brim), (b_, brim), (x + 2, top)], col)
    HL(x - w // 2, x + w // 2, brim, shade(c, -3))
    plat(x - w // 2, x + w // 2, brim - 1) if reg else None


def kiosk(x, fy, w=56, h=40, wall=(204, 182, 160), stripe=(110, 150, 168)):
    """海边的小卖部：木板小屋，条纹雨棚，柜台里亮着暖灯，屋顶插着冰淇淋招牌（平顶是单向平台）。"""
    floor_shadow(x, x + w, fy, 3)
    kbox(x, fy - h, x + w, fy, wall, depth=0.05, cap=4, side=shade(wall, 2))
    for bx in range(x + 3, x + w, 4):
        V(bx, fy - h + 1, fy, shade(wall, -1))
    R(x + 6, fy - 30, x + w - 6, fy - 16, (120, 96, 110))
    R(x + 7, fy - 29, x + w - 7, fy - 17, (240, 200, 146))
    for i, jx in enumerate(range(x + 10, x + w - 10, 8)):                 # 柜台里的罐子
        R(jx, fy - 22, jx + 4, fy - 17, [(200, 120, 110), (150, 180, 160), (226, 206, 150)][i % 3])
    R(x + 4, fy - 16, x + w - 4, fy - 14, shade(wall, -2))
    for i, sx_ in enumerate(range(x - 3, x + w + 3, 5)):                  # 条纹雨棚
        S().poly([(sx_, fy - 36), (sx_ + 5, fy - 36), (sx_ + 7, fy - 30), (sx_ + 2, fy - 30)], stripe if i % 2 else (236, 226, 210))
    R(x - 2, fy - h - 3, x + w + 2, fy - h, shade(wall, -2)); HL(x - 2, x + w + 2, fy - h - 3, shade(wall, 2))
    plat(x - 2, x + w + 2, fy - h - 3)
    sx_ = x + w // 2                                                       # 屋顶的冰淇淋招牌
    V(sx_, fy - h - 9, fy - h - 3, (110, 96, 100))
    S().poly([(sx_ - 4, fy - h - 16), (sx_ + 4, fy - h - 16), (sx_, fy - h - 8)], (216, 170, 120))
    disc(sx_, fy - h - 18, 4, (240, 190, 196)); P(sx_ - 1, fy - h - 20, (250, 226, 226))


def sandcastle(x, fy, c=(214, 178, 132)):
    R(x, fy - 8, x + 20, fy, c); R(x + 3, fy - 14, x + 9, fy - 8, c); R(x + 12, fy - 12, x + 17, fy - 8, c)
    for bx in (x, x + 4, x + 8, x + 12, x + 16):
        R(bx, fy - 10, bx + 2, fy - 8, c)
    V(x + 20, fy - 8, fy, shade(c, 2)); V(x + 9, fy - 14, fy - 8, shade(c, 2))
    R(x + 8, fy - 5, x + 11, fy, shade(c, -3))
    V(x + 6, fy - 20, fy - 14, (110, 90, 90)); R(x + 7, fy - 20, x + 10, fy - 18, CREW[3])


def deck_chair(x, fy, c=(98, 126, 182)):
    seg(x, fy, x + 18, fy - 6, (130, 104, 96)); seg(x + 4, fy, x + 10, fy - 14, (130, 104, 96))
    S().poly([(x + 2, fy - 3), (x + 18, fy - 7), (x + 18, fy - 5), (x + 3, fy - 1)], c)
    S().poly([(x + 3, fy - 3), (x + 9, fy - 15), (x + 11, fy - 14), (x + 5, fy - 2)], shade(c, 1))


def rock_mound(x, fy, w, h, c=(146, 120, 128), sun_right=True):
    pts = [(x, fy), (x + w * 0.1, fy - h * 0.7), (x + w * 0.3, fy - h), (x + w * 0.75, fy - h), (x + w * 0.92, fy - h * 0.6), (x + w, fy)]
    S().poly(pts, c)
    S().poly([(x + w * 0.5, fy - h), (x + w * 0.75, fy - h), (x + w * 0.92, fy - h * 0.6), (x + w, fy), (x + w * 0.6, fy)], shade(c, 1) if sun_right else shade(c, -1))
    S().poly([(x, fy), (x + w * 0.1, fy - h * 0.7), (x + w * 0.22, fy - h * 0.4), (x + w * 0.2, fy)], shade(c, -2))
    HL(int(x + w * 0.3), int(x + w * 0.75), int(fy - h), shade(c, 3))
    plat(int(x + w * 0.28), int(x + w * 0.77), int(fy - h))


def sc_beach(tv):
    """黄昏海滩。远景：左边一座海岬、右边几个小岛（贴着天色的剪影），一条远帆；太阳半落在海平线上；
    中景：海面一条碎金的倒影、浪花线；瞭望台、礁石上的两棵棕榈（一高一矮），两把沙滩伞，小卖部，右边一棵孤零零的棕榈；
    近景：沙堡、躺椅、冲浪板、小螃蟹、贝壳和脚印。太阳在右，迎光的一面暖亮，背光的一面偏紫。"""
    m_scr = begin(tv)
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wh = x1 - x0, fy - y0
    sz = size_of(tv)
    rnd = random.Random(113 + sz)
    hz = fy - int(wh * (0.26 if sz else 0.32))
    shore = fy - 8
    bands_v(tv, y0, hz, BEACH_SKY, jag=1)
    sx = x0 + int(rw * (0.66 if sz else 0.7))
    tone(ellipse_mask(sx, hz, wh * 0.24, wh * 0.18) & (k.YY < hz), 1)
    if sz:
        cloud_streaks(rnd, x0 + 10, x1 - 10, [y0 + int(wh * f) for f in ((0.14, 0.22, 0.36) if sz == 2 else (0.18, 0.32))],
                      (196, 140, 160), lit=(240, 190, 170), lmin=40, lmax=120)
    disc(sx, hz, max(8, wh // 12), (252, 226, 172))
    # 远景：海岬和小岛
    S().poly([(x0 - 4, hz), (x0 - 4, hz - int(wh * 0.16)), (x0 + int(rw * 0.08), hz - int(wh * 0.18)), (x0 + int(rw * 0.2), hz - int(wh * 0.08)),
              (x0 + int(rw * 0.3), hz - 3), (x0 + int(rw * 0.34), hz)], (150, 112, 150))
    S().poly([(x0 - 4, hz), (x0 - 4, hz - int(wh * 0.10)), (x0 + int(rw * 0.12), hz - int(wh * 0.07)), (x0 + int(rw * 0.2), hz)], (132, 100, 142))
    for ix, iw, ih in ([(0.82, 30, 8), (0.9, 18, 5), (0.44, 14, 4)] if sz else [(0.86, 16, 5)]):
        cx_ = x0 + int(rw * ix)
        S().poly([(cx_ - iw // 2, hz), (cx_ - iw // 4, hz - ih), (cx_ + iw // 5, hz - ih - 1), (cx_ + iw // 2, hz)], (160, 118, 150))
    if sz:
        bx = x0 + int(rw * 0.36)                                               # 远帆
        S().poly([(bx, hz - 3), (bx + 9, hz - 3), (bx + 7, hz - 1), (bx + 2, hz - 1)], (120, 96, 136))
        S().poly([(bx + 4, hz - 4), (bx + 4, hz - 16), (bx + 10, hz - 4)], (176, 140, 160))
    # 海
    bands_v(tv, hz, shore, [(150, 128, 170), (130, 116, 164), (116, 106, 156), (104, 98, 148)], jag=1)
    for i, y in enumerate(range(hz + 1, shore, 2)):                         # 太阳的碎金倒影
        hw = max(2, int(wh / 12) - i // 2) + i
        o = ((i * 5) % 7) - 3
        HL(sx + o - hw, sx + o - hw // 3, y, (246, 200, 150))
        HL(sx + o + hw // 4, sx + o + hw, y, (238, 182, 146) if i % 2 else (246, 210, 160))
    for y in range(hz + 3, shore, 4):
        for xx in range(x0 + (y * 11) % 23, x1, 29 + y % 7):
            HL(xx, xx + 4, y, (168, 144, 180))
    # 沙滩
    m = m_scr & (k.YY >= shore)
    S().fill_mask(m, SAND[0])
    S().fill_mask(m & (k.YY < shore + 3), (176, 150, 140))                    # 湿沙
    xx = x0
    while xx < x1:                                                             # 浪花线：断断续续
        L = rnd.randint(6, 24)
        HL(xx, xx + L, shore, (240, 230, 222))
        xx += L + rnd.randint(3, 14)
    ground(tv, SAND)
    S().fill_mask(m_scr & (k.YY == fy), shade(SAND[0], 1))
    # 中景 + 近景
    if sz == 2:
        lifeguard(x0 + 44, fy, 52, 38)
        palm(x0 + 196, fy, 82, 16, rnd)
        rock_mound(x0 + 136, fy, 56, 22)
        palm(x0 + 160, fy - 22, 104, -34, rnd)
        sandcastle(x0 + 204, fy)
        umbrella(x0 + 250, fy, 50, 30)
        deck_chair(x0 + 236, fy)
        umbrella(x0 + 284, fy, 34, 24, c=(110, 150, 168), reg=False)
        kiosk(x0 + 316, fy, 56, 40)
        R(x0 + 392, fy - 40, x0 + 397, fy, CREW[2]); R(x0 + 393, fy - 42, x0 + 396, fy - 41, CREW[2])   # 插在沙里的冲浪板
        V(x0 + 397, fy - 40, fy, shade(CREW[2], 2)); HL(x0 + 392, x0 + 397, fy - 26, (236, 226, 210))
        palm(x0 + 420, fy, 96, -24, rnd)
    elif sz == 1:
        lifeguard(x0 + 30, fy, 46, 38)
        umbrella(x0 + 126, fy, 46, 30)
        deck_chair(x0 + 110, fy)
        sandcastle(x0 + 160, fy)
        palm(x0 + 214, fy, 100, -30, rnd)
        palm(x0 + 236, fy, 70, 10, rnd)
    else:
        umbrella(x0 + 36, fy, 44, 28)
        palm(x0 + 100, fy, 70, -22, rnd)
        sandcastle(x0 + 66, fy)
    for cx_ in ([x0 + 120, x0 + 300] if sz == 2 else [x0 + 90] if sz else [x0 + 80]):   # 小螃蟹
        R(cx_, fy - 2, cx_ + 3, fy, (206, 90, 80)); P(cx_ - 1, fy - 3, (206, 90, 80)); P(cx_ + 4, fy - 3, (206, 90, 80))
    for i in range(6 + sz * 5):                                                # 脚印、贝壳
        fx = x0 + 8 + (i * 37) % max(10, rw - 16)
        P(fx, fy + 3 + (i % 3), SAND[2])
        if i % 4 == 0:
            P(fx + 2, fy + 2, (246, 230, 220))
    k.finish_room(tv, (sx, hz))


# ================================================================ 沙漠
DESERT_SKY = [(176, 182, 196), (190, 192, 196), (206, 200, 192), (222, 208, 188), (234, 216, 188), (242, 224, 192)]
DUNE = [(226, 186, 140), (214, 172, 128), (200, 158, 118)]


def mesa(x, base, w, h, c, lit, rr):
    """远处的平顶山：顶是平的，两边一级级往下收，朝太阳那面压亮一档。"""
    steps = rr.randint(2, 3)
    pts = [(x, base)]
    for i in range(steps):
        pts += [(x + i * w * 0.06, base - h * (i + 1) / steps * 0.9), (x + (i + 1) * w * 0.06, base - h * (i + 1) / steps * 0.9)]
    pts += [(x + w * 0.22, base - h), (x + w * 0.78, base - h)]
    for i in range(steps):
        pts += [(x + w - (steps - i) * w * 0.06, base - h * (steps - i) / steps * 0.9 + 1)]
    pts += [(x + w, base)]
    S().poly(pts, c)
    S().poly([(x + w * 0.62, base - h), (x + w * 0.78, base - h), (x + w, base), (x + w * 0.7, base)], lit)


def telegraph(xs, bases, hs, c=(126, 98, 92), wire=(150, 126, 118)):
    """一排往远处退的电线杆：越远越矮、挨得越近，杆顶两根横担，电线垂下来连着。"""
    tops = []
    for x, b, h in zip(xs, bases, hs):
        V(x, b - h, b, c); V(x + 1, b - h, b, shade(c, -1)) if h > 30 else None
        arm = max(3, h // 6)
        HL(x - arm, x + arm + 1, b - h + 2, c)
        if h > 30:
            HL(x - arm + 2, x + arm - 1, b - h + 6, c)
        tops.append((x - arm, x + arm + 1, b - h + 2))
    for (la, lb, ly), (ra, rb, ry) in zip(tops, tops[1:]):
        dip = max(2, abs(ra - la) // 12)
        sag(min(la, ra), ly if la < ra else ry, max(la, ra), ry if la < ra else ly, dip, wire)
        sag(min(lb, rb), ly if lb < rb else ry, max(lb, rb), ry if lb < rb else ly, dip, wire)


def windmill(x, fy, h, c=(118, 98, 100), lit=(176, 146, 136), blade=(200, 186, 176)):
    """抽水风车：四条腿的铁架往上收，横撑一格格，顶上一圈扇叶和一片尾翼。"""
    import math
    top = fy - h
    for (ax, bx) in [(x - 14, x - 2), (x + 14, x + 2)]:
        seg(ax, fy, bx, top, c)
        seg(ax + (1 if ax > x else -1), fy, bx, top, c)
    seg(x + 14, fy, x + 2, top, lit)
    for i, yy in enumerate(range(fy - 14, top + 6, -16)):
        t = (fy - yy) / h
        hw = int(14 - 12 * t)
        HL(x - hw, x + hw, yy, c)
        if i % 2 == 0:
            nyy = yy - 16
            nhw = int(14 - 12 * ((fy - nyy) / h))
            seg(x - hw, yy, x + nhw, max(top, nyy), shade(c, -1))
    R(x - 3, top - 4, x + 3, top + 2, c)
    hx, hy = x - 2, top - 3
    for i in range(12):
        a = i * math.pi / 6
        ex, ey = hx + 18 * math.cos(a), hy + 18 * math.sin(a)
        seg(hx + 5 * math.cos(a), hy + 5 * math.sin(a), ex, ey, blade if i % 2 else shade(blade, -2))
        seg(hx + 5 * math.cos(a + 0.12), hy + 5 * math.sin(a + 0.12), ex + 2 * math.cos(a + 1.6), ey + 2 * math.sin(a + 1.6), blade if i % 2 else shade(blade, -2))
    S().polyline([(hx + int(18 * math.cos(i * math.pi / 12)), hy + int(18 * math.sin(i * math.pi / 12))) for i in range(25)], shade(blade, -3))
    disc(hx, hy, 3, c)
    HL(x + 1, x + 20, top - 3, c)
    S().poly([(x + 16, top - 10), (x + 30, top - 8), (x + 30, top + 1), (x + 16, top + 2)], lit)
    V(x + 1, top + 2, fy - 4, (90, 80, 90))                                    # 抽水杆


def water_cistern(x, fy, w, h, c=(150, 128, 120)):
    floor_shadow(x - 6, x + w, fy, 3)
    R(x, fy - h, x + w, fy, c)
    for bx in range(x + 2, x + w, 3):
        V(bx, fy - h + 1, fy - 1, shade(c, -1))
    R(x + w - 6, fy - h, x + w, fy, shade(c, 1)); V(x + w, fy - h, fy, shade(c, 2))
    R(x - 1, fy - h - 2, x + w + 1, fy - h, shade(c, -2)); HL(x - 1, x + w + 1, fy - h - 2, shade(c, 3))
    HL(x, x + w, fy - h // 2, shade(c, -2))
    R(x + 4, fy - 6, x + 6, fy - 4, (110, 100, 110)); P(x + 5, fy - 3, (120, 140, 170))
    plat(x - 1, x + w + 1, fy - h - 2)


def car_wreck(x, fy, w=64, body=(162, 112, 94)):
    """沙里半埋的老轿车：没有轮子，锈成一块块，车顶是平台；背光那侧堆着一道沙。"""
    S().poly([(x, fy - 2), (x + 4, fy - 14), (x + w - 6, fy - 15), (x + w, fy - 6), (x + w, fy)], body)
    rx0, rx1 = x + 14, x + w - 16
    S().poly([(rx0 - 7, fy - 14), (rx0, fy - 28), (rx1, fy - 28), (rx1 + 8, fy - 15)], shade(body, -1))
    R(rx0 + 1, fy - 25, x + w // 2 - 2, fy - 16, (84, 70, 82)); R(x + w // 2 + 1, fy - 25, rx1 - 1, fy - 16, (84, 70, 82))
    HL(rx0, rx1, fy - 28, shade(body, 3)); HL(x + 4, x + w - 6, fy - 14, shade(body, 2))
    S().poly([(rx1, fy - 28), (rx1 + 8, fy - 15), (rx1 + 4, fy - 15), (rx1 - 2, fy - 27)], shade(body, 2))
    for (a_, b_) in [(x + 8, fy - 10), (x + 30, fy - 8), (x + 46, fy - 11)]:   # 锈斑
        R(a_, b_, a_ + 5, b_ + 2, (128, 84, 74))
    R(x + w - 3, fy - 11, x + w - 1, fy - 9, (210, 200, 180))
    S().poly([(x - 10, fy + 1), (x + 6, fy - 8), (x + 16, fy + 1)], DUNE[0])         # 堆过来的沙
    S().poly([(x + w - 10, fy + 1), (x + w + 2, fy - 4), (x + w + 14, fy + 1)], DUNE[0])
    plat(rx0, rx1, fy - 28)


def buried_tv(x, fy, w=36, h=24, shell=(176, 158, 138)):
    """半埋在沙里的大肚子电视：机壳、凸出来的屏、旋钮，一根天线斜着，沙子盖住下半截。"""
    floor_shadow(x - 6, x + w, fy, 2)
    kbox(x, fy - h, x + w, fy, shell, depth=0.06, cap=5, side=shade(shell, 2))
    R(x + 3, fy - h + 3, x + w - 11, fy - 5, (64, 66, 84))
    R(x + 4, fy - h + 4, x + w - 17, fy - h + 6, (106, 110, 132))
    for ky in (fy - h + 5, fy - h + 11):
        disc(x + w - 6, ky, 2, shade(shell, -3))
    seg(x + 8, fy - h, x + 2, fy - h - 12, (120, 110, 110)); seg(x + 12, fy - h, x + 18, fy - h - 10, (120, 110, 110))
    S().poly([(x - 8, fy + 1), (x + 4, fy - 6), (x + w // 2, fy - 3), (x + w + 4, fy - 7), (x + w + 12, fy + 1)], DUNE[0])
    plat(x, x + w, fy - h)


def saguaro(x, fy, h, c=(102, 140, 104), sun_right=True):
    floor_shadow(x - 6, x + 4, fy, 2)
    R(x, fy - h, x + 5, fy, c); V(x + (5 if sun_right else 0), fy - h, fy, shade(c, 2)); V(x + (0 if sun_right else 5), fy - h + 2, fy, shade(c, -2))
    R(x + 1, fy - h - 1, x + 4, fy - h, c)
    for side, ay, ah in [(-1, int(h * 0.45), int(h * 0.3)), (1, int(h * 0.62), int(h * 0.26))]:
        if h < 30 and side == 1:
            continue
        bx = x - 6 if side < 0 else x + 8
        R(min(bx, x), fy - ay, max(bx + 3, x + 5), fy - ay + 3, c)
        R(bx, fy - ay - ah, bx + 3, fy - ay + 3, c); V(bx + 3, fy - ay - ah, fy - ay + 3, shade(c, 2)); HL(bx, bx + 3, fy - ay - ah, shade(c, 3))
    for yy in range(fy - h + 3, fy, 4):
        P(x + 2, yy, shade(c, 1))


def sc_desert(tv):
    """白天的沙漠。远景：一排平顶山（宽窄高低都不一样，贴着天色）、远一层沙丘；
    中景：往远处退的一排电线杆（越远越矮越密）、抽水风车和水罐、半埋的老轿车、半埋的大肚子电视、高高的仙人掌；
    近景：石头、牛头骨、风滚草、小仙人掌。太阳在右上，影子往左拖。"""
    m_scr = begin(tv)
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wh = x1 - x0, fy - y0
    sz = size_of(tv)
    rnd = random.Random(131 + sz)
    sun = (x0 + int(rw * 0.8), y0 + int(wh * 0.18))
    bands_v(tv, y0, fy, DESERT_SKY, jag=1)
    tone(ellipse_mask(*sun, wh * 0.11 * 1.35, wh * 0.10 * 1.35) & m_scr, 1)   # 太阳光晕分两档，外圈淡，不再是一圈硬边
    tone(ellipse_mask(*sun, wh * 0.11 * 0.8, wh * 0.10 * 0.8) & m_scr, 1)
    disc(*sun, max(6, wh // 18), (252, 244, 214))
    hz = fy - int(wh * (0.22 if sz else 0.3))
    rr = random.Random(17)
    xx = x0 - 20
    while xx < x1:                                                              # 平顶山，成群：一大一小挨着，再隔一段
        w_ = rr.randint(40, 110) if sz else rr.randint(30, 60)
        h_ = int(rr.uniform(0.08, 0.2) * wh) + 6
        mesa(xx, hz + 2, w_, h_, (216, 184, 166), (226, 198, 178), rr)
        if rr.random() < 0.6:
            mesa(xx + w_ - 6, hz + 2, w_ // 3, int(h_ * 0.6), (210, 176, 160), (222, 192, 172), rr)
        xx += w_ + rr.randint(20, 90)
    R(x0, hz, x1, hz + 2, (216, 184, 166))
    for i, (c, base, amp, f) in enumerate([(DUNE[1], hz + 2, 5, 0.025), (DUNE[0], hz + (fy - hz) * 0.45, 7, 0.035)]):
        top = base - amp * (1 + np.sin(k.XX * f + i * 2.1))
        msk = m_scr & (k.YY >= top) & (k.YY < fy)
        S().fill_mask(msk, c)
        S().fill_mask(msk & (k.YY < top + 2) & (np.cos(k.XX * f + i * 2.1) < 0), shade(c, 2))     # 朝太阳的坡亮
        S().fill_mask(msk & (k.YY < top + 5) & (np.cos(k.XX * f + i * 2.1) > 0.4), shade(c, -1))   # 背阴的坡暗
    if sz:                                                                       # 左边一座近一点的孤峰，压住画面
        bw_ = 58 if sz == 2 else 40
        bh_ = int(wh * (0.56 if sz == 2 else 0.5))
        bx_, by_ = x0 - 6, fy - 6
        pts = [(bx_, by_), (bx_, by_ - bh_ + 10), (bx_ + 6, by_ - bh_), (bx_ + bw_ * 0.55, by_ - bh_), (bx_ + bw_ * 0.62, by_ - bh_ * 0.82),
               (bx_ + bw_ * 0.72, by_ - bh_ * 0.8), (bx_ + bw_ * 0.8, by_ - bh_ * 0.45), (bx_ + bw_ + 14, by_)]
        msk = S().poly(pts, (190, 140, 120))
        S().fill_mask(msk & (k.XX > bx_ + bw_ * 0.42), (206, 156, 130))          # 朝太阳的一面
        for i, f in enumerate((0.2, 0.38, 0.6, 0.78)):                           # 一层层岩层
            yy = int(by_ - bh_ * f)
            S().fill_mask(msk & (k.YY >= yy) & (k.YY < yy + 2), (176, 128, 112) if i % 2 else (200, 152, 128))
        HL(bx_ + 6, int(bx_ + bw_ * 0.55), by_ - bh_, (226, 180, 150))
    ground(tv, [(232, 196, 148), (220, 182, 136), (208, 170, 126), (198, 160, 120)])
    if sz == 2:
        xs = [x0 + 16, x0 + 70, x0 + 112, x0 + 146, x0 + 172, x0 + 192, x0 + 207]
        hs = [64, 50, 40, 32, 26, 21, 17]
        bases = [fy - 4, fy - 9, fy - 13, fy - 16, fy - 18, fy - 20, fy - 21]
        telegraph(xs, bases, hs)
        windmill(x0 + 318, fy, 112)
        water_cistern(x0 + 266, fy, 30, 28)
        saguaro(x0 + 368, fy, 66); saguaro(x0 + 414, fy, 24); saguaro(x0 + 426, fy, 15)
        floor_shadow(x0 + 24, x0 + 70, fy, 3)                                     # 平顶大石：几块叠在一起
        S().poly([(x0 + 26, fy), (x0 + 30, fy - 18), (x0 + 38, fy - 26), (x0 + 58, fy - 27), (x0 + 66, fy - 20), (x0 + 74, fy - 8), (x0 + 76, fy)], (164, 124, 112))
        S().poly([(x0 + 48, fy - 27), (x0 + 58, fy - 27), (x0 + 66, fy - 20), (x0 + 74, fy - 8), (x0 + 76, fy), (x0 + 56, fy), (x0 + 54, fy - 14)], (194, 148, 124))
        S().poly([(x0 + 26, fy), (x0 + 30, fy - 18), (x0 + 34, fy - 21), (x0 + 36, fy - 8), (x0 + 34, fy)], (144, 108, 102))
        seg(x0 + 40, fy - 16, x0 + 52, fy - 12, (146, 110, 102))
        HL(x0 + 39, x0 + 58, fy - 27, (222, 178, 148))
        disc(x0 + 80, fy - 3, 5, (176, 134, 116), 3); disc(x0 + 82, fy - 4, 3, (200, 156, 130), 2)
        plat(x0 + 38, x0 + 58, fy - 27)
        buried_tv(x0 + 104, fy, 38, 22)
        car_wreck(x0 + 180, fy, 66)
        disc(x0 + 92, fy - 2, 4, (160, 124, 110), 3); disc(x0 + 246, fy - 2, 5, (170, 130, 112), 3); disc(x0 + 252, fy - 1, 3, (186, 146, 122), 2)
        bones = (236, 226, 206)                                                 # 牛头骨
        R(x0 + 150, fy - 4, x0 + 156, fy - 1, bones); seg(x0 + 150, fy - 4, x0 + 146, fy - 8, bones); seg(x0 + 156, fy - 4, x0 + 160, fy - 8, bones)
        P(x0 + 152, fy - 3, (120, 100, 100)); P(x0 + 154, fy - 3, (120, 100, 100))
        for i in range(10):                                                     # 风滚草
            a = i * 0.63
            P(x0 + 350 + 5 * np.cos(a), fy - 5 + 4 * np.sin(a), (170, 140, 104)); P(x0 + 350 + 3 * np.cos(a + 1), fy - 5 + 2 * np.sin(a + 1), (150, 120, 96))
    elif sz == 1:
        telegraph([x0 + 14, x0 + 60, x0 + 92, x0 + 114], [fy - 4, fy - 9, fy - 12, fy - 14], [56, 40, 30, 22])
        buried_tv(x0 + 34, fy, 36, 22)
        car_wreck(x0 + 100, fy, 62)
        windmill(x0 + 210, fy, 96)
        saguaro(x0 + 244, fy, 40)
    else:
        buried_tv(x0 + 30, fy, 32, 20)
        saguaro(x0 + 90, fy, 44)
        saguaro(x0 + 104, fy, 16)
    if sz:
        for i, (bx, by) in enumerate([(0.42, 0.2), (0.47, 0.17), (0.52, 0.23)][:3 if sz == 2 else 2]):    # 天上盘旋的几只秃鹫
            flying_bird(x0 + int(rw * bx), y0 + int(wh * by), (150, 126, 120))
    k.finish_room(tv, sun)


SCENES_V3 = {"rooftop": sc_rooftop, "rain_street": sc_rain_street, "harbor": sc_harbor,
             "snow_yard": sc_snow_yard, "beach": sc_beach, "desert": sc_desert}
