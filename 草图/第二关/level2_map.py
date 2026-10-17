"""第二关整张地图：交换台大厅 → 胶片天桥 → 放映厅。3700×600，1 倍像素。

跑法：
  "/Users/jiamulin/Desktop/程序programs/AI Oscar/.venv/bin/python" level2_map.py

画法跟 Oscar 的场景2.aseprite：柔和分档渐变、中性灰 + 黄铜 + 红木、不用三角切面；胶片是画面里最亮的东西。

输出
  oscar-rush/art/levels/level2_far.png       0.55  远处：交换台墙、投在黑暗里的画面、放映厅后墙
  oscar-rush/art/levels/level2_mid.png       0.75  吊杆、配重球、线圈、继电器架、远处下垂的胶片
  oscar-rush/art/levels/level2_back.png      1.0   房间里的墙（插线板墙、放映室、观众厅墙和银幕）
  oscar-rush/art/levels/level2_props.png     1.0   接线台、电话、大片盘、放映机（人从前面走过）
  oscar-rush/art/levels/level2_solid.png     1.0   能站的东西：楼层、墙、胶片天桥、台阶座位、舞台
  oscar-rush/art/levels/level2_film.png      1.0   胶片天桥（游戏里不吃压暗）
  oscar-rush/art/levels/level2_near.png      1.0   前景：垂下来的线缆、座椅靠背
  oscar-rush/scripts/levels/level2_data.gd         上面这份 JSON 的 GDScript 版本（关卡直接 preload）
  oscar-rush/art/levels/level2_collision.json      碰撞矩形、出生点、出口、遭遇战、电话、换卷点
  草图/第二关/地图/level2_overview.png              不做视差换算、全部叠起来的总览（1 倍）
  草图/第二关/地图/level2_route.png                 总览 + 红色路线和标记
  草图/第二关/地图/level2_view_*.png                按游戏里的视差、在几个镜头位置截的屏（3 倍）

视差：parallax_scene.gd 让 s<1 的层在镜头偏离关卡正中时"落后"。
所以 s<1 的层上，想出现在地图 X 处背后的东西，要画在 s*X + (1-s)*CX（竖直方向落后量减半）。
总览图用不换算的坐标画同一套东西。
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
sys.path.insert(0, "/Users/jiamulin/Desktop/程序programs/AI Oscar")
sys.path.insert(0, str(HERE))
from oscarkit.canvas import Canvas  # noqa: E402
from oscarkit.shade import step_color  # noqa: E402
from oscarkit.light import smooth_noise  # noqa: E402
from oscarkit.measure import srgb_to_oklab  # noqa: E402
from oscarkit.palette import oklab_to_srgb  # noqa: E402
import level2_bridge as LB  # noqa: E402
import film_scenes as FS  # noqa: E402

GAME = Path("/Users/jiamulin/Desktop/程序programs/小游戏/Oscar Rush/oscar-rush")
ART = GAME / "art/levels"
MAPDIR = HERE / "地图"
MAPDIR.mkdir(exist_ok=True)

MW, MH = 3700, 600
CX, CY = MW / 2, MH / 2

# ---------------------------------------------------------------- 地形（地图坐标）
A_X1 = 1000                  # 前半段右边界（天桥从这里开始）
B_X0 = 2840                  # 后半段左边界
WALL = 12                    # 机房的墙、天花板、地板厚度
GIRDER = 10
BRIDGE_Y = 300               # 胶片天桥地面（下齿孔边顶面）
FILM_DY = BRIDGE_Y - LB.FLOOR            # 胶片样图在 270 高画布里的地面是 167
FILM_TOP = LB.FILM_TOP + FILM_DY         # 223
FILM_BOT = LB.FILM_BOT + FILM_DY         # 313
ROWS = [(3170 + 40 * i, 300 + 22 * (i + 1)) for i in range(9)]   # 观众席台阶 (x0, 顶面 y)，每排宽 40
ORCH_Y = 520
STAGE = (3600, 500)

# 前半段（10-17 作者定，换掉和第一关一样的三层折返）：四间悬在交换局大厅里的机房，
# 房间之间用玻璃气动管传送。x0/x1 是室内左右，top 是天花板下沿，floor 是地面
ROOMS = [
    {"name": "R1 接线员大厅", "x0": 40, "x1": 420, "top": 440, "floor": 540, "theme": "switch"},
    {"name": "R2 继电器机房", "x0": 532, "x1": 900, "top": 340, "floor": 430, "theme": "relay"},
    {"name": "R3 电话簿仓库", "x0": 52, "x1": 440, "top": 150, "floor": 250, "theme": "books"},
    {"name": "R4 片库", "x0": 560, "x1": A_X1, "top": 200, "floor": BRIDGE_Y, "theme": "film"},
]
# 气动管：mouth 是管口（房间墙上，人走进这块就被吸走，x, y, w, h），path 是管子走的折线，
# out/vel 是从下一间房喷出来的位置和速度，needs 是先打完第几场遭遇战管口才开
TUBES = [
    {"mouth": (404, 516, 16, 24), "path": [(426, 528), (468, 528), (468, 410), (526, 410)],
     "out": (548, 429), "vel": (130, -90), "needs": 0},
    {"mouth": (884, 406, 16, 24), "path": [(906, 418), (940, 418), (940, 470), (500, 470), (500, 236), (446, 236)],
     "out": (424, 249), "vel": (-130, -90), "needs": 1},
    {"mouth": (52, 226, 16, 24), "path": [(46, 238), (20, 238), (20, 62), (640, 62), (640, 194)],
     "out": (640, 214), "vel": (60, 40), "needs": 2},
]

SOLIDS = []                  # 碰撞矩形：x, y, w, h, 名字


def solid(x0, y0, x1, y1, name):
    SOLIDS.append({"name": name, "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0})


for r in ROOMS:
    n, x0, x1, top, fl = r["name"], r["x0"], r["x1"], r["top"], r["floor"]
    right = x1 if r["theme"] == "film" else x1 + WALL       # 片库右边敞开，直接接天桥
    solid(x0 - WALL, top - WALL, right, top, n + " 天花板")
    solid(x0 - WALL, fl, right, MH if n.startswith("R1") else fl + WALL, n + " 地面")
    solid(x0 - WALL, top, x0, fl, n + " 左墙")
    if r["theme"] != "film":
        solid(x1, top, x1 + WALL, fl, n + " 右墙")
solid(A_X1, BRIDGE_Y, B_X0, FILM_BOT, "胶片天桥")
solid(B_X0, 200, 3116, 214, "放映室天花板")
solid(3100, 214, 3116, 262, "放映室前墙（下面钻过去）")
solid(B_X0, BRIDGE_Y, 3170, MH, "放映室地板 + 包厢边")
for i, (rx, ry) in enumerate(ROWS):
    solid(rx, ry, rx + 40, MH, f"座位第 {i + 1} 排")
solid(ROWS[-1][0] + 40, ORCH_Y, MW, MH, "乐池地面")
solid(STAGE[0], STAGE[1], MW, ORCH_Y, "舞台")
solid(3116, 0, MW, 40, "观众厅天花板")
solid(MW - 16, 0, MW, MH, "B 右墙")

ENCOUNTERS = [
    {"name": "E1 接线员大厅", "x0": 110, "x1": 396, "floor_y": 540, "ceil": 440, "dir": "→"},
    {"name": "E2 继电器机房", "x0": 566, "x1": 880, "floor_y": 430, "ceil": 340, "dir": "→"},
    {"name": "E3 电话簿仓库", "x0": 72, "x1": 410, "floor_y": 250, "ceil": 150, "dir": "←"},
    {"name": "E4 乐池", "x0": 3470, "x1": 3684, "floor_y": ORCH_Y, "ceil": 330, "dir": "→"},
]
PHONES = [(250, 500), (720, 392), (250, 212), (3520, 470)]           # 墙上的电话：铃响预告来波
REEL_CHANGES = [1640, 2280]                                         # 天桥上的换卷点（镜头停下，打精英怪）
SPAWN = (70, 540)
EXIT = (3664, STAGE[1])

# ---------------------------------------------------------------- 调色（取自 Oscar 场景2）
VOID = (17, 16, 16)
DARK = [(14, 13, 13), (19, 17, 16), (24, 22, 20), (30, 27, 24), (37, 33, 29)]
GREY = LB.GREY
BRASS = LB.BRASS
WOOD = [(36, 12, 6), (52, 16, 7), (61, 19, 7), (81, 25, 9), (96, 29, 10), (122, 46, 20)]
TAN = [(83, 66, 46), (117, 88, 53), (147, 111, 68), (181, 142, 96)]
VELVET = [(34, 11, 13), (52, 16, 18), (74, 23, 25), (100, 34, 34), (132, 52, 48)]
LAMP = (236, 178, 86)
LAMP_OFF = (96, 66, 44)
SEPIA = LB.SEPIA


# ================================================================ 基础画法（直接切片，大画布上也快）
class Layer:
    """一张图层画布 + 坐标换算：s<1 的层按视差把设计坐标挪到图层坐标（design=True 时不换算）。"""

    def __init__(self, s=1.0, design=False):
        self.c = Canvas(MW, MH)
        self.s = 1.0 if design else s

    def X(self, x):
        return int(round(self.s * x + (1 - self.s) * CX))

    def Y(self, y):
        k = (1 - self.s) * 0.5
        return int(round(y * (1 - k) + k * CY))


def fill(c, x0, y0, x1, y1, col):
    """含两端的实心矩形。"""
    x0, x1 = max(0, int(x0)), min(c.w - 1, int(x1))
    y0, y1 = max(0, int(y0)), min(c.h - 1, int(y1))
    if x1 < x0 or y1 < y0:
        return
    c.a[y0:y1 + 1, x0:x1 + 1, :3] = col[:3]
    c.a[y0:y1 + 1, x0:x1 + 1, 3] = 255


def q(ramp, v):
    return ramp[int(np.clip(round(v * (len(ramp) - 1)), 0, len(ramp) - 1))]


def vgrad(c, x0, y0, x1, y1, ramp, v0, v1):
    for y in range(int(y0), int(y1) + 1):
        t = (y - y0) / max(1, y1 - y0)
        fill(c, x0, y, x1, y, q(ramp, v0 + (v1 - v0) * t))


def hgrad(c, x0, y0, x1, y1, ramp, v0, v1):
    for x in range(int(x0), int(x1) + 1):
        t = (x - x0) / max(1, x1 - x0)
        fill(c, x, y0, x, y1, q(ramp, v0 + (v1 - v0) * t))


def spoly(c, pts, col):
    """只在包围盒里算的多边形（大画布上 Canvas.poly 太慢）。"""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    bx0, by0 = int(min(xs)) - 1, int(min(ys)) - 1
    t = Canvas(int(max(xs)) - bx0 + 2, int(max(ys)) - by0 + 2)
    t.poly([(x - bx0, y - by0) for x, y in pts], col)
    c.paste(t, bx0, by0)


def sellipse(c, cx, cy, rx, ry, col):
    t = Canvas(2 * rx + 3, 2 * ry + 3)
    t.ellipse(rx + 1, ry + 1, rx, ry, col)
    c.paste(t, int(cx) - rx - 1, int(cy) - ry - 1)


def wire(c, ax, ay, bx, by, sag, ramp=TAN, n=None):
    """Oscar 的电线：两像素粗，上亮下暗，中间往下垂。"""
    n = n or max(8, int(abs(bx - ax) + abs(by - ay)))
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((int(round(ax + (bx - ax) * t)), int(round(ay + (by - ay) * t + sag * 4 * t * (1 - t)))))
    for (x, y) in pts:
        c.put(x, y, ramp[-1])
        c.put(x, y + 1, ramp[1])


def ball(c, cx, cy, r):
    LB.ball(c, int(cx), int(cy), r)


_STEP = {}


def nudge(c, x, y, k):
    """把 (x, y) 这一格的颜色挪 k 档（OKLab 明暗 + 冷暖），透明的格子不动。纹理都用它画，不加新色相。"""
    if not (0 <= x < c.w and 0 <= y < c.h) or c.a[y, x, 3] == 0:
        return
    col = (int(c.a[y, x, 0]), int(c.a[y, x, 1]), int(c.a[y, x, 2]))
    key = (col, k)
    if key not in _STEP:
        _STEP[key] = step_color(col, k)
    c.a[y, x, :3] = _STEP[key]


RUST = [(58, 34, 24), (78, 44, 28), (98, 58, 34)]


def metal_texture(c, x0, y0, x1, y1, seed=0, density=1.0):
    """钢板上的纹理：横向接缝 + 铆钉、短划痕（亮一档）、锈斑（几格锈色）、铆钉往下淌的锈水（暗一档）。"""
    rng = np.random.default_rng(seed)
    w, h = x1 - x0, y1 - y0
    if w < 6 or h < 6:
        return
    for yy in range(y0 + 28, y1 - 4, 30):                    # 横缝和一排铆钉
        for x in range(x0, x1 + 1):
            nudge(c, x, yy, -2)
            nudge(c, x, yy + 1, 1)
        for x in range(x0 + 5, x1 - 2, 9):
            nudge(c, x, yy - 3, 2)
            nudge(c, x, yy - 2, -1)
    area = w * h
    for _ in range(int(area / 260 * density)):               # 划痕
        x, y = int(rng.integers(x0, x1)), int(rng.integers(y0, y1))
        n = int(rng.integers(3, 7))
        d = 1 if rng.random() < 0.5 else -1
        for t in range(n):
            nudge(c, x + t, y + (t * d) // 2, 1)
    for _ in range(int(area / 1400 * density)):              # 锈斑
        x, y = int(rng.integers(x0 + 2, x1 - 2)), int(rng.integers(y0 + 2, y1 - 2))
        for t in range(int(rng.integers(3, 9))):
            px, py = x + int(rng.integers(-2, 3)), y + int(rng.integers(-1, 2))
            if x0 <= px <= x1 and y0 <= py <= y1 and c.a[py, px, 3]:
                c.put(px, py, RUST[int(rng.integers(0, 3))])
    for _ in range(int(area / 900 * density) if h > 12 else 0):   # 锈水痕
        x, y = int(rng.integers(x0, x1)), int(rng.integers(y0, y1 - 8))
        for t in range(int(rng.integers(4, 12))):
            if y + t <= y1:
                nudge(c, x, y + t, -1)


def girder(c, x0, x1, y, th=GIRDER, under=True):
    """钢梁楼层：顶面一条亮边，侧面分档，防滑花纹（一排排斜短线），铆钉；底下挂一排三角桁架（不算碰撞）。"""
    fill(c, x0, y, x1, y, GREY[7])
    fill(c, x0, y + 1, x1, y + 1, GREY[5])
    vgrad(c, x0, y + 2, x1, y + th - 1, GREY, 0.45, 0.2)
    fill(c, x0, y + th - 1, x1, y + th - 1, GREY[1])
    for x in range(x0 + 1, x1 - 1, 4):                       # 防滑花纹钢板
        for yy in range(y + 3, y + th - 2, 3):
            o = 2 if ((yy - y) // 3) % 2 else 0
            nudge(c, x + o, yy, 1)
            nudge(c, x + o + 1, yy - 1, 1)
    for x in range(x0 + 6, x1 - 2, 14):
        c.put(x, y + 4, BRASS[4])
        c.put(x, y + 5, BRASS[1])
    metal_texture(c, x0, y + 2, x1, y + th - 2, seed=x0 + y, density=0.6)
    if under:
        for x in range(x0, x1 - 10, 20):
            for t in range(11):
                c.put(x + t, y + th + t // 2, GREY[2])
                c.put(x + 20 - t, y + th + t // 2, GREY[2])
        fill(c, x0, y + th + 5, x1, y + th + 5, GREY[2])


def block(c, x0, y0, x1, y1, seam=40):
    """实心的钢板墙：深灰，竖向接缝，接缝两边有螺栓，再加横缝、划痕、锈斑、锈水。"""
    vgrad(c, x0, y0, x1, y1, DARK + [GREY[0], GREY[1]], 0.85, 0.15)
    for x in range(x0 + seam // 2, x1, seam):
        fill(c, x, y0 + 3, x, y1, DARK[0])
        fill(c, x + 1, y0 + 3, x + 1, y1, GREY[1])
        for yy in range(y0 + 10, y1, 30):
            c.put(x - 3, yy, GREY[3])
            c.put(x + 4, yy, GREY[3])
    metal_texture(c, x0, y0, x1, y1, seed=x0 * 7 + y0)


def wallpaper(c, x0, y0, x1, y1, seed=0):
    """机房墙面：竖条暗纹壁纸（菱形小花），下半截护墙板，再加几块水渍和一两处剥落。"""
    rng = np.random.default_rng(seed)
    wains = y1 - 22
    for x in range(x0, x1 + 1):
        for y in range(y0, wains):
            if (x - x0) % 10 == 0:
                nudge(c, x, y, 1)
            elif (x - x0) % 10 == 5 and (y - y0) % 12 in (5, 7):
                nudge(c, x, y, 1)
            elif (x - x0) % 10 in (4, 6) and (y - y0) % 12 == 6:
                nudge(c, x, y, 1)
    fill(c, x0, wains, x1, y1, WOOD[1])                       # 护墙板
    fill(c, x0, wains, x1, wains, WOOD[3])
    fill(c, x0, wains + 1, x1, wains + 1, WOOD[0])
    for x in range(x0 + 4, x1, 26):
        fill(c, x, wains + 4, x + 20, y1 - 3, WOOD[2])
        fill(c, x, wains + 4, x + 20, wains + 4, WOOD[3])
    noise = smooth_noise(y1 - y0 + 1, x1 - x0 + 1, 10, 30, seed=seed)
    for y in range(y0, wains):                                # 水渍：细长的往下淌的暗痕，上沿亮一点
        for x in range(x0, x1 + 1):
            v = noise[y - y0, x - x0]
            if v > 0.52:
                nudge(c, x, y, -1)
            elif v > 0.49:
                nudge(c, x, y, 1)
    for _ in range(2):                                        # 剥落：露出底下更暗的墙
        px, py = int(rng.integers(x0 + 10, x1 - 20)), int(rng.integers(y0 + 6, wains - 14))
        for t in range(int(rng.integers(5, 10))):
            fill(c, px + t, py + (t % 3), px + t, py + 6 + (t * 7) % 5, DARK[1])


# ================================================================ 物件
def switch_panel(c, x0, y0, w, h, seed):
    """一面插线板：红木框、深色面板、黄铜插孔网格、一排信号灯、铭牌、几根垂下来的跳线。"""
    rng = np.random.default_rng(seed)
    vgrad(c, x0, y0, x0 + w, y0 + h, WOOD, 0.75, 0.35)
    fill(c, x0, y0, x0 + w, y0, WOOD[5])
    fill(c, x0, y0, x0, y0 + h, WOOD[4])
    vgrad(c, x0 + 3, y0 + 3, x0 + w - 3, y0 + h - 3, WOOD, 0.35, 0.1)
    for gy in range(y0 + 8, y0 + h - 16, 7):
        for gx in range(x0 + 6, x0 + w - 4, 5):
            c.put(gx, gy, BRASS[3])
            c.put(gx, gy + 1, WOOD[0])
        if rng.random() < 0.6:
            for gx in range(x0 + 6, x0 + w - 4, 5):
                if rng.random() < 0.3:
                    c.put(gx, gy - 2, LAMP if rng.random() < 0.4 else LAMP_OFF)
    fill(c, x0 + 6, y0 + h - 11, x0 + w - 6, y0 + h - 8, BRASS[2])
    fill(c, x0 + 6, y0 + h - 11, x0 + w - 6, y0 + h - 11, BRASS[4])
    for _ in range(3):
        ax = x0 + 6 + 5 * int(rng.integers(0, max(1, (w - 10) // 5)))
        ay = y0 + 8 + 7 * int(rng.integers(0, max(1, (h - 30) // 7)))
        bx = int(np.clip(ax + rng.integers(-24, 24), x0 + 4, x0 + w - 4))
        wire(c, ax, ay, bx, ay + int(rng.integers(0, 14)), int(rng.integers(10, 26)))


def plug_board(c, x, y):
    """Oscar 原稿里那块：深红底板，三个铜色插头，电线往上走。"""
    fill(c, x, y, x + 15, y + 13, (61, 19, 7))
    fill(c, x + 1, y + 1, x + 14, y + 12, (87, 27, 10))
    for k in range(3):
        py = y + 2 + k * 4
        fill(c, x + 2, py, x + 8, py + 2, TAN[2])
        fill(c, x + 2, py, x + 7, py, TAN[3])
        fill(c, x + 9, py + 1, x + 10, py + 1, TAN[1])
        c.put(x + 4, py + 1, GREY[6])
        fill(c, x + 11, py + 1, x + 18 + k * 2, py + 1, TAN[2])
        fill(c, x + 18 + k * 2, y - 26 + k * 3, x + 18 + k * 2, py + 1, TAN[2 if k % 2 else 1])


def candle_phone(c, x, base):
    """烛台式老电话：圆底座、细杆、话筒，听筒挂在侧面的钩上。约 14 高。"""
    fill(c, x - 3, base - 1, x + 3, base - 1, GREY[2])
    fill(c, x - 2, base - 2, x + 2, base - 2, GREY[4])
    fill(c, x, base - 12, x, base - 3, GREY[3])
    fill(c, x - 1, base - 14, x + 1, base - 13, GREY[5])
    c.put(x + 1, base - 15, GREY[6])
    fill(c, x + 2, base - 10, x + 3, base - 10, GREY[3])
    fill(c, x + 3, base - 10, x + 4, base - 5, GREY[1])
    c.put(x + 3, base - 10, GREY[5])


def wall_phone(c, x, y):
    """墙上的老电话：窄木盒、顶上一个黄铜铃、往前伸的黑话筒、侧面用卷线挂着的听筒。
    铃响就是预告下一波。故意画得不对称，免得两个铃像一双眼睛、看着像怪。"""
    fill(c, x - 4, y - 8, x + 4, y + 12, WOOD[3])
    fill(c, x - 4, y - 8, x + 4, y - 8, WOOD[5])
    fill(c, x - 4, y - 7, x - 4, y + 12, WOOD[4])
    fill(c, x - 3, y + 6, x + 3, y + 11, WOOD[2])            # 下面的写字小台
    fill(c, x - 6, y + 6, x + 6, y + 6, WOOD[4])
    sellipse(c, x, y - 11, 3, 2, BRASS[3])                   # 一个铃，顶在盒子上
    fill(c, x - 1, y - 13, x, y - 13, BRASS[4])
    fill(c, x + 5, y - 1, x + 8, y + 1, GREY[1])             # 往前伸的话筒
    fill(c, x + 8, y - 2, x + 9, y + 2, GREY[2])
    fill(c, x - 8, y - 6, x - 7, y + 2, GREY[1])             # 侧面挂着的听筒
    c.put(x - 8, y - 6, GREY[4])
    for k in range(6):                                       # 卷线
        c.put(x - 7 + (k % 2), y + 3 + k, GREY[3])


def operator_desk(c, x0, floor, w, seed):
    """接线员的台子：斜面上一排插头和跳线，台面上摆电话。台子是背景，人从前面走过。"""
    rng = np.random.default_rng(seed)
    top = floor - 22
    vgrad(c, x0, top + 6, x0 + w, floor - 1, WOOD, 0.55, 0.2)
    fill(c, x0 + 2, top + 9, x0 + w - 2, floor - 3, WOOD[1])
    for k in range(x0 + 6, x0 + w - 6, 12):                    # 抽屉把手
        fill(c, k, floor - 12, k + 4, floor - 12, BRASS[3])
    spoly(c, [(x0, top + 6), (x0 + 4, top), (x0 + w - 4, top), (x0 + w, top + 6)], WOOD[4])
    fill(c, x0 + 4, top, x0 + w - 4, top, WOOD[5])
    for k in range(x0 + 8, x0 + w - 8, 5):                     # 斜面上的插头
        fill(c, k, top + 2, k + 1, top + 4, TAN[2])
        c.put(k, top + 2, TAN[3])
    for _ in range(3):
        a = x0 + 8 + 5 * int(rng.integers(0, max(1, (w - 16) // 5)))
        b = int(np.clip(a + rng.integers(-20, 20), x0 + 6, x0 + w - 6))
        wire(c, a, top + 4, b, top + 4, int(rng.integers(6, 12)))
    candle_phone(c, x0 + w - 10, top)
    if w > 60:
        candle_phone(c, x0 + 12, top)


def coil(c, cx, cy, half=22):
    """Oscar 的线圈：灰色筒身，两端法兰，中间一圈黄铜线。"""
    for y in range(cy - 7, cy + 8):
        for x in range(cx - half, cx + half + 1):
            v = 0.75 - 0.5 * abs(y - cy) / 8 - 0.25 * (x - cx + half) / (2 * half)
            c.put(x, y, q(GREY[1:7], v))
    for x in (cx - half, cx - half + 1, cx + half - 1, cx + half):
        for y in range(cy - 9, cy + 10):
            c.put(x, y, GREY[2] if x > cx else GREY[4])
    for x in range(cx - 5, cx + 6):
        for y in range(cy - 9, cy + 10):
            c.put(x, y, BRASS[3] if x % 2 else BRASS[1])


def hang_rod(c, x, y0, y1, knobs=()):
    fill(c, x, y0, x, y1, GREY[4])
    fill(c, x + 1, y0, x + 1, y1, GREY[2])
    for ky in knobs:
        ball(c, x, ky, 3)


def relay_rack(c, x0, y0, x1, y1, lit=0.0, seed=0, dim=False):
    """电话局的继电器架：灰框，一排排小继电器（灰筒 + 黄铜顶），lit 是亮着的指示灯比例。
    dim=True 是中景用的暗版，免得和机房里的抢眼。"""
    rng = np.random.default_rng(seed)
    g = [DARK[1], DARK[2], DARK[3], DARK[4], GREY[0]] if dim else GREY
    top = BRASS[0] if dim else BRASS[3]
    fill(c, x0, y0, x1, y1, g[1])
    fill(c, x0, y0, x0 + 1, y1, g[4])
    fill(c, x1 - 1, y0, x1, y1, g[2])
    for y in range(y0 + 4, y1 - 4, 9):
        fill(c, x0 + 2, y + 6, x1 - 2, y + 6, g[3])
        for x in range(x0 + 4, x1 - 3, 4):
            fill(c, x, y + 1, x + 1, y + 5, g[4])
            c.put(x, y + 1, top)
            c.put(x + 1, y + 5, g[2])
            if lit and rng.random() < lit:
                c.put(x + 1, y + 7, LAMP if rng.random() < 0.6 else (200, 90, 60))


FAR_WIRE = [(30, 25, 21), (36, 30, 24), (44, 36, 28), (52, 42, 32)]


def rotary_dial(c, cx, cy, R):
    """远处墙上一只巨大的转盘拨号盘：外圈、十个指孔、指挡、中心的号码牌。用很暗的几档灰。"""
    ramp = [DARK[1], DARK[2], DARK[3], DARK[4], GREY[0], GREY[1]]
    for y in range(cy - R, cy + R + 1):
        for x in range(cx - R, cx + R + 1):
            d = math.hypot(x - cx, y - cy)
            if d > R:
                continue
            v = 0.55 - 0.35 * ((x - cx) + (y - cy)) / (2 * R)
            if d > R - 3:
                v -= 0.25
            c.put(x, y, q(ramp, v))
    for k in range(10):                                      # 指孔：从右上顺时针一圈，底部留空给指挡
        a = math.radians(-60 - k * 27)
        hx, hy = cx + R * 0.7 * math.cos(a), cy + R * 0.7 * math.sin(a)
        hr = int(R * 0.15)
        sellipse(c, int(hx), int(hy), hr, hr, DARK[0])
        sellipse(c, int(hx) + 1, int(hy) + 1, hr - 2, hr - 2, DARK[1])
        c.put(int(hx) - hr // 2, int(hy) - hr // 2, GREY[1])
    sellipse(c, cx, cy, int(R * 0.36), int(R * 0.36), GREY[1])
    sellipse(c, cx, cy, int(R * 0.3), int(R * 0.3), (52, 46, 38))
    for k in range(3):                                       # 号码牌上的几行"字"
        fill(c, cx - 14 + k * 3, cy - 8 + k * 7, cx + 10 - k * 3, cy - 7 + k * 7, GREY[0])
    a = math.radians(65)                                     # 指挡
    fill(c, int(cx + R * 0.86 * math.cos(a)) - 3, int(cy + R * 0.86 * math.sin(a)) - 10,
         int(cx + R * 0.86 * math.cos(a)) + 3, int(cy + R * 0.86 * math.sin(a)) + 4, GREY[2])


def telephone_pole(c, x, top, bottom):
    """电线杆：木杆、两根横担、一排白瓷瓶。远景用，很暗。"""
    fill(c, x - 3, top, x + 3, bottom, (34, 26, 20))
    fill(c, x - 3, top, x - 2, bottom, (44, 34, 26))
    for k, dy in enumerate((4, 12, 20)):
        fill(c, x - 26, top + dy, x + 26, top + dy + 2, (40, 31, 24))
        for side in (-18, 0, 18):
            fill(c, x + side - 1, top + dy - 3, x + side + 1, top + dy - 1, (70, 66, 60))


def pipe(c, pts, dim=False):
    """玻璃气动管：8 像素粗，两边一像素金属边，中间深色玻璃，靠上（或靠左）一条高光，
    每隔 40 像素一道黄铜箍，拐角是黄铜弯头。dim=True 是远景里更暗的版本。"""
    edge, glass, hi, ring, ring_hi = ((GREY[3], DARK[3], GREY[5], BRASS[2], BRASS[4]) if not dim else
                                      (DARK[4], DARK[2], GREY[1], BRASS[0], BRASS[1]))
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        if ay == by:                                        # 横管
            x0, x1 = min(ax, bx), max(ax, bx)
            fill(c, x0, ay - 4, x1, ay + 3, glass)
            fill(c, x0, ay - 4, x1, ay - 4, edge)
            fill(c, x0, ay + 3, x1, ay + 3, edge)
            fill(c, x0, ay - 2, x1, ay - 2, hi)
            for x in range(x0 + 20, x1 - 5, 40):
                fill(c, x, ay - 5, x + 2, ay + 4, ring)
                fill(c, x, ay - 5, x, ay + 4, ring_hi)
        else:                                               # 竖管
            y0, y1 = min(ay, by), max(ay, by)
            fill(c, ax - 4, y0, ax + 3, y1, glass)
            fill(c, ax - 4, y0, ax - 4, y1, edge)
            fill(c, ax + 3, y0, ax + 3, y1, edge)
            fill(c, ax - 2, y0, ax - 2, y1, hi)
            for y in range(y0 + 20, y1 - 5, 40):
                fill(c, ax - 5, y, ax + 4, y + 2, ring)
                fill(c, ax - 5, y, ax + 4, y, ring_hi)
    for (x, y) in pts[1:-1]:                                # 弯头
        fill(c, x - 5, y - 5, x + 4, y + 4, ring)
        fill(c, x - 5, y - 5, x + 4, y - 5, ring_hi)
        fill(c, x - 5, y - 5, x - 5, y + 4, ring_hi)


def tube_mouth(c, x, y, w, h):
    """管口：墙上的黄铜喇叭口，里面黑洞洞的。上面那盏红/绿灯由游戏画。"""
    fill(c, x, y, x + w - 1, y + h - 1, BRASS[2])
    fill(c, x, y, x + w - 1, y, BRASS[4])
    fill(c, x, y, x, y + h - 1, BRASS[3])
    fill(c, x + 3, y + 3, x + w - 4, y + h - 1, DARK[0])
    fill(c, x + 3, y + 3, x + w - 4, y + 3, DARK[3])
    for yy in range(y + 6, y + h - 2, 5):                    # 里面的吸气格栅
        fill(c, x + 4, yy, x + w - 5, yy, DARK[2])


def room_interior(c, r, seed=0):
    """一间机房的室内（墙面 + 墙上的东西）。主题：switch 插线板、relay 继电器、books 电话簿、film 片库。"""
    rng = np.random.default_rng(seed)
    x0, x1, top, fl = r["x0"], r["x1"], r["top"], r["floor"]
    vgrad(c, x0, top, x1 - 1, fl - 1, [DARK[2], DARK[3], DARK[4], (44, 38, 33), (52, 44, 37)], 0.9, 0.35)
    wallpaper(c, x0, top, x1 - 1, fl - 1, seed=seed + 40)
    if r["theme"] == "switch":
        for i, x in enumerate(range(x0 + 8, x1 - 46, 52)):
            switch_panel(c, x, top + 6, 44, fl - top - 14, seed=seed * 10 + i)
    elif r["theme"] == "relay":
        for i, x in enumerate(range(x0 + 6, x1 - 34, 40)):
            relay_rack(c, x, top + 14, x + 32, fl - 4, lit=0.12, seed=seed * 10 + i)
        fill(c, x0, top + 6, x1 - 1, top + 9, BRASS[1])          # 走线槽
        fill(c, x0, top + 6, x1 - 1, top + 6, BRASS[3])
        for k in range(6):
            a = x0 + int(rng.integers(0, x1 - x0 - 60))
            wire(c, a, top + 10, a + int(rng.integers(30, 60)), top + 10, int(rng.integers(6, 16)))
    elif r["theme"] == "books":
        spines = [(96, 40, 32), (70, 60, 44), (52, 58, 64), (110, 88, 52), (64, 42, 52), (88, 74, 60)]
        for sy in range(top + 26, fl - 4, 24):                  # 书架：一层层电话簿
            fill(c, x0 + 4, sy, x1 - 5, sy + 2, WOOD[4])
            fill(c, x0 + 4, sy, x1 - 5, sy, WOOD[5])
            x = x0 + 6
            while x < x1 - 10:
                w = int(rng.integers(3, 7))
                h = int(rng.integers(11, 19))
                if rng.random() < 0.12:
                    x += w + 3
                    continue
                col = spines[int(rng.integers(len(spines)))]
                fill(c, x, sy - h, x + w - 1, sy - 1, col)
                fill(c, x, sy - h, x + w - 1, sy - h, step_color(col, 1))
                fill(c, x, sy - h + 4, x + w - 1, sy - h + 4, step_color(col, 2))
                x += w
        cx, cy = (x0 + x1) // 2, top + 22                      # 墙上的大挂钟
        sellipse(c, cx, cy, 15, 15, WOOD[3])
        sellipse(c, cx, cy, 12, 12, (196, 184, 160))
        for k in range(12):
            a = math.radians(k * 30)
            c.put(int(cx + 10 * math.cos(a)), int(cy + 10 * math.sin(a)), GREY[1])
        c.line(cx, cy, cx, cy - 8, GREY[0])
        c.line(cx, cy, cx + 6, cy + 3, GREY[0])
        fill(c, x1 - 40, top + 4, x1 - 38, fl - 1, WOOD[3])     # 梯子
        fill(c, x1 - 28, top + 4, x1 - 26, fl - 1, WOOD[3])
        for yy in range(top + 10, fl, 12):
            fill(c, x1 - 38, yy, x1 - 28, yy + 1, WOOD[4])
    elif r["theme"] == "film":
        for sy in range(top + 30, fl - 20, 26):                 # 片盒架
            fill(c, x0 + 6, sy, x0 + 260, sy + 2, GREY[3])
            fill(c, x0 + 6, sy, x0 + 260, sy, GREY[5])
            for x in range(x0 + 10, x0 + 250, 16):
                if rng.random() < 0.8:
                    hgt = int(rng.integers(2, 5))
                    for k in range(hgt):
                        sellipse(c, x + 6, sy - 3 - k * 4, 7, 2, GREY[4 - k % 2])
                        c.put(x + 2, sy - 4 - k * 4, GREY[6])
        for x in range(x0 + 270, x1 - 90, 30):                  # 倒片台
            fill(c, x, fl - 18, x + 24, fl - 16, WOOD[4])
            fill(c, x + 2, fl - 16, x + 3, fl - 1, WOOD[2])
            fill(c, x + 21, fl - 16, x + 22, fl - 1, WOOD[2])


def hanging_bulb(c, x, y0, y1):
    """天桥上空吊着的小灯泡：一根线、黄铜灯头、暖黄的泡，外面一圈分档的光晕。"""
    fill(c, x, y0, x, y1 - 3, GREY[2])
    sellipse(c, x, y1 + 3, 9, 9, (34, 27, 21))
    sellipse(c, x, y1 + 3, 5, 5, (58, 44, 30))
    fill(c, x - 1, y1 - 2, x + 1, y1, BRASS[3])
    fill(c, x - 2, y1 + 1, x + 2, y1 + 5, LAMP)
    fill(c, x - 1, y1 + 6, x + 1, y1 + 6, LAMP)
    c.put(x - 1, y1 + 2, (255, 236, 190))


def dim_reel(c, cx, cy, r):
    """远处吊着的大片盘剪影：很暗的盘面、三个圆孔、一圈缠着的胶片。"""
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            d = math.hypot(x - cx, y - cy)
            if d <= r:
                c.put(x, y, DARK[3] if d > r * 0.82 else (DARK[2] if int(d) % 4 else DARK[1]))
    for k in range(3):
        a = math.radians(90 + 120 * k)
        sellipse(c, int(cx + r * 0.5 * math.cos(a)), int(cy + r * 0.5 * math.sin(a)), int(r * 0.17), int(r * 0.17), VOID)
    sellipse(c, cx, cy, max(3, r // 8), max(3, r // 8), DARK[4])


def film_reel(c, cx, cy, r, seed=0):
    """大片盘：Oscar 的灰金属盘面（分档渐变），缠着的胶片一圈圈，三个圆孔，黄铜轴。"""
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            d = math.hypot(x - cx, y - cy)
            if d > r:
                continue
            if d > r * 0.8:
                v = 0.62 - 0.35 * ((x - cx) + (y - cy)) / (2 * r)
                col = q(GREY[2:8], v)
                if d > r - 1.2:
                    col = GREY[1] if x + y > cx + cy else GREY[6]
            else:
                ring = int(d) % 3
                col = [LB.RAIL_R[2], LB.RAIL_R[3], LB.RAIL_R[2]][ring]
                if (x - cx) + (y - cy) < -r * 0.4:
                    col = LB.RAIL_R[4] if ring == 1 else LB.RAIL_R[3]
            c.put(x, y, col)
    for k in range(3):
        a = math.radians(90 + 120 * k + seed * 13)
        hx, hy = cx + r * 0.5 * math.cos(a), cy + r * 0.5 * math.sin(a)
        hr = max(3, int(r * 0.18))
        sellipse(c, int(hx), int(hy), hr, hr, VOID)
        sellipse(c, int(hx), int(hy) + 1, max(1, hr - 1), max(1, hr - 1), DARK[2])
    sellipse(c, cx, cy, max(3, r // 7), max(3, r // 7), BRASS[2])
    c.put(cx - 1, cy - 1, BRASS[4])
    c.put(cx, cy, VOID)


def projector(c, x0, floor):
    """放映机：Oscar 灰的大机身、黄铜镜头筒、顶上两只片盘、侧面一排旋钮。约 110 宽。"""
    bx0, bx1, by0, by1 = x0, x0 + 96, floor - 66, floor - 18
    for y in range(by0, by1 + 1):
        for x in range(bx0, bx1 + 1):
            v = 0.7 - 0.45 * (y - by0) / (by1 - by0) - 0.15 * (x - bx0) / (bx1 - bx0)
            c.put(x, y, q(GREY[1:8], v))
    fill(c, bx0, by0, bx1, by0, GREY[8])
    fill(c, bx0 + 8, by0 + 8, bx0 + 40, by0 + 22, GREY[2])            # 散热格栅
    for y in range(by0 + 9, by0 + 22, 3):
        fill(c, bx0 + 9, y, bx0 + 39, y, GREY[4])
    for kx in (bx0 + 52, bx0 + 64, bx0 + 76):
        sellipse(c, kx, by0 + 14, 4, 4, GREY[1])
        sellipse(c, kx - 1, by0 + 13, 2, 2, GREY[5])
    c.put(bx0 + 86, by0 + 12, (220, 70, 60))
    fill(c, bx0 + 8, by1 - 12, bx1 - 8, by1 - 10, BRASS[2])            # 黄铜铭条
    fill(c, bx0 + 8, by1 - 12, bx1 - 8, by1 - 12, BRASS[4])
    # 镜头筒朝右
    for y in range(by0 + 14, by0 + 30):
        for x in range(bx1, bx1 + 22):
            c.put(x, y, q(BRASS, 0.85 - 0.7 * abs(y - by0 - 21) / 8))
    fill(c, bx1 + 22, by0 + 12, bx1 + 25, by0 + 31, GREY[3])
    fill(c, bx1 + 25, by0 + 16, bx1 + 25, by0 + 27, (250, 238, 200))
    # 底座和腿
    fill(c, bx0 + 10, by1 + 1, bx1 - 10, by1 + 4, GREY[2])
    for lx in (bx0 + 16, bx1 - 18):
        fill(c, lx, by1 + 4, lx + 3, floor - 1, GREY[3])
        fill(c, lx - 3, floor - 2, lx + 6, floor - 1, GREY[2])
    # 片盘支臂和两只片盘
    for (ax, ry, rr) in ((bx0 + 22, by0 - 38, 26), (bx1 - 18, by0 - 30, 20)):
        fill(c, ax, ry, ax + 1, by0, GREY[3])
        film_reel(c, ax, ry, rr, seed=ax)


def seat_back(c, x, y, w=12):
    """一个座椅靠背：红丝绒，顶上一道亮边。"""
    fill(c, x, y, x + w, y + 9, VELVET[2])
    fill(c, x + 1, y, x + w - 1, y, VELVET[4])
    fill(c, x, y + 1, x, y + 9, VELVET[3])
    fill(c, x + w, y + 1, x + w, y + 9, VELVET[1])
    fill(c, x + 2, y + 9, x + 3, y + 12, GREY[1])
    fill(c, x + w - 3, y + 9, x + w - 2, y + 12, GREY[1])


# ================================================================ 各层
def draw_far(design):
    L = Layer(0.55, design)
    c = L.c
    fill(c, 0, 0, MW - 1, MH - 1, VOID)
    # 前半段背后：交换局大厅很高的后墙，一只巨大的转盘拨号盘，几根电线杆拉着满天的电话线
    vgrad(c, L.X(-60), L.Y(0), L.X(1060), L.Y(MH), DARK, 0.15, 0.7)
    for y in range(L.Y(0), L.Y(MH), 8):                       # 砖缝：横缝每 8 像素，竖缝错开
        for x in range(L.X(-60), L.X(1060)):
            nudge(c, x, y, -1)
            if (x + (16 if (y // 8) % 2 else 0)) % 32 == 0:
                for t in range(1, 8):
                    nudge(c, x, y + t, -1)
    rotary_dial(c, L.X(470), L.Y(300), 130)
    poles = [(-20, 40), (250, 70), (700, 50), (1040, 80)]
    for x, top in poles:
        telephone_pole(c, L.X(x), L.Y(top), L.Y(MH))
    for (ax, at), (bx, bt) in zip(poles, poles[1:]):
        for k, dy in enumerate((6, 14, 22)):
            for side in (-18, 0, 18):
                wire(c, L.X(ax) + side, L.Y(at) + dy, L.X(bx) + side, L.Y(bt) + dy, 18 + k * 6, ramp=FAR_WIRE)
    rng = np.random.default_rng(3)
    for _ in range(40):                                  # 远处零星的信号灯
        c.put(int(rng.integers(L.X(-40), L.X(1040))), int(rng.integers(L.Y(20), L.Y(580))),
              LAMP_OFF if rng.random() < 0.7 else LAMP)
    # 天桥背后：黑暗里投着几块巨大的、很暗的画面（录像里的家，和最后一关呼应）
    dim = [(21, 19, 18), (27, 24, 21), (34, 29, 25), (42, 35, 28)]
    for k, (x, y, w, h) in enumerate(((1180, 50, 260, 150), (1720, 330, 220, 130), (2260, 60, 280, 160))):
        X, Y = L.X(x), L.Y(y)
        for yy in range(h):
            for xx in range(w):
                dx, dy = (xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)
                r = dx * dx * 0.8 + dy * dy
                if r <= 1:
                    c.put(X + xx, Y + yy, dim[3] if r < 0.35 else dim[2] if r < 0.7 else dim[1])
        g = Y + h - 34
        if k == 0:                                   # 房子
            spoly(c, [(X + 90, g + 6), (X + 90, g - 30), (X + 130, g - 62), (X + 170, g - 30), (X + 170, g + 6)], dim[0])
            fill(c, X + 104, g - 22, X + 116, g - 10, dim[3])
        elif k == 1:                                 # 四个人
            for j, hh in enumerate((40, 34, 24, 30)):
                px = X + 50 + j * 34
                fill(c, px, g - hh, px + 14, g + 6, dim[0])
                sellipse(c, px + 7, g - hh - 8, 7, 7, dim[0])
        else:                                        # 一家人围着电视
            fill(c, X + 110, g - 40, X + 170, g + 6, dim[0])
            fill(c, X + 118, g - 32, X + 162, g - 8, dim[3])
            for px, hh in ((X + 70, 32), (X + 86, 24), (X + 196, 30), (X + 212, 22)):
                fill(c, px, g - hh, px + 10, g + 6, dim[0])
                sellipse(c, px + 5, g - hh - 6, 5, 5, dim[0])
    for x, y, r in ((1320, 110, 90), (2080, 480, 120), (2640, 140, 80), (1600, 560, 70)):
        dim_reel(c, L.X(x), L.Y(y), r)
        fill(c, L.X(x), 0, L.X(x) + 1, L.Y(y) - r, DARK[3])
    # 后半段背后：观众厅很高的后墙，竖向装饰肋
    for x in range(2760, 3800, 36):
        X = L.X(x)
        vgrad(c, X, L.Y(10), X + 30, L.Y(590), DARK, 0.7, 0.2)
        fill(c, X + 2, L.Y(10), X + 3, L.Y(590), DARK[4])
    return L


def draw_mid(design):
    L = Layer(0.75, design)
    c = L.c
    # 前半段：几排很高的继电器架（灯亮着），吊着的配重球、线圈，和远处别的气动管
    for i, x in enumerate((-10, 150, 470, 760, 960)):
        relay_rack(c, L.X(x), L.Y(30 + (i % 2) * 60), L.X(x) + 44, L.Y(580), lit=0.1, seed=i, dim=True)
    for x, by in ((90, 330), (330, 380), (700, 150), (860, 520)):
        X = L.X(x)
        hang_rod(c, X, 0, L.Y(by), knobs=(L.Y(by) - 30,))
        ball(c, X, L.Y(by) + 12, 12)
    for x, cy in ((240, 300), (600, 520), (920, 40)):
        X = L.X(x)
        hang_rod(c, X, 0, L.Y(cy) - 9)
        coil(c, X, L.Y(cy))
    for path in (((-20, 120), (300, 120), (300, 400), (560, 400)), ((620, 580), (620, 260), (1040, 260))):
        pipe(c, [(L.X(x), L.Y(y)) for x, y in path], dim=True)
    # 天桥一带：远处下垂的胶片（悬链线）和吊着的线圈
    for (ax, ay, bx, by, sag) in ((1000, 120, 1500, 90, 70), (1400, 420, 2000, 450, 60), (1900, 140, 2500, 110, 80),
                                  (2350, 430, 2900, 400, 50), (1150, 520, 1600, 540, 30)):
        n = int(bx - ax)
        for i in range(n):
            t = i / n
            X = L.X(ax + (bx - ax) * t)
            Y = L.Y(ay + (by - ay) * t + sag * 4 * t * (1 - t))
            for o in range(9):
                col = LB.RAIL_R[1] if o in (0, 8) else LB.RAIL_R[0]
                if o in (1, 7) and i % 5 == 0:
                    col = LB.RAIL_R[3]
                if 2 < o < 6 and i % 12 < 9:
                    col = SEPIA[0]
                c.put(X, Y + o, col)
    for x in (1300, 1950, 2600):
        X = L.X(x)
        hang_rod(c, X, L.Y(FILM_BOT) + 4, L.Y(400) - 9)
        coil(c, X, L.Y(400))
    for k, x in enumerate(range(1080, 2800, 160)):
        hanging_bulb(c, L.X(x), 0, L.Y(60 + (k * 53) % 110))
    # 后半段：观众厅的吊灯（黄铜 + 暖光）
    for x in (3260, 3460):
        X = L.X(x)
        hang_rod(c, X, 0, L.Y(70))
        fill(c, X - 10, L.Y(70), X + 11, L.Y(74), BRASS[2])
        fill(c, X - 10, L.Y(70), X + 11, L.Y(70), BRASS[4])
        for k in range(-8, 10, 4):
            c.put(X + k, L.Y(76), LAMP)
    return L


def leader(c, x0, y0, w, h):
    """倒计时片头：亮底、两圈同心圆、十字线、扫过一半的扇形（暗一档）、中间一个粗的 3。"""
    cx, cy = x0 + w // 2, y0 + h // 2
    R = min(w, h) // 2 - 12
    sweep = math.radians(130)
    for y in range(y0, y0 + h + 1):
        for x in range(x0, x0 + w + 1):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            a = (math.atan2(dx, -dy)) % (2 * math.pi)          # 从 12 点顺时针
            v = 5 if d < R else 4
            if d < R and a < sweep:
                v = 3                                          # 已经扫过的扇形
            if abs(d - R) < 1.5 or abs(d - R * 0.72) < 1.0:
                v = 1
            if (abs(dx) < 1 or abs(dy) < 1) and d < R + 10:
                v = 1
            c.put(x, y, SEPIA[v])
    # 粗体的 3：三条横、右边两段竖
    t, gw, gh = 9, 46, 70
    gx, gy = cx - gw // 2, cy - gh // 2
    for (ax, ay, bx, by) in ((gx, gy, gx + gw, gy + t), (gx + 8, gy + gh // 2 - t // 2, gx + gw, gy + gh // 2 + t // 2),
                             (gx, gy + gh - t, gx + gw, gy + gh), (gx + gw - t, gy, gx + gw, gy + gh)):
        fill(c, ax, ay, bx, by, SEPIA[0])
    fill(c, gx + gw - t + 1, gy + 1, gx + gw - t + 1, gy + gh - 1, SEPIA[1])


def draw_back(design):
    L = Layer(1.0, design)
    c = L.c
    # ---- 前半段：四间机房，每间布置不一样
    for i, r in enumerate(ROOMS):
        room_interior(c, r, seed=i)
    # ---- 天桥起点：一只巨大的供片盘挂在悬崖边上，胶片从它下沿出来
    film_reel(c, A_X1 + 20, FILM_TOP - 4, 74, seed=1)
    fill(c, A_X1 + 18, 0, A_X1 + 21, FILM_TOP - 78, GREY[3])
    # ---- 后半段：放映室
    vgrad(c, B_X0, 214, 3100, BRIDGE_Y - 1, GREY, 0.3, 0.12)
    for x in range(B_X0 + 8, 3096, 22):                      # 墙板
        fill(c, x, 216, x, BRIDGE_Y - 2, GREY[0])
    metal_texture(c, B_X0, 214, 3099, BRIDGE_Y - 1, seed=99)
    for k, x in enumerate(range(3030, 3090, 14)):            # 架子上的片盒
        sellipse(c, x, 236, 6, 3, GREY[4 - k % 2])
        sellipse(c, x, 234, 6, 3, GREY[5])
    fill(c, 3024, 241, 3094, 242, WOOD[3])
    # ---- 观众厅：后墙、竖肋、壁灯、银幕和两侧红幕
    vgrad(c, 3116, 40, MW - 16, MH - 1, DARK, 0.7, 0.25)
    for x in range(3130, MW - 16, 44):
        fill(c, x, 40, x + 3, MH - 1, DARK[4])
        fill(c, x, 40, x, MH - 1, GREY[1])
        fill(c, x - 3, 40, x + 6, 44, BRASS[1])
    for x in (3150, 3238, 3326):                              # 壁灯
        fill(c, x - 2, 150, x + 2, 156, BRASS[2])
        fill(c, x - 1, 146, x + 1, 149, LAMP)
    # 银幕上方一圈放射纹（装饰艺术风格）
    sun = (3518, 186)
    for y in range(48, 140):
        for x in range(3340, 3700 - 17):
            a = math.degrees(math.atan2(sun[1] - y, x - sun[0]))
            if 12 < a < 168 and math.hypot(x - sun[0], y - sun[1]) > 50:
                c.put(x, y, BRASS[0] if int(a / 7) % 2 else DARK[3])
    for x0 in (3170, 3250):                                   # 左墙上的两个包厢
        fill(c, x0, 110, x0 + 60, 112, BRASS[3])
        vgrad(c, x0, 113, x0 + 60, 150, VELVET, 0.7, 0.3)
        for k in range(x0 + 4, x0 + 60, 8):
            fill(c, k, 113, k + 1, 150, VELVET[1])
        fill(c, x0 - 2, 150, x0 + 62, 156, BRASS[1])
        fill(c, x0 - 2, 150, x0 + 62, 150, BRASS[3])
    # 银幕：放的是老电影开头的倒计时片头（圆圈、十字线、扫过的扇形、大数字 3），1 倍像素直接画
    sx0, sy0, sw, sh = 3370, 190, 296, 214
    fill(c, sx0 - 6, sy0 - 6, sx0 + sw + 6, sy0 + sh + 6, DARK[0])
    leader(c, sx0, sy0, sw, sh)
    # 银幕边缘一圈暗角
    for y in range(sy0, sy0 + sh + 1):
        for x in range(sx0, sx0 + sw + 1):
            dx, dy = (x - sx0 - sw / 2) / (sw / 2), (y - sy0 - sh / 2) / (sh / 2)
            r = dx * dx * 0.7 + dy * dy * 0.7
            if r > 0.62:
                col = tuple(int(v) for v in c.a[y, x, :3])
                c.put(x, y, LB.shift(SEPIA, col, -1 if r < 0.95 else -2))
    for side, (a0, a1) in enumerate(((sx0 - 34, sx0 - 6), (sx0 + sw + 6, MW - 17))):
        for x in range(a0, a1 + 1):
            fold = (x - a0) % 9
            v = 0.75 if fold < 2 else 0.5 if fold < 6 else 0.25
            fill(c, x, 150, x, ORCH_Y - 1, q(VELVET, v))
        fill(c, a0, 150, a1, 156, VELVET[4])
    fill(c, sx0 - 34, 142, MW - 17, 149, BRASS[2])
    fill(c, sx0 - 34, 142, MW - 17, 142, BRASS[4])
    # 放映机的光束：从放映室小窗打到银幕，把落在光里的墙提亮
    beam = Canvas(MW, MH)
    beam.poly([(3104, 230), (3104, 246), (sx0, sy0 + sh - 10), (sx0, sy0 + 10)], (1, 1, 1))
    m = beam.mask
    m[:, sx0:] = False
    ys, xs = np.nonzero(m & (c.a[..., 3] > 0))
    cache = {}
    for y, x in zip(ys, xs):
        col = tuple(int(v) for v in c.a[y, x, :3])
        k = 2 if abs((y - 238) - (x - 3104) * ((sy0 + sh / 2 - 238) / (sx0 - 3104))) < 14 + (x - 3104) * 0.08 else 1
        if (col, k) not in cache:
            cache[(col, k)] = step_color(col, k, hue_deg=8)
        c.put(x, y, cache[(col, k)])
    rng = np.random.default_rng(4)
    for _ in range(60):                                       # 光里的灰尘
        i = int(rng.integers(len(ys)))
        c.put(xs[i], ys[i], (230, 206, 160))
    return L


def draw_props(design):
    L = Layer(1.0, design)
    c = L.c
    # 前半段：气动管（在墙后面，从一间房接到另一间）、管口、接线台、墙上的电话、Oscar 的插线板
    for t in TUBES:
        pipe(c, t["path"])
    for t in TUBES:
        tube_mouth(c, *t["mouth"])
    for x, w in ((150, 70), (300, 80)):
        operator_desk(c, x, 540, w, seed=x)
    operator_desk(c, 600, 430, 60, seed=7)
    for px, py in PHONES:
        wall_phone(c, px, py)
    for x, y in ((60, 470), (840, 370), (380, 170)):
        plug_board(c, x, y)
    # 后半段：放映机（胶片进它的片门）
    projector(c, B_X0 + 34, BRIDGE_Y)
    return L


def cable_vault(c, spans, y0, y1):
    """底层地板下面的地下线缆室：几扇装着格栅的大窗，里面垂着粗电缆、亮着几盏暗灯。纯背景，人进不去。"""
    rng = np.random.default_rng(12)
    for x0, x1 in spans:
        fill(c, x0 - 3, y0 - 3, x1 + 3, y1 + 3, GREY[3])
        fill(c, x0 - 3, y0 - 3, x1 + 3, y0 - 3, GREY[5])
        vgrad(c, x0, y0, x1, y1, DARK, 0.1, 0.5)
        for k in range(4):                                       # 粗电缆
            ax = x0 + int(rng.integers(0, (x1 - x0) // 2))
            bx = ax + int(rng.integers(60, 160))
            ay = y0 + int(rng.integers(6, 40))
            sag = int(rng.integers(30, 90))
            n = bx - ax
            for i in range(n):
                t = i / n
                xx, yy = ax + i, int(ay + sag * 4 * t * (1 - t))
                if x0 <= xx <= x1 and yy + 3 <= y1:
                    c.put(xx, yy, TAN[1])
                    c.put(xx, yy + 1, TAN[0])
                    c.put(xx, yy + 2, DARK[1])
        for k in range(3):                                       # 暗灯
            lx, ly = int(rng.integers(x0 + 10, x1 - 10)), int(rng.integers(y0 + 10, y1 - 30))
            c.put(lx, ly, LAMP)
            c.put(lx, ly - 1, LAMP_OFF)
        for gx in range(x0 + 6, x1, 12):                         # 格栅
            fill(c, gx, y0, gx + 1, y1, GREY[2])
            c.put(gx, y0, GREY[5])
        fill(c, x0, (y0 + y1) // 2, x1, (y0 + y1) // 2 + 1, GREY[2])
        for coil_x in range(x0 + 40, x1 - 30, 120):
            coil(c, coil_x, y1 - 14, half=16)


def draw_solid(design):
    L = Layer(1.0, design)
    c = L.c
    # 前半段：四间机房的外壳（钢板墙、铆钉、地面亮边）
    for r in ROOMS:
        x0, x1, top, fl = r["x0"], r["x1"], r["top"], r["floor"]
        right = x1 - 1 if r["theme"] == "film" else x1 + WALL - 1
        block(c, x0 - WALL, top - WALL, right, top - 1, seam=48)
        fill(c, x0 - WALL, top - 1, right, top - 1, GREY[3])
        bottom = MH - 1 if r["name"].startswith("R1") else fl + WALL - 1
        girder(c, x0 - WALL, right, fl, th=WALL, under=False)
        if bottom > fl + WALL:
            block(c, x0 - WALL, fl + WALL, right, bottom, seam=60)
        block(c, x0 - WALL, top, x0 - 1, fl - 1, seam=200)
        fill(c, x0 - 1, top, x0 - 1, fl - 1, GREY[4])
        if r["theme"] != "film":
            block(c, x1, top, x1 + WALL - 1, fl - 1, seam=200)
            fill(c, x1, top, x1, fl - 1, GREY[4])
        # 墙外侧的铭牌（房间名用色块代替，不写字）
        fill(c, x0 + 20, top - WALL + 3, x0 + 44, top - WALL + 7, BRASS[2])
        fill(c, x0 + 20, top - WALL + 3, x0 + 44, top - WALL + 3, BRASS[4])
    # 胶片天桥单独一层（draw_film），游戏里不吃场景压暗、自己发光
    # 吊杆夹住上齿孔边
    for x in range(A_X1 + 260, B_X0 - 60, 300):
        hang_rod(c, x, 0, FILM_TOP - 6, knobs=(FILM_TOP - 26,))
        fill(c, x - 5, FILM_TOP - 5, x + 6, FILM_TOP - 1, BRASS[2])
        fill(c, x - 5, FILM_TOP - 5, x + 6, FILM_TOP - 5, BRASS[4])
        fill(c, x - 5, FILM_TOP - 1, x + 6, FILM_TOP - 1, BRASS[0])
        fill(c, x - 5, FILM_TOP, x - 4, FILM_TOP + 4, BRASS[1])
        fill(c, x + 5, FILM_TOP, x + 6, FILM_TOP + 4, BRASS[1])
    # 片门：胶片从这里进放映室（一道黄铜框夹住胶片）
    fill(c, B_X0 - 4, FILM_TOP - 6, B_X0 + 5, FILM_BOT + 4, BRASS[2])
    fill(c, B_X0 - 4, FILM_TOP - 6, B_X0 + 5, FILM_TOP - 6, BRASS[4])
    fill(c, B_X0 - 4, FILM_TOP - 6, B_X0 - 4, FILM_BOT + 4, BRASS[3])
    fill(c, B_X0 + 5, FILM_TOP - 6, B_X0 + 5, FILM_BOT + 4, BRASS[0])
    for yy in range(FILM_TOP, FILM_BOT, 10):
        c.put(B_X0, yy, BRASS[4])
    # 后半段：放映室
    block(c, B_X0, 200, 3115, 213, seam=60)
    fill(c, B_X0, 213, 3115, 213, GREY[4])
    block(c, 3100, 214, 3115, 261, seam=100)
    fill(c, 3100, 261, 3115, 261, GREY[4])
    fill(c, 3102, 228, 3113, 248, (250, 238, 200))           # 放映窗（亮）
    fill(c, 3102, 228, 3113, 228, GREY[2])
    girder(c, B_X0, 3169, BRIDGE_Y, under=False)
    block(c, B_X0, BRIDGE_Y + GIRDER, 3169, MH - 1, seam=60)
    fill(c, 3150, 286, 3169, 287, BRASS[2])                  # 包厢栏杆
    for x in range(3150, 3170, 5):
        fill(c, x, 287, x, BRIDGE_Y - 1, BRASS[1])
    # 观众席台阶
    for i, (rx, ry) in enumerate(ROWS):
        fill(c, rx, ry, rx + 39, ry, VELVET[4])
        fill(c, rx, ry + 1, rx + 39, ry + 3, VELVET[2])           # 台阶边的地毯
        for x in range(rx + 1, rx + 39, 3):
            nudge(c, x, ry + 2, 1)
        vgrad(c, rx, ry + 4, rx + 39, MH - 1, DARK + [GREY[0]], 0.95, 0.2)
        fill(c, rx, ry + 1, rx, MH - 1, GREY[1])
        for y in range(ry + 10, MH - 1, 22):                       # 台阶立面上的木板缝
            for x in range(rx + 1, rx + 39):
                nudge(c, x, y, -1)
        metal_texture(c, rx + 1, ry + 6, rx + 38, MH - 2, seed=i, density=0.5)
    # 乐池和舞台
    fill(c, ROWS[-1][0] + 40, ORCH_Y, MW - 1, ORCH_Y, GREY[5])
    vgrad(c, ROWS[-1][0] + 40, ORCH_Y + 1, MW - 1, MH - 1, DARK, 0.8, 0.2)
    sx, sy = STAGE
    fill(c, sx, sy, MW - 1, sy, WOOD[5])
    vgrad(c, sx, sy + 1, MW - 1, ORCH_Y - 1, WOOD, 0.6, 0.2)
    for x in range(sx + 4, MW, 10):
        fill(c, x, sy + 2, x, ORCH_Y - 1, WOOD[1])
    block(c, 3116, 0, MW - 1, 39, seam=44)
    fill(c, 3116, 39, MW - 1, 39, BRASS[2])
    block(c, MW - 16, 40, MW - 1, MH - 1, seam=200)
    fill(c, MW - 16, 40, MW - 16, MH - 1, GREY[3])
    # 出口：舞台上银幕右边的一扇小门，门上一盏出口灯
    ex, ey = EXIT
    fill(c, ex - 6, ey - 34, ex + 6, ey - 29, (90, 160, 100))
    fill(c, ex - 5, ey - 33, ex + 5, ey - 30, (170, 240, 170))
    fill(c, ex - 10, ey - 26, ex + 10, ey - 1, WOOD[2])
    fill(c, ex - 8, ey - 24, ex + 8, ey - 1, (250, 220, 150))
    fill(c, ex - 10, ey - 26, ex + 10, ey - 26, WOOD[5])
    return L


def draw_film(design):
    L = Layer(1.0, design)
    film = LB.draw_film(0, B_X0 - A_X1, seed=0)
    src = film.a[LB.FILM_TOP:LB.FILM_BOT]
    m = src[..., 3] > 0
    L.c.a[FILM_TOP:FILM_BOT, A_X1:B_X0][m] = src[m]
    return L


def draw_near(design):
    L = Layer(1.0, design)
    c = L.c
    dark = [(10, 9, 9), (16, 13, 12), (22, 18, 16)]
    # 前半段：每间机房天花板垂下来一两捆线缆
    rng = np.random.default_rng(7)
    for r in ROOMS:
        for x in (r["x0"] + 70, r["x1"] - 120):
            for k in range(4):
                ax = x + k * 3
                n = int(rng.integers(14, 30))
                for y in range(r["top"], r["top"] + n):
                    sway = int(2 * math.sin(y / 9 + k))
                    c.put(ax + sway, y, dark[k % 3])
                    c.put(ax + sway + 1, y, dark[(k + 1) % 3])
    # 后半段：每排台阶上的座椅靠背
    for rx, ry in ROWS:
        for k in range(3):
            seat_back(c, rx + 2 + k * 13, ry - 10, 11)
    return L


# ================================================================ 褪色
def fade(c, chroma=0.55, lift=0.07, gain=0.88, warm=(0.004, 0.012)):
    """整层调成褪色老胶片的感觉（作者 10-17：像胶片那段，但没那么夸张）：
    饱和度乘 chroma，往暖褐偏一点（warm 是 OKLab a/b 的偏移），黑色提亮到 lift，高光压到 lift+gain。
    按颜色一一映射，不会多出噪点。"""
    a = c.a
    m = a[..., 3] > 0
    if not m.any():
        return
    cols, inv = np.unique(a[m][:, :3], axis=0, return_inverse=True)
    lab = srgb_to_oklab(cols.astype(np.uint8))
    lab[:, 0] = lift + gain * lab[:, 0]
    lab[:, 1] = lab[:, 1] * chroma + warm[0]
    lab[:, 2] = lab[:, 2] * chroma + warm[1]
    out = oklab_to_srgb(lab)
    px = a[m]
    px[:, :3] = out[inv.reshape(-1)]
    a[m] = px


FADE = {"film": dict(chroma=0.85, lift=0.03, gain=0.95, warm=(0.002, 0.006))}


# ================================================================ 输出
def compose(layers):
    out = Canvas(MW, MH)
    for L in layers:
        m = L.c.a[..., 3] > 0
        out.a[m] = L.c.a[m]
    return out


def route_overlay(base):
    """Oscar 草图那种红线：路线 + 遭遇战框 + 电话 + 换卷点 + 出生点和出口。"""
    c = base.copy()
    RED, ORANGE, YELLOW, WHITE, GREEN = (230, 40, 40), (240, 140, 40), (250, 220, 60), (250, 250, 250), (60, 220, 90)
    path = [(SPAWN[0], 534), (412, 534)] + TUBES[0]["path"] + [(548, 424), (892, 424)] + TUBES[1]["path"] + \
        [(424, 244), (60, 244)] + TUBES[2]["path"] + [(640, 294), (B_X0 + 300, BRIDGE_Y - 6)]
    for rx, ry in ROWS:
        path.append((rx + 20, ry - 6))
    path += [(ROWS[-1][0] + 60, ORCH_Y - 6), (STAGE[0] - 4, ORCH_Y - 6), (STAGE[0] + 6, STAGE[1] - 6), (EXIT[0], STAGE[1] - 6)]
    for (ax, ay), (bx, by) in zip(path, path[1:]):
        for o in (0, 1):
            c.line(ax, ay + o, bx, by + o, RED)
    for e in ENCOUNTERS:
        y0, y1 = e["ceil"] + 2, e["floor_y"] - 1
        for (ax, ay, bx, by) in ((e["x0"], y0, e["x1"], y0), (e["x0"], y1, e["x1"], y1),
                                 (e["x0"], y0, e["x0"], y1), (e["x1"], y0, e["x1"], y1)):
            c.line(ax, ay, bx, by, ORANGE)
        fill(c, e["x0"], y0 - 2, e["x0"] + 2, y1, ORANGE)     # 左边的闸门
        fill(c, e["x1"] - 2, y0 - 2, e["x1"], y1, ORANGE)
    for px, py in PHONES:
        for a in range(0, 360, 20):
            c.put(int(px + 14 * math.cos(math.radians(a))), int(py + 14 * math.sin(math.radians(a))), YELLOW)
    for x in REEL_CHANGES:
        for yy in range(FILM_TOP - 30, FILM_BOT + 30):
            if yy % 6 < 3:
                c.put(x, yy, WHITE)
                c.put(x + 1, yy, WHITE)
        for d in (0, 9):
            sellipse(c, x + 40 + d, FILM_TOP - 40, 3, 3, WHITE)
    sellipse(c, SPAWN[0], SPAWN[1] - 8, 5, 5, GREEN)
    sellipse(c, EXIT[0], EXIT[1] - 34, 5, 5, GREEN)
    return c


def view(layer_imgs, cam_x, cam_y, zoom=1, scale=3):
    """按 parallax_scene.gd 的规则把各层叠成游戏里镜头在 (cam_x, cam_y) 时看到的画面（zoom=2 时一屏 240×135）。"""
    sw, sh = 480 // zoom, 270 // zoom
    scale *= zoom
    cam_x = min(max(cam_x, sw / 2), MW - sw / 2)
    cam_y = min(max(cam_y, sh / 2), MH - sh / 2)
    offx, offy = cam_x - CX, cam_y - CY
    out = np.zeros((sh, sw, 4), np.uint8)
    out[..., 3] = 255
    for img, s, mod in layer_imgs:
        lag = 1 - s
        px, py = round(offx * lag), round(offy * lag * 0.5)
        # 屏幕左上角在地图上的位置 → 这一层图里的位置
        sx0 = int(round(cam_x - sw / 2 - px))
        sy0 = int(round(cam_y - sh / 2 - py))
        sub = np.zeros((sh, sw, 4), np.uint8)
        ys0, xs0 = max(0, sy0), max(0, sx0)
        ys1, xs1 = min(MH, sy0 + sh), min(MW, sx0 + sw)
        sub[ys0 - sy0:ys1 - sy0, xs0 - sx0:xs1 - sx0] = img[ys0:ys1, xs0:xs1]
        m = sub[..., 3] > 0
        rgb = (sub[..., :3].astype(float) * np.array(mod)).astype(np.uint8)
        out[..., :3][m] = rgb[m]
    return Image.fromarray(out).resize((sw * scale, sh * scale), Image.NEAREST)


def write_gd_data():
    """关卡用的数据（GDScript 常量）。JSON 不是资源，网页导出默认不打包，所以另写一份 .gd。"""
    L = ["extends RefCounted",
         "## 第二关的地图数据，草图/第二关/level2_map.py 生成的，别手改（改脚本重新跑）。",
         "## 坐标都是地图像素：3700×600，前半交换台 x 0~%d，胶片天桥 %d~%d，后半放映厅 %d~%d。" % (A_X1, A_X1, B_X0, B_X0, MW),
         "",
         "const BOUNDS := Rect2(0, 0, %d, %d)" % (MW, MH),
         "const SPAWN := Vector2(%d, %d)" % SPAWN,
         "## 出口：舞台上的小门，门前一块",
         "const EXIT := Rect2(%d, %d, 24, 34)" % (EXIT[0] - 12, EXIT[1] - 30),
         "const A_X1 := %d" % A_X1,
         "const B_X0 := %d" % B_X0,
         "const BRIDGE_Y := %d" % BRIDGE_Y,
         "const FILM_TOP := %d" % FILM_TOP,
         "const FILM_BOT := %d" % FILM_BOT,
         "## 换卷点：镜头中心走到这里停下，打一场精英怪",
         "const REEL_CHANGES: Array[float] = [%s]" % ", ".join("%.1f" % x for x in REEL_CHANGES),
         "## 墙上的电话（遭遇战来波前响铃），和 ENCOUNTERS 一一对应",
         "const PHONES: Array[Vector2] = [%s]" % ", ".join("Vector2(%d, %d)" % p for p in PHONES),
         "## 碰撞矩形（名字见 level2_collision.json）",
         "const SOLIDS: Array[Rect2] = ["]
    for r in SOLIDS:
        L.append("\tRect2(%d, %d, %d, %d),  # %s" % (r["x"], r["y"], r["w"], r["h"], r["name"]))
    L.append("]")
    L.append("## 遭遇战的场子：left/right 是闸门 x，ceil 是天花板（怪从这里掉），floor 是地面")
    L.append("const ARENAS := [")
    for e in ENCOUNTERS:
        fl, fr = e["floor_y"], e["floor_y"]
        x0, x1 = e["x0"], e["x1"]
        if e["name"].startswith("E4"):
            # 左闸门落在第 8 排台阶上；右闸门在右墙里，地面写乐池的 520，
            # 因为 Encounter 只认两扇闸门里低的那个地面以上算"进场"，乐池比舞台低
            x0, fl, fr = ROWS[7][0] + 20, ROWS[7][1], ORCH_Y
        L.append('\t{"name": "%s", "left": %d, "right": %d, "ceil": %d, "floor_l": %d, "floor_r": %d},'
                 % (e["name"], x0, x1, e["ceil"], fl, fr))
    L.append("]")
    L.append("## 气动管：mouth 是管口（人走进去就被吸走），path 是管子的折线，out/vel 是喷出来的位置和速度，")
    L.append("## needs 是先打完 ARENAS 里第几场管口才开")
    L.append("const TUBES := [")
    for t in TUBES:
        L.append('\t{"mouth": Rect2(%d, %d, %d, %d), "path": [%s], "out": Vector2(%d, %d), "vel": Vector2(%d, %d), "needs": %d},'
                 % (*t["mouth"], ", ".join("Vector2(%d, %d)" % p for p in t["path"]), *t["out"], *t["vel"], t["needs"]))
    L.append("]")
    L.append("## 机房（室内范围），提示牌和调试用")
    L.append("const ROOMS := [")
    for r in ROOMS:
        L.append('\t{"name": "%s", "rect": Rect2(%d, %d, %d, %d)},' % (r["name"], r["x0"], r["top"], r["x1"] - r["x0"], r["floor"] - r["top"]))
    L.append("]")
    (GAME / "scripts/levels/level2_data.gd").write_text("\n".join(L) + "\n")


def main():
    builders = [("far", draw_far, 0.55, (0.72, 0.72, 0.8)), ("mid", draw_mid, 0.75, (0.8, 0.8, 0.86)),
                ("back", draw_back, 1.0, (1, 1, 1)), ("props", draw_props, 1.0, (1, 1, 1)),
                ("solid", draw_solid, 1.0, (1, 1, 1)), ("film", draw_film, 1.0, (1, 1, 1)),
                ("near", draw_near, 1.0, (1, 1, 1))]
    game_layers, design_layers = [], []
    for name, fn, s, mod in builders:
        g = fn(False)
        fade(g.c, **FADE.get(name, {}))
        g.c.save(ART / f"level2_{name}.png")
        game_layers.append((g.c.a, s, mod))
        if s == 1.0:
            design_layers.append(g)
        else:
            d = fn(True)
            fade(d.c, **FADE.get(name, {}))
            design_layers.append(d)
        print("layer", name)
    overview = compose(design_layers)
    overview.save(MAPDIR / "level2_overview.png")
    route_overlay(overview).save(MAPDIR / "level2_route.png")
    # 机房和放映厅按游戏里的 2 倍镜头（一屏 240×135），天桥按 1 倍（480×270）
    for name, (cx, cy, z) in {"R1": (250, 520, 2), "R2": (720, 410, 2), "R3": (250, 230, 2), "R4": (760, 280, 2),
                              "hallA": (480, 300, 1), "bridge_in": (1150, 268, 1), "bridge": (1900, 268, 1),
                              "booth": (2980, 280, 2), "hall": (3400, 420, 2), "stage": (3600, 490, 2)}.items():
        view(game_layers, cx, cy, zoom=z).save(MAPDIR / f"level2_view_{name}.png")
    data = {
        "size": [MW, MH],
        "parallax": {name: s for name, _, s, _ in builders},
        "solids": SOLIDS,
        "spawn": SPAWN,
        "exit": EXIT,
        "encounters": ENCOUNTERS,
        "phones": PHONES,
        "bridge": {"x0": A_X1, "x1": B_X0, "floor_y": BRIDGE_Y, "film_top": FILM_TOP, "film_bottom": FILM_BOT,
                   "scroll_speed": 70, "reel_changes": REEL_CHANGES},
    }
    (ART / "level2_collision.json").write_text(json.dumps(data, ensure_ascii=False, indent=1))
    write_gd_data()
    print("ok")


if __name__ == "__main__":
    main()
