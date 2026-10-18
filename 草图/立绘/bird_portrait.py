"""小鸟立绘方案（只出方案，不接进游戏；早上作者挑）。96×96 透明底，构图和恐龙一样：脸朝右的半身像。

设计照游戏里的小人 oscar-rush/art/chars/bird_body.png：
- 深蓝靛色（小人 47,54,80 一族），圆头在上，又短又细的喙朝右；
- 横着的身子，背上一道淡紫白的亮条（strip 层 201,212,255）→ 立绘里是翅膀上沿的高光；
- 颜色像红衣、恐龙那样从小人提亮，色相不变。
画法照小奥斯卡：光从左上来，按离光远近一档一档切，不描黑边，一个色相（淡紫算同一族的亮端）。

三版：
  1 利落：细长喙，眼周一圈淡紫，脖子细一点
  2 圆滚滚：大圆头、大眼睛、短喙、胸口一撮绒毛
  3 飞行镜：在 1 的基础上，额头推着一副黄铜飞行护目镜（和机器人的黄铜、"旧科技"呼应）

跑：python3 草图/立绘/bird_portrait.py（要 AI Oscar 的 oscarkit）
出：草图/立绘/bird_portrait_{1,2,3}.png
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path.home() / "Desktop/程序programs/AI Oscar"))
from oscarkit.canvas import Canvas  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
W = H = 96
ROWS = np.arange(H)[:, None]
COLS = np.arange(W)[None, :]
LIGHT = np.array([-0.62, -0.78])

# 深蓝靛：暗 → 亮（不用黑）。小人是 47,54,80 一族，提亮、加饱和，像红衣和恐龙那样
N = ["#141a33", "#1c2547", "#25305b", "#2f3d70", "#3b4b86", "#4b5c9b", "#5f71b0", "#7a8cc4", "#9aaad6"]
# 淡紫白：背上那道亮条
L = ["#9aa6d6", "#c3ccf5", "#e6e9ff"]
BEAK = ["#1b1f2b", "#2a2f3f", "#434a60", "#646c86"]
EYE_DARK = "#0f1220"
BRASS = ["#653c1c", "#93673e", "#bf966b", "#e7c9a4"]   # 机器人那条铜色阶里挑的
GLASS = ["#34374b", "#575668", "#9fb3c8"]


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ellipse(cx, cy, rx, ry):
    return ((COLS - cx) / (rx + 0.5)) ** 2 + ((ROWS - cy) / (ry + 0.5)) ** 2 <= 1.0


def edge(mask, side):
    dy, dx = {"top": (1, 0), "bottom": (-1, 0), "left": (0, 1), "right": (0, -1)}[side]
    inner = np.zeros_like(mask)
    inner[max(dy, 0):H + min(dy, 0), max(dx, 0):W + min(dx, 0)] = \
        mask[max(-dy, 0):H + min(-dy, 0), max(-dx, 0):W + min(-dx, 0)]
    return mask & ~inner


class Painter:
    def __init__(self):
        self.c = Canvas(W, H)

    def paint(self, mask, col):
        self.c.a[mask] = (*rgb(col), 255)

    def lit(self, mask, levels, bias=0.0):
        ys, xs = np.nonzero(mask)
        if len(xs) == 0:
            return
        p = xs * LIGHT[0] + ys * LIGHT[1]
        lo, hi = p.min(), p.max()
        t = (hi - p) / max(hi - lo, 1e-6) + bias
        idx = np.clip((t * len(levels)).astype(int), 0, len(levels) - 1)
        for i, lv in enumerate(levels):
            sel = idx == i
            self.c.a[ys[sel], xs[sel]] = (*rgb(lv), 255)

    def poly(self, pts):
        return self.c.poly([(round(x), round(y)) for x, y in pts])


LIGHT3 = np.array([-0.5, -0.62, 0.6])
LIGHT3 = LIGHT3 / np.linalg.norm(LIGHT3)


def sphere(pt, mask, cx, cy, rx, ry, levels, cut=(0.75, 0.45, 0.15)):
    """圆的东西按球面打光：levels 从亮到暗，cut 是分档的亮度阈值（档边是顺着形体的弧，不是斜直线）。"""
    ys, xs = np.nonzero(mask)
    nx = (xs - cx) / max(rx, 1)
    ny = (ys - cy) / max(ry, 1)
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    v = nx * LIGHT3[0] + ny * LIGHT3[1] + nz * LIGHT3[2]
    idx = np.full(len(xs), len(levels) - 1)
    for i, c in reversed(list(enumerate(cut))):
        idx[v > c] = i
    idx = np.minimum(idx, len(levels) - 1)
    for i, lv in enumerate(levels):
        sel = idx == i
        pt.c.a[ys[sel], xs[sel]] = (*rgb(lv), 255)


def scallops(pt, mask, x0, x1, y0, y1, step_x=5, step_y=4, dark=None, light=None):
    """一排排鳞片状的羽毛：每片底下一道深一档的弧，弧上一格亮一档。"""
    for r, y in enumerate(range(y0, y1, step_y)):
        off = (r % 2) * (step_x // 2)
        for x in range(x0 + off, x1, step_x):
            for dx in range(-2, 3):
                yy = y + (1 if abs(dx) == 2 else 0)
                if 0 <= x + dx < W and 0 <= yy < H and mask[yy, x + dx]:
                    pt.c.put(x + dx, yy, dark)
            if light and 0 <= y - 1 < H and mask[y - 1, x]:
                pt.c.put(x, y - 1, light)


def draw(variant: int) -> Image.Image:
    pt = Painter()
    cute = variant == 2
    hx, hy, hrx, hry = (46, 38, 23, 21) if cute else (46, 34, 20, 19)

    # ---- 身子：画框下沿切掉，往左后方伸（小人的身子是横着的）
    body = ellipse(44, 100, 38, 30) | ellipse(14, 96, 20, 18)
    sphere(pt, body, 40, 104, 40, 34, [N[4], N[3], N[2], N[1]])
    # 胸口：正对镜头，羽毛一排排
    chest = ellipse(58, 88, 16, 20) & body
    sphere(pt, chest, 58, 88, 16, 20, [N[5], N[4], N[3], N[2]])
    scallops(pt, chest, 46, 76, 76, 96, step_x=8, step_y=6, dark=N[3])
    # 翅膀：左后方一大片，上沿是小人背上那道淡紫白亮条，亮条下面一排羽尖
    wing = ellipse(24, 92, 28, 17) & (ROWS >= 74)
    sphere(pt, wing, 24, 92, 28, 17, [N[4], N[3], N[2], N[1]])
    band = wing & ~ellipse(25, 94, 27, 15) & (ROWS < 88)
    pt.lit(band, [L[2], L[1], L[0]])
    for x in range(4, 50, 6):
        yb = int(np.nonzero(band[:, x])[0].max()) + 1 if band[:, x].any() else None
        if yb is None:
            continue
        pt.c.poly([(x - 2, yb), (x + 3, yb), (x, yb + 4)], L[0])
        pt.c.put(x, yb + 4, N[3])
    for x0 in (20, 32, 44):
        pt.c.line(x0, 88, x0 - 7, 96, N[1])

    # ---- 脖子：两段椭圆接起来，往右前方弯一点
    neck = ellipse(hx + 3, hy + 22, 10, 15) | ellipse(hx + 8, hy + 38, 13, 12)
    sphere(pt, neck, hx + 4, hy + 28, 12, 20, [N[5], N[4], N[3], N[2]])
    if cute:
        for x in range(hx - 4, hx + 16, 4):
            pt.c.poly([(x, hy + 18), (x + 3, hy + 18), (x + 1, hy + 24)], N[7])

    # ---- 头
    head = ellipse(hx, hy, hrx, hry)
    sphere(pt, head, hx, hy, hrx, hry, [N[7], N[6], N[5], N[4], N[3]], cut=(0.85, 0.7, 0.45, 0.2))
    # 后脑勺一撮翘毛（小人头顶那格）
    tuft = pt.poly([(hx - 9, hy - hry + 2), (hx - 6, hy - hry - 6), (hx - 2, hy - hry - 3), (hx, hy - hry + 2)])
    pt.lit(tuft, [N[7], N[6], N[5]])

    # ---- 眼罩纹：从喙根穿过眼睛往后脑勺的一道深色（鸟的样子靠它）
    ex, ey = hx + (7 if cute else 8), hy - 2
    bx0 = hx + hrx - 4
    streak = pt.poly([(bx0 + 2, hy), (ex + 3, ey - 3), (ex - 5, ey - 4), (hx - 13, ey - 1),
                      (hx - 13, ey + 1), (ex - 5, ey + 4), (ex + 3, ey + 4), (bx0 + 2, hy + 2)]) & head
    pt.paint(streak, N[2])
    pt.paint(edge(streak, "top"), N[3])

    # ---- 喙：朝右
    bx, by = hx + hrx - 4, hy + 1
    if cute:
        beak = pt.poly([(bx, by - 5), (bx + 11, by), (bx, by + 4)])
    else:
        beak = pt.poly([(bx, by - 4), (bx + 24, by + 1), (bx + 24, by + 2), (bx, by + 4)])
    pt.lit(beak, [BEAK[3], BEAK[2], BEAK[1]])
    pt.paint(edge(beak, "top") & (COLS < bx + (8 if cute else 16)), BEAK[3])
    pt.paint(edge(beak, "bottom"), BEAK[0])
    pt.c.line(bx + 1, by + 1, bx + (9 if cute else 22), by + 1, BEAK[0])

    # ---- 眼睛
    if cute:
        pt.paint(ellipse(ex, ey, 6, 6), L[0])
        pt.paint(ellipse(ex, ey, 5, 5), EYE_DARK)
        pt.paint(ellipse(ex - 2, ey - 2, 1, 1), L[2])
        pt.c.put(ex + 2, ey + 2, L[1])
    else:
        pt.paint(ellipse(ex, ey, 4, 4), L[1])
        pt.paint(ellipse(ex, ey, 4, 4) & ~ellipse(ex, ey, 3, 3) & (ROWS > ey), L[0])
        pt.paint(ellipse(ex + 1, ey, 2, 2), EYE_DARK)
        pt.c.put(ex, ey - 1, L[2])

    # ---- 方案 3：额头推着一副黄铜飞行护目镜，带子绕到后脑
    if variant == 3:
        strap = ellipse(hx, hy - 9, hrx + 1, 1) & (head | ellipse(hx, hy - 9, hrx + 1, 1))
        pt.paint(strap, BRASS[0])
        pt.paint(edge(strap, "top"), BRASS[1])
        for gx in (hx - 2, hx + 9):
            rim = ellipse(gx, hy - 13, 5, 4)
            pt.lit(rim, [BRASS[3], BRASS[2], BRASS[1], BRASS[0]])
            lens = ellipse(gx, hy - 13, 3, 2)
            pt.paint(lens, GLASS[0])
            pt.paint(lens & (ROWS <= hy - 14) & (COLS <= gx), GLASS[2])
            pt.c.put(gx + 1, hy - 12, GLASS[1])
        pt.paint(pt.c.rect(hx + 3, hy - 14, hx + 4, hy - 13), BRASS[1])

    return Image.fromarray(pt.c.a, "RGBA")


if __name__ == "__main__":
    for v in (1, 2, 3):
        draw(v).save(ROOT / f"草图/立绘/bird_portrait_{v}.png")
    print("ok")
