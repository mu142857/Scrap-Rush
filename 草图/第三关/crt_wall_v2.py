"""第三关「显像管仓库」样图 v2：一整面电视墙，每块屏幕都是一个房间，房间之间打通。

和 v1 的区别（2026-10-17 作者要求）：
- 所有电视都放大到能进人（屏幕里的房间至少 130×90，主角 13 格高、跳 45 格）。
- 相邻电视之间的外壳被砸穿：左右是齐地面的通道，上下是带电线梯子的洞。
- 每台电视的显示方式不同，房间就是那种颜色：彩色、黑白、绿色荧光、琥珀色单色屏。
- 每个房间是"家"的一部分：厨房、客厅、卧室、儿童房、书房、玄关。

分层（480×270 透明 PNG）：l3v2_far / l3v2_mid（外壳和通道，吃光照）/ l3v2_screens（房间，不吃光照）/ l3v2_near
预览：预览v2_原图_3x.png、预览v2_游戏_3x.png
跑法："~/Desktop/程序programs/AI Oscar/.venv/bin/python" crt_wall_v2.py
"""
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, "/Users/jiamulin/Desktop/程序programs/AI Oscar")
from oscarkit.canvas import Canvas  # noqa: E402
from oscarkit.shade import facet, step_color  # noqa: E402
from oscarkit.light import smooth_noise, polygonal  # noqa: E402

OUT = Path(__file__).parent
W, H = 480, 270
FLOOR = 256
random.seed(4)
rng = np.random.default_rng(4)

KHAKI = [(188, 185, 169), (179, 173, 157), (169, 159, 145), (156, 142, 132), (138, 118, 115), (116, 86, 91), (89, 62, 72)]
WOOD = [(164, 116, 86), (152, 106, 80), (138, 95, 73), (124, 85, 67), (104, 70, 60), (88, 58, 58), (66, 44, 50)]
GREY = [(156, 156, 164), (145, 145, 156), (132, 131, 145), (119, 117, 133), (100, 95, 113), (84, 76, 94), (64, 56, 74)]
PLUM = [(150, 132, 150), (138, 120, 140), (124, 107, 128), (110, 94, 116), (92, 78, 100), (76, 62, 84), (58, 46, 66)]
RECESS = [(39, 44, 56), (55, 55, 74), (81, 72, 94)]
GLARE = (84, 84, 108)
WALL = [(30, 28, 39), (36, 33, 46), (43, 39, 55), (50, 46, 63)]
FLOOR_C = [(96, 90, 104), (78, 72, 88), (68, 62, 78), (58, 53, 68)]
CABLE = [(42, 34, 44), (58, 46, 58), (74, 60, 72)]
PCB = [(46, 74, 60), (62, 96, 74), (84, 120, 88)]
COPPER = (190, 140, 96)
LED_RED, LED_GRN = (226, 72, 64), (120, 214, 130)

# 屏幕的显示方式：把房间的亮度映射到一条色阶上（彩色的不映射）
TINTS = {
    "color": None,
    "bw": [(34, 36, 44), (70, 72, 82), (112, 114, 124), (156, 158, 166), (204, 206, 210), (236, 236, 236)],
    "green": [(18, 36, 26), (32, 70, 46), (56, 116, 72), (96, 170, 104), (150, 220, 150), (206, 246, 196)],
    "amber": [(40, 22, 16), (86, 46, 22), (146, 84, 34), (204, 128, 54), (238, 178, 96), (252, 222, 160)],
}
TINT_LIGHT = {"color": (255, 206, 150), "bw": (190, 200, 220), "green": (120, 230, 140), "amber": (255, 170, 80)}

far = Canvas(W, H)
mid = Canvas(W, H)
scr = Canvas(W, H)
near = Canvas(W, H)
LIGHTS = []
YY, XX = np.mgrid[0:H, 0:W]


def setup(w, h, floor):
    """大地图脚本（crt_level3.py）复用这里的画法：换一块更大的画布。"""
    global W, H, FLOOR, far, mid, scr, near, YY, XX, LIGHTS
    W, H, FLOOR = w, h, floor
    far, mid, scr, near = Canvas(W, H), Canvas(W, H), Canvas(W, H), Canvas(W, H)
    YY, XX = np.mgrid[0:H, 0:W]
    LIGHTS = []


def rrect(x0, y0, x1, y1, r):
    out = np.zeros((H, W), bool)
    ys, xs = slice(max(0, y0), max(0, min(H, y1 + 1))), slice(max(0, x0), max(0, min(W, x1 + 1)))
    X, Y = XX[ys, xs], YY[ys, xs]
    m = np.ones(X.shape, bool)
    for cx, cy in [(x0 + r, y0 + r), (x1 - r, y0 + r), (x0 + r, y1 - r), (x1 - r, y1 - r)]:
        corner = ((X < x0 + r) if cx == x0 + r else (X > x1 - r)) & ((Y < y0 + r) if cy == y0 + r else (Y > y1 - r))
        m &= ~(corner & ((X - cx) ** 2 + (Y - cy) ** 2 > r * r + 0.5))
    out[ys, xs] = m
    return out


def ring_depth(x0, y0, x1, y1, r):
    d = np.full((H, W), -1)
    k = 0
    while x1 - k > x0 + k and y1 - k > y0 + k and k < 12:
        d[rrect(x0 + k, y0 + k, x1 - k, y1 - k, max(1, r - k // 2 + k // 3))] = k
        k += 1
    return d


def glare(x0, y0, x1, y1, c=None):
    c = c or scr
    n = max(3, min(x1 - x0, y1 - y0) // 7)
    for k, off in enumerate((0, 3)):
        for i in range(n - k * 2):
            c.put(x0 + 3 + off + i, y0 + 3 + n - i, GLARE)


def vignette(x0, y0, x1, y1, r, steps=((1, 0.55), (3, 0.72), (6, 0.86))):
    d = ring_depth(x0, y0, x1, y1, r)
    a = scr.a[..., :3].astype(float)
    for lim, f in reversed(steps):
        m = (d >= 0) & (d <= lim)
        a[m] *= f
    scr.a[..., :3] = np.clip(a, 0, 255).astype(np.uint8)


def scanlines(x0, y0, x1, y1, f=0.92):
    a = scr.a[..., :3].astype(float)
    a[y0:y1 + 1:2, x0:x1 + 1] *= f
    scr.a[..., :3] = a.astype(np.uint8)


def tint(m, ramp):
    """房间画完以后按亮度映射到这台电视的色阶上：黑白、绿荧光、琥珀都是这样来的。"""
    if ramp is None:
        return
    a = scr.a[..., :3].astype(float)
    L = (0.3 * a[..., 0] + 0.55 * a[..., 1] + 0.15 * a[..., 2]) / 255
    lo, hi = np.percentile(L[m], 3), np.percentile(L[m], 97)       # 按这个房间自己的明暗分档，不然会发白
    t = np.clip((L - lo) / max(1e-3, hi - lo), 0, 0.999) ** 1.15
    idx = (t * len(ramp)).astype(int)
    pal = np.array(ramp, np.uint8)
    scr.a[..., :3][m] = pal[idx[m]]


# ---------------------------------------------------------------- 外壳
def body(x0, y0, x1, y1, P, lip=6):
    h = y1 - y0
    mid.rect(x0, y0, x1, y1, P[1])
    mid.rect(x0, y0, x1, y0 + max(1, h // 10), P[0])
    mid.rect(x0, y0 + int(h * 0.55), x1, y1, P[2])
    mid.rect(x0, y1 - lip, x1, y1, P[3])
    mid.rect(x1 - 2, y0 + 1, x1 - 1, y1, P[4])
    mid.line(x0, y0, x1, y0, P[5]); mid.line(x0, y0, x0, y1, P[5])
    mid.line(x1, y0, x1, y1, P[6]); mid.line(x0, y1, x1, y1, P[6])


def recess(x0, y0, x1, y1, r):
    mid.fill_mask(rrect(x0 - 2, y0 - 2, x1 + 2, y1 + 2, r + 2), RECESS[2])
    mid.fill_mask(rrect(x0 - 2, y0 - 2, x1 + 1, y1 + 1, r + 2), RECESS[1])
    mid.fill_mask(rrect(x0 - 1, y0 - 1, x1 + 1, y1 + 1, r + 1), RECESS[0])


def knob(x, y, P):
    for dy in range(5):
        for dx in range(5):
            if (dx - 2) ** 2 + (dy - 2) ** 2 <= 5:
                mid.put(x + dx, y + dy, P[6] if dx + dy >= 5 else P[5])
    mid.put(x + 1, y + 1, P[2]); mid.put(x + 3, y + 2, P[0])


def controls(x0, x1, by, P, kind):
    """下边框的控制条，每台电视样子不一样。"""
    if kind == "speaker":
        for gy in range(by, by + 8, 2):
            for gx in range(x0 + (gy // 2) % 2, x0 + 30, 3):
                mid.put(gx, gy, P[5])
    if kind in ("speaker", "meter"):
        mid.rect(x0 + 38, by - 1, x0 + 74, by + 7, RECESS[0])
        mid.rect(x0 + 39, by, x0 + 73, by + 6, (38, 66, 54))
        for k, gx in enumerate(range(x0 + 42, x0 + 70, 5)):
            mid.rect(gx, by + 2, gx + 2, by + 4, (110, 206, 126) if k < 4 else (52, 92, 72))
    if kind == "buttons":
        for i in range(6):
            bx = x0 + 4 + i * 9
            mid.rect(bx, by + 1, bx + 6, by + 5, P[5]); mid.rect(bx, by + 1, bx + 5, by + 4, P[2])
            mid.line(bx, by + 1, bx + 5, by + 1, P[0])
    knob(x1 - 26, by, P); knob(x1 - 16, by, P)
    mid.put(x1 - 6, by + 2, LED_RED if kind == "buttons" else LED_GRN)


def screw(x, y, P):
    mid.put(x, y, P[3]); mid.put(x + 1, y + 1, P[5])


class TV:
    """一台电视。屏幕里是一个房间，房间地面 = 屏幕下沿往上 FLOOR_IN 格。"""
    FLOOR_IN = 10

    def __init__(self, x0, y0, w, h, P, ctrl, tintname, top=None):
        self.x0, self.y0, self.x1, self.y1 = x0, y0, x0 + w - 1, y0 + h - 1
        self.P, self.ctrl, self.tint, self.top = P, ctrl, tintname, top
        self.sx0, self.sy0 = self.x0 + 8, self.y0 + 8
        self.sx1, self.sy1 = self.x1 - 8, self.y1 - 17
        self.fy = self.sy1 - self.FLOOR_IN       # 房间地面，也就是主角站的高度

    def draw_shell(self):
        P = self.P
        body(self.x0, self.y0, self.x1, self.y1, P, lip=10)
        recess(self.sx0, self.sy0, self.sx1, self.sy1, 5)
        controls(self.sx0, self.sx1, self.y1 - 12, P, self.ctrl)
        for x, y in [(self.x0 + 3, self.y0 + 3), (self.x1 - 4, self.y0 + 3), (self.x0 + 3, self.y1 - 4), (self.x1 - 4, self.y1 - 4)]:
            screw(x, y, P)
        if self.top == "vents":
            for i in range(8):
                vx = (self.x0 + self.x1) // 2 - 40 + i * 10
                mid.rect(vx, self.y0 + 3, vx + 6, self.y0 + 4, P[5]); mid.line(vx, self.y0 + 5, vx + 6, self.y0 + 5, P[0])

    def screen_mask(self):
        return rrect(self.sx0, self.sy0, self.sx1, self.sy1, 5)


# ---------------------------------------------------------------- 房间：墙、地板、光
def room_base(tv, wallc, floorc, lamp, wainscot=None):
    set_vp(tv)
    x0, y0, x1, y1, fy = tv.sx0, tv.sy0, tv.sx1, tv.sy1, tv.fy
    rw = x1 - x0 + 1
    inside = tv.screen_mask()
    dist = np.hypot((XX - lamp[0]) * 0.8, (YY - lamp[1]) * 1.1) + ((XX // 7 + YY // 5) % 3) * 2.5
    band = np.clip((dist / (rw * 0.16)).astype(int), 0, len(wallc) - 1)
    wall = inside & (YY < fy)
    for i, c in enumerate(wallc):
        scr.fill_mask(wall & (band == i), c)
    if wainscot:
        scr.fill_mask(inside & (YY >= fy - 8) & (YY < fy), wainscot[0])
        scr.fill_mask(inside & (YY == fy - 8), wainscot[1])
    fl = inside & (YY >= fy)
    fband = np.clip(((np.abs(XX - lamp[0]) * 0.5 + (YY - fy) * 2.2) / (rw * 0.12)).astype(int), 0, len(floorc) - 1)
    for i, c in enumerate(floorc):
        scr.fill_mask(fl & (fband == i), c)
    for gy in range(fy + 3, y1, 4):
        for gx in range(x0 + (gy * 7) % 11, x1, 23):
            scr.line(gx, gy, min(x1, gx + 12), gy, floorc[-1])
    scr.line(x0, fy, x1, fy, floorc[0])


def window(x0, y0, w, h, frame=(138, 108, 112), moon=True):
    scr.rect(x0 - 2, y0 - 2, x0 + w + 2, y0 + h + 3, frame)
    scr.rect(x0, y0, x0 + w, y0 + h, (54, 62, 104))
    scr.rect(x0, y0 + h // 2, x0 + w, y0 + h, (62, 72, 116))
    scr.line(x0, y0 + h // 2, x0 + w, y0 + h // 2, frame)
    scr.line(x0 + w // 2, y0, x0 + w // 2, y0 + h, frame)
    if moon:
        scr.rect(x0 + w - 6, y0 + 3, x0 + w - 4, y0 + 5, (226, 222, 196))
    for sx, sy in [(x0 + 3, y0 + 4), (x0 + 8, y0 + 2), (x0 + w - 8, y0 + h - 5)]:
        scr.put(sx, sy, (180, 186, 220))


def crew_photo(x, y):
    """墙上的合照：四个船员（红、铜、蓝、绿）。每个房间都挂一张，是这一关的线索。"""
    scr.rect(x - 2, y - 2, x + 21, y + 13, (112, 84, 80))
    scr.rect(x, y, x + 19, y + 11, (226, 214, 180))
    scr.rect(x, y + 7, x + 19, y + 11, (196, 196, 156))
    for i, c in enumerate([(206, 72, 64), (190, 140, 96), (96, 136, 214), (110, 180, 100)]):
        fx = x + 2 + i * 5
        scr.rect(fx, y + 3, fx + 2, y + 9, c)
        scr.put(fx + 1, y + 2, c)


# ---------------------------------------------------------------- 体积：照 Oscar 的家具，每件都有侧面和顶面
VP = [0, 0]          # 当前这块屏幕的灭点（屏幕中间、视线高度）
_SHADE = {}


def set_vp(tv):
    VP[0] = (tv.sx0 + tv.sx1) // 2
    VP[1] = tv.sy0 + int((tv.fy - tv.sy0) * 0.42)


def shade(c, k):
    """c 往亮（k>0，偏暖）或往暗（k<0，偏冷）挪 k 档，一档约 0.045 OKLab。"""
    key = (tuple(c[:3]), int(k))
    if key not in _SHADE:
        _SHADE[key] = step_color(c[:3], k) if k else tuple(c[:3])
    return _SHADE[key]


def extrude(pts, front, depth=0.07, side=None, top=None, under=None, cap=9):
    """把一个正面多边形朝灭点挤出厚度：灭点左边的东西露右侧面，比视线低的露顶面。"""
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    # 小东西的厚度跟着自己的大小收：一个 7×2 的灯座不能挤出 9 格厚，会变成一块歪木板
    span = min(max(p[0] for p in pts) - min(p[0] for p in pts), max(p[1] for p in pts) - min(p[1] for p in pts))
    cap = int(min(cap, max(1, span // 2 + 1)))
    ox = int(np.clip(round((VP[0] - cx) * depth), -cap, cap))
    oy = int(np.clip(round((VP[1] - cy) * depth), -cap, cap))
    side = side or shade(front, -2)
    top = top or shade(front, 1)
    under = under or shade(front, -3)
    vq, hq = [], []
    for i in range(len(pts)):
        p, q = pts[i], pts[(i + 1) % len(pts)]
        nx, ny = q[1] - p[1], -(q[0] - p[0])                   # 边的法线，朝外
        if nx * ((p[0] + q[0]) / 2 - cx) + ny * ((p[1] + q[1]) / 2 - cy) < 0:
            nx, ny = -nx, -ny
        if nx * ox + ny * oy <= 0:                             # 往里挤的边看不见
            continue
        quad = [p, q, (q[0] + ox, q[1] + oy), (p[0] + ox, p[1] + oy)]
        (vq if abs(q[1] - p[1]) > abs(q[0] - p[0]) else hq).append(quad)
    for quad in vq:
        scr.poly(quad, side)
    for quad in hq:
        scr.poly(quad, top if oy < 0 else under)
    return scr.poly(pts, front)


def box(x0, y0, x1, y1, front, **kw):
    """含端点的矩形，挤出厚度。"""
    return extrude([(x0, y0), (x1 + 1, y0), (x1 + 1, y1 + 1), (x0, y1 + 1)], front, **kw)


def panel(x0, y0, x1, y1, base):
    """柜门、抽屉这种嵌进去的面板：上、左一道暗缝，下、右一道亮边。"""
    scr.rect(x0, y0, x1, y1, shade(base, -1))
    scr.line(x0, y0, x1, y0, shade(base, -3)); scr.line(x0, y0, x0, y1, shade(base, -3))
    scr.line(x0 + 1, y1, x1, y1, shade(base, 1)); scr.line(x1, y0 + 1, x1, y1, shade(base, 1))


def floor_shadow(x0, x1, fy, depth=3):
    """家具脚下一块柔和的影子，往背光那边拖一点。"""
    a = scr.a
    for dy in range(depth):
        xa, xb = max(0, x0 - 1 + dy), min(W - 1, x1 + 3 + dy * 2)
        y = fy + 1 + dy
        if 0 <= y < H:
            seg = a[y, xa:xb + 1, :3].astype(float) * (0.78 + dy * 0.06)
            a[y, xa:xb + 1, :3] = seg.astype(np.uint8)


def floor_lamp(x, fy, top):
    floor_shadow(x - 4, x + 4, fy)
    scr.line(x, top + 6, x, fy, (90, 70, 70)); scr.line(x + 1, top + 6, x + 1, fy, (70, 56, 60))
    box(x - 3, fy - 1, x + 3, fy, (90, 70, 70))
    scr.poly([(x - 6, top + 6), (x + 7, top + 6), (x + 4, top - 4), (x - 3, top - 4)], (246, 226, 168))
    scr.poly([(x + 2, top + 6), (x + 7, top + 6), (x + 4, top - 4), (x + 2, top - 4)], (232, 204, 150))
    scr.line(x - 6, top + 6, x + 6, top + 6, (252, 240, 200))


def hanging_lamp(x, ceil, y):
    """吊灯：电线、灯罩（朝光一侧亮、背光一侧暗、底边一道深色口沿）、贴着灯罩的灯泡。
    灯罩亮面和灯泡都是发光色（最亮通道 ≥ 240），光照色块不会改它，在什么色调的屏幕里都和墙分得开。"""
    scr.line(x, ceil, x, y - 5, (70, 56, 60))
    scr.rect(x - 1, y - 5, x + 1, y - 4, (90, 72, 70))                            # 灯头
    scr.poly([(x - 8, y + 3), (x + 9, y + 3), (x + 4, y - 4), (x - 3, y - 4)], (244, 222, 168))
    scr.poly([(x + 3, y + 3), (x + 9, y + 3), (x + 4, y - 4), (x + 2, y - 4)], (190, 160, 122))
    scr.line(x - 8, y + 2, x + 8, y + 2, (120, 96, 84))                          # 灯罩口沿
    scr.rect(x - 2, y + 3, x + 2, y + 4, (255, 244, 204))                        # 灯泡贴着灯罩


def sofa(x0, x1, fy):
    c = (88, 114, 118)
    floor_shadow(x0, x1, fy, 4)
    box(x0 + 3, fy - 21, x1 - 3, fy - 10, shade(c, 1))                    # 靠背
    for cx in range(x0 + 4, x1 - 4, max(8, (x1 - x0) // 3)):
        scr.line(cx, fy - 20, cx, fy - 11, shade(c, -1))
    box(x0, fy - 11, x1, fy, c)                                           # 坐垫
    scr.line(x0 + 1, fy - 11, x1 - 1, fy - 11, shade(c, 2))
    scr.line((x0 + x1) // 2, fy - 10, (x0 + x1) // 2, fy - 1, shade(c, -2))
    box(x0 - 1, fy - 16, x0 + 5, fy, shade(c, -1))                         # 扶手
    box(x1 - 5, fy - 16, x1 + 1, fy, shade(c, 1))
    scr.line(x1 - 5, fy - 16, x1, fy - 16, shade(c, 3))
    scr.rect(x0 + 1, fy - 1, x0 + 2, fy, (60, 44, 44)); scr.rect(x1 - 2, fy - 1, x1 - 1, fy, (60, 44, 44))


def rug(cx, fy, rx, c=(150, 116, 140), c2=(168, 132, 150)):
    m = (XX - cx) ** 2 / rx ** 2 + (YY - (fy + 5)) ** 2 / 4.0 ** 2 <= 1
    scr.fill_mask(m, c)
    scr.fill_mask(m & (XX > cx + rx * 0.3), c2)
    scr.fill_mask(m & (YY >= fy + 8), shade(c, -1))


def small_tv(x, fy):
    floor_shadow(x, x + 14, fy)
    box(x, fy - 8, x + 14, fy, (122, 84, 72))
    panel(x + 2, fy - 6, x + 6, fy - 2, (122, 84, 72)); panel(x + 8, fy - 6, x + 12, fy - 2, (122, 84, 72))
    box(x + 2, fy - 18, x + 12, fy - 9, (176, 168, 150))
    scr.rect(x + 3, fy - 17, x + 9, fy - 11, (120, 150, 196)); scr.put(x + 4, fy - 16, (176, 200, 230))
    scr.put(x + 11, fy - 12, LED_RED)
    scr.line(x + 6, fy - 19, x + 2, fy - 24, (90, 80, 80)); scr.line(x + 8, fy - 19, x + 12, fy - 25, (90, 80, 80))


def fridge(x, fy, w=20, h=46):
    c = (214, 214, 204)
    floor_shadow(x, x + w, fy, 4)
    box(x, fy - h, x + w, fy, c)
    scr.line(x, fy - h + 16, x + w, fy - h + 16, shade(c, -3))
    scr.line(x, fy - h + 17, x + w, fy - h + 17, shade(c, 1))
    scr.rect(x + 2, fy - h + 5, x + 3, fy - h + 12, shade(c, -4)); scr.put(x + 2, fy - h + 5, shade(c, 2))
    scr.rect(x + 2, fy - h + 20, x + 3, fy - h + 30, shade(c, -4)); scr.put(x + 2, fy - h + 20, shade(c, 2))
    scr.rect(x + 7, fy - h + 4, x + 11, fy - h + 8, (232, 200, 120))     # 冰箱贴
    scr.rect(x + 9, fy - h + 22, x + 14, fy - h + 27, (226, 214, 180))    # 小孩的画
    scr.line(x + 10, fy - h + 25, x + 13, fy - h + 24, (96, 136, 214)); scr.put(x + 11, fy - h + 23, (206, 72, 64))
    scr.rect(x + 1, fy - 2, x + w - 1, fy, shade(c, -3))


def table_chairs(x0, fy, w=40):
    wood = (150, 104, 82)
    top = fy - 14
    floor_shadow(x0, x0 + w, fy, 3)
    for cx, d in [(x0 - 9, -1), (x0 + w + 4, 1)]:                         # 椅子
        bx = cx if d < 0 else cx + 5
        box(bx, fy - 23, bx + 1, fy, shade(wood, -1))
        box(cx, fy - 10, cx + 6, fy - 8, shade(wood, -1))
        scr.rect(cx + (5 if d < 0 else 0), fy - 7, cx + (6 if d < 0 else 1), fy, shade(wood, -2))
    scr.rect(x0 + 3, top + 3, x0 + 4, fy, shade(wood, -2)); scr.rect(x0 + w - 4, top + 3, x0 + w - 3, fy, shade(wood, -2))
    box(x0, top, x0 + w, top + 2, wood)
    scr.rect(x0 + 2, top - 1, x0 + w - 2, top - 1, (226, 214, 200))       # 桌布
    # 桌上：一个蛋糕，四根蜡烛
    box(x0 + 14, top - 6, x0 + 26, top - 1, (232, 210, 200))
    scr.line(x0 + 14, top - 4, x0 + 26, top - 4, (206, 130, 140))
    for k_ in range(4):
        scr.put(x0 + 16 + k_ * 3, top - 9, (252, 226, 150)); scr.put(x0 + 16 + k_ * 3, top - 8, (220, 120, 120)); scr.put(x0 + 16 + k_ * 3, top - 7, (220, 120, 120))


def counter(x0, x1, fy):
    c = (176, 160, 146)
    floor_shadow(x0, x1, fy, 3)
    box(x0, fy - 16, x1, fy, c)
    for dx in range(x0 + 3, x1 - 9, 13):
        panel(dx, fy - 13, dx + 10, fy - 2, c); scr.put(dx + 8, fy - 8, shade(c, -5))
    box(x0 - 1, fy - 19, x1 + 1, fy - 17, (214, 204, 190))               # 台面
    scr.rect(x0 + 6, fy - 22, x0 + 12, fy - 20, (140, 150, 170)); scr.rect(x0 + 8, fy - 25, x0 + 9, fy - 23, (180, 184, 196))   # 水壶
    box(x0, fy - 60, x1, fy - 44, c)                                      # 墙上的吊柜：比视线高，露底面
    for dx in range(x0 + 3, x1 - 9, 13):
        panel(dx, fy - 57, dx + 10, fy - 47, c)
    for k_ in range(3):                                                   # 吊柜下挂着的杯子
        scr.rect(x0 + 18 + k_ * 6, fy - 41, x0 + 20 + k_ * 6, fy - 39, [(206, 120, 110), (110, 150, 200), (220, 200, 130)][k_])


def bed(x0, fy, w=50):
    wood, quilt = (118, 84, 72), (130, 140, 186)
    floor_shadow(x0, x0 + w, fy, 4)
    box(x0, fy - 27, x0 + 4, fy, wood)                                   # 床头
    scr.rect(x0 + 1, fy - 25, x0 + 3, fy - 25, shade(wood, 2))
    box(x0 + 4, fy - 5, x0 + w, fy - 3, wood)
    box(x0 + 4, fy - 12, x0 + w, fy - 6, (220, 214, 204))                 # 床垫
    box(x0 + 5, fy - 16, x0 + 16, fy - 12, (236, 232, 222), depth=0.04)   # 枕头
    box(x0 + 18, fy - 14, x0 + w, fy - 7, quilt)                          # 被子
    for qx in range(x0 + 22, x0 + w, 8):
        scr.line(qx, fy - 13, qx + 2, fy - 8, shade(quilt, -1))
    scr.rect(x0 + w - 2, fy - 3, x0 + w, fy, wood); scr.rect(x0 + 4, fy - 3, x0 + 6, fy, wood)


def wardrobe(x, fy, w=28, h=54):
    c = (140, 100, 82)
    floor_shadow(x, x + w, fy, 4)
    box(x, fy - h, x + w, fy, c)
    panel(x + 2, fy - h + 4, x + w // 2 - 1, fy - 6, c); panel(x + w // 2 + 1, fy - h + 4, x + w - 2, fy - 6, c)
    scr.put(x + w // 2 - 3, fy - h // 2, (226, 196, 130)); scr.put(x + w // 2 + 3, fy - h // 2, (226, 196, 130))
    box(x - 1, fy - h - 2, x + w + 1, fy - h, shade(c, 1))               # 顶檐
    box(x + 4, fy - h - 9, x + 14, fy - h - 3, (196, 170, 130))           # 上面放着的纸箱


def bunk(x0, fy, w=44):
    post = (124, 92, 78)
    floor_shadow(x0, x0 + w, fy, 4)
    for by, quilt in [(fy - 6, (200, 120, 110)), (fy - 30, (110, 160, 200))]:
        box(x0 + 2, by, x0 + w, by + 2, post)
        box(x0 + 2, by - 6, x0 + w, by - 1, (224, 218, 206))
        box(x0 + 14, by - 8, x0 + w, by - 3, quilt)
        box(x0 + 3, by - 9, x0 + 11, by - 6, (240, 236, 228), depth=0.04)
    box(x0, fy - 50, x0 + 2, fy, post); box(x0 + w, fy - 50, x0 + w + 2, fy, post)
    for k_ in range(5):                                                   # 梯子
        scr.line(x0 + w - 8, fy - 6 - k_ * 5, x0 + w - 2, fy - 6 - k_ * 5, shade(post, 1))
    scr.line(x0 + w - 8, fy - 30, x0 + w - 8, fy, post)


def rocket(x, fy):
    floor_shadow(x - 3, x + 10, fy)
    box(x, fy - 18, x + 6, fy - 4, (226, 222, 210), depth=0.04)
    scr.poly([(x, fy - 18), (x + 7, fy - 18), (x + 3, fy - 25)], (206, 72, 64))
    scr.poly([(x + 4, fy - 18), (x + 7, fy - 18), (x + 3, fy - 25)], (176, 56, 56))
    disc_ = (XX - (x + 3)) ** 2 + (YY - (fy - 13)) ** 2 <= 2.5
    scr.fill_mask(disc_, (96, 136, 214)); scr.put(x + 2, fy - 14, (176, 206, 240))
    scr.poly([(x - 3, fy), (x, fy - 7), (x, fy)], (206, 72, 64)); scr.poly([(x + 7, fy - 7), (x + 10, fy), (x + 7, fy)], (176, 56, 56))


def stars(x0, y0, x1, y1, n=9):
    for _ in range(n):
        sx, sy = random.randint(x0, x1), random.randint(y0, y1)
        for dx, dy in [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)]:
            scr.put(sx + dx, sy + dy, (246, 230, 150))
        scr.put(sx + 1, sy + 1, (200, 180, 110))


def bookshelf(x, fy, w=34, h=58):
    wood = (118, 84, 72)
    floor_shadow(x, x + w, fy, 4)
    box(x, fy - h, x + w, fy, wood)
    cols = [(180, 84, 80), (96, 120, 170), (200, 180, 120), (110, 150, 110), (150, 110, 160), (220, 210, 190)]
    for sy in range(fy - h + 3, fy - 2, 14):
        scr.rect(x + 2, sy, x + w - 2, sy + 11, (64, 46, 46))
        scr.rect(x + 2, sy, x + w - 2, sy + 1, (50, 36, 38))
        bx = x + 3
        while bx < x + w - 4:
            bw = random.choice([2, 3, 3, 4])
            bh = random.choice([8, 9, 10, 11])
            c = random.choice(cols)
            scr.rect(bx, sy + 11 - bh, min(x + w - 3, bx + bw - 1), sy + 10, c)
            scr.line(bx, sy + 11 - bh, bx, sy + 10, shade(c, 1))
            if bw >= 3:
                scr.put(bx + 1, sy + 13 - bh, shade(c, 3))
            bx += bw + (1 if random.random() < 0.2 else 0)
        scr.rect(x + 1, sy + 11, x + w - 1, sy + 12, shade(wood, 2))


def wall_clock(cx, cy, r=7):
    scr.fill_mask((XX - cx - 1) ** 2 + (YY - cy - 1) ** 2 <= r * r, (60, 44, 50))
    scr.fill_mask((XX - cx) ** 2 + (YY - cy) ** 2 <= r * r, (112, 84, 80))
    scr.fill_mask((XX - cx) ** 2 + (YY - cy) ** 2 <= (r - 2) ** 2, (236, 228, 206))
    scr.fill_mask(((XX - cx) ** 2 + (YY - cy) ** 2 <= (r - 2) ** 2) & (XX > cx + 1) & (YY > cy + 1), (214, 204, 186))
    scr.line(cx, cy, cx, cy - r + 3, (60, 50, 50)); scr.line(cx, cy, cx + 3, cy + 1, (60, 50, 50))


def armchair(x, fy):
    c = (150, 90, 84)
    floor_shadow(x - 2, x + 20, fy, 4)
    box(x, fy - 23, x + 18, fy - 9, c)
    scr.line(x + 9, fy - 22, x + 9, fy - 10, shade(c, -1))
    box(x - 2, fy - 12, x + 20, fy, shade(c, -1))
    box(x - 3, fy - 16, x + 2, fy, shade(c, -2)); box(x + 16, fy - 16, x + 21, fy, shade(c, 1))
    scr.line(x, fy - 23, x + 18, fy - 23, shade(c, 2))
    box(x + 4, fy - 15, x + 10, fy - 12, (220, 206, 170), depth=0.03)    # 椅子上的毛毯


def front_door(x, fy, w=24, h=48):
    c = (116, 74, 64)
    box(x - 3, fy - h - 3, x + w + 3, fy, (150, 120, 112), depth=0.03)
    scr.rect(x, fy - h, x + w, fy, shade(c, -3))
    scr.rect(x + 1, fy - h + 1, x + w, fy, c)
    panel(x + 4, fy - h + 20, x + w - 4, fy - h + 30, c); panel(x + 4, fy - h + 34, x + w - 4, fy - 4, c)
    scr.rect(x + 5, fy - h + 5, x + w - 6, fy - h + 16, (226, 200, 150))    # 门上的小窗透着光
    scr.rect(x + 5, fy - h + 5, x + w - 6, fy - h + 6, (252, 236, 190))
    scr.line(x + w // 2 - 1, fy - h + 5, x + w // 2 - 1, fy - h + 16, c)
    scr.rect(x + w - 6, fy - h // 2, x + w - 4, fy - h // 2 + 1, (226, 200, 120)); scr.put(x + w - 6, fy - h // 2, (252, 236, 180))
    box(x - 2, fy - 1, x + w + 2, fy, (150, 110, 140))                    # 门垫


def coat_rack(x, fy):
    floor_shadow(x - 5, x + 6, fy)
    scr.line(x, fy - 44, x, fy, (100, 72, 64)); scr.line(x + 1, fy - 44, x + 1, fy, (80, 58, 54))
    box(x - 4, fy - 1, x + 4, fy, (100, 72, 64))
    for dx, c, top in [(-5, (206, 72, 64), 40), (3, (96, 136, 214), 42), (-3, (110, 180, 100), 34)]:
        scr.rect(x + dx, fy - top, x + dx + 4, fy - top + 16, c)            # 四个人的外套
        scr.line(x + dx, fy - top, x + dx, fy - top + 16, shade(c, 1))
        scr.line(x + dx + 4, fy - top + 2, x + dx + 4, fy - top + 16, shade(c, -2))
    scr.rect(x + 1, fy - 38, x + 5, fy - 24, (190, 140, 96)); scr.line(x + 5, fy - 36, x + 5, fy - 24, shade((190, 140, 96), -2))


def shoes(x, fy):
    for k_, c in enumerate([(206, 72, 64), (190, 140, 96), (96, 136, 214), (110, 180, 100)]):
        scr.rect(x + k_ * 7, fy - 2, x + k_ * 7 + 4, fy, c)
        scr.put(x + k_ * 7, fy - 3, c); scr.put(x + k_ * 7 + 1, fy - 2, shade(c, 2)); scr.put(x + k_ * 7 + 4, fy, shade(c, -2))


def plant(x, fy):
    pot = (176, 110, 86)
    floor_shadow(x, x + 8, fy)
    for dx, h in [(1, 16), (4, 22), (7, 14)]:
        scr.line(x + 4, fy - 8, x + dx, fy - 8 - h, (96, 150, 104))
        scr.rect(x + dx - 1, fy - 9 - h, x + dx + 1, fy - 6 - h, (120, 176, 120))
        scr.put(x + dx + 1, fy - 6 - h, (90, 140, 100)); scr.put(x + dx - 1, fy - 9 - h, (150, 200, 140))
    box(x, fy - 7, x + 8, fy, pot, depth=0.04)
    scr.line(x, fy - 7, x + 8, fy - 7, shade(pot, 2))


def light_pass(tv, light_at, gain=2.6, amp=0.9, cell=9, min_px=160, seed=0):
    """Oscar 的色块：每个大面按离场景光源的远近切成一档一档，档的边是直线段（三角网格），
    再加一点低频扰动让边缘有棱角。发光的东西（最亮通道 >= 240）不动；
    小于 min_px 的颜色（灯罩、相框、小摆件）也不动，不然小东西会被切碎、和墙糊在一起。"""
    x0, y0, x1, y1 = tv.sx0, tv.sy0, tv.sx1, tv.sy1
    h, w = y1 - y0 + 1, x1 - x0 + 1
    sub = scr.a[y0:y1 + 1, x0:x1 + 1]
    m = tv.screen_mask()[y0:y1 + 1, x0:x1 + 1]
    Y, X = np.mgrid[0:h, 0:w]
    d = np.hypot(X + x0 - light_at[0], (Y + y0 - light_at[1]) * 1.1) / max(w, h)
    F = -gain * d + amp * smooth_noise(h, w, sx=22, sy=16, seed=seed)
    F = polygonal(F, cell, cell * 0.8, seed=seed)
    key = (sub[..., 0].astype(np.int64) << 16) | (sub[..., 1].astype(np.int64) << 8) | sub[..., 2]
    for kv in np.unique(key[m]):
        col = ((kv >> 16) & 255, (kv >> 8) & 255, kv & 255)
        if max(col) >= 240:
            continue
        sel = (key == kv) & m
        if sel.sum() < min_px:
            continue
        kk = np.clip(np.round(F[sel] - F[sel].mean()), -2, 2).astype(int)
        out = np.array([shade(col, v) for v in range(-2, 3)], np.uint8)[kk + 2]
        sub[..., :3][sel] = out


def static_band(tv, y0, y1):
    """回忆坏掉的地方：几行雪花横穿房间。"""
    m = tv.screen_mask() & (YY >= y0) & (YY <= y1)
    ys, xs = np.nonzero(m)
    tones = [(96, 104, 124), (140, 150, 168), (196, 204, 220)]
    pick = rng.choice(3, size=len(ys), p=[0.45, 0.35, 0.2])
    for y, x, k in zip(ys, xs, pick):
        scr.put(x, y, tones[k])
    # 撕裂：雪花下面几行整体往右错 3 格
    seg = scr.a[y1 + 1:y1 + 4, tv.sx0:tv.sx1 - 3].copy()
    scr.a[y1 + 1:y1 + 4, tv.sx0 + 3:tv.sx1] = seg


## 同一种场景第二、三次出现时的变化（crt_level3.py 在画之前填）：mirror 左右镜像，hue 彩色屏的色相偏移（度）
VARIANT = {"mirror": False, "hue": 0.0}


def mirror_screen(tv):
    """把屏幕里的画面左右翻过来（在上色、扫描线、反光之前做，反光还在左上角）。"""
    m = tv.screen_mask()
    ys, xs = np.nonzero(m)
    a = scr.a.copy()
    scr.a[ys, xs] = a[ys, tv.sx0 + tv.sx1 - xs]


def hue_shift(tv, deg):
    from oscarkit.measure import srgb_to_oklab
    from oscarkit.palette import oklab_to_srgb
    m = tv.screen_mask() & (scr.a[..., 3] > 0)
    px = scr.a[..., :3][m]
    keys, inv = np.unique(px, axis=0, return_inverse=True)
    lab = srgb_to_oklab(keys.astype(np.uint8))
    C, h = np.hypot(lab[:, 1], lab[:, 2]), np.arctan2(lab[:, 2], lab[:, 1]) + np.radians(deg)
    new = oklab_to_srgb(np.stack([lab[:, 0], C * np.cos(h), C * np.sin(h)], 1))
    scr.a[..., :3][m] = new[inv.ravel()]


def finish_room(tv, light_at):
    m = tv.screen_mask()
    if VARIANT["mirror"] and not getattr(tv, "flat", False):   # 测试卡、天气预报上有字，不翻
        mirror_screen(tv)
        light_at = (tv.sx0 + tv.sx1 - light_at[0], light_at[1])
    if VARIANT["hue"] and tv.tint == "color":
        hue_shift(tv, VARIANT["hue"])
    if not getattr(tv, "flat", False):
        light_pass(tv, light_at, seed=tv.sx0 % 97)
    tint(m, TINTS[tv.tint])
    scanlines(tv.sx0, tv.sy0, tv.sx1, tv.sy1)
    vignette(tv.sx0, tv.sy0, tv.sx1, tv.sy1, 5)
    glare(tv.sx0, tv.sy0, tv.sx1, tv.sy1)
    rw = tv.sx1 - tv.sx0
    LIGHTS.append(((tv.sx0 + tv.sx1) / 2, tv.sy1, rw * 0.95, TINT_LIGHT[tv.tint], 0.7))
    LIGHTS.append((light_at[0], light_at[1], rw * 0.45, TINT_LIGHT[tv.tint], 0.35))


WARM_WALL = [(214, 178, 150), (196, 160, 140), (176, 142, 132), (150, 120, 122), (124, 100, 112)]
WARM_FLOOR = [(170, 120, 92), (150, 104, 82), (128, 88, 74), (104, 72, 66)]
TILE_FLOOR = [(206, 200, 186), (180, 172, 160), (150, 142, 136), (120, 112, 112)]
BLUE_WALL = [(176, 190, 206), (156, 170, 192), (136, 148, 176), (114, 124, 156), (94, 100, 134)]
GREEN_WALL = [(196, 214, 176), (176, 196, 160), (154, 176, 144), (130, 150, 128), (106, 124, 112)]


def room_kitchen(tv):
    """厨房（木壳彩电）：冰箱、橱柜、桌上一个插了四根蜡烛的蛋糕。"""
    fy, x0, x1 = tv.fy, tv.sx0, tv.sx1
    lamp = ((x0 + x1) // 2 + 10, tv.sy0 + 30)
    room_base(tv, [(222, 206, 160), (206, 188, 146), (186, 166, 132), (160, 140, 120), (132, 114, 108)], TILE_FLOOR, lamp)
    for gx in range(x0, x1, 8):                                        # 地砖缝
        scr.line(gx, fy + 1, gx, tv.sy1, (150, 142, 136))
    counter(x0 + 6, x0 + 50, fy)
    fridge(x1 - 34, fy)
    table_chairs((x0 + x1) // 2 - 4, fy, 36)
    hanging_lamp(lamp[0], tv.sy0, lamp[1])
    crew_photo(x0 + 66, tv.sy0 + 22)
    finish_room(tv, lamp)


def room_living(tv):
    """客厅（米色监控屏，彩色）：沙发、落地灯、窗、合照、小电视。"""
    fy, x0, x1 = tv.fy, tv.sx0, tv.sx1
    rw = x1 - x0
    lamp = (x0 + int(rw * 0.8), tv.sy0 + 32)
    room_base(tv, WARM_WALL, WARM_FLOOR, lamp, wainscot=((150, 112, 104), (186, 146, 128)))
    window(x0 + 12, tv.sy0 + 14, 26, 32)
    crew_photo(x0 + int(rw * 0.38), tv.sy0 + 18)
    rug(x0 + int(rw * 0.4), fy, rw * 0.3)
    sofa(x0 + int(rw * 0.22), x0 + int(rw * 0.58), fy)
    small_tv(x0 + int(rw * 0.62), fy)
    floor_lamp(lamp[0], fy, lamp[1])
    finish_room(tv, lamp)


def room_bedroom(tv):
    """卧室（灰色监控屏，黑白）：大床、衣柜、窗外的月亮。"""
    fy, x0, x1 = tv.fy, tv.sx0, tv.sx1
    rw = x1 - x0
    win = (x0 + int(rw * 0.42), tv.sy0 + 14)
    room_base(tv, BLUE_WALL, WARM_FLOOR, (win[0] + 12, win[1] + 16))
    window(win[0], win[1], 26, 30)
    bed(x0 + 8, fy, 54)
    wardrobe(x1 - 38, fy)
    crew_photo(x0 + 14, tv.sy0 + 16)
    rug(win[0] + 12, fy, 16, (120, 110, 150), (140, 130, 168))
    finish_room(tv, (win[0] + 12, win[1] + 16))


def room_kids(tv):
    """儿童房（梅子色电视，绿荧光）：上下铺、玩具火箭、墙上的星星贴纸。"""
    fy, x0, x1 = tv.fy, tv.sx0, tv.sx1
    rw = x1 - x0
    lamp = (x0 + int(rw * 0.55), tv.sy0 + 26)
    room_base(tv, GREEN_WALL, WARM_FLOOR, lamp)
    stars(x0 + 60, tv.sy0 + 8, x1 - 12, tv.sy0 + 40, 8)
    bunk(x0 + 10, fy, 46)
    rocket(x0 + int(rw * 0.56), fy)
    hanging_lamp(lamp[0], tv.sy0, lamp[1])
    crew_photo(x1 - 40, tv.sy0 + 34)
    plant(x1 - 18, fy)
    finish_room(tv, lamp)


def room_study(tv):
    """书房（米色电视，琥珀单色屏）：书架、挂钟、扶手椅、台灯。"""
    fy, x0, x1 = tv.fy, tv.sx0, tv.sx1
    rw = x1 - x0
    lamp = (x0 + int(rw * 0.7), tv.sy0 + 36)
    room_base(tv, WARM_WALL, WARM_FLOOR, lamp, wainscot=((150, 112, 104), (186, 146, 128)))
    bookshelf(x0 + 8, fy)
    bookshelf(x0 + 44, fy, 26, 46)
    wall_clock(x0 + int(rw * 0.56), tv.sy0 + 18)
    armchair(x0 + int(rw * 0.74), fy)
    floor_lamp(lamp[0] - 10, fy, lamp[1])
    crew_photo(x1 - 30, tv.sy0 + 12)
    finish_room(tv, lamp)


def room_entry(tv):
    """玄关（木壳小电视，彩色，信号最差）：大门、衣帽架上四件外套、门口四双鞋。离家最近，也坏得最厉害。"""
    fy, x0, x1 = tv.fy, tv.sx0, tv.sx1
    rw = x1 - x0
    lamp = (x0 + int(rw * 0.5), tv.sy0 + 22)
    room_base(tv, WARM_WALL, WARM_FLOOR, lamp, wainscot=((150, 112, 104), (186, 146, 128)))
    front_door(x0 + int(rw * 0.4), fy)
    coat_rack(x0 + 16, fy)
    shoes(x0 + 26, fy)
    plant(x1 - 22, fy)
    hanging_lamp(lamp[0] + 2, tv.sy0, lamp[1])
    static_band(tv, tv.sy0 + 34, tv.sy0 + 41)
    static_band(tv, fy - 10, fy - 8)
    finish_room(tv, lamp)


# ---------------------------------------------------------------- 打通：通道和洞
def side_passage(left, right, h=24):
    """左右两台电视之间的外壳砸穿，开一条齐地面的通道。里面露出显像管的内脏：电路板、电线。"""
    fy = left.fy
    xa, xb = left.sx1 - 2, right.sx0 + 2
    y0 = fy - h
    # 外壳上的洞（吃光照，画在中景）
    mid.rect(xa, y0, xb, fy + 2, RECESS[0])
    mid.rect(xa, y0, xb, y0 + 1, RECESS[1])
    for x in range(xa - 2, xb + 3):                                     # 砸出来的边，参差不齐
        for k in range((x * 7) % 4):
            mid.put(x, y0 - 1 - k, RECESS[1] if k == 0 else RECESS[2])
    mid.rect(xa, fy - 3, xb, fy + 2, PCB[0])                            # 地面是一块电路板
    mid.line(xa, fy - 3, xb, fy - 3, PCB[2])
    for x in range(xa + 2, xb - 1, 4):
        mid.put(x, fy - 1, COPPER)
    for k, (c, sag) in enumerate([((168, 76, 72), 6), ((90, 110, 170), 9), ((200, 176, 110), 4)]):
        for x in range(xa, xb + 1):
            t = (x - xa) / max(1, xb - xa)
            mid.put(x, y0 + 3 + k * 2 + round(sag * 4 * t * (1 - t)), c)
    # 屏幕上的破口：玻璃碎边（不发光，画在屏幕层上会被当成光，所以要先擦掉屏幕层）
    for tv, side in [(left, 1), (right, -1)]:
        edge = tv.sx1 if side > 0 else tv.sx0
        for y in range(y0, fy + 3):
            for x in range(min(edge, edge - side * 4), max(edge, edge - side * 4) + 1):
                scr.clear(x, y)
        for y in range(y0 - 3, fy + 1, 3):
            jag = (y * 7) % 4
            x = edge - side * (4 + jag)
            scr.put(x, y, GLARE); scr.put(x, y + 1, (60, 60, 82))
    LIGHTS.append(((xa + xb) / 2, fy - h / 2, 30, (120, 200, 140), 0.25))


def drop_hole(upper, lower, x, w=22):
    """上下两台电视之间的洞：上面房间的地板裂开，一根电线垂下去当梯子。"""
    y0 = upper.fy - 1
    y1 = lower.sy0 + 4
    mid.rect(x, y0, x + w, y1, RECESS[0])
    mid.rect(x, y0, x + 1, y1, RECESS[1]); mid.rect(x + w - 1, y0, x + w, y1, (30, 32, 42))
    for y in range(y0 + 4, y1 - 2, 7):                                  # 洞壁上的电路板碎片
        mid.rect(x + 2, y, x + 4, y + 3, PCB[1]); mid.put(x + 3, y + 1, COPPER)
    for tv, ys in [(upper, range(upper.fy - 1, upper.sy1 + 3)), (lower, range(lower.sy0 - 2, lower.sy0 + 6))]:
        for y in ys:
            for xx in range(x, x + w + 1):
                scr.clear(xx, y)
    # 地板裂口：上面房间的地板边缘参差，断开的木板往下翘
    for xx in range(x - 3, x + w + 4):
        jag = (xx * 5) % 3
        for y in range(upper.fy - 1, upper.fy + 1 + jag):
            scr.clear(xx, y)
            mid.put(xx, y, RECESS[0])
    for side, bx in [(-1, x - 3), (1, x + w + 3)]:
        for k in range(6):
            scr.put(bx + side * -k, upper.fy - 1 + k // 2, (104, 72, 66))
    for xx in range(x - 2, x + w + 3, 3):                              # 下面房间天花板上的碎玻璃
        scr.put(xx, lower.sy0 + 6 + (xx % 2), GLARE)
    # 洞口盖一块铁格栅（作者 2026-10-17：走着走着容易掉下去）：从下面爬上来能穿过去，站在上面不会掉
    for xx in range(x - 3, x + w + 4):
        near.put(xx, upper.fy - 1, (168, 168, 178) if xx % 3 else (120, 120, 132))
        near.put(xx, upper.fy, (96, 96, 110) if xx % 3 else (60, 60, 72))
        near.put(xx, upper.fy + 1, (60, 60, 72) if xx % 3 == 0 else (0, 0, 0, 0))
    for bx in (x - 3, x + w + 3):
        near.rect(bx - 1, upper.fy - 2, bx, upper.fy + 1, (120, 120, 132))
    # 电线梯子：一根垂到下面房间地板附近，每隔 5 格一个结
    cx = x + w // 2
    for y in range(upper.fy - 6, lower.fy - 22):
        near.put(cx, y, CABLE[1]); near.put(cx + 1, y, CABLE[0])
        if (y - upper.fy) % 5 == 0:
            near.rect(cx - 1, y, cx + 2, y + 1, CABLE[2])


# ---------------------------------------------------------------- 远景、近景
def build_far():
    far.rect(0, 0, W - 1, H - 1, WALL[1])
    far.rect(0, 0, W - 1, 10, WALL[0])
    for x in range(0, W, 60):
        far.rect(x + 20, 0, x + 25, 10, WALL[2])
    far.rect(0, FLOOR - 6, W - 1, H - 1, WALL[2])


def cable(pts, sag, thick=2):
    (ax, ay), (bx, by) = pts
    for i in range(0, 201):
        t = i / 200
        x = ax + (bx - ax) * t
        y = ay + (by - ay) * t + sag * 4 * t * (1 - t)
        for k in range(thick):
            near.put(round(x), round(y) + k, CABLE[0] if k else CABLE[1])


def build_floor():
    mid.rect(0, FLOOR, W - 1, H - 1, FLOOR_C[2])
    mid.line(0, FLOOR, W - 1, FLOOR, FLOOR_C[0]); mid.line(0, FLOOR + 1, W - 1, FLOOR + 1, FLOOR_C[1])
    mid.rect(0, FLOOR + 7, W - 1, H - 1, FLOOR_C[3])


if __name__ == "__main__":
    # ---------------------------------------------------------------- 摆电视墙
    build_far()
    build_floor()
    # 下排：三台，下沿都在地上，屏幕底一样高，所以房间地面齐平，可以一路走过去
    A = TV(2, 134, 160, 122, WOOD, "speaker", "color")
    B = TV(162, 134, 160, 122, KHAKI, "meter", "color", top="vents")
    C = TV(322, 134, 156, 122, GREY, "buttons", "bw")
    # 上排：三台叠在下排上面，错开一点
    D = TV(10, 14, 156, 120, PLUM, "buttons", "green")
    E = TV(166, 14, 154, 120, KHAKI, "speaker", "amber", top="vents")
    F = TV(320, 14, 150, 120, WOOD, "meter", "color")
    for tv in (A, B, C, D, E, F):
        tv.draw_shell()
    room_kitchen(A)
    room_living(B)
    room_bedroom(C)
    room_kids(D)
    room_study(E)
    room_entry(F)
    side_passage(A, B)
    side_passage(B, C)
    side_passage(D, E)
    side_passage(E, F)
    drop_hole(E, B, 284)
    drop_hole(D, A, 120)
    # 顶上的兔耳天线和垂下来的线
    for ax in (240, 400):
        mid.line(ax, 14, ax - 14, 2, PLUM[5]); mid.line(ax + 1, 14, ax + 16, 3, PLUM[5])
    cable([(-4, 6), (170, 8)], 10, 2)
    cable([(300, 2), (484, 10)], 8, 2)

    mid = facet(mid, cell=11, min_area=60, grad=0.6, seed=5,
                keep=tuple(RECESS) + tuple(FLOOR_C) + (GLARE,) + tuple(PCB))

    for name, c in [("l3v2_far", far), ("l3v2_mid", mid), ("l3v2_screens", scr), ("l3v2_near", near)]:
        Image.fromarray(c.a).save(OUT / f"{name}.png")


    def over(dst, src):
        m = src[..., 3] > 0
        dst[m] = src[m]
        return dst


    def hero_sprite():
        chars = OUT.parents[1] / "oscar-rush/art/chars"
        a = np.array(Image.open(chars / "red_body.png").convert("RGBA"))[:, 0:16]
        b = np.array(Image.open(chars / "red_strip.png").convert("RGBA"))[:, 0:16]
        return over(a, b)


    raw = np.zeros((H, W, 4), np.uint8)
    for c in (far, mid, scr, near):
        over(raw, c.a)
    hero = hero_sprite()
    hx, hy = 236, B.fy - hero.shape[0] + 1
    over(raw[hy:hy + hero.shape[0], hx:hx + 16], hero)
    Image.fromarray(raw).resize((W * 3, H * 3), Image.NEAREST).save(OUT / "预览v2_原图_3x.png")

    DARK = np.array([0.36, 0.35, 0.41])
    light = np.ones((H, W, 3)) * DARK
    LIGHTS.append((hx + 8, hy + 6, 60, (255, 200, 140), 0.7))
    for (lx, ly, r, col, k) in LIGHTS:
        d = np.hypot(XX - lx, (YY - ly) * 1.15) / r
        band = np.floor(np.clip(1 - d, 0, 1) * 4) / 4
        light += band[..., None] * (np.array(col) / 255.0) * k
    lit = raw[..., :3] * np.clip(light, 0, 1.15)
    unshaded = scr.a[..., 3] > 0
    lit[unshaded] = raw[..., :3][unshaded]
    heromask = np.zeros((H, W), bool)
    heromask[hy:hy + hero.shape[0], hx:hx + 16] = hero[..., 3] > 0
    lit[heromask] = raw[..., :3][heromask] * 0.9      # 在屏幕房间里时，主角吃房间的光
    lit = np.clip(lit, 0, 255).astype(np.uint8)
    Image.fromarray(np.dstack([lit, np.full((H, W), 255, np.uint8)])).resize((W * 3, H * 3), Image.NEAREST).save(OUT / "预览v2_游戏_3x.png")
    print("ok", A.fy, D.fy)
