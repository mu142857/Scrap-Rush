"""第三关「显像管仓库」画风样图：一屏 480×270，1 倍像素。

分层（都是 480×270 透明 PNG，可直接按 parallax_scene.gd 的思路接）：
  l3_far      远景：仓库后墙、货架上一排排小电视的剪影
  l3_mid      中景：电视堆（可站的平台）、巨型显像管外壳、地面
  l3_screens  屏幕：不吃光照（unshaded），自己发光
  l3_near     近景：垂下来的电线
预览：
  预览_原图_3x.png   所有图层直接叠
  预览_游戏_3x.png   模拟游戏里的 CanvasModulate 变暗 + 屏幕和马灯的分档光

跑法："~/Desktop/程序programs/AI Oscar/.venv/bin/python" crt_sample.py
"""
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, "/Users/jiamulin/Desktop/程序programs/AI Oscar")
from oscarkit.canvas import Canvas  # noqa: E402
from oscarkit.shade import facet  # noqa: E402

OUT = Path(__file__).parent
W, H = 480, 270
FLOOR = 236
random.seed(3)
rng = np.random.default_rng(3)

# ---------------------------------------------------------------- 调色板
# 外壳色阶：亮面 4 档 → 暗面 → 左上描边 → 右下描边（照 meme 监控屏）
KHAKI = [(188, 185, 169), (179, 173, 157), (169, 159, 145), (156, 142, 132), (138, 118, 115), (116, 86, 91), (89, 62, 72)]
WOOD = [(164, 116, 86), (152, 106, 80), (138, 95, 73), (124, 85, 67), (104, 70, 60), (88, 58, 58), (66, 44, 50)]
GREY = [(156, 156, 164), (145, 145, 156), (132, 131, 145), (119, 117, 133), (100, 95, 113), (84, 76, 94), (64, 56, 74)]
PLUM = [(150, 132, 150), (138, 120, 140), (124, 107, 128), (110, 94, 116), (92, 78, 100), (76, 62, 84), (58, 46, 66)]
RECESS = [(39, 44, 56), (55, 55, 74), (81, 72, 94)]  # 凹槽：阴影 → 中 → 受光边
GLASS_OFF = [(34, 34, 50), (42, 42, 60), (50, 50, 70), (58, 58, 80)]
GLARE = (84, 84, 108)
WALL = [(30, 28, 39), (36, 33, 46), (43, 39, 55), (50, 46, 63)]
FLOOR_C = [(96, 90, 104), (78, 72, 88), (68, 62, 78), (58, 53, 68)]
CABLE = [(42, 34, 44), (58, 46, 58), (74, 60, 72)]
LED_RED, LED_GRN = (226, 72, 64), (120, 214, 130)

far = Canvas(W, H)
mid = Canvas(W, H)
scr = Canvas(W, H)
near = Canvas(W, H)
LIGHTS = []        # (x, y, 半径, 颜色, 强度)
SCREENS = []       # 屏幕矩形，给预览判断 unshaded 用


def rrect(x0, y0, x1, y1, r):
    """圆角矩形的 mask（含端点）。"""
    yy, xx = np.mgrid[0:H, 0:W]
    m = (xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1)
    for cx, cy in [(x0 + r, y0 + r), (x1 - r, y0 + r), (x0 + r, y1 - r), (x1 - r, y1 - r)]:
        corner = ((xx < x0 + r) if cx == x0 + r else (xx > x1 - r)) & ((yy < y0 + r) if cy == y0 + r else (yy > y1 - r))
        m &= ~(corner & ((xx - cx) ** 2 + (yy - cy) ** 2 > r * r + 0.5))
    return m


def ring_depth(x0, y0, x1, y1, r):
    """屏幕里每个像素离圆角边框有几格（用来画玻璃的一圈圈弧面）。"""
    d = np.full((H, W), -1)
    k = 0
    while True:
        m = rrect(x0 + k, y0 + k, x1 - k, y1 - k, max(1, r - k // 2 + k // 3))
        if not m.any() or x1 - k <= x0 + k or y1 - k <= y0 + k:
            break
        d[m] = k
        k += 1
    return d


# ---------------------------------------------------------------- 屏幕内容
def glass_off(x0, y0, x1, y1, r=3):
    """关着的屏幕不发光，画在中景层上，跟外壳一起吃光照。"""
    d = ring_depth(x0, y0, x1, y1, r)
    span = max(1, min(x1 - x0, y1 - y0) // 2)
    for i, c in enumerate(GLASS_OFF):
        mid.fill_mask(d >= int(span * (0, 0.12, 0.3, 0.55)[i]), c)
    glare(x0, y0, x1, y1, mid)


def glare(x0, y0, x1, y1, c=None):
    """左上角两道斜反光，照 meme 监控屏。"""
    c = c or scr
    n = max(3, min(x1 - x0, y1 - y0) // 7)
    for k, off in enumerate((0, 3)):
        for i in range(n - k * 2):
            c.put(x0 + 3 + off + i, y0 + 3 + n - i, GLARE)


def vignette(x0, y0, x1, y1, r=3, steps=((0, 0.62), (1, 0.78), (3, 0.9))):
    """玻璃边缘压暗，做出显像管的弧面。"""
    d = ring_depth(x0, y0, x1, y1, r)
    a = scr.a[..., :3].astype(float)
    for lim, f in reversed(steps):
        m = (d >= 0) & (d <= lim)
        a[m] = a[m] * f / (1 if lim == steps[-1][0] else 1)
    scr.a[..., :3] = np.clip(a, 0, 255).astype(np.uint8)


def scanlines(x0, y0, x1, y1, f=0.9):
    a = scr.a[..., :3].astype(float)
    a[y0:y1 + 1:2, x0:x1 + 1] *= f
    scr.a[..., :3] = a.astype(np.uint8)


def glass_static(x0, y0, x1, y1, r=3, tint=(0.75, 0.85, 1.0)):
    tones = [tuple(int(v * t) for v, t in zip((v, v, v), tint)) for v in (96, 128, 168, 210)]
    m = rrect(x0, y0, x1, y1, r)
    ys, xs = np.nonzero(m)
    pick = rng.choice(4, size=len(ys), p=[0.38, 0.32, 0.2, 0.1])
    # 雪花横着拉长两格，看起来像信号而不是噪点
    for y, x, k in zip(ys, xs, pick):
        scr.put(x, y, tones[k])
    for y, x in zip(ys[::2], xs[::2]):
        if x + 1 <= x1 and m[y, x + 1]:
            scr.put(x + 1, y, scr.get(x, y)[:3])
    vignette(x0, y0, x1, y1, r)
    glare(x0, y0, x1, y1)
    LIGHTS.append(((x0 + x1) / 2, (y0 + y1) / 2, max(x1 - x0, y1 - y0) * 1.6, (150, 175, 220), 0.55))


def glass_bars(x0, y0, x1, y1, r=3):
    """彩条测试卡，颜色压低饱和度，和 meme 的粉紫薄荷配。"""
    bars = [(206, 204, 196), (206, 196, 128), (126, 194, 190), (128, 184, 128), (190, 128, 180), (194, 116, 116), (116, 120, 196)]
    m = rrect(x0, y0, x1, y1, r)
    bw = (x1 - x0 + 1) / len(bars)
    split = y0 + int((y1 - y0) * 0.72)
    for i, c in enumerate(bars):
        bx0 = x0 + int(i * bw)
        bx1 = x0 + int((i + 1) * bw) - 1
        mm = m.copy(); mm[:, :bx0] = False; mm[:, bx1 + 1:] = False; mm[split:, :] = False
        scr.fill_mask(mm, c)
    low = m.copy(); low[:split, :] = False
    scr.fill_mask(low, (46, 44, 64))
    for i, c in enumerate([(116, 120, 196), (46, 44, 64), (206, 204, 196)]):
        bx0 = x0 + int(i * bw * 1.3)
        mm = low.copy(); mm[:, :bx0] = False; mm[:, bx0 + int(bw * 1.1):] = False; mm[split + 2:, :] = False
        scr.fill_mask(mm, c)
    vignette(x0, y0, x1, y1, r)
    glare(x0, y0, x1, y1)
    LIGHTS.append(((x0 + x1) / 2, (y0 + y1) / 2, max(x1 - x0, y1 - y0) * 1.6, (200, 190, 210), 0.5))


def glass_blue(x0, y0, x1, y1, r=3):
    """蓝屏 + 角上一个频道号。"""
    m = rrect(x0, y0, x1, y1, r)
    scr.fill_mask(m, (70, 92, 168))
    digits = {"0": ["###", "#.#", "#.#", "#.#", "###"], "3": ["###", "..#", ".##", "..#", "###"]}
    for k, ch in enumerate("03"):
        for yy, row in enumerate(digits[ch]):
            for xx, v in enumerate(row):
                if v == "#":
                    scr.put(x1 - 10 + k * 4 + xx, y0 + 4 + yy, (176, 214, 170))
    vignette(x0, y0, x1, y1, r)
    glare(x0, y0, x1, y1)
    LIGHTS.append(((x0 + x1) / 2, (y0 + y1) / 2, max(x1 - x0, y1 - y0) * 1.7, (110, 140, 230), 0.6))


# ---------------------------------------------------------------- 电视外壳
def body(x0, y0, x1, y1, P, lip=6):
    """外壳平涂：顶面最亮，往下一档档暗，底边一条更暗的唇；左上 / 右下用梅子色描边。"""
    h = y1 - y0
    mid.rect(x0, y0, x1, y1, P[1])
    mid.rect(x0, y0, x1, y0 + max(1, h // 8), P[0])
    mid.rect(x0, y0 + int(h * 0.55), x1, y1, P[2])
    mid.rect(x0, y1 - lip, x1, y1, P[3])
    mid.rect(x1 - 2, y0 + 1, x1 - 1, y1, P[4])          # 右侧暗面
    mid.line(x0, y0, x1, y0, P[5]); mid.line(x0, y0, x0, y1, P[5])
    mid.line(x1, y0, x1, y1, P[6]); mid.line(x0, y1, x1, y1, P[6])


def recess(x0, y0, x1, y1, r=3):
    """屏幕的凹槽：外圈一像素冷色受光边在下 / 右，阴影在上 / 左。"""
    mid.fill_mask(rrect(x0 - 2, y0 - 2, x1 + 2, y1 + 2, r + 2), RECESS[2])
    mid.fill_mask(rrect(x0 - 2, y0 - 2, x1 + 1, y1 + 1, r + 2), RECESS[1])
    mid.fill_mask(rrect(x0 - 1, y0 - 1, x1 + 1, y1 + 1, r + 1), RECESS[0])
    SCREENS.append((x0, y0, x1, y1))


def knob(x, y, P):
    for dx, dy in [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)]:
        mid.put(x + dx, y + dy, P[6])
    mid.put(x + 1, y + 1, P[4]); mid.put(x + 1, y, P[5])
    mid.put(x + 1, y + 3, P[3])


def grille(x0, y0, x1, y1, P, step=2):
    for y in range(y0, y1 + 1, step):
        mid.line(x0, y, x1, y, P[5])


def tv_monitor(x0, y0, w, h, P=KHAKI, screen="off", led=LED_GRN):
    """meme 那种方正的监控屏：屏幕在上，底下一条控制条。"""
    x1, y1 = x0 + w - 1, y0 + h - 1
    body(x0, y0, x1, y1, P, lip=max(4, h // 6))
    pad = max(4, w // 10)
    strip = max(7, h // 5)
    sx0, sy0, sx1, sy1 = x0 + pad, y0 + pad, x1 - pad, y1 - strip - 2
    recess(sx0, sy0, sx1, sy1)
    by = y1 - strip + 2
    if w >= 40:
        grille(x0 + pad, by, x0 + pad + w // 5, by + strip - 5, P)
        knob(x1 - pad - 12, by, P); knob(x1 - pad - 6, by, P)
    mid.put(x1 - pad - 1, by + 1, led)
    mid.put(x0 + 2, y0 + 2, P[3]); mid.put(x1 - 3, y0 + 2, P[3])   # 螺丝
    {"off": glass_off, "static": glass_static, "bars": glass_bars, "blue": glass_blue}[screen](sx0, sy0, sx1, sy1)
    return (x0, y0, x1, y1)


def tv_console(x0, y0, w, h, screen="off"):
    """木壳落地电视：屏幕在左，右边竖条喇叭，底下四条腿。"""
    legs = 6
    x1, y1 = x0 + w - 1, y0 + h - 1 - legs
    body(x0, y0, x1, y1, WOOD, lip=5)
    # 木纹：几道横向的长条，一档之差
    for i, gy in enumerate(range(y0 + 6, y1 - 6, 5)):
        gx = x0 + 3 + (i * 13) % 17
        mid.line(gx, gy, min(x1 - 4, gx + 14 + i % 3 * 6), gy, WOOD[2] if gy < y0 + h * 0.55 else WOOD[3])
    sw = int(w * 0.66)
    sx0, sy0, sx1, sy1 = x0 + 6, y0 + 6, x0 + sw, y1 - 8
    recess(sx0, sy0, sx1, sy1, r=4)
    gx0 = x0 + sw + 6
    mid.rect(gx0 - 1, y0 + 6, x1 - 5, y1 - 8, WOOD[5])
    for y in range(y0 + 7, y1 - 8, 2):
        mid.line(gx0, y, x1 - 6, y, WOOD[3])
    knob(gx0 + 2, y1 - 6, WOOD); knob(gx0 + 8, y1 - 6, WOOD)
    for lx in (x0 + 4, x1 - 6):
        mid.rect(lx, y1 + 1, lx + 2, y1 + legs, WOOD[5])
        mid.put(lx, y1 + 1, WOOD[3])
    {"off": glass_off, "static": glass_static, "bars": glass_bars, "blue": glass_blue}[screen](sx0, sy0, sx1, sy1, 4)
    return (x0, y0, x1, y1 + legs)


def tv_portable(x0, y0, w, h, P=GREY, screen="static", ears=True):
    """手提小电视：顶上提手，可选兔耳天线。"""
    x1, y1 = x0 + w - 1, y0 + h - 1
    body(x0, y0, x1, y1, P, lip=3)
    sx0, sy0, sx1, sy1 = x0 + 3, y0 + 3, x1 - 9, y1 - 4
    recess(sx0, sy0, sx1, sy1, r=2)
    for y in range(y0 + 4, y1 - 4, 2):
        mid.line(x1 - 7, y, x1 - 3, y, P[5])
    mid.put(x1 - 5, y1 - 3, LED_RED)
    # 提手
    hx0, hx1 = x0 + w // 4, x1 - w // 4
    mid.rect(hx0, y0 - 3, hx0 + 1, y0 - 1, P[5]); mid.rect(hx1 - 1, y0 - 3, hx1, y0 - 1, P[6])
    mid.line(hx0, y0 - 4, hx1, y0 - 4, P[4]); mid.line(hx0 + 1, y0 - 4, hx1 - 2, y0 - 4, P[3])
    if ears:
        cx = (x0 + x1) // 2
        mid.line(cx, y0 - 5, cx - 9, y0 - 18, P[5]); mid.line(cx + 1, y0 - 5, cx + 12, y0 - 16, P[5])
        mid.put(cx - 9, y0 - 19, P[2]); mid.put(cx + 12, y0 - 17, P[2])
        mid.rect(cx - 1, y0 - 6, cx + 2, y0 - 5, P[4])
    {"off": glass_off, "static": glass_static, "bars": glass_bars, "blue": glass_blue}[screen](sx0, sy0, sx1, sy1, 2)
    return (x0, y0, x1, y1)


# ---------------------------------------------------------------- 屏幕里的房间
def memory_room(x0, y0, x1, y1):
    """巨型显像管里的那间屋子：一家人的客厅，台灯暖光，窗外是夜。走进屏幕就进这个房间。"""
    rw, rh = x1 - x0 + 1, y1 - y0 + 1
    floor_y = y0 + int(rh * 0.72)
    lamp = (x0 + int(rw * 0.78), y0 + int(rh * 0.34))
    yy, xx = np.mgrid[0:H, 0:W]
    inside = rrect(x0, y0, x1, y1, 6)
    # 墙：按离台灯的距离分四档，档与档之间是直线段（等亮线顺着三角网格），不是平滑渐变
    wallc = [(214, 178, 150), (196, 160, 140), (176, 142, 132), (150, 120, 122), (124, 100, 112)]
    dist = np.hypot((xx - lamp[0]) * 0.8, (yy - lamp[1]) * 1.1)
    dist = dist + ((xx // 7 + yy // 5) % 3) * 2.5     # 让档位边缘有棱角
    band = np.clip((dist / (rw * 0.17)).astype(int), 0, 4)
    wall = inside & (yy < floor_y)
    for i, c in enumerate(wallc):
        scr.fill_mask(wall & (band == i), c)
    # 护墙板
    scr.fill_mask(inside & (yy >= floor_y - 9) & (yy < floor_y), (150, 112, 104))
    scr.fill_mask(inside & (yy == floor_y - 9), (186, 146, 128))
    scr.fill_mask(inside & (yy >= floor_y - 9) & (yy < floor_y) & (np.hypot(xx - lamp[0], (yy - lamp[1])) < rw * 0.3), (172, 128, 112))
    # 地板：横向木板，靠墙一条最亮
    floorc = [(170, 120, 92), (150, 104, 82), (128, 88, 74), (104, 72, 66)]
    fl = inside & (yy >= floor_y)
    fband = np.clip(((np.abs(xx - lamp[0]) * 0.5 + (yy - floor_y) * 2.2) / (rw * 0.12)).astype(int), 0, 3)
    for i, c in enumerate(floorc):
        scr.fill_mask(fl & (fband == i), c)
    for gy in range(floor_y + 4, y1, 5):
        for gx in range(x0 + (gy * 7) % 11, x1, 23):
            scr.line(gx, gy, min(x1, gx + 12), gy, (96, 66, 62) if gy > floor_y + 10 else (118, 82, 70))
    # 地毯
    rug = (xx - (x0 + rw * 0.36)) ** 2 / (rw * 0.3) ** 2 + (yy - (floor_y + 10)) ** 2 / 6.0 ** 2 <= 1
    scr.fill_mask(rug & inside, (150, 116, 140))
    scr.fill_mask(rug & inside & (xx > x0 + rw * 0.48), (168, 132, 150))
    # 窗：夜色，十字窗棂，一点月亮
    wx0, wy0, wx1, wy1 = x0 + int(rw * 0.08), y0 + int(rh * 0.14), x0 + int(rw * 0.3), y0 + int(rh * 0.5)
    scr.rect(wx0 - 2, wy0 - 2, wx1 + 2, wy1 + 3, (138, 108, 112))
    scr.rect(wx0, wy0, wx1, wy1, (54, 62, 104))
    scr.rect(wx0, wy0 + (wy1 - wy0) // 2, wx1, wy1, (62, 72, 116))
    scr.line(wx0, (wy0 + wy1) // 2, wx1, (wy0 + wy1) // 2, (138, 108, 112))
    scr.line((wx0 + wx1) // 2, wy0, (wx0 + wx1) // 2, wy1, (138, 108, 112))
    scr.rect(wx1 - 6, wy0 + 3, wx1 - 4, wy0 + 5, (226, 222, 196))
    for sx, sy in [(wx0 + 3, wy0 + 4), (wx0 + 9, wy0 + 2), (wx1 - 9, wy1 - 6)]:
        scr.put(sx, sy, (180, 186, 220))
    scr.rect(wx0 - 3, wy1 + 2, wx1 + 3, wy1 + 3, (196, 160, 140))   # 窗台
    # 沙发：灰绿，背光那一侧暗，朝灯那条边一道亮边
    sx0, sx1 = x0 + int(rw * 0.2), x0 + int(rw * 0.55)
    sb = floor_y + 3
    scr.rect(sx0 + 3, sb - 20, sx1 - 3, sb - 9, (92, 118, 120))       # 靠背
    scr.rect(sx0, sb - 11, sx1, sb, (84, 108, 112))                    # 坐垫
    scr.rect(sx0, sb - 15, sx0 + 5, sb, (74, 96, 104))                 # 左扶手
    scr.rect(sx1 - 5, sb - 15, sx1, sb, (100, 128, 126))               # 右扶手（朝灯）
    scr.line(sx1 - 5, sb - 15, sx1, sb - 15, (140, 164, 150))
    scr.line(sx0 + 3, sb - 20, sx1 - 3, sb - 20, (116, 142, 136))
    scr.line(sx0 + (sx1 - sx0) // 2, sb - 19, sx0 + (sx1 - sx0) // 2, sb - 10, (80, 104, 110))
    scr.rect(sx0 + 2, sb + 1, sx1 - 2, sb + 1, (86, 60, 60))           # 沙发底的影子
    # 墙上的合照：四个人（红、铜、蓝、绿）——就是船员们
    px0, py0 = x0 + int(rw * 0.33), y0 + int(rh * 0.2)
    scr.rect(px0 - 2, py0 - 2, px0 + 21, py0 + 13, (112, 84, 80))
    scr.rect(px0, py0, px0 + 19, py0 + 11, (226, 214, 180))
    scr.rect(px0, py0 + 7, px0 + 19, py0 + 11, (196, 196, 156))
    for i, c in enumerate([(206, 72, 64), (190, 140, 96), (96, 136, 214), (110, 180, 100)]):
        fx = px0 + 2 + i * 5
        scr.rect(fx, py0 + 3, fx + 2, py0 + 9, c)
        scr.put(fx + 1, py0 + 2, c)
    # 落地灯：灯罩发光，下面一圈暖光
    lx, ly = lamp
    scr.line(lx, ly + 6, lx, floor_y + 4, (90, 70, 70))
    scr.rect(lx - 3, floor_y + 4, lx + 3, floor_y + 5, (90, 70, 70))
    scr.poly([(lx - 6, ly + 6), (lx + 7, ly + 6), (lx + 4, ly - 4), (lx - 3, ly - 4)], (246, 226, 168))
    scr.line(lx - 6, ly + 6, lx + 6, ly + 6, (226, 196, 140))
    # 小茶几 + 一台小电视（屋子里也有一台电视）
    tx0 = x0 + int(rw * 0.6)
    scr.rect(tx0, floor_y - 2, tx0 + 14, floor_y + 6, (122, 84, 72))
    scr.line(tx0, floor_y - 2, tx0 + 14, floor_y - 2, (160, 116, 92))
    scr.rect(tx0 + 2, floor_y - 12, tx0 + 12, floor_y - 3, (176, 168, 150))
    scr.rect(tx0 + 3, floor_y - 11, tx0 + 9, floor_y - 5, (120, 150, 196))
    scr.put(tx0 + 11, floor_y - 6, LED_RED)
    # 显像管的玻璃效果
    scanlines(x0, y0, x1, y1, 0.93)
    vignette(x0, y0, x1, y1, 6, steps=((1, 0.55), (3, 0.72), (6, 0.86)))
    glare(x0, y0, x1, y1)
    LIGHTS.append(((x0 + x1) / 2, y1 - 4, rw * 1.05, (255, 206, 150), 0.95))
    LIGHTS.append((lx, ly, rw * 0.5, (255, 214, 160), 0.4))


def giant_crt(x0, y0, w, h):
    """巨型显像管：这块屏幕就是一扇门。屏幕下沿离地 22 格，正好跳一下进去。"""
    x1, y1 = x0 + w - 1, y0 + h - 1
    body(x0, y0, x1, y1, KHAKI, lip=10)
    # 顶上的散热缝
    for i in range(10):
        vx = x0 + w // 2 - 50 + i * 10
        mid.rect(vx, y0 + 4, vx + 6, y0 + 5, KHAKI[5]); mid.line(vx, y0 + 6, vx + 6, y0 + 6, KHAKI[0])
    # 一圈压纹
    mid.line(x0 + 4, y0 + 4, x1 - 4, y0 + 4, KHAKI[3]); mid.line(x0 + 4, y0 + 4, x0 + 4, y1 - 12, KHAKI[3])
    mid.line(x1 - 4, y0 + 4, x1 - 4, y1 - 12, KHAKI[4])
    sx0, sy0, sx1, sy1 = x0 + 12, y0 + 12, x1 - 12, y1 - 22
    recess(sx0, sy0, sx1, sy1, r=6)
    # 底下控制条：喇叭网孔、读数窗、旋钮、电源灯
    by = y1 - 16
    for gy in range(by, by + 9, 2):
        for gx in range(x0 + 12 + (gy // 2) % 2, x0 + 44, 3):
            mid.put(gx, gy, KHAKI[5])
    mid.rect(x0 + 54, by - 1, x0 + 98, by + 8, RECESS[0])
    mid.rect(x0 + 55, by, x0 + 97, by + 7, (38, 66, 54))
    for k, gx in enumerate(range(x0 + 58, x0 + 94, 5)):
        mid.rect(gx, by + 2, gx + 2, by + 5, (110, 206, 126) if k < 5 else (52, 92, 72))
    for kx in (x1 - 52, x1 - 40):
        for dy in range(5):
            for dx in range(5):
                if (dx - 2) ** 2 + (dy - 2) ** 2 <= 5:
                    mid.put(kx + dx, by + 1 + dy, KHAKI[6] if dx + dy >= 5 else KHAKI[5])
        mid.put(kx + 1, by + 2, KHAKI[2]); mid.put(kx + 3, by + 3, KHAKI[0])
    mid.rect(x1 - 24, by + 1, x1 - 20, by + 5, KHAKI[4]); mid.rect(x1 - 23, by + 2, x1 - 21, by + 4, (82, 63, 63))
    mid.put(x1 - 22, by + 3, LED_RED)
    # 资产标签
    mid.rect(x1 - 16, by + 1, x1 - 8, by + 6, (206, 203, 188))
    for gx in range(x1 - 15, x1 - 9, 2):
        mid.line(gx, by + 2, gx, by + 5, KHAKI[6])
    memory_room(sx0, sy0, sx1, sy1)
    return (sx0, sy0, sx1, sy1)


# ---------------------------------------------------------------- 远景
def build_far():
    far.rect(0, 0, W - 1, H - 1, WALL[1])
    far.rect(0, 0, W - 1, 18, WALL[0])                      # 天花板
    far.rect(0, 18, W - 1, 21, WALL[2])
    for x in range(0, W, 60):                               # 天花板的梁
        far.rect(x + 20, 0, x + 25, 18, WALL[2])
    # 货架：一层层摆满小电视的剪影，屏幕偶尔一点暗蓝
    for i, rx in enumerate(range(-20, W, 118)):
        rx1 = rx + 96
        far.rect(rx, 40, rx + 2, FLOOR, WALL[3]); far.rect(rx1, 40, rx1 + 2, FLOOR, WALL[3])
        for k, sy in enumerate(range(70, FLOOR, 42)):
            far.rect(rx, sy, rx1 + 2, sy + 2, WALL[3])
            x = rx + 4
            while x < rx1 - 12:
                tw = random.choice([14, 18, 22, 26])
                th = random.choice([12, 16, 20])
                if x + tw > rx1 - 2:
                    break
                far.rect(x, sy - th, x + tw, sy - 1, WALL[2])
                far.line(x, sy - th, x + tw, sy - th, WALL[3])
                lit = random.random()
                sc = (52, 58, 82) if lit < 0.25 else (36, 36, 50)
                far.rect(x + 2, sy - th + 2, x + tw - 5, sy - 4, sc)
                if lit < 0.25:
                    LIGHTS.append((x + tw / 2, sy - th / 2, 22, (100, 120, 190), 0.18))
                x += tw + random.choice([1, 2, 4])
    # 地面远处
    far.rect(0, FLOOR - 6, W - 1, H - 1, WALL[2])


# ---------------------------------------------------------------- 中景：电视堆 + 地面
def build_mid():
    # 地面：水泥，顶边一条亮，往下暗
    mid.rect(0, FLOOR, W - 1, H - 1, FLOOR_C[2])
    mid.rect(0, FLOOR + 6, W - 1, H - 1, FLOOR_C[3])
    mid.line(0, FLOOR, W - 1, FLOOR, FLOOR_C[0]); mid.line(0, FLOOR + 1, W - 1, FLOOR + 1, FLOOR_C[1])
    for cx in (70, 228, 391):
        mid.line(cx, FLOOR + 2, cx - 3, H - 1, FLOOR_C[3] if cx % 2 else (50, 46, 60))

    # 左边一堆：木壳落地电视做底，上面叠监控屏和手提小电视
    tv_console(6, 170, 84, 66, screen="static")
    tv_monitor(14, 128, 56, 42, screen="off")
    tv_portable(70, 146, 34, 24, screen="blue", ears=False)
    tv_portable(22, 104, 30, 24, screen="static")
    tv_monitor(96, 206, 40, 30, P=GREY, screen="off")
    tv_monitor(100, 176, 34, 30, P=PLUM, screen="bars", led=LED_RED)

    # 巨型显像管
    giant_crt(150, 72, 176, 164)

    # 右边一座塔：错落叠高，台阶式，可以一路跳上去
    tv_monitor(338, 192, 62, 44, P=GREY, screen="static")
    tv_console(400, 170, 76, 66, screen="off")
    tv_monitor(352, 152, 44, 40, screen="off")
    tv_monitor(404, 126, 60, 44, P=PLUM, screen="blue")
    tv_portable(360, 128, 32, 24, P=KHAKI, screen="bars", ears=True)
    tv_monitor(420, 90, 40, 36, P=GREY, screen="static")
    tv_portable(428, 66, 28, 24, P=WOOD, screen="off", ears=True)


# ---------------------------------------------------------------- 近景：垂下来的电线
def cable(pts, sag, thick=2):
    (ax, ay), (bx, by) = pts
    for i in range(0, 201):
        t = i / 200
        x = ax + (bx - ax) * t
        y = ay + (by - ay) * t + sag * 4 * t * (1 - t)
        for k in range(thick):
            near.put(round(x), round(y) + k, CABLE[0] if k else CABLE[1])


def build_near():
    cable([(-4, 30), (150, 52)], 46, 3)
    cable([(120, -2), (300, -2)], 30, 2)
    cable([(330, -4), (490, 40)], 54, 3)
    cable([(300, 2), (372, 6)], 16, 2)
    # 地上一捆粗线，从巨型显像管背后绕出来
    for k, off in enumerate((0, 3, 5)):
        pts = [(x, FLOOR + 3 + off + round(2 * np.sin(x / 23 + k))) for x in range(0, W, 2)]
        for x, y in pts:
            near.put(x, y, CABLE[0]); near.put(x + 1, y, CABLE[0])
            near.put(x, y - 1, CABLE[2] if (x // 6 + k) % 3 == 0 else CABLE[1])


# ---------------------------------------------------------------- 主角（比例尺）
def hero_sprite():
    chars = OUT.parents[1] / "oscar-rush/art/chars"
    a = np.array(Image.open(chars / "red_body.png").convert("RGBA"))[:, 0:16]
    b = np.array(Image.open(chars / "red_strip.png").convert("RGBA"))[:, 0:16]
    return over(a, b)


build_far()
build_mid()
build_near()

# 色块派切面：外壳大平面切成低多边形小面，屏幕和小零件不动
# 远景和地面不切：切了太花，抢中景
mid = facet(mid, cell=11, min_area=60, grad=0.6, seed=5, keep=tuple(RECESS) + tuple(FLOOR_C) + tuple(GLASS_OFF) + (GLARE,))

for name, c in [("l3_far", far), ("l3_mid", mid), ("l3_screens", scr), ("l3_near", near)]:
    Image.fromarray(c.a).save(OUT / f"{name}.png")


def over(dst, src):
    m = src[..., 3] > 0
    dst[m] = src[m]
    return dst


raw = np.zeros((H, W, 4), np.uint8)
for c in (far, mid, scr, near):
    over(raw, c.a)
hero = hero_sprite()
hx, hy = 186, FLOOR - hero.shape[0]
over(raw[hy:hy + hero.shape[0], hx:hx + 16], hero)
Image.fromarray(raw).resize((W * 3, H * 3), Image.NEAREST).save(OUT / "预览_原图_3x.png")

# 模拟游戏里的样子：CanvasModulate 压暗，屏幕不吃光照，光照按档位跳（until-someone-passes 那套）
DARK = np.array([0.36, 0.35, 0.41])
yy, xx = np.mgrid[0:H, 0:W]
light = np.ones((H, W, 3)) * DARK
LIGHTS.append((hx + 8, hy + 6, 70, (255, 200, 140), 0.85))   # 马灯
for (lx, ly, r, col, k) in LIGHTS:
    d = np.hypot(xx - lx, (yy - ly) * 1.15) / r
    band = np.floor(np.clip(1 - d, 0, 1) * 4) / 4      # 四档硬边
    light += band[..., None] * (np.array(col) / 255.0) * k
lit = raw[..., :3] * np.clip(light, 0, 1.15)
unshaded = scr.a[..., 3] > 0
lit[unshaded] = raw[..., :3][unshaded]
lit = np.clip(lit, 0, 255).astype(np.uint8)
game = np.dstack([lit, np.full((H, W), 255, np.uint8)])
Image.fromarray(game).resize((W * 3, H * 3), Image.NEAREST).save(OUT / "预览_游戏_3x.png")
print("ok", len(LIGHTS), "lights")
