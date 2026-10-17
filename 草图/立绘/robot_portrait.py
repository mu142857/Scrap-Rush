"""铜色机器人立绘，96×96 透明底，和 red_portrait 同一个构图（头在上、底座被画框切掉）。

设计照游戏里的小人 oscar-rush/art/chars/robot_body.png（作者 10-17：上一版"跟小型的角色不符"）：
- 头顶一根短烟囱；方盒子头，脸是奶油色（小人左上那道浅色，255,225,194）；
- 头的右侧插一把发条钥匙往外伸（小人右边那个 ⊐⊏）；
- 弹簧脖子，一宽一窄；下面一个宽底座，正面一排深色格栅，右侧面暗；没有手臂。
- 颜色：小人是很暗的铜色，立绘像红衣那样提亮，色相不变。

画法照小奥斯卡：光从左上来，每个面按离光远近切成几档（档与档之间是直线），不描黑边，一个色相。
透视：一个灭点，盒子都用 oscarkit.persp.View 推出来。视线高度在眼睛，镜头在右边（灭点在画框外）：
头和视线一样高，看不到头顶，看得到右侧面；底座比视线低，看得到顶面和右侧面；越往里的东西越往灭点那边偏。

跑："~/Desktop/程序programs/AI Oscar/.venv/bin/python" 草图/立绘/robot_portrait.py
出：Art_Assets/yellow.png、oscar-rush/art/chars/robot_portrait.png、草图/立绘/robot_preview.png
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path.home() / "Desktop/程序programs/AI Oscar"))
from oscarkit.canvas import Canvas  # noqa: E402
from oscarkit.persp import View  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
W = H = 96

# 铜：暗 → 亮 9 档（oscarkit.palette.ramp((146,102,62), 9, L_span=0.6, hue_shift=14)），小人的色相提亮
B = ["#361803", "#4e290e", "#653c1c", "#7c512c", "#93673e", "#a97e53", "#bf966b", "#d3af86", "#e7c9a4"]
# 脸板：小人脸上的奶油色，暗 → 亮
F = ["#d2ae8c", "#ebc7a6", "#ffe1c2", "#fff0dc"]
BLUSH = "#eaa48e"
# 玻璃：冷的深灰蓝；暖光：游戏里马灯的暖黄（Hud.WARM）
V = ["#252837", "#34374b", "#45465c", "#575668"]
EYE = ["#e0954a", "#ffd38a", "#fff0cf"]

# 脸的方案（见 face_1 ~ face_4）。带参数跑只出试稿：python robot_portrait.py --try 2
TRY = len(sys.argv) > 2 and sys.argv[1] == "--try"
FACE = int(sys.argv[2]) if TRY else 1

EYE_Y = 28
view = View(102, EYE_Y, dist=140)

c = Canvas(W, H)
LIGHT = np.array([-0.62, -0.78])  # 光从左上来
ROWS = np.arange(H)[:, None]
COLS = np.arange(W)[None, :]


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lit(mask, levels, bias=0.0):
    """按离光源远近把一个面切成几档。levels 从亮到暗；档的分界是垂直于光线的直线。"""
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return
    p = xs * LIGHT[0] + ys * LIGHT[1]
    lo, hi = p.min(), p.max()
    t = (hi - p) / max(hi - lo, 1e-6) + bias
    idx = np.clip((t * len(levels)).astype(int), 0, len(levels) - 1)
    for i, lv in enumerate(levels):
        sel = idx == i
        c.a[ys[sel], xs[sel]] = (*_rgb(lv), 255)


def paint(mask, col):
    c.a[mask] = (*_rgb(col), 255)


def poly(pts):
    return c.poly([(round(x), round(y)) for x, y in pts])


def edge(mask, side):
    """mask 在某一侧的边缘那一圈像素。"""
    dy, dx = {"top": (1, 0), "bottom": (-1, 0), "left": (0, 1), "right": (0, -1)}[side]
    inner = np.zeros_like(mask)
    inner[max(dy, 0):H + min(dy, 0), max(dx, 0):W + min(dx, 0)] = \
        mask[max(-dy, 0):H + min(-dy, 0), max(-dx, 0):W + min(-dx, 0)]
    return mask & ~inner


def box(x0, x1, y0, y1, depth, front=0.0):
    return {k: poly(v) for k, v in view.box(x0, x1, y0, y1, front - depth, front).items()}


def P(x, y, d):
    px, py = view.p(x, y, d)
    return round(px), round(py)


def ellipse(cx, cy, rx, ry):
    return ((COLS - cx) / (rx + 0.5)) ** 2 + ((ROWS - cy) / (ry + 0.5)) ** 2 <= 1.0


def cylinder(mask, levels):
    """竖着的圆柱：光从左边来，按列分档（左亮右暗），最左一列退半档。"""
    xs = np.nonzero(mask.any(axis=0))[0]
    x0, x1 = xs.min(), xs.max()
    t = (COLS - x0) / max(x1 - x0, 1)
    # 最亮的地方在左边 1/4 处，不是贴着边
    t = np.where(t < 0.2, 0.25, t)
    idx = np.clip((t * len(levels)).astype(int), 0, len(levels) - 1)
    for i, lv in enumerate(levels):
        paint(mask & (idx == i), lv)


HEAD = dict(x0=26, x1=66, y0=15, y1=45, depth=28)
BASE = dict(x0=15, x1=78, y0=66, y1=140, depth=34)

# ---------------------------------------------------------------- 底座
base = box(BASE["x0"], BASE["x1"], BASE["y0"], BASE["y1"], BASE["depth"])
lit(base["top"], [B[7], B[6]])
lit(base["right"], [B[2], B[1], B[0]])
lit(base["front"], [B[5], B[4], B[3]], bias=-0.05)
# 前沿一道倒角（小人底座最上一行比下面窄一格）
paint(base["front"] & (ROWS == BASE["y0"]), B[8])
paint(base["front"] & (ROWS == BASE["y0"] + 1), B[7])
paint(base["front"] & (ROWS == BASE["y0"] + 2), B[6])
paint(edge(base["front"], "left") & (ROWS > BASE["y0"] + 2), B[6])

# 格栅：一块往里凹的板子，里面竖着的条和深缝（小人底座那排深色格子）
gx0, gx1, gy0, gy1 = 23, 70, 75, 89
paint(c.rect(gx0, gy0, gx1, gy1), B[0])
for x in range(gx0 + 3, gx1 - 1, 5):
    bar = c.rect(x, gy0 + 1, x + 2, gy1 - 1)
    paint(bar, B[3])
    paint(bar & (ROWS == gy0 + 1), B[1])        # 上面压下来的影子
    paint(bar & (COLS == x), B[4])              # 受光的左边
paint(c.rect(gx0, gy0, gx0 + 1, gy1), B[1])     # 左内壁：背光
paint(c.rect(gx0 + 2, gy1, gx1, gy1), B[6])     # 下内壁：朝上，受光
# 格栅外框：上、左亮，下、右暗一点
paint(c.rect(gx0 - 1, gy0 - 1, gx1 + 1, gy0 - 1), B[2])
paint(c.rect(gx0 - 1, gy1 + 1, gx1 + 1, gy1 + 1), B[6])
for (x, y) in [(19, 71), (73, 71), (19, 93), (73, 93)]:
    c.put(x, y, B[8])
    c.put(x + 1, y + 1, B[2])
# 腰线：正面横着走，转到侧面往灭点收
paint(c.rect(BASE["x0"], 95, BASE["x1"], 95), B[2])

# ---------------------------------------------------------------- 弹簧脖子：插在底座顶面正中，比头往里
NECK_D = -HEAD["depth"] / 2
ncx, _ = P(46, 50, NECK_D)
_, n_top = P(46, HEAD["y1"] - 2, NECK_D)
_, n_bot = P(46, BASE["y0"], NECK_D)
core = c.rect(ncx - 9, n_top, ncx + 9, n_bot)
cylinder(core, [B[2], B[1], B[0]])
# 两圈宽的弹簧，比视线低，所以看得到每圈的上表面（前沿往下弯）
# 小人的脖子：窄、宽、窄、宽，宽的那圈约是头宽的 3/4
for cy in (n_top + 6, n_top + 12):
    ring = ellipse(ncx, cy, 14, 2) | (ellipse(ncx, cy + 1, 14, 2))
    cylinder(ring, [B[6], B[5], B[4], B[3], B[2]])
    paint(ring & ~ellipse(ncx, cy - 1, 14, 2), B[2])   # 下沿
    paint(ellipse(ncx, cy - 1, 10, 1) & ring & (ROWS <= cy - 1), B[7])  # 上表面受光

# 头在底座顶面和脖子上投一块影子（光从左上来，影子在右下）
shadow = poly([(46, 50), (86, 46), (86, 74), (74, 72), (62, 66), (46, 66)]) & c.mask
darker = {B[i]: B[max(i - 2, 0)] for i in range(len(B))}
for y, x in zip(*np.nonzero(shadow)):
    col = "#%02x%02x%02x" % tuple(c.a[y, x, :3])
    if col in darker:
        c.a[y, x, :3] = _rgb(darker[col])

# ---------------------------------------------------------------- 烟囱：插在头顶正中，头顶看不到，所以从前沿后面冒出来
ccx, _ = P(46, HEAD["y0"], NECK_D)
stack = c.rect(ccx - 7, 5, ccx + 7, HEAD["y0"] - 1)
cylinder(stack, [B[6], B[5], B[4], B[3], B[2]])
lip = c.rect(ccx - 9, 2, ccx + 9, 5)
cylinder(lip, [B[7], B[6], B[5], B[4], B[3]])
paint(lip & (ROWS == 2), B[8])
paint(lip & (ROWS == 5), B[2])
paint(c.rect(ccx - 7, 6, ccx + 7, 6) & stack, B[2])   # 帽檐下的影子
# 一道箍
paint(c.rect(ccx - 7, 10, ccx + 7, 10) & stack, B[2])
paint(c.rect(ccx - 7, 11, ccx + 7, 11) & stack & (COLS < ccx + 3), B[6])

# ---------------------------------------------------------------- 头：和视线一样高，看不到顶面
head = box(HEAD["x0"], HEAD["x1"], HEAD["y0"], HEAD["y1"], HEAD["depth"])
assert "top" not in head and "bottom" not in head
lit(head["right"], [B[3], B[2], B[1]])
lit(head["front"], [B[6], B[5], B[4], B[3]], bias=-0.1)
paint(edge(head["front"], "left"), B[7])
paint(edge(head["front"], "top"), B[8])
paint(edge(head["right"], "top"), B[4])

def rivets():
    for (x, y) in [(HEAD["x0"] + 1, HEAD["y0"] + 1), (HEAD["x1"] - 2, HEAD["y0"] + 1),
                   (HEAD["x0"] + 1, HEAD["y1"] - 2), (HEAD["x1"] - 2, HEAD["y1"] - 2)]:
        c.put(x, y, B[8])
        c.put(x + 1, y + 1, B[3])


def grille_mouth(x0, x1, ys):
    """喇叭格栅当嘴：几道横缝，比视线低，所以缝的下沿受光。"""
    for y in ys:
        paint(c.rect(x0, y, x1, y), B[1])
        paint(c.rect(x0, y + 1, x1, y + 1), B[6])


def gauge(cx, cy, r, tip):
    """圆表盘当眼睛：铜圈 + 往里凹的奶油色盘面 + 刻度 + 指针。tip = 指针尖相对圆心的 (dx, dy)。
    铜圈受光：左上亮、右下暗。盘面往里凹，镜头在右边，所以盘面左边露出一道圈的内壁（暗），上沿有圈投下的影子。"""
    rim = ellipse(cx, cy, r, r)
    lit(rim, [B[8], B[7], B[6], B[5], B[4], B[3]])
    dial = ellipse(cx, cy, r - 2, r - 2)
    lit(dial, [F[3], F[2], F[2], F[1]])
    paint(dial & ~ellipse(cx + 1, cy, r - 2, r - 2), B[3])              # 左内壁
    paint(dial & ~ellipse(cx, cy + 1, r - 2, r - 2) & (COLS >= cx - 2), F[0])  # 上沿的影子
    # 刻度：上半圈 4 道，让开指针那一格；最右边那道是红区（和情绪指针表一样，越往右越红）
    for i, ang in enumerate(np.radians([200, 235, 270, 345])):
        x = round(cx + np.cos(ang) * (r - 3))
        y = round(cy + np.sin(ang) * (r - 3))
        c.put(x, y, "#c8323c" if i == 3 else B[2])
    # 指针：深色，从圆心到针尖；圆心一颗铜钉
    c.line(cx, cy, cx + tip[0], cy + tip[1], B[0])
    paint(c.rect(cx, cy, cx + 1, cy + 1), B[1])
    c.put(cx, cy, B[5])
    # 玻璃反光：左上一小道斜线
    for k in range(3):
        c.put(cx - r + 4 + k, cy - 2 - k, F[3])


def face_plate():
    """奶油色脸板，四周一圈铜框。返回脸板 mask。"""
    fx0, fx1, fy0, fy1 = HEAD["x0"] + 4, HEAD["x1"] - 4, HEAD["y0"] + 4, HEAD["y1"] - 4
    face = c.rect(fx0, fy0, fx1, fy1)
    face &= ~(c.rect(fx0, fy0, fx0, fy0) | c.rect(fx1, fy0, fx1, fy0) | c.rect(fx0, fy1, fx0, fy1) | c.rect(fx1, fy1, fx1, fy1))
    paint(c.rect(fx0 - 1, fy0 - 1, fx1 + 1, fy1 + 1) & ~face, B[2])
    lit(face, [F[3], F[2], F[2], F[1], F[0]], bias=-0.05)
    return face


def face_1():
    """表盘眼：铜脸上两只圆表盘当眼睛，指针当眼珠，中间一根连杆（小人脸上 f.f / fff / f.f 那个形状），
    下面一排喇叭格栅当嘴。和游戏里的情绪指针表呼应。指针都朝右上 45°（斜线不出锯齿），像在看对话框里的字。"""
    rivets()
    # 连杆：一根横着的铜管，两头插进表圈
    bar = c.rect(42, EYE_Y - 1, 50, EYE_Y + 1)
    paint(bar, B[4])
    paint(bar & (ROWS == EYE_Y - 1), B[7])
    paint(bar & (ROWS == EYE_Y + 1), B[2])
    gauge(36, EYE_Y, 8, (4, -4))
    gauge(56, EYE_Y, 8, (4, -4))
    grille_mouth(41, 51, (39, 41))


def face_2():
    """暖光眼：铜脸上两个圆舷窗，深色玻璃里亮着马灯一样的暖光；嘴是格栅。"""
    rivets()
    for cx in (37, 55):
        rim = ellipse(cx, EYE_Y, 7, 7)
        lit(rim, [B[7], B[6], B[4], B[2]])
        glass = ellipse(cx, EYE_Y, 5, 5)
        paint(glass, V[1])
        paint(glass & ~ellipse(cx + 1, EYE_Y + 1, 5, 5), V[0])     # 左上内壁的影子
        glow = ellipse(cx, EYE_Y + 1, 2, 3)
        paint(glow, EYE[1])
        paint(glow & (ROWS >= EYE_Y + 3), EYE[0])
        c.put(cx - 1, EYE_Y - 1, EYE[2])
        c.put(cx - 3, EYE_Y - 3, V[3])
    grille_mouth(40, 52, (39, 41))


def face_3():
    """铁皮玩具：奶油色脸板上印着两只竖着的椭圆眼（大高光），方嘴里几颗牙。"""
    face_plate()
    rivets()
    for ex in (38, 54):
        eye = ellipse(ex, EYE_Y - 1, 3, 5)
        paint(eye, B[0])
        paint(c.rect(ex - 2, EYE_Y - 5, ex - 1, EYE_Y - 3), F[3])
        c.put(ex + 1, EYE_Y + 2, B[2])
    mouth = c.rect(40, 36, 52, 40)
    paint(mouth, B[1])
    paint(c.rect(40, 36, 52, 36), B[0])
    for x in range(42, 52, 3):
        paint(c.rect(x, 37, x + 1, 39), F[1])
    paint(c.rect(40, 41, 52, 41), F[3])


def face_4():
    """一条缝：上面一道奶油色的眉板（小人头上那道浅色），下面一条深色观察缝，缝里两颗暖光点；嘴是格栅。"""
    rivets()
    brow = c.rect(HEAD["x0"] + 3, HEAD["y0"] + 3, HEAD["x1"] - 4, EYE_Y - 5)
    lit(brow, [F[3], F[2], F[1]])
    paint(c.rect(HEAD["x0"] + 3, EYE_Y - 4, HEAD["x1"] - 4, EYE_Y - 4), B[2])
    slit = c.rect(HEAD["x0"] + 5, EYE_Y - 3, HEAD["x1"] - 6, EYE_Y + 4)
    paint(slit, V[1])
    paint(c.rect(HEAD["x0"] + 5, EYE_Y - 3, HEAD["x1"] - 6, EYE_Y - 2), V[0])
    paint(c.rect(HEAD["x0"] + 5, EYE_Y + 4, HEAD["x1"] - 6, EYE_Y + 4), B[6])
    for ex in (38, 54):
        dot = ellipse(ex, EYE_Y + 1, 2, 2)
        paint(dot, EYE[1])
        c.put(ex - 1, EYE_Y, EYE[2])
        paint(dot & (ROWS == EYE_Y + 3), EYE[0])
    grille_mouth(40, 52, (37, 39, 41))


FACES = {1: face_1, 2: face_2, 3: face_3, 4: face_4}
FACES[FACE]()

# 齿轮耳朵 → 发条钥匙：从头右侧面正中间插出来，往右伸
kx, ky = P(HEAD["x1"], EYE_Y + 1, NECK_D)
collar = ellipse(kx, ky, 1, 4) & head["right"]
paint(collar, B[0])
c.put(kx, ky - 3, B[3])
shaft = c.rect(kx + 1, ky - 1, kx + 12, ky + 1)
paint(shaft, B[4])
paint(shaft & (ROWS == ky - 1), B[6])
paint(shaft & (ROWS == ky + 1), B[2])
# 钥匙柄：上下两片叶子，像蝴蝶（小人右边那个 ⊐⊏）
bx = kx + 16
for cy, sign in ((ky - 6, -1), (ky + 6, 1)):
    leaf = ellipse(bx, cy, 4, 5) & ~ellipse(bx, cy, 1, 2)
    lit(leaf, [B[7], B[6], B[5], B[3]])
    paint(edge(leaf, "right") | edge(leaf, "bottom"), B[2])
hub = c.rect(bx - 3, ky - 2, bx + 3, ky + 2)
lit(hub, [B[6], B[5], B[3]])
paint(c.rect(bx - 4, ky - 1, bx - 4, ky + 1), B[5])

# ---------------------------------------------------------------- 输出
img = Image.fromarray(c.a, "RGBA")
if TRY:
    img.save(ROOT / f"草图/立绘/robot_face_{FACE}.png")
    sys.exit(0)
img.save(ROOT / "Art_Assets/yellow.png")
img.save(ROOT / "oscar-rush/art/chars/robot_portrait.png")

# 预览：游戏里的小人 / 立绘 / 红衣小人 / 红衣立绘，深底；第二行带透视辅助线
S = 4
red = Image.open(ROOT / "oscar-rush/art/chars/red_portrait.png").convert("RGBA")
spr_r = Image.open(ROOT / "oscar-rush/art/chars/robot_body.png").convert("RGBA").crop((0, 0, 16, 20))
spr_red = Image.open(ROOT / "oscar-rush/art/chars/red_body.png").convert("RGBA").crop((0, 0, 16, 20))
BG = (26, 26, 34, 255)


def tile(im, scale):
    t = Image.new("RGBA", im.size, BG)
    t.alpha_composite(im)
    return t.resize((im.width * scale, im.height * scale), Image.NEAREST)


pv = Image.new("RGBA", (16 * 19 * 2 + 96 * S * 2 + 50, 96 * S * 2 + 30), (255, 255, 255, 255))
x = 10
for im, sc in [(spr_r, 19), (img, S), (spr_red, 19), (red, S)]:
    pv.paste(tile(im, sc), (x, 10))
    x += im.width * sc + 10
guide = tile(img, S)
g = ImageDraw.Draw(guide)
vp = (view.vx * S, view.vy * S)
g.line([(0, vp[1]), (96 * S, vp[1])], fill=(80, 200, 255), width=1)
for (gx, gy) in [(HEAD["x1"], HEAD["y0"]), (HEAD["x1"], HEAD["y1"]), (BASE["x0"], BASE["y0"]), (BASE["x1"], BASE["y0"])]:
    g.line([(gx * S, gy * S), vp], fill=(255, 90, 90), width=1)
pv.paste(guide, (10 + 16 * 19 + 10, 96 * S + 20))
pv.save(ROOT / "草图/立绘/robot_preview.png")
print("colors", len({tuple(p) for p in c.a.reshape(-1, 4) if p[3]}))
