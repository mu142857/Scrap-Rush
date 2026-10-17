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
            wpitch=(3, 4), wsz=(0, 1), rim=None, sun_x=None, tops=0.4, masts=0.0, x_from=None, x_to=None):
    """一层城市剪影。楼高 = 慢变的包络（一片高、一片矮）× 随机，偶尔冒一栋高楼；
    窗户按一户一户成片亮（同一层挨着的两三扇），不是满墙均匀撒。rim：朝太阳那一侧和楼顶压一道亮边。
    masts：有些楼顶上两三根小天线挨在一起（成组），大多数楼顶没有。"""
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
        x += bw + rnd.randint(*gap)
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


def lamp_post(x, fy, h=45, c=(52, 52, 66), head=(246, 232, 190), arm=1, pool=None, plat_top=False):
    """路灯：灯杆、往一侧伸出去的灯臂、灯罩、下面一盏亮灯；pool 给地上一圈光（挪几档）。"""
    floor_shadow(x - 2, x + 2, fy, 2)
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
    tone(ellipse_mask(*sun, wh * 0.16, wh * 0.13) & (k.YY < pw), 1)
    disc(*sun, max(5, wh // 16), (252, 228, 180))
    skyline_sun = sun
    # 远景：三层剪影
    skyline(tv, rnd, pw, wh * 0.30, wh * 0.62, (176, 130, 152), wr=(9, 22), gap=(0, 2), tops=0.5, masts=0.08)
    skyline(tv, rnd, pw, wh * 0.16, wh * 0.40, (146, 108, 140), wr=(10, 26), gap=(0, 4), win=(222, 170, 140),
            win_n=1.2, wpitch=(3, 4), wsz=(0, 1), rim=(188, 140, 150), sun_x=sun[0], tops=0.5, masts=0.15)
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
NIGHT = [(20, 22, 34), (24, 26, 40), (30, 32, 48), (38, 40, 56), (46, 48, 64)]
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
    skyline(tv, rnd, fy, wh * 0.55, wh * 0.95, (40, 42, 58), wr=(14, 34), gap=(0, 4), win=(90, 88, 92), win_n=0.8,
            wpitch=(4, 6), wsz=(1, 2), tops=0.5, masts=0.2)
    # 中景：临街的楼
    walls = [(74, 74, 92), (64, 66, 84), (84, 82, 98), (70, 72, 88)]
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
    rain(tv, rnd, rw * wh // 260, (106, 110, 132))
    rain(tv, rnd, rw * wh // 900, (150, 154, 172), length=4)
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
    tone(ellipse_mask(x, y, r * 3.2, r * 3.0) & sky_mask, 1)
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


def crane(xa, xb, fy, top, boom_x0, boom_x1, c=(88, 64, 76), lit=(140, 104, 106)):
    """岸边的集装箱吊车（夜里一大片剪影）：两条门腿带交叉撑，门梁上一座 A 字架，长臂伸到水上，
    小车下面垂两根钢缆，顶上红色警示灯。左边缘朝月亮，压一道亮边。"""
    beam = top + 28
    for lx in (xa, xb):
        R(lx, beam, lx + 3, fy, c); V(lx, beam, fy, lit)
        R(lx - 3, fy - 3, lx + 6, fy, shade(c, -1))
    for yy in range(beam + 4, fy - 8, 22):                                    # 门腿之间的交叉撑
        seg(xa + 3, yy, xb, yy + 22, shade(c, -1)); seg(xa + 3, yy + 22, xb, yy, shade(c, -1))
    R(xa - 4, beam - 6, xb + 8, beam, c); HL(xa - 4, xb + 8, beam - 6, lit)
    ax = (xa + xb) // 2 + 10
    seg(xa + 6, beam - 6, ax, top, c); seg(xa + 7, beam - 6, ax + 1, top, c)
    seg(xb, beam - 6, ax + 2, top, c); seg(xb + 1, beam - 6, ax + 3, top, c)
    by = beam - 16
    R(boom_x0, by, boom_x1, by + 4, c); HL(boom_x0, boom_x1, by, lit)
    for bx in range(boom_x0 + 4, boom_x1, 9):
        seg(bx, by + 4, bx + 5, by, shade(c, -1))
    seg(ax, top + 1, boom_x0 + 10, by, (120, 100, 110)); seg(ax, top + 1, boom_x1 - 4, by, (120, 100, 110))
    cab = xa - 6
    R(cab, by + 5, cab + 12, by + 14, shade(c, 1))
    R(cab + 2, by + 7, cab + 10, by + 10, (226, 206, 150))
    tx = boom_x0 + (xa - boom_x0) // 3
    R(tx - 4, by + 5, tx + 4, by + 8, c)
    V(tx - 2, by + 9, by + 40, (110, 100, 112)); V(tx + 2, by + 9, by + 40, (110, 100, 112))
    R(tx - 7, by + 40, tx + 7, by + 43, c)
    for lx in (ax + 1, boom_x0 + 1, boom_x1 - 2):
        R(lx, (top - 3) if lx == ax + 1 else by - 2, lx + 1, (top - 2) if lx == ax + 1 else by - 1, (230, 96, 84))
    return tx


def bollard(x, fy, c=(70, 72, 86)):
    R(x, fy - 6, x + 5, fy, c); R(x - 1, fy - 8, x + 6, fy - 6, shade(c, 1)); HL(x - 1, x + 6, fy - 8, shade(c, 3))


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
    mx, my = x0 + int(rw * (0.12 if sz == 2 else 0.18)), y0 + int(wh * 0.18)
    moon(mx, my, max(5, wh // 26), m_scr & (k.YY < hz))
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
    lhx = x1 - int(rw * 0.08)                                                # 对岸的小灯塔
    R(lhx - 1, hz - 16, lhx + 1, hz - 3, (110, 114, 140)); R(lhx - 2, hz - 19, lhx + 2, hz - 17, (240, 230, 180))
    S().fill_mask(S().poly([(lhx - 2, hz - 18), (lhx - int(rw * 0.35), hz - 30), (lhx - int(rw * 0.35), hz - 14)]) & (k.YY < hz - 2) & m_scr
                  & (S().a[..., 2] > 80), (70, 78, 116))
    # 海面
    bands_v(tv, hz, fy, [(40, 54, 92), (36, 50, 86), (32, 46, 80), (30, 42, 74)], jag=1)
    for y in range(hz + 2, fy, 3):
        for xx in range(x0 + (y * 7) % 19, x1, 23 + (y % 5)):
            HL(xx, xx + 3 + (y % 3), y, (58, 74, 112))
    for i, y in enumerate(range(hz + 1, fy, 2)):                            # 月光的碎影
        hw = 2 + i // 2 + (i * 7) % 3
        HL(mx - hw, mx + hw - (i % 3), y, (150, 156, 176) if i % 3 else (110, 120, 150))
    # 中景
    if sz == 2:
        tx = crane(x0 + 196, x0 + 384, fy, fy - 168, x0 + 70, x0 + 436)
        fishing_boat(x0 + 14, fy - 4, 116)
    elif sz == 1:
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
        for i, (cx_, cy_, cw) in enumerate([(x0 + 60, fy, 15), (x0 + 76, fy, 14), (x0 + 66, fy - 14, 15)]):    # 木箱堆
            kbox(cx_, cy_ - 14, cx_ + cw, cy_, (150, 118, 96), depth=0.05, cap=3)
            seg(cx_ + 1, cy_ - 13, cx_ + cw - 1, cy_ - 1, (120, 94, 82)); HL(cx_, cx_ + cw, cy_ - 14, (186, 150, 120))
        plat(x0 + 66, x0 + 82, fy - 28)
        for dx_, c_ in [(x0 + 130, (96, 110, 124)), (x0 + 143, CREW[2])]:     # 油桶
            c_ = shade(c_, -2)
            floor_shadow(dx_, dx_ + 11, fy, 2)
            R(dx_, fy - 18, dx_ + 11, fy, c_); V(dx_ + 1, fy - 18, fy, shade(c_, 2)); V(dx_ + 10, fy - 18, fy, shade(c_, -2))
            HL(dx_, dx_ + 11, fy - 13, shade(c_, -2)); HL(dx_, dx_ + 11, fy - 5, shade(c_, -2)); HL(dx_, dx_ + 11, fy - 18, shade(c_, 3))
        S().poly([(x0 + 156, fy), (x0 + 172, fy - 2), (x0 + 172, fy - 11), (x0 + 156, fy - 9)], (90, 82, 96))   # 倒着的一个
        disc(x0 + 172, fy - 6, 5, (110, 100, 112), 5)
        plat(x0 + 130, x0 + 155, fy - 18)
        container(x0 + 200, fy, 62, 22, (128, 82, 76)); container(x0 + 264, fy, 62, 22, (82, 104, 108))
        container(x0 + 226, fy - 23, 64, 21, (120, 110, 90))
        plat(x0 + 200, x0 + 327, fy - 22); plat(x0 + 226, x0 + 291, fy - 44)
        R(tx - 7, fy - 47, tx + 7, fy - 45, (88, 64, 76))
        for bx in (x0 + 340, x0 + 350, x0 + 420):
            bollard(bx, fy)
        sag(x0 + 343, fy - 6, x0 + 352, fy - 6, 2, (180, 160, 130))
        lamps = [lamp_post(x0 + 366, fy, 45, arm=1, pool=18), lamp_post(x0 + 378, fy, 45, arm=1, pool=18)]
        disc(x0 + 404, fy - 4, 4, (176, 150, 120), 2); disc(x0 + 404, fy - 4, 2, (130, 108, 96), 1)            # 一卷缆绳
        R(x0 + 430, fy - 30, x0 + 431, fy, (110, 90, 86))                     # 救生圈挂在桩上
        disc(x0 + 431, fy - 24, 5, (220, 200, 186)); disc(x0 + 431, fy - 24, 2, (104, 82, 80))
        for a in (0, 2):
            P(x0 + 427 + a * 4 - 1, fy - 24 + (a - 1) * 4 + 1, (200, 80, 70))
    elif sz == 1:
        for i, (cx_, cy_, cw) in enumerate([(x0 + 112, fy, 14), (x0 + 127, fy, 14), (x0 + 118, fy - 14, 14)]):
            kbox(cx_, cy_ - 14, cx_ + cw, cy_, (150, 118, 96), depth=0.05, cap=3)
            seg(cx_ + 1, cy_ - 13, cx_ + cw - 1, cy_ - 1, (120, 94, 82)); HL(cx_, cx_ + cw, cy_ - 14, (186, 150, 120))
        plat(x0 + 118, x0 + 133, fy - 28)
        container(x0 + 160, fy, 62, 22, (128, 82, 76))
        container(x0 + 178, fy - 23, 60, 21, (82, 104, 108))
        plat(x0 + 160, x0 + 223, fy - 22); plat(x0 + 178, x0 + 239, fy - 44)
        lamps = [lamp_post(x0 + 248, fy, 45, arm=-1, pool=16)]
        for bx in (x0 + 96, x0 + 104):
            bollard(bx, fy)
    else:
        for bx in (x0 + 90, x0 + 99):
            bollard(bx, fy)
        lamps = [lamp_post(x0 + 114, fy, 42, arm=-1, pool=12)]
    k.finish_room(tv, (mx, my))


SCENES_V3 = {"rooftop": sc_rooftop, "rain_street": sc_rain_street, "harbor": sc_harbor}
