"""第二关开场「气动管冲刺」的多层视差背景（10-18 作者："第二关开始的移动的场景的背景太单调，比起第一关的视差背景差太多了"）。

    "/Users/jiamulin/Desktop/程序programs/AI Oscar/.venv/bin/python" tube_backdrop_art.py

画五张能左右无缝接上的循环图（都是 270 高，宽不超过 2048），再生成灯、管、表的位置表：
  tube_bd_0_night.png   960   远景  窗外的夜：靛蓝的天、月亮、远处楼群一格格亮着的窗
  tube_bd_1_hall.png    1440  远景  交换局大厅的墙：高高的拱窗（透明，透出夜色）、壁柱，下面一整排红木接线板（插孔灯会闪）
  tube_bd_2_relay.png   1200  中远  铁柱子、柱子之间垂着的电缆束、吊灯、一排继电器柜（指示灯会闪）
  tube_bd_3_mid.png     1600  中景  铆钉钢梁和斜撑、管道支架、贴着底下走的蒸汽管、黄铜阀门、压力表（指针游戏里画）、
                                    竖着穿过三条道后面的别的气动管（里面的胶囊和信件筒游戏里画）
  tube_bd_4_near.png    1920  近景  镜头前擦过的大块剪影：管壁接缝的铆钉钢箍、粗管弯头、垂下来的电缆（三条道那一段只留很淡的影子）
  scripts/levels/tube_backdrop_data.gd  上面这些图里会动的东西的位置（自动生成，别手改）

三条道在 y = 104 / 140 / 176（管半径 9），所以背景的"戏"主要放在上面 0~93、下面 187~270 两条，
道与道之间 18 像素的缝里也露得出来。远的层暗、偏冷，近的层亮、偏暖；最后都过一遍 level2_map 的褪色（和第二关主体一样）。
游戏里：scripts/levels/tube_backdrop.gd。
"""
import math
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import level2_map as M  # noqa: E402
from oscarkit.canvas import Canvas  # noqa: E402

H = 270
LANES = (104, 140, 176)
BAND = (93, 187)                     # 三条道（含管壁）占的那一段
GAME = M.GAME
DATA_GD = GAME / "scripts/levels/tube_backdrop_data.gd"

GREY, BRASS, DARK, WOOD, TAN = M.GREY, M.BRASS, M.DARK, M.WOOD, M.TAN
LAMP, LAMP_OFF, RELAY_RED = M.LAMP, M.LAMP_OFF, M.RELAY_RED
NIGHT = [(13, 14, 24), (17, 19, 32), (22, 25, 40), (29, 31, 50), (37, 38, 60), (50, 46, 62)]
CITY = [(15, 15, 22), (20, 19, 28), (26, 24, 34)]
WIN_LIT = [(122, 92, 54), (168, 126, 70), (214, 166, 92)]
STONE = [(30, 27, 25), (38, 34, 31), (47, 42, 37), (58, 52, 45), (70, 63, 54)]
SOOT = [(10, 9, 9), (14, 12, 12), (19, 16, 15), (25, 21, 19), (33, 28, 24), (44, 36, 29)]


def wrap(c, W, fn, x, *a, **k):
    """在 x、x-W、x+W 各画一遍：跨过左右边界的部分在另一边接上（图要能无缝循环）。"""
    for dx in (0, -W, W):
        fn(c, x + dx, *a, **k)


def disc(c, cx, cy, r, col):
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                c.put(x, y, col)


def record_lamps(c, kinds):
    """记下图里每个"会亮灭"的像素：kinds = {颜色: 种类}。返回 [x, y, kind, ...]（褪色之前记）。"""
    out = []
    for col, kind in kinds.items():
        m = (c.a[..., 0] == col[0]) & (c.a[..., 1] == col[1]) & (c.a[..., 2] == col[2]) & (c.a[..., 3] > 0)
        for y, x in zip(*np.nonzero(m)):
            out += [int(x), int(y), kind]
    return out


# ================================================================ 0 窗外的夜
def layer_night():
    W = 960
    c = Canvas(W, H)
    M.vgrad(c, 0, 0, W - 1, H - 1, NIGHT, 0.0, 1.0)
    rng = np.random.default_rng(3)
    for _ in range(70):                                        # 星星：大多很暗，几颗亮一点
        x, y = int(rng.integers(0, W)), int(rng.integers(2, 110))
        c.put(x, y, NIGHT[4] if rng.random() < 0.75 else (120, 118, 132))
    # 月亮：一个暖白的圆，右下一道暗的弦，外面一圈很淡的晕
    for r, col in ((15, NIGHT[3]), (12, NIGHT[4])):
        disc(c, 700, 44, r, col)
    disc(c, 700, 44, 8, (196, 188, 158))
    disc(c, 703, 47, 6, (168, 160, 134))
    c.put(696, 40, (222, 214, 184))
    c.put(697, 40, (222, 214, 184))
    # 远处的楼群：两排，后排更暗更高，窗格子一格格亮着暖光
    for row, (base, hmin, hmax, col, lit) in enumerate(((150, 40, 110, CITY[0], 0.10), (185, 20, 80, CITY[1], 0.22))):
        x = 0
        while x < W:
            w = int(rng.integers(26, 64))
            h = int(rng.integers(hmin, hmax))
            top = base - h
            x1 = min(x + w - 1, W - 1)
            M.fill(c, x, top, x1, H - 1, col)
            M.fill(c, x, top, x1, top, CITY[2])                # 楼顶一道亮边（月光）
            if rng.random() < 0.3:                             # 水塔 / 天线
                tx = x + w // 2
                M.fill(c, tx, top - 8, tx, top - 1, CITY[2])
                M.fill(c, tx - 3, top - 12, tx + 3, top - 8, col)
            for wy in range(top + 4, H - 4, 6):
                for wx in range(x + 3, x1 - 2, 5):
                    if rng.random() < lit:
                        k = 0 if rng.random() < 0.6 else (1 if rng.random() < 0.8 else 2)
                        c.put(wx, wy, WIN_LIT[k])
                        c.put(wx + 1, wy, WIN_LIT[max(0, k - 1)])
            x += w + int(rng.integers(0, 10))
    # 远处一根电台铁塔，塔尖一盏红灯（游戏里闪）
    for y in range(40, 152):
        half = (y - 40) // 9
        c.put(240 - half, y, CITY[2])
        c.put(240 + half, y, CITY[2])
        if y % 8 == 0:
            M.fill(c, 240 - half, y, 240 + half, y, CITY[2])
    c.put(240, 38, RELAY_RED)
    c.put(240, 39, (120, 50, 40))
    blinks = [240, 38, 5]
    M.fade(c, chroma=0.8, lift=0.04, gain=0.92, warm=(0.0, 0.004))
    return c, blinks


# ================================================================ 1 交换局大厅的墙
def arch_window(c, x0, top, w, sill):
    """高拱窗：透明的玻璃（透出夜）、铁的窗棂、上面半圆拱、木头窗框、石头窗台。"""
    r = w // 2
    cx = x0 + r
    spring = top + r                                           # 半圆拱的圆心高度
    for y in range(top - 4, sill + 1):                         # 外框：先整个涂成窗框色
        for x in range(x0 - 4, x0 + w + 4):
            inside = y >= spring or (x - cx + 0.5) ** 2 + (y - spring) ** 2 <= (r + 4) ** 2
            if inside:
                c.put(x, y, WOOD[2] if x < cx else WOOD[1])
    for y in range(top, sill - 2):                             # 玻璃：抠成透明
        for x in range(x0, x0 + w):
            inside = y >= spring or (x - cx + 0.5) ** 2 + (y - spring) ** 2 <= r * r
            if inside:
                c.a[y, x] = 0
    for x in range(x0 + w // 4, x0 + w, w // 4):               # 竖窗棂
        for y in range(top, sill - 2):
            if c.a[y, x, 3] == 0 or c.a[y, x - 1, 3] == 0:
                c.put(x, y, GREY[1])
                c.put(x + 1, y, DARK[3])
    for y in range(spring + 10, sill - 4, 26):                 # 横窗棂
        for x in range(x0, x0 + w):
            c.put(x, y, GREY[1])
            c.put(x, y + 1, DARK[3])
    for k in range(-r, r + 1, 3):                              # 拱上的扇形放射窗棂
        a = math.atan2(-r, k)
        for t in range(2, r):
            x, y = int(round(cx + t * math.cos(a))), int(round(spring + t * math.sin(a)))
            if 0 <= y < H and 0 <= x < c.w and c.a[y, x, 3] == 0 and t % 2 == 0 and abs(k) % 6 == 0:
                c.put(x, y, GREY[1])
    M.fill(c, x0 - 7, sill - 2, x0 + w + 6, sill + 1, STONE[3])   # 窗台
    M.fill(c, x0 - 7, sill - 2, x0 + w + 6, sill - 2, STONE[4])
    M.fill(c, x0 - 6, sill + 2, x0 + w + 5, sill + 2, STONE[0])
    for x in (cx - 1, cx, cx + 1):                             # 拱顶的楔石
        M.fill(c, x, top - 7, x, top - 3, STONE[3] if x < cx + 1 else STONE[2])


def pilaster(c, x, w=26):
    """壁柱：石头的竖方柱，左亮右暗，柱头一道线脚，柱身两道凹槽。"""
    M.hgrad(c, x, 0, x + w - 1, H - 1, STONE, 0.65, 0.15)
    for gx in (x + w // 3, x + 2 * w // 3):
        M.fill(c, gx, 14, gx, H - 1, STONE[0])
        M.fill(c, gx + 1, 14, gx + 1, H - 1, STONE[3])
    for y0 in (6, 152):
        M.fill(c, x - 3, y0, x + w + 2, y0 + 4, STONE[2])
        M.fill(c, x - 3, y0, x + w + 2, y0, STONE[4])
        M.fill(c, x - 3, y0 + 5, x + w + 2, y0 + 5, STONE[0])


def layer_hall():
    W = 1440
    c = Canvas(W, H)
    M.vgrad(c, 0, 0, W - 1, H - 1, DARK, 0.85, 0.35)
    for y in range(0, H, 9):                                    # 砖缝（周期 36，1440 能整除）
        for x in range(W):
            M.nudge(c, x, y, -1)
            if (x + (18 if (y // 9) % 2 else 0)) % 36 == 0:
                for t in range(1, 9):
                    M.nudge(c, x, y + t, -1)
    for i in range(4):                                         # 四扇高拱窗，间距 360
        arch_window(c, 90 + i * 360, 10, 116, 156)
    for i in range(4):
        wrap(c, W, pilaster, 315 + i * 360, 26)
    # 墙脚：一整排接线板（红木框、插孔、信号灯），板子底下的木护墙
    M.fill(c, 0, 168, W - 1, H - 1, WOOD[1])
    M.fill(c, 0, 168, W - 1, 168, WOOD[4])
    for i, x in enumerate(range(0, W, 72)):
        M.switch_panel(c, x + 2, 172, 68, 72, seed=40 + i)
    M.fill(c, 0, 246, W - 1, H - 1, WOOD[2])                   # 台面
    M.fill(c, 0, 246, W - 1, 246, WOOD[5])
    for x in range(0, W, 72):
        M.fill(c, x + 1, 250, x + 1, H - 1, WOOD[0])
    M.metal_texture(c, 0, 0, W - 1, 8, seed=11, density=0.4)
    blinks = record_lamps(c, {LAMP: 1, LAMP_OFF: 0})
    M.fade(c)
    return c, blinks


# ================================================================ 2 柱子、电缆、吊灯、继电器柜
def column(c, x, w=14):
    """铁柱：左亮右暗，每 30 像素一圈铆钉箍，顶上一个托架。"""
    M.hgrad(c, x, 0, x + w - 1, H - 1, GREY, 0.42, 0.08)
    for y in range(10, H, 30):
        M.fill(c, x - 1, y, x + w, y + 2, GREY[3])
        M.fill(c, x - 1, y, x + w, y, GREY[5])
        for rx in range(x + 1, x + w - 1, 4):
            c.put(rx, y + 1, GREY[6])
    if 0 <= x and x + w <= c.w:
        M.metal_texture(c, x, 0, x + w - 1, H - 1, seed=7, density=0.5)
    M.spoly(c, [(x - 10, 4), (x + w + 10, 4), (x + w, 14), (x, 14)], GREY[2])
    M.fill(c, x - 10, 4, x + w + 10, 4, GREY[5])


def hanging_lamp(c, x, y0, y1):
    """吊灯：一根杆，黄铜灯罩（倒扣的梯形），罩口下一颗灯泡。返回灯泡位置。"""
    M.fill(c, x, y0, x, y1 - 6, GREY[3])
    M.spoly(c, [(x - 2, y1 - 6), (x + 2, y1 - 6), (x + 7, y1), (x - 7, y1)], BRASS[2])
    M.fill(c, x - 7, y1, x + 7, y1, BRASS[4])
    M.fill(c, x - 2, y1 - 6, x + 1, y1 - 6, BRASS[4])
    M.fill(c, x - 1, y1 + 1, x + 1, y1 + 2, LAMP)
    return (x, y1 + 1)


def layer_relay():
    W = 1200
    c = Canvas(W, H)
    cols = [300, 700, 1100]
    for x in cols:                                             # 柱子之间垂下来的电缆束（每段 4 根，垂度不同）
        nx = x + 400
        for k, (dy, sag) in enumerate(((16, 34), (19, 40), (22, 30), (25, 46))):
            for off in (0, -W):
                M.wire(c, x + 14 + off, dy, nx + off, dy + 2, sag, ramp=M.FAR_WIRE)
    glows = []
    for x in (100, 500, 900):                                  # 吊灯
        glows += list(hanging_lamp(c, x, 0, 40 + (x // 100) % 3 * 6))
    for x in cols:
        wrap(c, W, column, x)
    for i, x in enumerate((40, 420, 820)):                     # 继电器柜，两两一组
        for k in range(2):
            M.relay_rack(c, x + k * 74, 196 - k * 10, x + k * 74 + 66, H - 1, lit=0.16, seed=7 + i * 2 + k)
            M.fill(c, x + k * 74, 196 - k * 10, x + k * 74 + 66, 196 - k * 10 + 2, GREY[5])
    blinks = record_lamps(c, {LAMP: 2, RELAY_RED: 3})
    # 吊灯泡不算会闪的（它们是 glows）
    gl = set((glows[i], glows[i + 1]) for i in range(0, len(glows), 2))
    keep = []
    for i in range(0, len(blinks), 3):
        x, y = blinks[i], blinks[i + 1]
        if not any(abs(x - gx) <= 1 and 0 <= y - gy <= 1 for gx, gy in gl):
            keep += blinks[i:i + 3]
    M.fade(c)
    return c, keep, glows


# ================================================================ 3 钢梁、支架、蒸汽管、阀门、压力表、竖着的别的气动管
def ibeam(c, x0, x1, y, h=12, dark=False):
    """工字钢横梁：上下翼缘亮、腹板暗，翼缘上一排铆钉。dark=True 是贴着三条道下面那根：整根压暗，
    免得一条横贯整屏的亮灰带子看着像又一条道。"""
    g = [DARK[0], DARK[1], DARK[2], DARK[3], DARK[4], GREY[0], GREY[1], GREY[2], GREY[3]] if dark else GREY
    M.fill(c, x0, y, x1, y + 2, g[5])
    M.fill(c, x0, y, x1, y, g[7])
    M.vgrad(c, x0, y + 3, x1, y + h - 4, g, 0.3, 0.12)
    M.fill(c, x0, y + h - 3, x1, y + h - 1, g[3])
    M.fill(c, x0, y + h - 1, x1, y + h - 1, g[1])
    for x in range(x0 + 3, x1, 7):
        c.put(x, y + 1, g[8])
        c.put(x, y + h - 2, g[5])
    M.metal_texture(c, x0, y + 3, x1, y + h - 4, seed=y + x0, density=0.7)


def brace(c, x, y0, y1, d):
    """斜撑：一条 3 像素宽的角钢，从梁上斜下去。"""
    n = y1 - y0
    for t in range(n):
        xx = x + d * t
        c.put(xx, y0 + t, GREY[4])
        c.put(xx + 1, y0 + t, GREY[2])
        c.put(xx + 2, y0 + t, GREY[1])


PIPE = [DARK[1], DARK[2], DARK[3], DARK[4], GREY[0], GREY[1]]


def steam_pipe(c, x0, x1, cy, r=5):
    """蒸汽管（在三条道下面）：一段一段的，两头拐个弯钻进地里，不是一根通到头的横管
    （10-18 第二关会话：原来一整根灰管带亮箍，看着像第 4 条道，正是新玩家报告第 4 条）。颜色压到很暗的几档。"""
    for y in range(cy - r, cy + r + 1):
        v = 0.8 - 0.7 * (y - cy + r) / (2 * r)
        M.fill(c, x0 + r, y, x1 - r, y, M.q(PIPE, v))
    for x in range(x0 + 40, x1 - 20, 70):                      # 法兰：暗一档的箍，不用亮灰
        M.fill(c, x, cy - r - 1, x + 2, cy + r + 1, PIPE[3])
        M.fill(c, x, cy - r - 1, x, cy + r + 1, PIPE[5])
    for ex, d in ((x0, 1), (x1, -1)):                          # 两头的弯头：往下拐进地里
        for y in range(cy - r, H):
            for x in range(ex - r if d > 0 else ex - r, ex + r + 1):
                t = (x - (ex - r)) / (2 * r)
                c.put(x, y, M.q(PIPE, 0.75 - 0.6 * t))
        M.fill(c, ex - r - 1, cy - r - 1, ex + r + 1, cy - r + 1, PIPE[4])
        M.fill(c, ex - r - 1, cy - r - 1, ex + r + 1, cy - r - 1, PIPE[5])


def valve_wheel(c, x, cy):
    """黄铜阀门：管上立一根阀杆，顶上一个手轮（不用红色，免得和道上的红阀门障碍弄混）。"""
    M.fill(c, x - 1, cy - 13, x + 1, cy - 6, GREY[4])
    M.fill(c, x - 4, cy - 8, x + 4, cy - 5, BRASS[2])
    M.fill(c, x - 4, cy - 8, x + 4, cy - 8, BRASS[4])
    for k in range(-6, 7):                                     # 手轮（从侧面看是一条扁的）
        c.put(x + k, cy - 15, BRASS[3] if k < 0 else BRASS[1])
        c.put(x + k, cy - 14, BRASS[1])
    c.put(x - 6, cy - 16, BRASS[4])
    c.put(x + 6, cy - 16, BRASS[2])
    c.put(x, cy - 16, BRASS[4])


def gauge(c, cx, cy, r=7):
    """压力表：黄铜圈、米白表盘、刻度（指针游戏里画），下面一截短管接到管上。返回表盘圆心。"""
    M.fill(c, cx - 1, cy + r, cx + 1, cy + r + 5, GREY[4])
    disc(c, cx, cy, r, BRASS[1])
    disc(c, cx, cy, r - 1, BRASS[3])
    disc(c, cx, cy, r - 2, (196, 182, 150))
    for k in range(7):                                         # 刻度：下面留一个缺口
        a = math.radians(135 + k * 45)
        c.put(int(round(cx + (r - 3) * math.cos(a))), int(round(cy + (r - 3) * math.sin(a))), (90, 80, 64))
    a = math.radians(135 + 6 * 45)
    c.put(int(round(cx + (r - 3) * math.cos(a))), int(round(cy + (r - 3) * math.sin(a))), (170, 60, 44))
    c.put(cx - r + 2, cy - r + 3, (230, 222, 196))             # 玻璃反光
    c.put(cx - r + 3, cy - r + 2, (230, 222, 196))
    return (cx, cy)


def bracket(c, x, y0, y1):
    """管道支架：从梁上吊下来的扁钢 + 底下一个半圆托。"""
    M.fill(c, x, y0, x + 1, y1, GREY[3])
    M.fill(c, x + 2, y0, x + 2, y1, GREY[1])
    M.fill(c, x - 3, y1, x + 5, y1 + 1, GREY[4])


def layer_mid():
    W = 1600
    c = Canvas(W, H)
    tubes = [250, 780, 1330]
    for x in tubes:                                            # 竖着穿过三条道后面的别的气动管（暗一点）
        M.pipe(c, [(x, 0), (x, H - 1)], dim=False)
    # 上面：一根工字钢长梁、斜撑往下扎、梁下挂一束粗电缆
    ibeam(c, 0, W - 1, 58, 13)
    for x in range(40, W, 200):
        brace(c, x, 71, 90, 1)
        brace(c, x + 120, 71, 90, -1)
    gauges = []
    for x in (160, 620, 1060, 1480):                           # 梁上挂的压力表
        gauges += list(gauge(c, x, 48))
        M.fill(c, x - 1, 55, x + 1, 57, GREY[4])
    # 下面：一根工字钢、吊着的支架托着一根粗蒸汽管，管上立着阀门和压力表
    ibeam(c, 0, W - 1, 198, 11, dark=True)
    segs = [(40, 380), (470, 760), (840, 1320), (1380, 1560)]
    for x0, x1 in segs:
        steam_pipe(c, x0, x1, 232, 6)
        for x in range(x0 + 30, x1 - 20, 80):
            bracket(c, x, 209, 224)
    for x in (90, 520, 900, 1250):
        valve_wheel(c, x, 226)
    for x in (330, 1150):
        gauges += list(gauge(c, x, 210, 8))
    for x in range(0, W, 40):                                  # 最底下一层格栅地板
        M.fill(c, x, 252, x + 38, 254, GREY[2])
        M.fill(c, x, 252, x + 38, 252, GREY[4])
        for xx in range(x + 2, x + 38, 4):
            M.fill(c, xx, 255, xx, 262, GREY[1])
    M.fade(c)
    return c, tubes, gauges


# ================================================================ 4 近景：镜头前擦过的大块剪影
def near_hoop(c, x, w=22):
    """管壁接缝那道铆钉大钢箍：上下两截实的（压在道外面），道那一段只画很淡的一层（半透明）。"""
    for y in list(range(0, BAND[0] - 2)) + list(range(BAND[1] + 3, H)):
        for xx in range(x, x + w):
            t = (xx - x) / (w - 1)
            col = SOOT[3] if t < 0.15 else (SOOT[1] if t < 0.85 else SOOT[0])
            c.put(xx, y, col)
    # 道那一段的淡影子在游戏里画（贴图只能全透明或不透明），位置记在 NEAR_HOOPS
    for y0 in (BAND[0] - 10, BAND[1] + 3):                     # 道上下两块连接板 + 铆钉
        M.fill(c, x - 4, y0, x + w + 3, y0 + 7, SOOT[2])
        M.fill(c, x - 4, y0, x + w + 3, y0, SOOT[4])
        for rx in range(x - 1, x + w + 2, 6):
            c.put(rx, y0 + 3, SOOT[5])
            c.put(rx, y0 + 4, SOOT[0])
    for y in range(6, BAND[0] - 12, 14):
        c.put(x + 3, y, SOOT[4])
    for y in range(BAND[1] + 14, H - 4, 14):
        c.put(x + 3, y, SOOT[4])


def near_elbow(c, x, top=True):
    """粗管弯头：从上面（或下面）伸进来，拐个弯又出去。"""
    r = 9
    if top:
        M.fill(c, x, 0, x + 2 * r, 40, SOOT[2])
        M.fill(c, x, 0, x + 3, 40, SOOT[4])
        M.fill(c, x + 2 * r - 2, 0, x + 2 * r, 40, SOOT[0])
        M.fill(c, x - 3, 30, x + 2 * r + 3, 34, SOOT[3])
        M.fill(c, x - 3, 30, x + 2 * r + 3, 30, SOOT[5])
        M.fill(c, x, 41, x + 2 * r + 40, 41 + 2 * r, SOOT[2])
        M.fill(c, x, 41, x + 2 * r + 40, 43, SOOT[4])
        M.fill(c, x, 41 + 2 * r - 2, x + 2 * r + 40, 41 + 2 * r, SOOT[0])
        M.fill(c, x + 2 * r + 41, 38, x + 2 * r + 45, 44 + 2 * r, SOOT[3])
    else:
        M.fill(c, x, 222, x + 2 * r, H - 1, SOOT[2])
        M.fill(c, x, 222, x + 3, H - 1, SOOT[4])
        M.fill(c, x + 2 * r - 2, 222, x + 2 * r, H - 1, SOOT[0])
        M.fill(c, x - 50, 204, x + 2 * r, 204 + 2 * r, SOOT[2])
        M.fill(c, x - 50, 204, x + 2 * r, 206, SOOT[4])
        M.fill(c, x - 54, 201, x - 50, 207 + 2 * r, SOOT[3])
        M.fill(c, x - 3, 240, x + 2 * r + 3, 244, SOOT[3])


def near_cables(c, x, w):
    """从顶上垂下来的一把电缆（垂到道上面为止）。"""
    for k in range(4):
        M.wire(c, x + k * 3, -2, x + w + k * 3, -2, 60 + k * 8, ramp=SOOT[1:5])


NEAR_HOOPS = [60, 520, 1010, 1430]


def layer_near():
    W = 1920
    c = Canvas(W, H)
    for x in NEAR_HOOPS:
        wrap(c, W, near_hoop, x)
    wrap(c, W, near_elbow, 260, True)
    wrap(c, W, near_elbow, 1200, True)
    wrap(c, W, near_elbow, 760, False)
    wrap(c, W, near_elbow, 1700, False)
    for x, w in ((340, 140), (1500, 180)):
        near_cables(c, x, w)
    # 边缘被灯打亮的一道暖色（近景是黑的剪影，只留一条受光边）
    a = c.a
    rim = (a[..., 3] == 255) & (np.roll(a[..., 3], 1, axis=0) == 0)
    rim[0] = False
    a[rim, :3] = (70, 52, 36)
    return c


# ================================================================ 输出
def main():
    out = M.ART
    night, b0 = layer_night()
    hall, b1 = layer_hall()
    relay, b2, glows = layer_relay()
    mid, tubes, gauges = layer_mid()
    near = layer_near()
    files = []
    for i, (name, cv) in enumerate((("night", night), ("hall", hall), ("relay", relay), ("mid", mid), ("near", near))):
        p = out / f"tube_bd_{i}_{name}.png"
        cv.save(p)
        files.append(p)
        print(p.name, cv.w, "x", cv.h)
    lines = [
        "## 气动管冲刺的视差背景数据（草图/第二关/tube_backdrop_art.py 生成，别手改）。",
        "## LAYERS：每层 [贴图, 宽, 跟着赛道走的倍速, 颜色, 在三条道前面吗]。",
        "## BLINKS：每层会亮灭的小灯 [x, y, 种类, ...]（种类：0 插孔灭着会亮，1 插孔亮着会灭，2 继电器琥珀灯，3 继电器红灯，5 铁塔红灯）。",
        "## GLOWS：第 2 层吊灯泡 [x, y, ...]；TUBES：第 3 层竖着的别的气动管 x；GAUGES：第 3 层压力表圆心 [x, y, ...]；",
        "## NEAR_HOOPS：近景大钢箍的左边 x（道那一段的淡影子由游戏画）。",
        "",
        "const LAYERS := [",
        '\t["res://art/levels/tube_bd_0_night.png", 960, 0.03, Color(0.86, 0.88, 1.0), false],',
        '\t["res://art/levels/tube_bd_1_hall.png", 1440, 0.12, Color(0.74, 0.73, 0.8), false],',
        '\t["res://art/levels/tube_bd_2_relay.png", 1200, 0.3, Color(0.7, 0.69, 0.75), false],',
        '\t["res://art/levels/tube_bd_3_mid.png", 1600, 0.6, Color(0.72, 0.7, 0.72), false],',
        '\t["res://art/levels/tube_bd_4_near.png", 1920, 1.9, Color.WHITE, true],',
        "]",
        f"const BLINKS := [{b0}, {b1}, {b2}, [], []]",
        f"const GLOWS := {glows}",
        f"const TUBES := {tubes}",
        f"const GAUGES := {gauges}",
        f"const NEAR_HOOPS := {NEAR_HOOPS}",
        f"const NEAR_HOOP_W := 22",
        "",
    ]
    DATA_GD.write_text("\n".join(lines))
    print("数据：", DATA_GD, "灯", [len(b) // 3 for b in (b0, b1, b2)], "吊灯", len(glows) // 2, "表", len(gauges) // 2)
    # 预览：五层叠起来（按游戏里的颜色乘一下），2 倍
    prev = Canvas(480 * 2, H)
    mods = [(0.86, 0.88, 1.0), (0.74, 0.73, 0.8), (0.84, 0.83, 0.88), (0.93, 0.92, 0.94), (1, 1, 1)]
    for cv, mod in zip((night, hall, relay, mid, near), mods):
        a = cv.a[:, :960].astype(float)
        a[..., :3] *= mod
        al = a[..., 3:4] / 255.0
        prev.a[..., :3] = (prev.a[..., :3] * (1 - al) + a[..., :3] * al).astype(np.uint8)
        prev.a[..., 3] = 255
    prev.save(M.MAPDIR / "tube_backdrop_preview.png", scale=2)


if __name__ == "__main__":
    main()
