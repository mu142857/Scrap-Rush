"""第一关 6 个精英怪的草图：照 Oscar 的爬虫（Art_Assets/爬虫.aseprite）画。

    python3 elites.py            # 输出到本文件夹：每只一张 1 倍 PNG（待机、放招两格）+ 一张放大的总览图

画法照爬虫：暖调深灰一个色相，亮框 + 暗芯 + 格栅，光从上面来（上边、左边亮一档），
不描边；腿是几根细线；一只红色指示灯当眼睛（游戏里红灯单独一层发光）。
全部朝左（爬虫默认往左走）。地面是画布最后一行。主角约 13 格高，精英怪 22~34 格。
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent

# 调色板：0~8 取自爬虫原稿（暗 → 亮），9 是大件顶边多加的一档；r* 是爬虫里那点锈色
PAL = {
    0: "#121110", 1: "#1a1918", 2: "#1d1b1a", 3: "#242221", 4: "#2a2828",
    5: "#32302e", 6: "#3b3835", 7: "#4b4742", 8: "#4f4b47", 9: "#5c5752",
    "r1": "#302926", "r2": "#362f2c", "r3": "#45362e",
    "L": "#ff4730", "l": "#8c2a1e",            # 红灯、红灯的暗边
    "s": "#6e6862", "S": "#8a847c",            # 蒸汽、飞尘（特效，脚本画）
}
RGB = {k: tuple(int(v[i:i + 2], 16) for i in (1, 3, 5)) for k, v in PAL.items()}


class G:
    """调色板下标的小画布，None = 透明。"""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.full((h, w), None, dtype=object)

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = c

    def pts(self, pts, c):
        for x, y in pts:
            self.put(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def box(self, x0, y0, x1, y1, base=4, top=8, left=7, right=5, bottom=3):
        """爬虫那种框：顶边最亮、左边亮、右边和底边暗一档。"""
        self.rect(x0, y0, x1, y1, base)
        self.rect(x0, y1, x1, y1, bottom)
        self.rect(x1, y0, x1, y1, right)
        self.rect(x0, y0, x0, y1, left)
        self.rect(x0, y0, x1, y0, top)

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

    def path(self, pts, c):
        for p, q in zip(pts, pts[1:]):
            self.line(*p, *q, c)

    def disk(self, cx, cy, r, c, ring=None):
        for y in range(self.h):
            for x in range(self.w):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d <= r + 0.3 and (ring is None or d > r - ring + 0.3):
                    self.put(x, y, c)

    def poly(self, pts, c):
        m = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(m).polygon(pts, fill=1)
        ys, xs = np.nonzero(np.asarray(m))
        for y, x in zip(ys, xs):
            self.put(x, y, c)

    def led(self, x, y, w=1):
        """红色指示灯：亮点 + 下面一格暗边。"""
        for i in range(w):
            self.put(x + i, y, "L")

    def rgba(self):
        out = np.zeros((self.h, self.w, 4), np.uint8)
        for y in range(self.h):
            for x in range(self.w):
                c = self.a[y, x]
                if c is not None:
                    out[y, x, :3] = RGB[c]
                    out[y, x, 3] = 255
        return out


def legs(g, roots, ground, spread=2, col=4, knee=5):
    """爬虫那种细线腿：从身子底下斜着落到地上，中间折一下。"""
    for i, (x, y) in enumerate(roots):
        d = -1 if i % 2 == 0 else 1
        kx, ky = x + d * spread, (y + ground) // 2
        g.line(x, y, kx, ky, knee)
        g.line(kx, ky, kx - d, ground, col)
        g.put(kx - d - 1, ground, col)


# ---------------------------------------------------------------- 1. 布谷鸟钟
def cuckoo(pose):
    W, H = 38, 40
    g = G(W, H)
    ox = 12                                      # 本体往右放，左边留给弹出来的鸟
    # 屋顶：三角 + 屋檐
    g.poly([(ox + 1, 10), (ox + 12, 1), (ox + 24, 10)], 5)
    g.path([(ox + 1, 10), (ox + 12, 1), (ox + 24, 10)], 8)
    g.path([(ox + 2, 10), (ox + 12, 2)], 9)
    g.rect(ox + 3, 11, ox + 22, 11, 2)                                    # 檐下的影子
    g.pts([(ox + 12, 0), (ox + 13, 0)], 7)
    # 钟身
    g.box(ox + 4, 11, ox + 21, 27, base=4, top=6, left=7, right=5, bottom=3)
    for x in range(ox + 5, ox + 21, 2):                                   # 底边雕花
        g.put(x, 26, 6)
    # 鸟门
    g.rect(ox + 11, 12, ox + 14, 15, 0)
    g.pts([(ox + 10, 12), (ox + 10, 13), (ox + 10, 14), (ox + 10, 15), (ox + 11, 11), (ox + 14, 11)], 6)
    # 钟面：亮圈 + 暗面 + 指针，中心是红灯
    cx, cy = ox + 12.5, 20.5
    g.disk(cx, cy, 4.6, 6)
    g.disk(cx, cy, 3.6, 1)
    g.pts([(ox + 12, 17), (ox + 13, 17), (ox + 9, 20), (ox + 16, 21), (ox + 12, 24)], 5)
    g.line(ox + 12, 18, ox + 12, 20, 8)                                   # 时针
    g.line(ox + 13, 21, ox + 15, 22, 7)                                   # 分针
    g.led(ox + 12, 21)
    # 钟摆和两个松果坠子
    swing = 0 if pose == 0 else -3
    g.line(ox + 12, 28, ox + 12 + swing, 33, 5)
    g.disk(ox + 12 + swing, 34.5, 1.8, "r3")
    g.pts([(ox + 11 + swing, 33), (ox + 12 + swing, 33)], 8)
    for wx, wl in [(ox + 7, 31), (ox + 18, 29)]:
        for y in range(28, wl):
            g.put(wx, y, 4)
        g.rect(wx - 1, wl, wx + 1, wl + 4, "r2")
        g.rect(wx - 1, wl, wx + 1, wl, 7)
        g.put(wx, wl + 5, "r1")
    # 腿
    legs(g, [(ox + 5, 28), (ox + 20, 28)], H - 1, spread=3)
    legs(g, [(ox + 9, 28), (ox + 16, 28)], H - 1, spread=1, col=3, knee=4)
    if pose == 1:                                                         # 放招：门开，铁鸟顶着弹簧冲出来
        g.rect(ox + 11, 12, ox + 14, 15, 0)
        g.pts([(ox + 15, 12), (ox + 16, 12), (ox + 15, 13), (ox + 16, 13)], 8)        # 门板往右甩开
        g.path([(ox + 11, 13), (ox + 9, 11), (ox + 7, 14), (ox + 5, 11), (ox + 3, 14), (ox + 1, 11), (ox - 1, 13),
                (ox - 3, 12)], 7)                                           # 弹簧
        g.poly([(1, 11), (4, 9), (7, 10), (7, 14), (3, 14)], 6)          # 鸟身
        g.path([(1, 11), (4, 9), (7, 10)], 9)
        g.pts([(5, 13), (4, 14), (5, 14), (6, 14)], 4)                     # 翅膀
        g.put(3, 11, "L")
        g.put(0, 12, 9)                                                     # 嘴尖
    return g.rgba()


# ---------------------------------------------------------------- 2. 缝纫机
def sewing(pose):
    W, H = 42, 28
    g = G(W, H)
    # 侧面的手轮（在立柱后面）
    g.disk(36.5, 8.5, 4.5, 6)
    g.disk(36.5, 8.5, 3.5, 2)
    g.pts([(36, 5), (37, 12), (33, 8), (40, 9)], 5)
    g.pts([(36, 8), (37, 8), (36, 9), (37, 9)], 7)
    # C 形机臂：横臂 + 右立柱 + 左机头
    g.box(6, 3, 33, 7, base=5, top=9, left=8, right=5, bottom=2)
    g.box(27, 3, 33, 15, base=4, top=9, left=7, right=5, bottom=3)
    g.box(4, 3, 11, 13, base=4, top=9, left=8, right=5, bottom=3)
    g.rect(12, 8, 26, 8, 1)                                               # 横臂下面最深的一道影子
    # 臂上那点锈金色花纹（老缝纫机的贴花）
    g.pts([(15, 5), (16, 4), (17, 5), (18, 4), (19, 5), (22, 5), (23, 4), (24, 5)], "r3")
    # 线轴
    g.line(20, 1, 20, 2, 7)
    g.rect(19, 0, 21, 1, "r2")
    g.put(19, 0, "r3")
    # 机头上的红灯
    g.led(6, 6, 2)
    # 压脚和针
    g.rect(5, 14, 10, 14, 6)
    needle_end = 17 if pose == 0 else 27
    g.line(8, 13, 8, needle_end, 9)
    # 台面
    g.box(2, 16, 38, 18, base=5, top=9, left=7, right=5, bottom=3)
    # 铸铁脚架：两个带格栅的 A 字架 + 踏板
    for x0, x1 in [(5, 12), (27, 34)]:
        g.path([(x0 + 2, 19), (x0, H - 1)], 5)
        g.path([(x1 - 2, 19), (x1, H - 1)], 4)
        for y in range(20, H - 2, 2):
            g.line(x0 + 2, y, x1 - 2, y + 1, 3)
        g.put(x0 - 1, H - 1, 4)
        g.put(x1 + 1, H - 1, 4)
    g.rect(12, 24, 27, 24, 4)
    g.rect(14, 23, 25, 23, 5)                                             # 踏板
    if pose == 1:                                                         # 放招：针一路扎到地上，留下一道线
        g.rect(5, 14, 10, 14, 7)
        for x in range(0, 8, 2):
            g.put(x, H - 1, "s")
        g.pts([(7, 26), (9, 26), (8, 25)], 7)
    return g.rgba()


# ---------------------------------------------------------------- 3. 自动钢琴
def piano(pose):
    W, H = 52, 32
    g = G(W, H)
    ox = 8
    g.rect(ox + 2, 2, ox + 41, 3, 8)                                      # 琴盖
    g.rect(ox + 2, 2, ox + 41, 2, 9)
    g.box(ox + 3, 4, ox + 40, 26, base=3, top=6, left=7, right=5, bottom=2)
    # 上面的窗口：里面在卷穿孔纸，红灯在纸卷中间
    g.box(ox + 9, 6, ox + 34, 13, base=0, top=6, left=6, right=5, bottom=5)
    g.rect(ox + 10, 8, ox + 33, 11, 5)
    rng = np.random.default_rng(7 + pose)
    for x in range(ox + 11, ox + 33):
        for y in (8, 9, 10, 11):
            if rng.random() < 0.28:
                g.put(x, y, 2)
    g.rect(ox + 10, 7, ox + 33, 7, 2)
    g.rect(ox + 10, 12, ox + 33, 12, 2)
    g.led(ox + 21, 9, 2)
    # 两边的雕花柱
    for x in (ox + 5, ox + 38):
        g.rect(x, 5, x, 14, 6)
        g.put(x, 5, 8)
    # 键盘：白键是亮的，黑键是最暗的
    g.rect(ox + 1, 16, ox + 42, 18, 8)
    g.rect(ox + 1, 16, ox + 42, 16, 9)
    for x in range(ox + 1, ox + 43, 3):
        g.put(x, 17, 6)
        g.put(x, 18, 6)
    for x in range(ox + 2, ox + 42, 7):
        g.pts([(x, 16), (x + 1, 16), (x + 3, 16), (x + 4, 16)], 0)
    g.rect(ox + 1, 19, ox + 42, 19, 5)
    g.rect(ox + 3, 20, ox + 40, 20, 1)                                    # 键盘下的影子
    # 下面两块凹进去的板
    for x0 in (ox + 6, ox + 23):
        g.rect(x0, 21, x0 + 13, 25, 4)
        g.rect(x0, 21, x0 + 13, 21, 2)
        g.rect(x0, 21, x0, 25, 2)
    # 前腿和小轮子
    for x in (ox + 3, ox + 39):
        g.rect(x, 17, x + 1, 27, 6)
        g.put(x, 17, 8)
    legs(g, [(ox + 8, 27), (ox + 34, 27)], H - 1, spread=2)
    g.pts([(ox + 3, 28), (ox + 4, 28), (ox + 39, 28), (ox + 40, 28)], 4)
    g.pts([(ox + 3, 29), (ox + 40, 29)], 3)
    if pose == 1:                                                         # 放招：琴键一根根往上翘，地面的键顶起来
        for x in range(ox + 1, ox + 43, 6):
            g.rect(x, 14, x + 2, 15, 8)
            g.rect(x, 14, x + 2, 14, 9)
        for i, x in enumerate(range(0, ox, 3)):
            h = [5, 8, 3][i % 3]
            g.rect(x, H - h, x + 1, H - 1, 8)
            g.rect(x, H - h, x + 1, H - h, 9)
            g.put(x + 1, H - h + 1, 6)
    return g.rgba()


# ---------------------------------------------------------------- 4. 收银机
def register(pose):
    W, H = 40, 32
    g = G(W, H)
    ox = 9
    # 顶上的弹牌窗：红灯在里面
    g.box(ox + 9, 1, ox + 21, 7, base=0, top=8, left=7, right=5, bottom=5)
    g.rect(ox + 10, 3, ox + 20, 5, 1)
    g.pts([(ox + 11, 3), (ox + 12, 3), (ox + 14, 3), (ox + 17, 3), (ox + 18, 3)], 4)
    g.led(ox + 15, 4, 2)
    # 机身
    g.box(ox + 2, 8, ox + 26, 22, base=4, top=8, left=7, right=5, bottom=3)
    # 斜面键盘：一排排圆键（单像素亮点）
    g.poly([(ox + 3, 18), (ox + 3, 12), (ox + 17, 9), (ox + 17, 18)], 2)
    for r, y in enumerate((11, 13, 15, 17)):
        for x in range(ox + 4 + (3 - r), ox + 17, 2):
            if y >= 9 + (ox + 17 - x) * 3 // 14:
                g.put(x, y, 7 if r else 8)
    # 侧面摇把
    g.line(ox + 27, 12, ox + 29, 16, 6)
    g.pts([(ox + 29, 17), (ox + 30, 17)], 8)
    # 锈色铭牌
    g.rect(ox + 19, 12, ox + 24, 13, "r2")
    g.rect(ox + 19, 12, ox + 24, 12, "r3")
    # 钱箱抽屉
    if pose == 0:
        g.box(ox + 1, 19, ox + 27, 23, base=5, top=7, left=7, right=5, bottom=3)
        g.pts([(ox + 13, 21), (ox + 14, 21), (ox + 15, 21)], 9)
    else:                                                                 # 放招：抽屉弹出来，像一张嘴
        g.rect(ox + 2, 19, ox + 26, 23, 0)
        g.box(0, 20, ox + 4, 24, base=5, top=7, left=7, right=5, bottom=3)
        g.rect(0, 20, ox + 2, 20, 1)                                      # 抽屉格子里面
        for x in range(0, ox + 3, 3):                                     # 一格格的分隔板，像牙
            g.put(x, 19, 8)
            g.put(x, 20, 7)
        g.pts([(2, 22), (3, 22), (4, 22)], 9)
        g.pts([(1, 17), (5, 16), (8, 18)], "S")                          # 弹出来的硬币
    # 腿
    legs(g, [(ox + 4, 24), (ox + 11, 24), (ox + 17, 24), (ox + 24, 24)], H - 1, spread=2)
    return g.rgba()


# ---------------------------------------------------------------- 5. 吸尘器
def vacuum(pose):
    W, H = 48, 24
    g = G(W, H)
    ox = 6
    # 鱼雷形的罐身
    g.rect(ox + 13, 5, ox + 38, 15, 5)
    g.rect(ox + 12, 7, ox + 12, 13, 5)
    g.rect(ox + 39, 7, ox + 39, 13, 4)
    for y, c in [(5, 9), (6, 8), (7, 7), (13, 4), (14, 3), (15, 3)]:
        g.rect(ox + 13, y, ox + 38, y, c)
    g.pts([(ox + 12, 7), (ox + 12, 8)], 8)
    # 两道亮箍
    for x in (ox + 19, ox + 32):
        g.rect(x, 5, x, 15, 8)
        g.put(x, 5, 9)
        g.rect(x + 1, 6, x + 1, 15, 3)
    # 尾部排气格栅
    for y in range(8, 13, 2):
        g.line(ox + 36, y, ox + 38, y, 2)
    g.led(ox + 14, 8)                                                     # 红灯在罐头上
    # 底下的两条滑脚 + 小轮
    for x in (ox + 17, ox + 33):
        g.line(x, 16, x - 1, 19, 4)
        g.disk(x - 1, 20.5, 1.6, 3)
        g.put(x - 2, 19, 6)
    if pose == 0:
        # 软管：一节节的波纹
        hose = [(ox + 12, 10), (ox + 8, 11), (ox + 6, 14), (ox + 5, 18)]
        g.path(hose, 4)
        g.path([(ox + 12, 11), (ox + 8, 12), (ox + 7, 15), (ox + 6, 18)], 4)
        for x, y in [(ox + 10, 10), (ox + 8, 12), (ox + 6, 15)]:
            g.put(x, y, 6)
        # 吸头趴在地上，前面一条最深的嘴
        g.box(0, 18, ox + 8, 21, base=5, top=8, left=7, right=5, bottom=3)
        g.rect(0, 22, ox + 7, 22, 0)
        g.rect(0, 23, ox + 7, 23, 3)
    else:                                                                 # 放招：吸头抬起来对着你，往里吸
        g.path([(ox + 12, 10), (ox + 6, 9), (ox + 3, 10)], 4)
        g.path([(ox + 12, 11), (ox + 6, 10), (ox + 3, 11)], 4)
        g.pts([(ox + 9, 9), (ox + 6, 10)], 6)
        g.box(ox - 1, 5, ox + 3, 15, base=5, top=8, left=7, right=5, bottom=3)
        g.rect(ox - 1, 7, ox - 1, 13, 0)                                  # 嘴朝左张开
        for y, x0 in [(7, 0), (10, 1), (13, 0)]:                          # 被吸过来的灰，一串往嘴里飞
            for x in range(x0, ox - 2, 2):
                g.put(x, y + (1 if x < 2 else 0), "S" if x > 2 else 6)
    legs(g, [(ox + 22, 16), (ox + 28, 16)], H - 1, spread=1, col=3, knee=4)
    return g.rgba()


# ---------------------------------------------------------------- 6. 蒸汽压路机
def roller(pose):
    W, H = 54, 38
    g = G(W, H)
    ox, oy = 2, 4
    # 后轮（大轮，带辐条）
    g.disk(ox + 38, oy + 24, 8.5, 6)
    g.disk(ox + 38, oy + 24, 7.5, 2)
    for dx, dy in [(0, -7), (5, -5), (7, 0), (5, 5), (0, 7), (-5, 5), (-7, 0), (-5, -5)]:
        g.line(ox + 38, oy + 24, ox + 38 + dx, oy + 24 + dy, 4)
    g.disk(ox + 38, oy + 24, 1.6, 7)
    for a in range(0, 360, 30):                                           # 轮缘上的抓地齿
        import math
        x = round(ox + 38 + 8.6 * math.cos(math.radians(a)))
        y = round(oy + 24 + 8.6 * math.sin(math.radians(a)))
        g.put(x, y, 7 if y < oy + 24 else 5)
    # 驾驶棚：顶板 + 两根柱子，里面一个飞轮
    g.rect(ox + 26, oy + 1, ox + 47, oy + 2, 8)
    g.rect(ox + 26, oy + 1, ox + 47, oy + 1, 9)
    g.rect(ox + 28, oy + 3, ox + 28, oy + 16, 5)
    g.rect(ox + 45, oy + 3, ox + 45, oy + 15, 4)
    g.disk(ox + 36, oy + 10, 3.5, 5, ring=1)
    g.disk(ox + 36, oy + 10, 0.8, 7)
    # 锅炉：横着的圆筒，越往下越暗，两道铆钉箍
    for y, c in [(oy + 8, 9), (oy + 9, 8), (oy + 10, 7), (oy + 11, 6), (oy + 12, 6), (oy + 13, 5), (oy + 14, 5),
                 (oy + 15, 4), (oy + 16, 3)]:
        g.rect(ox + 7, y, ox + 31, y, c)
    for x in (ox + 15, ox + 24):
        g.rect(x, oy + 8, x, oy + 16, 7)
        for y in range(oy + 9, oy + 16, 2):
            g.put(x, y, 9)
    # 烟箱（最前面）+ 红色"大灯眼"
    g.box(ox + 4, oy + 8, ox + 7, oy + 16, base=3, top=8, left=6, right=4, bottom=2)
    g.led(ox + 5, oy + 11)
    # 烟囱
    g.rect(ox + 10, oy + 0, ox + 12, oy + 7, 5)
    g.rect(ox + 10, oy + 0, ox + 10, oy + 7, 7)
    g.rect(ox + 9, oy - 1, ox + 13, oy, 8)
    g.rect(ox + 9, oy - 1, ox + 13, oy - 1, 9)
    # 前滚筒（侧面看是一个大圆）和上面的叉架
    g.rect(ox + 7, oy + 17, ox + 9, oy + 20, 5)
    g.rect(ox + 4, oy + 17, ox + 12, oy + 17, 7)
    g.disk(ox + 8, oy + 25, 7.6, 5)
    g.disk(ox + 8, oy + 25, 7.6, 8, ring=1)
    for y in range(oy + 25, oy + 33):                                     # 下半圈暗一档
        for x in range(ox, ox + 17):
            if g.a[y, x] == 8:
                g.a[y, x] = 4
    g.disk(ox + 8, oy + 25, 5.0, 3, ring=1)
    g.disk(ox + 8, oy + 25, 1.5, 7)
    if pose == 1:                                                         # 放招：烟囱喷汽，往前冲，身后速度线
        for cx, cy, r in [(ox + 11, oy - 3, 1.6), (ox + 14, oy - 4, 2.0), (ox + 18, oy - 4, 1.5)]:
            g.disk(cx, cy, r, "s")
        g.pts([(ox + 12, oy - 4), (ox + 15, oy - 5)], "S")
        for y, x0 in [(oy + 12, 47), (oy + 18, 49), (oy + 22, 48)]:
            for x in range(x0, W, 2):
                g.put(x, y, 6)
        g.a[oy + 11, ox + 5] = "L"
        g.put(ox + 3, oy + 11, "l")
    return g.rgba()


ELITES = [("cuckoo", "布谷鸟钟", cuckoo), ("sewing", "缝纫机", sewing), ("piano", "自动钢琴", piano),
          ("register", "收银机", register), ("vacuum", "吸尘器", vacuum), ("roller", "蒸汽压路机", roller)]


def trim_pair(frames):
    """两格用同一个外框，脚底对齐。"""
    al = np.zeros(frames[0].shape[:2], bool)
    for f in frames:
        al |= f[..., 3] > 0
    ys, xs = np.nonzero(al)
    return [f[ys.min():ys.max() + 1, xs.min():xs.max() + 1] for f in frames]


def main():
    from PIL import ImageFont
    font = None
    for p in ["/Users/jiamulin/Desktop/程序programs/小游戏/Oscar Rush/oscar-rush/fonts/PixelFont.ttf",
              "/System/Library/Fonts/PingFang.ttc"]:
        try:
            font = ImageFont.truetype(p, 22)
            break
        except OSError:
            pass
    crawler = np.asarray(Image.open(OUT.parents[1] / "oscar-rush/art/enemies/crawler.png").convert("RGBA"))[:, :36]
    hero = None
    hp = OUT.parents[1] / "oscar-rush/art/chars/red_body.png"
    if hp.exists():
        body = np.asarray(Image.open(hp).convert("RGBA"))[:, :16].copy()
        strip = np.asarray(Image.open(hp.with_name("red_strip.png")).convert("RGBA"))[:, :16]
        m = strip[..., 3] > 0
        body[m] = strip[m]
        hero = body
    S, BG, GAP = 6, (104, 102, 110), 4
    rows = []
    for name, title, fn in ELITES:
        fr = trim_pair([fn(0), fn(1)])
        h = max(f.shape[0] for f in fr)
        w = sum(f.shape[1] for f in fr) + GAP
        sheet = np.zeros((h, w, 4), np.uint8)
        x = 0
        for f in fr:
            sheet[h - f.shape[0]:, x:x + f.shape[1]] = f
            x += f.shape[1] + GAP
        Image.fromarray(sheet).save(OUT / f"{name}.png")
        rows.append((title, fr))
    # 总览：每行一只，左边是待机、放招，右边放爬虫和主角当比例尺
    cell_h = max(max(f.shape[0] for f in fr) for _, fr in rows) * S + 40
    total_w = 1300
    img = Image.new("RGB", (total_w, cell_h * len(rows) + 50), BG)
    d = ImageDraw.Draw(img)
    d.text((16, 12), "Scrap Rush · 第一关精英怪草图（照爬虫画风，6 倍放大；每行：待机 / 放招 / 比例尺：爬虫、主角）",
           fill=(235, 232, 228), font=font)
    for i, (title, fr) in enumerate(rows):
        y0 = 50 + i * cell_h
        d.text((16, y0 + 4), title, fill=(235, 232, 228), font=font)
        base_y = y0 + cell_h - 8
        x = 16
        for f in list(fr) + [crawler] + ([hero] if hero is not None else []):
            im = Image.fromarray(f).resize((f.shape[1] * S, f.shape[0] * S), Image.NEAREST)
            img.paste(im, (x, base_y - im.size[1]), im)
            x += im.size[0] + 30
    img.save(OUT / "精英怪草图.png")
    print("ok", [(t, fr[0].shape[1], fr[0].shape[0]) for t, fr in rows])


if __name__ == "__main__":
    main()
