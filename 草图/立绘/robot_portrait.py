"""铜色机器人立绘，96×96 透明底，和 red_portrait 同一个构图（头在上、胸口以下被画框切掉）。
照 Art_Assets/yellow.jpg 的设计重画：方盒子头、深色面罩里两只眼、侧面齿轮、胸口面板、黄铜色。
画法照小奥斯卡：光从左上来，每个面按离光远近切成几档（档与档之间是直线），不描黑边，一个色相。

跑："~/Desktop/程序programs/AI Oscar/.venv/bin/python" 草图/立绘/robot_portrait.py
出：Art_Assets/yellow.png、oscar-rush/art/chars/robot_portrait.png、草图/立绘/robot_preview.png
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path.home() / "Desktop/程序programs/AI Oscar"))
from oscarkit.canvas import Canvas  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
W = H = 96

# 黄铜：暗 → 亮 9 档（oscarkit.palette.ramp((176,128,72), 9, L_span=0.62, hue_shift=14)）
B = ["#4f290a", "#683c15", "#815123", "#996834", "#b08048", "#c6995f", "#dcb379", "#f0ce97", "#ffeab8"]
# 面罩：冷的深灰蓝，整张图最暗的地方，不用黑
V = ["#252837", "#34374b", "#45465c", "#575668"]
# 眼睛和灯：游戏里马灯的暖黄（Hud.WARM = 255,211,138）
EYE = ["#e0954a", "#ffd38a", "#fff0cf"]
# 胸口表盘的底色，跟游戏里小人的脸板同色（255,225,194）
DIAL = ["#d9b48e", "#ffe1c2"]

c = Canvas(W, H)
LIGHT = np.array([-0.62, -0.78])  # 光从左上来


def lit(mask, levels, light=LIGHT, bias=0.0):
    """按离光源远近把一个面切成几档。levels 从亮到暗；档的分界是垂直于光线的直线。"""
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return
    p = xs * light[0] + ys * light[1]  # 越大越靠近光
    lo, hi = p.min(), p.max()
    t = (hi - p) / max(hi - lo, 1e-6) + bias  # 0 = 最亮那端
    idx = np.clip((t * len(levels)).astype(int), 0, len(levels) - 1)
    for i, lv in enumerate(levels):
        sel = idx == i
        c.a[ys[sel], xs[sel]] = (*_rgb(lv), 255)


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def poly(pts):
    return c.poly(pts)


def edge(mask, side):
    """mask 在某一侧的边缘那一圈像素。side: 'top' / 'left' / 'bottom' / 'right'"""
    m = mask.copy()
    sh = {"top": (1, 0), "bottom": (-1, 0), "left": (0, 1), "right": (0, -1)}[side]
    inner = np.zeros_like(m)
    dy, dx = sh
    inner[max(dy, 0):H + min(dy, 0), max(dx, 0):W + min(dx, 0)] = m[max(-dy, 0):H + min(-dy, 0), max(-dx, 0):W + min(-dx, 0)]
    return m & ~inner


def paint(mask, col):
    c.a[mask] = (*_rgb(col), 255)


# ---------------------------------------------------------------- 举起来打招呼的右臂（在身体后面先画）
upper = poly([(73, 58), (80, 53), (89, 61), (82, 66)])
lit(upper, [B[4], B[3], B[2]])
fore = poly([(82, 61), (91, 61), (92, 36), (83, 36)])
lit(fore, [B[5], B[4], B[3]])
paint(edge(fore, "right"), B[2])
paint(edge(fore, "left"), B[6])
elbow = c.ellipse(86, 61, 4, 4)
lit(elbow, [B[5], B[4], B[2]])
cuff = c.rect(82, 34, 92, 38)
lit(cuff, [B[6], B[5], B[3]])
# 钳子手：和游戏里小人一样是 C 形的钳子
yy, xx = np.mgrid[0:H, 0:W]
ring = ((xx - 87) / 6.5) ** 2 + ((yy - 26) / 7.5) ** 2
claw = (ring <= 1.0) & (((xx - 87) / 3.2) ** 2 + ((yy - 26) / 4.2) ** 2 > 1.0)
claw &= ~((xx < 87) & (abs(yy - 25) <= 1))  # 朝头那边开口
lit(claw, [B[6], B[5], B[4], B[3]])
paint(edge(claw, "right") | edge(claw, "bottom"), B[2])
paint(c.rect(85, 32, 89, 34), B[2])

# ---------------------------------------------------------------- 身体
torso_top = poly([(21, 55), (71, 55), (77, 50), (27, 50)])
lit(torso_top, [B[6], B[5]])
torso_side = poly([(71, 55), (77, 50), (77, 95), (71, 95)])
lit(torso_side, [B[2], B[1], B[0]])
torso = c.rect(21, 55, 70, 95)
lit(torso, [B[5], B[4], B[3], B[2]], bias=-0.05)
paint(edge(torso, "left") & (np.arange(H)[:, None] < 80), B[6])
# 腰上一道接缝：深一档的缝，下面一行亮一档的棱
paint(c.rect(21, 87, 70, 87), B[2])
paint(c.rect(21, 88, 70, 88), B[5])
paint(c.rect(71, 87, 76, 87) & ~c.rect(0, 0, 70, 95), B[1])

# 左肩和垂下来的左臂
arm_l = poly([(12, 60), (21, 57), (21, 95), (12, 95)])
lit(arm_l, [B[5], B[4], B[3]])
paint(edge(arm_l, "right"), B[2])
shoulder = c.ellipse(19, 60, 6, 6)
lit(shoulder, [B[7], B[6], B[5], B[3]])

# 胸口面板：往里凹，所以上、左内边暗（阴影），下、右内边亮（受光）
panel = c.rect(31, 62, 61, 81)
paint(panel, B[3])
paint(c.rect(31, 62, 61, 62), B[1])
paint(c.rect(31, 62, 31, 81), B[2])
paint(c.rect(31, 81, 61, 81), B[6])
paint(c.rect(61, 62, 61, 81), B[5])
# 表盘：半圆，奶油色底，几道刻度，一根指针（游戏里的情绪指针表）
dial = c.ellipse(43, 76, 9, 9) & (np.arange(H)[:, None] <= 76)
paint(dial, DIAL[1])
paint(dial & ~c.ellipse(43, 76, 8, 8), DIAL[0])
for (x, y) in [(36, 74), (37, 71), (40, 69), (43, 68), (46, 69), (49, 71), (50, 74)]:
    c.put(x, y, B[2])
c.put(49, 71, "#c8323c")
c.put(50, 74, "#c8323c")
c.line(43, 76, 47, 70, V[1])
paint(c.rect(34, 77, 52, 78), B[2])
paint(c.ellipse(43, 76, 1, 1), B[1])
# 两颗小按钮
for y in (67, 74):
    paint(c.ellipse(56, y, 2, 2), B[6])
    c.put(55, y - 1, B[8])
    c.put(57, y + 1, B[4])
c.put(56, 74, EYE[1])

# 铆钉
for (x, y) in [(24, 58), (67, 58), (24, 84), (67, 84), (24, 91), (67, 91)]:
    c.put(x, y, B[8])
    c.put(x + 1, y + 1, B[3])

# 头挡住左上来的光，在肩上和胸口上沿投一块影子（斜边顺着光）
shadow = poly([(40, 50), (78, 50), (78, 66), (70, 66), (63, 60), (44, 60)]) & c.mask
dark1 = {B[i]: B[max(i - 2, 0)] for i in range(len(B))}
ys, xs = np.nonzero(shadow)
for y, x in zip(ys, xs):
    col = "#%02x%02x%02x" % tuple(c.a[y, x, :3])
    if col in dark1:
        c.a[y, x, :3] = _rgb(dark1[col])

# ---------------------------------------------------------------- 脖子：一圈一圈的弹簧
neck = c.rect(39, 45, 53, 52)
paint(neck, B[2])
for y in (47, 50):
    paint(c.rect(39, y, 53, y), B[4])
    c.put(39, y, B[5])
paint(edge(neck, "right"), B[1])

# ---------------------------------------------------------------- 头
head_top = poly([(25, 12), (63, 12), (70, 6), (32, 6)])
lit(head_top, [B[7], B[6]])
head_side = poly([(63, 12), (70, 6), (70, 40), (63, 46)])
lit(head_side, [B[3], B[2], B[1]])
head = c.rect(25, 12, 62, 46)
lit(head, [B[6], B[5], B[4], B[3]], bias=-0.08)
paint(edge(head, "left"), B[6])
paint(edge(head, "bottom"), B[3])
paint(c.rect(25, 12, 62, 12), B[7])

# 侧面的齿轮耳朵：侧面是斜着看的，所以齿轮压扁
gear = c.ellipse(66, 25, 3, 7)
paint(gear, B[0])
for (x, y) in [(66, 17), (66, 33), (68, 19), (68, 31), (64, 19), (64, 31), (69, 25), (63, 25)]:
    paint(c.rect(x, y, x, y + 1) if x in (63, 69) else c.rect(x, y, x, y), B[0])
paint(c.ellipse(66, 25, 2, 5), B[3])
paint(c.ellipse(66, 25, 2, 5) & (np.arange(H)[:, None] < 23), B[5])
paint(c.ellipse(66, 25, 0, 1), B[1])
c.put(66, 25, B[6])

# 天线和顶上的小灯
paint(c.rect(46, 3, 47, 7), B[2])
c.put(46, 5, B[4])
paint(c.rect(44, 7, 49, 8), B[4])
paint(c.rect(44, 7, 49, 7), B[6])
bulb = c.ellipse(46, 2, 2, 2) | c.ellipse(47, 2, 2, 2)
paint(bulb, EYE[1])
paint(bulb & (np.arange(H)[:, None] >= 4), EYE[0])
c.put(45, 1, EYE[2])

# 面罩：圆角的深色玻璃
vis = c.rect(29, 18, 58, 37) & ~(c.rect(29, 18, 29, 18) | c.rect(58, 18, 58, 18) | c.rect(29, 37, 29, 37) | c.rect(58, 37, 58, 37))
paint(vis, V[1])
paint(edge(vis, "top") | edge(vis, "left"), V[0])
paint(edge(vis, "bottom") & ~edge(vis, "left"), V[2])
# 面罩框：外沿上、左亮一档（受光），下、右暗一档
frame = (c.rect(28, 17, 59, 38) & ~c.rect(29, 18, 58, 37))
frame &= ~(c.rect(28, 17, 28, 17) | c.rect(59, 17, 59, 17) | c.rect(28, 38, 28, 38) | c.rect(59, 38, 59, 38))
paint(frame, B[4])
paint(frame & (c.rect(28, 17, 59, 17) | c.rect(28, 17, 28, 38)), B[3])
paint(frame & (c.rect(28, 38, 59, 38) | c.rect(59, 17, 59, 38)), B[7])

# 眼睛：两只竖着的圆角方块，发马灯一样的暖黄光；左上一小块高光
for x0 in (34, 47):
    eye = np.zeros((H, W), bool)
    eye[22:32, x0:x0 + 7] = Canvas.from_rows([
        "..###..",
        ".#####.",
        "#######",
        "#######",
        "#######",
        "#######",
        "#######",
        "#######",
        ".#####.",
        "..###..",
    ], {"#": EYE[1]}).mask
    paint(eye, EYE[1])
    paint(edge(eye, "bottom") | (edge(eye, "right") & (np.arange(H)[:, None] > 26)), EYE[0])
    paint(c.rect(x0 + 1, 23, x0 + 2, 25), EYE[2])
    # 脸红：眼睛底下两道暗暖色的短线
    paint(c.rect(x0 + 1, 34, x0 + 2, 34) | c.rect(x0 + 4, 34, x0 + 5, 34), "#7a4e4a")
# 眼睛在玻璃上的一点反光
# 玻璃上的斜反光（两道，平行）
c.line(31, 35, 35, 19, V[3])
c.line(52, 35, 56, 19, V[2])

# 嘴：喇叭的三道格栅
for y in (40, 42):
    paint(c.rect(39, y, 49, y), B[3])
    paint(c.rect(39, y + 1, 49, y + 1), B[7])

# 头前脸四角的铆钉
for (x, y) in [(27, 14), (60, 14), (27, 43), (60, 43)]:
    c.put(x, y, B[8])
    c.put(x + 1, y + 1, B[4])

out = c.a
from PIL import Image  # noqa: E402

img = Image.fromarray(out, "RGBA")
img.save(ROOT / "Art_Assets/yellow.png")
img.save(ROOT / "oscar-rush/art/chars/robot_portrait.png")

# 预览：原图 / 新图 / 和红衣并排，深底和暖底各一张
S = 4
red = Image.open(ROOT / "oscar-rush/art/chars/red_portrait.png").convert("RGBA")
old = Image.open(ROOT / "Art_Assets/yellow.jpg").convert("RGBA").resize((96, 96), Image.NEAREST)
pv = Image.new("RGBA", (96 * S * 3 + 40, 96 * S * 2 + 30), (255, 255, 255, 255))
for row, bg in enumerate([(26, 26, 34, 255), (226, 186, 128, 255)]):
    for col, im in enumerate([old, img, red]):
        tile = Image.new("RGBA", (96, 96), bg)
        tile.alpha_composite(im)
        pv.paste(tile.resize((96 * S, 96 * S), Image.NEAREST), (10 + col * (96 * S + 10), 10 + row * (96 * S + 10)))
pv.save(ROOT / "草图/立绘/robot_preview.png")
print("colors", len({tuple(p) for p in out.reshape(-1, 4) if p[3]}))
