"""商店（升级房间）的美术。房间右半边是 Oscar 画的（Art_Assets/商店.aseprite，355×200），
这里把它放进 480×270 的画面右下角，补上左半边、天花板和地面，再画货架上的图标。

    python3 tools/draw_shop.py

输出 art/shop/：
  room.png      480×270 背景：Oscar 的右半边 + 补的左半边（洞洞板、工作台、天花板、吊灯、电线）
  room_fg.png   480×270 前景：船员坐的两只木箱（挡住腿，看上去是坐着）
  icons.png     16×16 一格的图标横条，顺序见 ICONS
  preview_shop.png  放大 3 倍的总览，给人看

补的部分照 Oscar 那半边的画法：深酒红的底，暗芯 + 1 像素亮一点的细线勾结构，不描黑边，
颜色都从他那半边取。图标照小怪的调色板（暖调深灰）+ 一点点暖光和红灯。
坐标常量（钩子、货架、篝火、箱子）游戏代码里要对上：scripts/shop/shop_room.gd。
"""
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT.parent / "Art_Assets/商店.aseprite"
OUT = ROOT / "art/shop"
ASEPRITE = "/Applications/Aseprite.app/Contents/MacOS/aseprite"

W, H = 480, 270
OX, OY = 125, 70                 # Oscar 的 355×200 放在这里
FLOOR_LOW = OY + 188             # 左边低的那层地面（台阶以左）
FLOOR_HIGH = OY + 182            # 右边高的那层（台阶 x≈281 起）
STEP_X = OX + 156

# 从 Oscar 那半边取的颜色（暗 → 亮）
BG = (18, 9, 9)
K0 = (8, 8, 8)
K1 = (13, 11, 11)
K2 = (17, 14, 14)
D1 = (20, 13, 13)
D2 = (25, 19, 19)
D3 = (31, 23, 23)
D4 = (37, 28, 28)
M1 = (42, 35, 34)
M2 = (48, 41, 37)
M3 = (58, 49, 45)
RUST = (44, 17, 17)

# 游戏代码要用的坐标
HOOKS = [36, 70, 104, 138]       # 洞洞板上 4 个挂钩的 x（装备升级）
HOOK_Y = 176
BENCH_Y = 226                    # 工作台台面
REPAIR_X = 160                   # 修灯放在工作台右头
FIRE_X = 236                     # 篝火（马灯）
CRATES = [(204, 14), (262, 14)]  # 船员坐的箱子：中心 x、宽
CRATE_H = 10
SHELF_Y = 206                    # 黑机箱正面开的 4 个小窗（像旧售货机）：窗口上沿
SHELF_X = [352, 380, 414, 442]   # 窗口中心 x：武器 2 + 变异 2
REFRESH_X = 300                  # 刷新拉杆（机箱左边那根斜管旁）


class Px:
    def __init__(self, a):
        self.a = a

    def put(self, x, y, c):
        if 0 <= x < self.a.shape[1] and 0 <= y < self.a.shape[0]:
            self.a[y, x, :3] = c
            self.a[y, x, 3] = 255

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def hline(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vline(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def sag(self, x0, y0, x1, y1, depth, c):
        """两点之间往下垂的电线（抛物线），一像素一格连起来。"""
        prev = None
        for x in range(x0, x1 + 1):
            t = (x - x0) / max(x1 - x0, 1)
            y = round(y0 + (y1 - y0) * t + depth * 4 * t * (1 - t))
            if prev is not None and abs(y - prev) > 1:
                self.vline(x, min(y, prev) + 1, max(y, prev) - 1, c)
            self.put(x, y, c)
            prev = y


def load_oscar():
    with tempfile.TemporaryDirectory() as d:
        out = Path(d) / "shop.png"
        subprocess.run([ASEPRITE, "-b", str(SRC), "--save-as", str(out)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return np.asarray(Image.open(out).convert("RGBA")).copy()


def draw_room(oscar):
    a = np.zeros((H, W, 4), np.uint8)
    a[..., :3] = BG
    a[..., 3] = 255
    a[OY:OY + oscar.shape[0], OX:OX + oscar.shape[1]] = oscar
    p = Px(a)

    # 地面往左接：Oscar 的地毯花纹 17 像素一循环
    for y in range(188, 200):
        for x in range(0, OX):
            a[OY + y, x] = oscar[y, (x - OX) % 17]

    # 天花板：一根工字梁，下沿亮一线，铆钉每 12 格一颗
    p.rect(0, 0, W - 1, 5, K1)
    p.hline(0, W - 1, 6, D2)
    p.hline(0, W - 1, 1, D1)
    for x in range(5, W, 12):
        p.put(x, 3, D3)
    # Oscar 那台吊着的加热器原来顶到画布上沿：补两根吊杆和中间一根粗电缆
    for x in (OX + 172, OX + 250):
        p.vline(x, 7, OY - 1, D3)
        p.vline(x + 1, 7, OY - 1, K2)
        p.rect(x - 1, 7, x + 2, 8, M1)
    p.rect(OX + 210, 7, OX + 212, OY - 1, K1)
    p.vline(OX + 210, 7, OY - 1, D2)
    for y in range(12, OY, 9):
        p.hline(OX + 209, OX + 213, y, D3)           # 电缆上的扎带

    # 左边垂下来的几根电线，交错着搭在梁上
    p.sag(0, 12, 120, 10, 22, D2)
    p.sag(40, 7, 200, 7, 30, D1)
    p.sag(150, 7, OX + 160, 7, 16, D2)

    # 吊灯：电线 + 灯罩 + 不亮的灯泡（游戏里不点亮，光只来自篝火）
    lx = 92
    p.vline(lx, 7, 52, D2)
    p.rect(lx - 1, 52, lx + 1, 53, M1)
    for i, half in enumerate([2, 3, 4, 5, 6, 7]):
        p.hline(lx - half, lx + half, 54 + i, D3 if i < 5 else M1)
        p.put(lx - half, 54 + i, M1)
    p.rect(lx - 2, 60, lx + 2, 62, D4)
    p.hline(lx - 1, lx + 1, 63, D3)
    p.put(lx - 1, 61, M2)

    # 洞洞板：暗芯，上、左一圈亮线，右、下暗线，孔 6 格一个
    x0, y0, x1, y1 = 14, 150, 166, 214
    p.rect(x0, y0, x1, y1, K1)
    p.hline(x0, x1, y0, M1)
    p.vline(x0, y0, y1, D4)
    p.hline(x0, x1, y1, D2)
    p.vline(x1, y0, y1, D2)
    for y in range(y0 + 4, y1 - 1, 6):
        for x in range(x0 + 4, x1 - 1, 6):
            p.put(x, y, D2)
    # 板子用两根角铁钉在墙上
    for x in (x0 + 10, x1 - 10):
        p.rect(x, y0 - 3, x + 1, y0 - 1, D3)
    # 四个挂钩：装备挂在这里，钩子下面空出来给图标
    for hx in HOOKS:
        p.rect(hx - 1, HOOK_Y - 9, hx + 1, HOOK_Y - 8, M2)
        p.vline(hx, HOOK_Y - 7, HOOK_Y - 6, M1)
        p.put(hx + 1, HOOK_Y - 5, M1)
    # 板上用粉笔一样的细线画的价签框（游戏里在框里写等级）
    for hx in HOOKS:
        p.hline(hx - 9, hx + 9, 199, D3)
        p.put(hx - 9, 198, D3)
        p.put(hx + 9, 198, D3)
    # 板子上还挂着几件杂物：一卷电线、一把扳手的剪影
    p.rect(150, 158, 160, 160, D3)
    p.rect(152, 161, 158, 166, D2)
    p.hline(153, 157, 161, D4)
    p.line(20, 205, 28, 197, D3)
    p.rect(27, 195, 29, 197, D3)

    # 工作台：台面亮边、暗底，两条腿，下面一层隔板
    bx0, bx1 = 8, 182
    p.rect(bx0, BENCH_Y, bx1, BENCH_Y + 3, D3)
    p.hline(bx0, bx1, BENCH_Y, M2)
    p.hline(bx0, bx1, BENCH_Y + 3, K2)
    for x in range(bx0 + 7, bx1, 23):
        p.put(x, BENCH_Y + 1, D2)                      # 木板接缝
    for lx_ in (bx0 + 4, bx1 - 5):
        p.rect(lx_, BENCH_Y + 4, lx_ + 1, FLOOR_LOW - 1, D2)
        p.vline(lx_, BENCH_Y + 4, FLOOR_LOW - 1, D3)
    p.rect(bx0 + 4, 246, bx1 - 4, 247, D2)
    p.hline(bx0 + 4, bx1 - 4, 246, D3)
    # 隔板上堆的零碎：两个铁皮罐、一只破喇叭口
    p.rect(30, 240, 36, 245, D3)
    p.hline(30, 36, 240, M1)
    p.rect(39, 242, 44, 245, D2)
    p.hline(39, 44, 242, D4)
    p.rect(120, 241, 128, 245, D2)
    p.line(128, 241, 133, 238, D3)
    p.line(128, 245, 133, 248 - 3, D3)
    # 台面上：一个台钳（左头）
    p.rect(14, BENCH_Y - 5, 22, BENCH_Y - 1, D4)
    p.hline(14, 22, BENCH_Y - 5, M2)
    p.rect(23, BENCH_Y - 3, 27, BENCH_Y - 2, D3)
    p.put(27, BENCH_Y - 4, M1)

    # 黑机箱正面开 4 个小窗：暗芯，上、左亮线，窗下一道价签槽；武器和变异之间一根竖隔条
    for wx in SHELF_X:
        x0, y0 = wx - 10, SHELF_Y
        p.rect(x0, y0, x0 + 19, y0 + 19, K0)
        p.hline(x0, x0 + 19, y0, M1)
        p.vline(x0, y0, y0 + 19, D4)
        p.hline(x0, x0 + 19, y0 + 19, D2)
        p.vline(x0 + 19, y0, y0 + 19, D2)
        p.hline(x0 + 3, x0 + 16, y0 + 23, D3)
    p.vline((SHELF_X[1] + SHELF_X[2]) // 2, SHELF_Y - 2, SHELF_Y + 24, M1)

    # 刷新拉杆：机箱左边地上一根带红把手的拉杆，底座贴着高的那层地面
    rx = REFRESH_X
    gy = FLOOR_HIGH
    p.rect(rx - 4, gy - 3, rx + 4, gy - 1, D3)
    p.hline(rx - 4, rx + 4, gy - 3, M1)
    p.line(rx, gy - 4, rx - 4, gy - 16, M1)
    p.line(rx + 1, gy - 4, rx - 3, gy - 16, D3)
    p.rect(rx - 6, gy - 19, rx - 3, gy - 17, RUST)
    return a


def draw_fg():
    a = np.zeros((H, W, 4), np.uint8)
    p = Px(a)
    for cx, w in CRATES:
        x0, x1 = cx - w // 2, cx + w // 2 - 1
        y0, y1 = FLOOR_LOW - CRATE_H, FLOOR_LOW - 1
        p.rect(x0, y0, x1, y1, D3)
        p.hline(x0, x1, y0, M2)
        p.vline(x0, y0 + 1, y1, D4)
        p.vline(x1, y0 + 1, y1, D2)
        p.hline(x0 + 1, x1 - 1, y0 + 5, D2)          # 中间一道板缝
        p.line(x0 + 1, y1 - 1, x1 - 1, y0 + 6, D2)    # 斜撑
        p.put(x0 + 1, y0 + 1, M3)
    return a


# ---------------------------------------------------------------- 图标（16×16 一格）
# 调色板：小怪那套暖调深灰 + 锈色 + 红灯，另外加一档马灯的暖光、电弧的冷白
sys.path.insert(0, str(ROOT.parent / "草图/精英怪"))
from elites import G, RGB  # noqa: E402

RGB.update({
    "y1": (122, 74, 34), "y2": (214, 150, 72), "y3": (255, 211, 138), "y4": (255, 240, 200),
    "b1": (120, 150, 190), "b2": (215, 235, 255),
})

ICONS = ["part", "charge", "fuel", "plating", "damping", "repair", "refresh",
         "hammer", "tongs", "horn", "rivet", "rage", "slave", "echo", "dynamo",
         "shotgun", "laser", "record"]   # 10-18 新武器（游戏设计会话画的占位，美术可以重画）


# 新武器图标：一格一格点的 16×16（光从左上来，枪口 / 发射口朝左，和铆钉枪、喇叭一样）。
# 数字 = G 的灰阶档，s / S = 亮钢，a b c d = 暖黄 y1~y4（铜、火光），r = 锈 r3，L / l = 红灯 / 暗红，u / w = 电弧的冷蓝 / 冷白
PIX_KEY = {"a": "y1", "b": "y2", "c": "y3", "d": "y4", "r": "r3", "u": "b1", "w": "b2"}
PIXEL_ICONS = {
    # 废铁霰弹枪：一截粗排气管当枪管（两道锈箍）、喇叭口枪口、黄铜泵、握把，枪口喷出一扇碎铁
    "shotgun": [
        "................",
        "c...............",
        ".b..............",
        "..c.............",
        ".889............",
        "c9SS999r999r9998",
        ".117777r777r7776",
        "c116666r666r6665",
        ".855555r555r5554",
        "..c.4abbba.97654",
        "...c.aaaaa..7654",
        "............7654",
        ".............765",
        ".............654",
        "..............54",
        "................",
    ],
    # 显像管激光：右边大头的玻壳（屏幕那面亮一道）、往左收成管颈、管颈上一圈铜线圈，管口射出一道红光
    "laser": [
        "...........9SSS.",
        ".........979996S",
        "........97777769",
        ".......977666659",
        "......9766665559",
        "....9b76555544S9",
        "Llll7ab655444459",
        "LllL6ab544433349",
        "....5ab443333349",
        "......5433332249",
        ".......53322229.",
        "........5222224.",
        "..........53328.",
        "...........677..",
        "..........56665.",
        "..........44444.",
    ],
    # 唱片回旋镖：黑胶唱片（一圈圈纹路）、中间红标签、两道转动的反光，左边一道飞出去的弧
    "record": [
        "................",
        ".....3333333....",
        "...33222222233..",
        "..3292323232223.",
        ".329S23232323223",
        ".3292323l23232S3",
        "S323232lLLl2323S",
        "S32323lLc0Ll3232",
        "S32323lL00ll3232",
        ".3232322llll2323",
        ".32232323ll2S923",
        "..3223232322S93.",
        "...33222222933..",
        ".....3333333....",
        "................",
        "................",
    ],
    # 特斯拉电钳：两片钳臂在铆钉处交叉，上面钳嘴张开、往里勾，两个钳尖之间一道冷蓝电弧；下面握把缠着锈色胶布
    "tongs": [
        "...9.......9....",
        "..u8w.....w8u...",
        "..S7.wu.uw.7S...",
        "...87..w..78....",
        "....86....68....",
        ".....86..68.....",
        "......8SS6......",
        "......7SS6......",
        ".....86..67.....",
        "....86....67....",
        "...rr......rr...",
        "..rar......rar..",
        "..rr........rr..",
        ".rar........rar.",
        ".rr..........rr.",
        "................",
    ],
}


def icon(name):
    g = G(16, 16)
    if name == "part":                    # 零件：一颗齿轮，中间一个孔
        g.disk(7.5, 7.5, 5.2, "s")
        for x, y in [(7, 1), (8, 1), (7, 14), (8, 14), (1, 7), (1, 8), (14, 7), (14, 8),
                     (3, 3), (12, 3), (3, 12), (12, 12)]:
            g.put(x, y, "s")
        g.disk(7.5, 7.5, 4.2, 9)
        g.pts([(5, 4), (6, 3), (4, 5), (7, 1), (8, 1), (3, 3)], "S")
        g.disk(7.5, 7.5, 1.6, 2)
        g.pts([(10, 11), (11, 10), (12, 12), (14, 8)], 7)
    elif name == "charge":                # 闪光灯：反光碗 + 灯泡，碗后面一根手柄
        g.poly([(3, 2), (12, 2), (10, 8), (5, 8)], 7)
        g.path([(3, 2), (12, 2)], 9)
        g.disk(7.5, 4.5, 1.8, "y4")
        g.pts([(7, 4)], "y4")
        g.rect(7, 9, 8, 14, 5)
        g.rect(7, 9, 7, 14, 6)
        g.rect(6, 12, 9, 12, 4)
        g.pts([(2, 0), (13, 0), (0, 3), (15, 3)], "y3")          # 闪一下的光芒
    elif name == "fuel":                  # 火箭靴：靴子 + 后跟一个小喷口
        g.rect(4, 2, 9, 9, 6)
        g.rect(4, 2, 9, 2, 8)
        g.rect(4, 3, 4, 9, 7)
        g.rect(2, 10, 12, 12, 6)
        g.rect(2, 10, 12, 10, 8)
        g.rect(10, 6, 12, 9, 5)                                  # 喷口
        g.rect(10, 6, 12, 6, 7)
        g.pts([(11, 13), (10, 14), (12, 14), (11, 15)], "y2")
        g.put(11, 14, "y3")
        g.rect(5, 5, 8, 5, 4)                                    # 鞋带
    elif name == "plating":               # 马灯 · 镀层：马灯外面套一圈亮铁箍
        g.rect(5, 1, 10, 1, 7)
        g.rect(4, 2, 11, 3, 6)
        g.rect(5, 4, 10, 11, "y2")
        g.rect(6, 5, 9, 9, "y3")
        g.pts([(7, 6), (8, 6), (7, 7)], "y4")
        g.rect(4, 12, 11, 13, 6)
        for y in range(3, 13):
            g.put(3, y, 9 if y % 3 else 8)
            g.put(12, y, 8 if y % 3 else 7)
        g.rect(3, 7, 12, 7, 9)
    elif name == "damping":               # 指针表 · 阻尼：怀表，指针压在低档
        g.disk(7.5, 8.5, 6.2, 7)
        g.disk(7.5, 8.5, 5.2, 2)
        g.rect(7, 0, 8, 1, 7)
        g.put(7, 1, 9)
        for x, y in [(3, 8), (7, 4), (12, 8), (4, 5), (11, 5)]:
            g.put(x, y, 6)
        g.path([(7, 9), (4, 10)], 9)                             # 指针偏左（压低）
        g.put(7, 9, "L")
        g.pts([(4, 3), (3, 4)], 9)
    elif name == "repair":                # 修灯：马灯 + 一把扳手
        g.rect(4, 2, 9, 2, 7)
        g.rect(3, 3, 10, 4, 6)
        g.rect(4, 5, 9, 11, "y2")
        g.rect(5, 6, 8, 10, "y3")
        g.pts([(6, 7), (7, 7)], "y4")
        g.rect(3, 12, 10, 13, 6)
        g.line(10, 14, 14, 10, 8)
        g.pts([(13, 9), (15, 9), (15, 11)], 8)
        g.pts([(9, 15), (10, 15)], 7)
        g.pts([(1, 2), (1, 3), (0, 3)], "y3")                    # 加号一样的小火光
    elif name == "refresh":               # 刷新：拉杆往下一拉，两头的箭头
        g.rect(3, 12, 12, 14, 6)
        g.rect(3, 12, 12, 12, 8)
        g.line(7, 11, 3, 3, 8)
        g.rect(1, 1, 4, 3, "r3")
        g.put(2, 1, "L")
        g.path([(10, 2), (13, 2), (13, 7)], 7)
        g.pts([(12, 6), (14, 6), (13, 8)], 7)
    elif name == "hammer":                # 蒸汽锤：粗锤头 + 一根汽缸当柄
        g.rect(2, 2, 13, 6, 6)
        g.rect(2, 2, 13, 2, 9)
        g.rect(2, 3, 2, 6, 7)
        g.rect(13, 3, 13, 6, 4)
        g.rect(5, 4, 10, 4, 4)
        g.rect(7, 7, 8, 14, 5)
        g.rect(7, 7, 7, 14, 7)
        g.rect(6, 10, 9, 11, 6)
        g.pts([(1, 0), (14, 1), (0, 1)], "s")                    # 冒的汽
    elif name == "horn":                  # 留声机喇叭：大喇叭口朝右
        g.poly([(2, 7), (6, 6), (14, 1), (14, 14), (6, 9), (2, 9)], 6)
        g.path([(6, 6), (14, 1)], 9)
        g.path([(14, 1), (14, 14)], 8)
        g.path([(6, 9), (14, 14)], 4)
        g.poly([(11, 4), (13, 3), (13, 12), (11, 11)], 2)        # 喇叭里面
        g.rect(1, 7, 3, 9, 7)
        g.pts([(9, 5), (8, 6)], 9)
    elif name == "rivet":                 # 铆钉枪：枪身 + 一颗打出去的铆钉
        g.rect(4, 4, 13, 8, 6)
        g.rect(4, 4, 13, 4, 8)
        g.rect(4, 5, 4, 8, 7)
        g.rect(1, 5, 3, 7, 5)                                    # 枪口（朝左）
        g.rect(9, 9, 12, 14, 5)                                  # 握把
        g.rect(9, 9, 9, 14, 6)
        g.rect(6, 6, 11, 6, 4)
        g.put(0, 6, "y3")
        for x in range(5, 14, 2):                                # 上面一排待打的铆钉
            g.put(x, 3, 9)
        g.pts([(14, 9), (15, 10), (14, 11)], 7)
    elif name == "rage":                  # 怒火：表盘指针打到红区
        g.disk(7.5, 9.5, 6.2, 7, ring=1)
        g.disk(7.5, 9.5, 5.2, 2)
        g.rect(1, 13, 14, 15, 5)
        g.rect(1, 13, 14, 13, 7)
        for x, y in [(11, 5), (12, 6), (13, 8)]:
            g.put(x, y, "L")
        g.path([(7, 10), (11, 6)], 9)
        g.put(7, 10, "L")
        g.pts([(3, 6), (4, 5)], 9)
    elif name == "slave":                 # 从闪：一大一小两个灯泡，小的跟着闪
        g.disk(5.5, 6.5, 3.6, "y3")
        g.disk(5.5, 6.5, 2.0, "y4")
        g.rect(4, 10, 7, 12, 6)
        g.rect(4, 10, 7, 10, 8)
        g.disk(12, 10, 2.2, "y2")
        g.put(12, 9, "y4")
        g.rect(11, 13, 13, 14, 6)
        g.pts([(9, 3), (10, 5), (14, 6), (15, 8)], "y3")
    elif name == "echo":                  # 磁带回声：一盘磁带，后面一道淡一点的重影
        g.rect(4, 5, 15, 12, 4)
        g.rect(1, 2, 12, 9, 6)
        g.rect(1, 2, 12, 2, 8)
        g.rect(1, 3, 1, 9, 7)
        g.rect(3, 4, 10, 4, "r3")
        g.rect(3, 5, 10, 7, 1)
        g.disk(4.5, 6, 0.9, 7)
        g.disk(9.5, 6, 0.9, 7)
        g.rect(5, 9, 8, 9, 2)
        g.pts([(13, 13), (15, 13)], 5)
    elif name == "dynamo":                # 发电机：线圈 + 摇把 + 一道闪电
        g.rect(2, 5, 10, 13, 5)
        g.rect(2, 5, 10, 5, 8)
        for x in range(3, 10, 2):
            g.rect(x, 6, x, 12, "r3")
        g.rect(11, 8, 12, 9, 6)
        g.line(12, 8, 14, 3, 7)
        g.put(14, 2, 9)
        g.path([(7, 0), (5, 3), (8, 3), (6, 6)], "y3")
    elif name in PIXEL_ICONS:             # 新武器（10-18 放映机会话一格一格点的，见 PIXEL_ICONS）
        for y, row in enumerate(PIXEL_ICONS[name]):
            for x, ch in enumerate(row):
                if ch != ".":
                    g.put(x, y, PIX_KEY.get(ch, ch if not ch.isdigit() else int(ch)))
    return g.rgba()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    room = draw_room(load_oscar())
    fg = draw_fg()
    Image.fromarray(room).save(OUT / "room.png")
    Image.fromarray(fg).save(OUT / "room_fg.png")
    icons = np.concatenate([icon(n) for n in ICONS], axis=1)
    Image.fromarray(icons).save(OUT / "icons.png")

    # 预览：房间（提亮 2.2 倍，方便看）+ 图标放大
    S = 3
    view = room.copy()
    m = fg[..., 3] > 0
    view[m] = fg[m]
    for i, n in enumerate(ICONS[1:6]):
        x = (HOOKS + [REPAIR_X])[i] - 8
        y = HOOK_Y - 6 if i < 4 else BENCH_Y - 16
        ic = icon(n)
        mm = ic[..., 3] > 0
        view[y:y + 16, x:x + 16][mm] = ic[mm]
    for i, n in enumerate(["hammer", "horn", "slave", "dynamo"]):
        x, y = SHELF_X[i] - 8, SHELF_Y + 2
        ic = icon(n)
        mm = ic[..., 3] > 0
        view[y:y + 16, x:x + 16][mm] = ic[mm]
    bright = np.clip(view[..., :3].astype(float) * 2.2, 0, 255).astype(np.uint8)
    top = Image.fromarray(bright).resize((W * S, H * S), Image.NEAREST)
    ic_big = Image.fromarray(icons).resize((icons.shape[1] * 6, 16 * 6), Image.NEAREST)
    sheet = Image.new("RGB", (W * S, H * S + 16 * 6 + 20), (40, 36, 40))
    sheet.paste(top, (0, 0))
    sheet.paste(ic_big, (10, H * S + 10), ic_big)
    sheet.save(OUT / "preview_shop.png")
    print("ok", room.shape, icons.shape)


if __name__ == "__main__":
    main()
