"""第二关画风样图：放映机房 → 胶片走廊的入口，一屏 480×270，1 倍像素。

分 5 层，和第一关 parallax_scene.gd 的分组一一对应（镜头比例 0.55 / 0.7 / 0.8 / 0.9 / 1）：
  far       交换台墙（插线板、信号灯、跳线）+ 远处银幕
  beam      放映机光束照在墙上的亮块（和 far 一起动，单独一层方便以后做闪烁）
  machines  放映机、大片盘、导片轮
  film      胶片走廊（碰撞层）：下齿孔边是地面，上齿孔边是平台，中间画框是回忆画面
  near      前景：电影院座椅靠背、响铃的电话

另外两层是特效（游戏里动态画，这里只为预览）：burn（左边追人的烧穿边）、player（比例参考）。

跑法：
  "/Users/jiamulin/Desktop/程序programs/AI Oscar/.venv/bin/python" level2_style.py
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, "/Users/jiamulin/Desktop/程序programs/AI Oscar")
from oscarkit.canvas import Canvas  # noqa: E402
from oscarkit.light import Light, lit_plane, smooth_noise, polygonal  # noqa: E402
from oscarkit.shade import step_color  # noqa: E402

HERE = Path(__file__).parent
OUT = HERE / "样图"
OUT.mkdir(exist_ok=True)
GAME = Path("/Users/jiamulin/Desktop/程序programs/小游戏/Oscar Rush/oscar-rush")

W, H = 480, 270
CELL = (14, 12)

# ---------------------------------------------------------------- 尺寸（和第一关手感对齐）
# 主角约 13 像素高，满按跳 45 像素：上齿孔边比地面高 40，跳得上去。
FILM_X0 = 118          # 胶片从放映机片门出来的位置
RAIL_TOP = 176         # 上齿孔边（平台）顶面
FRAME_Y0 = 184
FRAME_Y1 = 216         # 画框 32 高
FLOOR = 216            # 下齿孔边（地面）顶面
RAIL_BOT = 224
FRAME_PITCH = 46       # 画框 44 宽 + 2 像素片框线，35mm 胶片的比例

# ---------------------------------------------------------------- 调色（暖琥珀 + 紫褐暗部）
VOID = (24, 19, 27)
WALL = (58, 46, 54)
PANEL = (78, 64, 66)
PANEL_RIM = (47, 38, 45)
JACK = (34, 27, 33)
LAMP_ON = (236, 178, 86)
LAMP_OFF = (104, 72, 56)
CORDS = [(150, 70, 62), (86, 118, 112), (168, 146, 114)]
SCREEN = (196, 184, 160)
METAL = (124, 112, 106)
BRASS = (150, 122, 84)
CASE = (150, 138, 122)       # meme 那种米色机壳，在暗处
FILM = (98, 64, 40)
FILM_RAIL = (68, 45, 33)
FRAME_LINE = (46, 31, 26)
SEPIA = [(116, 80, 52), (156, 112, 70), (200, 154, 98), (232, 196, 136)]
HOLE = (226, 182, 112)
SEAT = (46, 34, 40)
PHONE = (40, 36, 40)

LENS = (126, 136)            # 放映机镜头，主光源
LIGHTS = [
    Light(LENS[0], LENS[1], 40, (255, 232, 180), 1.6, 120),
    Light(300, 200, 30, (255, 210, 140), 0.9, 140),      # 胶片自己发的光
    Light(440, 90, 60, (240, 230, 210), 0.7, 90),        # 银幕反光
]


def lit(c, mask, base, normal=(0, 0, 1), z=0.0, gain=0.5, seed=0, center=0.25, noise=None, rim=None):
    """把一个面按场景光照切成色块，画到 c 上。"""
    if not mask.any():
        return
    out = lit_plane(mask, base, normal, z, LIGHTS, gain=gain, center=center, cell=CELL,
                    cell_seed=seed, noise=noise, noise_amp=0.6, rim=rim)
    m = out[..., 3] > 0
    c.a[m] = out[m]


def mask_of(fn):
    t = Canvas(W, H)
    fn(t)
    return t.mask


def stepped(col, k):
    return step_color(col, int(k)) if k else col


# ================================================================ far：交换台墙 + 远处银幕
def draw_far():
    c = Canvas(W, H)
    c.rect(0, 0, W - 1, H - 1, VOID)
    nz = smooth_noise(H, W, 8, 60, seed=3)
    lit(c, mask_of(lambda t: t.rect(0, 14, W - 1, 236, WALL)), WALL, seed=1, noise=nz)

    # 一列一列的插线板
    panels = []
    x = 4
    while x < W - 10:
        pw = 38
        panels.append((x, 26, x + pw, 168))
        x += pw + 6
    for i, (x0, y0, x1, y1) in enumerate(panels):
        if x0 > 360:      # 右边留给银幕
            continue
        lit(c, mask_of(lambda t: t.rect(x0, y0, x1, y1, PANEL_RIM)), PANEL_RIM, seed=10 + i)
        lit(c, mask_of(lambda t: t.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, PANEL)), PANEL, seed=20 + i,
            rim=(-1, -1))
        # 插孔网格 + 信号灯
        rng = np.random.default_rng(i)
        for gy in range(y0 + 8, y1 - 14, 7):
            for gx in range(x0 + 5, x1 - 3, 5):
                c.put(gx, gy, JACK)
                c.put(gx, gy + 1, JACK)
                if gy % 14 == (y0 + 8) % 14 and rng.random() < 0.55:
                    c.put(gx, gy - 2, LAMP_ON if rng.random() < 0.35 else LAMP_OFF)
        # 铭牌
        c.rect(x0 + 6, y1 - 10, x1 - 6, y1 - 7, stepped(PANEL, 2))
        # 跳线：从一个孔垂下来再插进另一个孔
        for k in range(3):
            ax = int(rng.integers(x0 + 5, x1 - 3)) // 5 * 5
            bx = ax + int(rng.integers(-30, 30))
            ay = int(rng.integers(y0 + 20, y1 - 40))
            sag = int(rng.integers(18, 40))
            col = CORDS[(i + k) % 3]
            pts = []
            for s in range(0, 21):
                t = s / 20
                px = ax + (bx - ax) * t
                py = ay + sag * 4 * t * (1 - t) + 6 * t
                pts.append((int(round(px)), int(round(py))))
            for p, q in zip(pts, pts[1:]):
                c.line(p[0], p[1], q[0], q[1], col)

    # 交换台台面（接线员的桌子）
    lit(c, mask_of(lambda t: t.rect(0, 168, 360, 176, BRASS)), BRASS, normal=(0, -1, 1), z=8, seed=30, rim=(0, -1))
    lit(c, mask_of(lambda t: t.rect(0, 177, 360, 236, PANEL_RIM)), PANEL_RIM, normal=(0, 0.3, 1), z=8, seed=31)

    # 远处银幕：被光束照亮的一块
    sx0, sy0, sx1, sy1 = 380, 34, 474, 132
    lit(c, mask_of(lambda t: t.rect(sx0 - 4, sy0 - 4, sx1 + 4, sy1 + 6, PANEL_RIM)), PANEL_RIM, seed=40)
    lit(c, mask_of(lambda t: t.rect(sx0, sy0, sx1, sy1, SCREEN)), SCREEN, seed=41, gain=0.35)
    # 银幕上放的画面：一座房子的剪影（录像里的家）
    house = [(404, 118), (404, 86), (426, 66), (448, 86), (448, 118)]
    c.poly(house, stepped(SCREEN, -3))
    c.rect(420, 98, 430, 118, stepped(SCREEN, -1))
    c.rect(410, 90, 416, 96, stepped(SCREEN, 2))
    c.rect(436, 90, 442, 96, stepped(SCREEN, 2))
    c.rect(sx0, sy1 - 12, sx1, sy1, stepped(SCREEN, -2))
    # 幕布两边的帘子
    for side, (a0, a1) in enumerate([(sx0 - 14, sx0 - 4), (sx1 + 4, W - 1)]):
        lit(c, mask_of(lambda t: t.rect(a0, 20, a1, 150, (110, 46, 52))), (110, 46, 52), seed=50 + side,
            noise=smooth_noise(H, W, 3, 80, seed=side))
    # 银幕下方的舞台边
    lit(c, mask_of(lambda t: t.rect(362, 150, W - 1, 158, BRASS)), BRASS, normal=(0, -1, 1), z=6, seed=55)
    return c


# ================================================================ beam：光束打在墙上的亮块
def beam_polygon():
    return [LENS, (380, 30), (474, 30), (474, 136), (380, 140)]


def draw_beam(far):
    """光束不是半透明叠色，而是把墙上落在光锥里的色块提亮 1~2 档（Oscar 的做法：光切成档）。"""
    c = Canvas(W, H)
    cone = mask_of(lambda t: t.poly(beam_polygon(), (1, 1, 1)))
    core = mask_of(lambda t: t.poly([LENS, (380, 62), (474, 64), (474, 104), (380, 108)], (1, 1, 1)))
    ys, xs = np.nonzero(cone & (far.a[..., 3] > 0))
    # 光束里越靠近镜头越亮，块边用三角网格切直
    d = np.hypot(np.arange(W)[None, :] - LENS[0], np.arange(H)[:, None] - LENS[1])
    f = polygonal(1.6 - d / 260.0, 22, 16, seed=7)
    cache = {}
    for y, x in zip(ys, xs):
        if 380 <= x and 30 <= y <= 136:     # 银幕本身已经是亮的
            continue
        k = int(np.clip(round(f[y, x] + (0.8 if core[y, x] else 0)), 1, 3))
        col = tuple(far.a[y, x, :3])
        key = (col, k)
        if key not in cache:
            cache[key] = step_color(col, k, hue_deg=7)
        c.put(x, y, cache[key])
    # 光束里的灰尘
    rng = np.random.default_rng(11)
    for _ in range(46):
        i = rng.integers(len(ys))
        y, x = ys[i], xs[i]
        if x < 360:
            c.put(x, y, (238, 214, 168))
    return c


# ================================================================ machines：放映机、片盘、导片轮
def reel(c, cx, cy, r, seed, base=METAL):
    disk = mask_of(lambda t: t.ellipse(cx, cy, r, r, base))
    lit(c, disk, base, z=20, seed=seed, rim=(-1, -1), gain=0.6)
    # 片盘上缠着的一圈胶片
    film = mask_of(lambda t: t.ellipse(cx, cy, int(r * 0.78), int(r * 0.78), FILM))
    lit(c, film, FILM, z=22, seed=seed + 1, gain=0.5)
    for rr in range(int(r * 0.3), int(r * 0.78), 3):
        for a in range(0, 360, 2):
            if (a // 2 + rr) % 9 == 0:
                x = int(round(cx + rr * math.cos(math.radians(a))))
                y = int(round(cy + rr * math.sin(math.radians(a))))
                c.put(x, y, stepped(FILM, -1))
    # 金属盘面上的三个大圆孔（老片盘的标志）
    for k in range(3):
        a = math.radians(90 + k * 120 + seed * 7)
        hx, hy = cx + r * 0.52 * math.cos(a), cy + r * 0.52 * math.sin(a)
        hr = max(3, int(r * 0.2))
        hole = mask_of(lambda t: t.ellipse(int(hx), int(hy), hr, hr, (1, 1, 1)))
        c.a[hole] = (*stepped(FILM, -2), 255)
        c.a[hole & (np.roll(hole, 1, 0) == 0)] = (*stepped(FILM, 1), 255)
    hub = mask_of(lambda t: t.ellipse(cx, cy, max(3, r // 6), max(3, r // 6), BRASS))
    lit(c, hub, BRASS, z=24, seed=seed + 2, rim=(-1, -1))
    c.put(cx, cy, VOID)


def draw_machines():
    c = Canvas(W, H)
    # 放映机机身（meme 风格的米色机壳）
    body = mask_of(lambda t: t.rect(14, 112, 112, 206, CASE))
    lit(c, body, CASE, z=30, seed=60, gain=0.45, rim=(-1, -1), noise=smooth_noise(H, W, 30, 30, seed=60))
    top = mask_of(lambda t: t.poly([(14, 112), (24, 104), (120, 104), (112, 112)], CASE))
    lit(c, top, stepped(CASE, 2), normal=(0, -1, 0.6), z=34, seed=61)
    side = mask_of(lambda t: t.poly([(112, 112), (120, 104), (120, 198), (112, 206)], CASE))
    lit(c, side, stepped(CASE, -2), normal=(1, 0, 0.3), z=34, seed=62)
    # 机壳上的格栅、铭牌、旋钮、指示灯
    for y in range(124, 150, 3):
        c.line(24, y, 62, y, stepped(CASE, -3))
    c.rect(70, 122, 104, 132, stepped(CASE, -4))
    c.rect(72, 124, 102, 130, (58, 70, 60))
    for k, x in enumerate(range(74, 100, 6)):
        c.put(x, 127, (130, 200, 140) if k % 2 else (70, 110, 80))
    for kx in (78, 94):
        c.ellipse(kx, 148, 4, 4, stepped(CASE, -5))
        c.put(kx - 1, 146, stepped(CASE, 1))
    c.rect(24, 160, 104, 164, stepped(CASE, -3))
    c.put(30, 172, (220, 70, 60))
    c.put(31, 172, (220, 70, 60))
    c.put(36, 172, LAMP_OFF)
    c.put(37, 172, LAMP_OFF)
    # 镜头筒
    barrel = mask_of(lambda t: t.rect(112, 128, 124, 144, METAL))
    lit(c, barrel, METAL, normal=(0, -0.4, 1), z=36, seed=63, rim=(0, -1))
    c.rect(124, 130, 127, 142, stepped(METAL, -2))
    c.ellipse(LENS[0] + 1, LENS[1], 2, 5, (250, 236, 196))
    # 片门：胶片从这里出来
    c.rect(104, 172, 118, 226, stepped(CASE, -4))
    c.rect(106, 176, 118, 222, (34, 26, 28))
    # 机脚
    c.rect(20, 206, 30, 236, PANEL_RIM)
    c.rect(96, 206, 106, 236, PANEL_RIM)

    # 两只供片盘装在放映机顶上，用支臂撑着
    c.line(46, 104, 50, 66, stepped(METAL, -2))
    c.line(47, 104, 51, 66, stepped(METAL, -1))
    c.line(92, 104, 100, 50, stepped(METAL, -2))
    c.line(93, 104, 101, 50, stepped(METAL, -1))
    reel(c, 50, 62, 30, 1)
    reel(c, 104, 46, 38, 2)
    # 片盘出来的胶片导进机器
    c.line(132, 46, 120, 106, FILM)
    c.line(133, 46, 121, 106, stepped(FILM, -1))

    # 右上大收片盘，胶片从走廊尽头卷上去
    reel(c, 330, 40, 46, 3, base=stepped(METAL, -1))
    # 导片轮：小平台
    for gx, gy in ((210, 140), (268, 128), (330, 118)):
        g = mask_of(lambda t: t.ellipse(gx, gy, 6, 6, BRASS))
        lit(c, g, BRASS, z=26, seed=gx, rim=(-1, -1))
        c.put(gx, gy, VOID)
        for a in range(0, 360, 45):
            c.put(int(gx + 7 * math.cos(math.radians(a))), int(gy + 7 * math.sin(math.radians(a))), stepped(BRASS, -2))
    return c


# ================================================================ film：胶片走廊（碰撞层）
def memory_frame(c, x0, y0, kind):
    """画框里的回忆：家里的几个镜头，都用褐色调剪影。"""
    w, h = FRAME_PITCH - 2, FRAME_Y1 - FRAME_Y0
    s0, s1, s2, s3 = SEPIA
    c.rect(x0, y0, x0 + w - 1, y0 + h - 1, s2)
    c.rect(x0, y0 + h - 9, x0 + w - 1, y0 + h - 1, s1)               # 地面
    g = y0 + h - 9
    if kind == 0:      # 房子
        c.poly([(x0 + 10, g), (x0 + 10, g - 12), (x0 + 21, g - 21), (x0 + 32, g - 12), (x0 + 32, g)], s0)
        c.rect(x0 + 15, g - 9, x0 + 18, g - 6, s3)
        c.rect(x0 + 24, g - 8, x0 + 27, g, s1)
    elif kind == 1:    # 四个人站成一排（就是四个船员）
        for k, hh in enumerate((12, 10, 7, 9)):
            px = x0 + 8 + k * 8
            c.rect(px, g - hh, px + 3, g - 1, s0)
            c.rect(px, g - hh - 3, px + 3, g - hh - 1, s0)
        c.line(x0 + 11, g - 6, x0 + 33, g - 6, s0)
    elif kind == 2:    # 树和太阳
        c.ellipse(x0 + 32, y0 + 8, 4, 4, s3)
        c.rect(x0 + 14, g - 10, x0 + 16, g - 1, s0)
        c.ellipse(x0 + 15, g - 15, 8, 7, s0)
    elif kind == 3:    # 一家人围着电视
        c.rect(x0 + 16, g - 11, x0 + 30, g - 1, s0)
        c.rect(x0 + 18, g - 9, x0 + 28, g - 4, s3)
        for px in (x0 + 6, x0 + 36):
            c.rect(px, g - 7, px + 3, g - 1, s0)
            c.rect(px, g - 10, px + 3, g - 8, s0)
    # 老胶片的划痕和片框边的暗角
    c.line(x0 + 5 + kind * 7, y0, x0 + 5 + kind * 7, y0 + h - 1, s3 if kind % 2 else s1)
    for k in range(w):
        if k % 3 == 0:
            c.put(x0 + k, y0, s1)
            c.put(x0 + k, y0 + h - 1, s0)


def rail(c, y0, seed):
    m = mask_of(lambda t: t.rect(FILM_X0, y0, W - 1, y0 + 7, FILM_RAIL))
    lit(c, m, FILM_RAIL, normal=(0, 0, 1), z=10, seed=seed, rim=(0, -1), gain=0.4)
    # 齿孔：4 个一组对着一个画框，透出后面的光
    for x in range(FILM_X0 + 4, W, FRAME_PITCH):
        for k in range(4):
            hx = x + k * 11
            if hx + 4 >= W:
                continue
            c.rect(hx, y0 + 2, hx + 4, y0 + 5, HOLE)
            c.rect(hx + 1, y0 + 2, hx + 3, y0 + 2, (250, 222, 160))
            c.put(hx, y0 + 2, FILM_RAIL)
            c.put(hx + 4, y0 + 5, FILM_RAIL)


def draw_film():
    c = Canvas(W, H)
    rail(c, RAIL_TOP, 70)
    rail(c, FLOOR, 71)
    c.line(FILM_X0, RAIL_TOP, W - 1, RAIL_TOP, stepped(FILM_RAIL, 3))   # 能站的顶面亮一条
    c.line(FILM_X0, FLOOR, W - 1, FLOOR, stepped(FILM_RAIL, 3))
    x = FILM_X0
    k = 0
    while x < W:
        c.rect(x, FRAME_Y0, x + 1, FRAME_Y1 - 1, FRAME_LINE)
        memory_frame(c, x + 2, FRAME_Y0, [1, 0, 3, 2, 1, 0, 2, 3][k % 8])
        x += FRAME_PITCH
        k += 1
    # 放映机里刚出来的一小段还是暗的（没被照亮）
    c.rect(FILM_X0, FRAME_Y0, FILM_X0 + 1, FRAME_Y1 - 1, FRAME_LINE)
    # 走廊尽头胶片往上卷到收片盘（导片轮之间的斜段，可以当斜坡）
    pts = [(204, 140), (210, 133), (268, 121), (330, 111), (372, 76)]
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        for o in range(3):
            c.line(ax, ay + o, bx, by + o, FILM_RAIL if o != 1 else HOLE)
    return c


# ================================================================ near：座椅靠背、电话
def draw_near():
    c = Canvas(W, H)
    nz = smooth_noise(H, W, 6, 30, seed=90)
    for i, x in enumerate(range(-6, W, 30)):
        back = mask_of(lambda t: t.poly([(x, H), (x + 2, 246), (x + 6, 240), (x + 22, 240), (x + 26, 246), (x + 28, H)], SEAT))
        lit(c, back, SEAT, z=60, seed=100 + i, rim=(0, -1), gain=0.6, noise=nz)
        c.line(x + 6, 240, x + 22, 240, stepped(SEAT, 2))
    # 一台响铃的老电话立在座椅前面（来波预警就是它在响）
    px, py = 440, 238
    c.rect(px - 1, py - 14, px + 1, py, PHONE)
    c.rect(px - 6, py, px + 6, py + 3, PHONE)
    c.ellipse(px, py - 17, 4, 3, PHONE)
    c.rect(px + 4, py - 12, px + 7, py - 6, PHONE)          # 挂着的听筒
    c.line(px - 3, py - 18, px + 3, py - 18, stepped(PHONE, 2))
    for r, col in ((8, (236, 178, 86)), (11, (180, 120, 70))):  # 铃声的弧线
        for a in range(-60, 61, 12):
            for sgn in (-1, 1):
                ang = math.radians(a + (90 if sgn > 0 else 270) - 90)
                c.put(int(px + sgn * r * math.cos(math.radians(a))), int(py - 17 + r * math.sin(math.radians(a))), col)
    return c


# ================================================================ 特效（预览用）
def draw_burn():
    """左边缘：胶片被放映机烧穿，像老电影卡住时那种冒泡的洞，追着玩家。"""
    c = Canvas(W, H)
    rng = np.random.default_rng(5)
    edge = smooth_noise(H, W, 20, 9, seed=8)[:, 0]
    for y in range(H):
        e = 34 + edge[y] * 10
        for x in range(0, int(e) + 8):
            d = e - x
            if d > 18:
                col = (255, 244, 214)
            elif d > 10:
                col = (250, 206, 100)
            elif d > 4:
                col = (226, 120, 54)
            elif d > 0:
                col = (110, 46, 32)
            else:
                if rng.random() < 0.25:
                    col = (64, 30, 26)
                else:
                    continue
            c.put(x, y, col)
    # 往右飘的火星
    for _ in range(24):
        x, y = int(rng.integers(36, 70)), int(rng.integers(0, H))
        c.put(x, y, (250, 206, 100) if rng.random() < 0.5 else (226, 120, 54))
    return c


def draw_player():
    c = Canvas(W, H)
    strip = np.array(Image.open(GAME / "art/chars/red_strip.png").convert("RGBA"))
    fr = strip[:, 0:16]
    ys, xs = np.nonzero(fr[..., 3])
    fr = fr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = fr.shape[:2]
    x0, y0 = 170, FLOOR - h
    sub = c.a[y0:y0 + h, x0:x0 + w]
    m = fr[..., 3] > 0
    sub[m] = fr[m]
    # 手里的马灯
    c.rect(x0 + w + 1, FLOOR - 7, x0 + w + 3, FLOOR - 4, (250, 220, 150))
    # 画框里走出来的一只爬虫（示意怪从画面里出来）
    cr = GAME / "art/enemies/crawler.png"
    if cr.exists():
        e = np.array(Image.open(cr).convert("RGBA"))
        ys, xs = np.nonzero(e[..., 3])
        e = e[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        eh, ew = e.shape[:2]
        if ew > 40:
            e = e[:, :ew // max(1, ew // eh)]
            eh, ew = e.shape[:2]
        ex, ey = 300, FLOOR - eh
        sub = c.a[ey:ey + eh, ex:ex + ew]
        m = e[..., 3] > 0
        sub[m] = e[m]
    return c


def over(dst, src):
    m = src.a[..., 3] > 0
    dst.a[m] = src.a[m]


def main():
    far = draw_far()
    beam = draw_beam(far)
    machines = draw_machines()
    film = draw_film()
    near = draw_near()
    burn = draw_burn()
    player = draw_player()

    layers = {"far": far, "beam": beam, "machines": machines, "film": film, "near": near}
    for name, cv in layers.items():
        cv.save(OUT / f"level2_sample_{name}.png")
    burn.save(OUT / "level2_sample_fx_burn.png")

    comp = far.copy()
    for cv in (beam, machines, film, near):
        over(comp, cv)
    comp.save(OUT / "level2_sample.png")
    comp.save(OUT / "level2_sample_3x.png", scale=3)

    play = comp.copy()
    for cv in (player, burn):
        over(play, cv)
    play.save(OUT / "level2_sample_play_3x.png", scale=3)
    print("ok", OUT)


if __name__ == "__main__":
    main()
