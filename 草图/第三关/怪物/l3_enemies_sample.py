"""第三关怪物样图：每种屏幕场景一种怪，长得像那个场景里的东西，红色指示灯眼睛保留（第一关的怪也都有），
这样和场景融在一起也一眼认得出来。游戏里怪会吃所在屏幕的显示方式（黑白 / 绿荧光 / 琥珀）和扫描线。

小怪直接用现成的三种打法换皮：
  飞（扑灯蛾的打法）、跳（弹簧跳蚤的打法）、冲（剃须刀的打法）。
这里先画 8 只小怪 + 2 只精英怪的第一帧给作者看风格，通过以后再画全套、加动画、写进游戏。

输出：样图_怪物.png（每只：左边原色放大 6 倍，右边放进它的屏幕里、按游戏里的样子上色，放大 3 倍）
跑法："~/Desktop/程序programs/AI Oscar/.venv/bin/python" l3_enemies_sample.py
"""
import json
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, "/Users/jiamulin/Desktop/程序programs/AI Oscar")
from oscarkit.canvas import Canvas  # noqa: E402
from oscarkit.shade import top_light, step_color  # noqa: E402

HERE = Path(__file__).parent
L3 = HERE.parent
R = (226, 72, 64)                      # 红色指示灯
random.seed(5)


def sprite(rows, pal):
    return Canvas.from_rows(rows, {**pal, "R": R})


# ---------------------------------------------------------------- 小怪（ASCII 手点，一个字母一档颜色）
SMALL = {}

SMALL["toaster"] = ("kitchen", "跳", "吐司机：蹲下时两片吐司先弹出来，然后整台跳过来", sprite([
    "...TTt..TTt...",
    "...Ttt..Ttt...",
    "..3333333333..",
    ".233333333332.",
    ".222222222221k",
    ".2R222222221kk",
    ".222222222221k",
    ".111111111110.",
    ".1.00000000.0.",
    "..0........0..",
], {"0": (70, 72, 84), "1": (120, 124, 136), "2": (170, 174, 184), "3": (214, 216, 222),
    "t": (196, 140, 84), "T": (230, 186, 120), "k": (60, 50, 50)}))

SMALL["book"] = ("study", "飞", "飞书：封皮当翅膀扇，扑向灯光，俯冲时整本合上撞过来", sprite([
    "1.............1",
    "21...........12",
    ".21P.......P12.",
    "..21PP...PP12..",
    "...21PPpPP12...",
    "....21pRp12....",
    ".....21012.....",
    "......000......",
], {"0": (96, 42, 44), "1": (150, 66, 60), "2": (190, 96, 80), "P": (236, 228, 206), "p": (196, 186, 166)}))

SMALL["crab"] = ("beach", "冲", "螃蟹：横着走，举钳子一亮就横冲过来夹一下", sprite([
    "22.............22",
    "232...........232",
    ".22..W.....W..22.",
    "..2..1.....1..2..",
    "..2223333333222..",
    ".22222222R222222.",
    ".111111111111111.",
    "..0.0.0...0.0.0..",
    ".0.0.0.....0.0.0.",
], {"0": (120, 50, 50), "1": (170, 70, 62), "2": (206, 96, 78), "3": (236, 134, 104), "W": (240, 236, 230)}))

SMALL["fish"] = ("aquarium", "飞", "小丑鱼：在水里游，追光，冲刺时尾巴一甩", sprite([
    "....332.......",
    "..2223322...12",
    ".2R2W2W22111.2",
    "22222W2W22211.",
    ".1111W1W111.12",
    "..1111110...01",
    "....000.......",
], {"0": (160, 76, 44), "1": (206, 110, 60), "2": (240, 150, 80), "3": (250, 196, 130), "W": (244, 240, 230)}))

SMALL["snowman"] = ("snow_yard", "跳", "小雪人：原地蹦，蹲下时围巾一甩，跳过来砸", sprite([
    "...22222...",
    "..2222222..",
    "..2k222R2..",
    "..22222oo..",
    "...11111...",
    "..rrrrrrr..",
    ".22222rr21.",
    "2222222r221",
    "22222222211",
    "12222222211",
    ".111111111.",
    "..0000000..",
], {"0": (150, 160, 190), "1": (190, 200, 222), "2": (236, 240, 248), "k": (40, 40, 50),
    "o": (240, 150, 80), "r": (206, 72, 64)}))

SMALL["ufo"] = ("space", "飞", "小飞碟：底下一圈灯转，追光，俯冲时打开光束", sprite([
    "......DDd......",
    ".....DDddd.....",
    "....dddddd.....",
    "..22222222222..",
    "222y222R222y222",
    ".1111111111111.",
    "...000000000...",
    "....y.....y....",
], {"0": (96, 96, 112), "1": (150, 150, 164), "2": (204, 204, 214), "d": (120, 176, 220),
    "D": (186, 222, 244), "y": (246, 214, 110)}))

SMALL["mushroom"] = ("forest", "跳", "蘑菇：伞盖一缩一弹地跳，落地撒一圈孢子", sprite([
    "...22222...",
    ".2222W2222.",
    "22W2222W222",
    "21111111112",
    ".000000000.",
    "...sssS....",
    "...sRsS....",
    "...sssS....",
    "..ssssSS...",
    "..S....S...",
], {"0": (130, 50, 50), "1": (180, 74, 66), "2": (222, 110, 92), "W": (240, 230, 220),
    "s": (222, 212, 192), "S": (180, 170, 150)}))


def ghost():
    """雪花幽灵：一块会飘的雪花，下摆是参差的，只有一只红眼。"""
    w, h = 12, 14
    c = Canvas(w, h)
    tones = [(110, 116, 134), (160, 166, 184), (210, 214, 228), (240, 242, 248)]
    rng = random.Random(3)
    for y in range(h):
        for x in range(w):
            top = (x - 5.5) ** 2 / 36 + (y - 5) ** 2 / 25 <= 1 and y <= 5
            body = 0 <= x < w and 5 <= y < h - 2
            hem = y >= h - 2 and (x + (y % 2)) % 3 != 0
            if top or body or hem:
                c.put(x, y, tones[min(3, rng.choice([0, 1, 1, 2, 2, 3]) + (1 if y < 4 else 0))])
    for x, y in [(3, 5), (3, 6), (8, 5)]:
        c.put(x, y, (40, 40, 56))
    c.put(8, 6, R)
    return c


SMALL["ghost"] = ("static", "飞", "雪花幽灵：一块会飘的雪花，平时半透明，被光照到才现形", ghost())


# ---------------------------------------------------------------- 精英怪（形状 + 从上往下的光）
def ramp(base, n=6, span=1.0):
    return [step_color(base, k) for k in np.linspace(-2.5 * span, 2.5 * span, n)]


def octopus():
    """港口的精英：戴老式铜潜水头盔的章鱼。头盔的圆窗里就是那只红眼，六条触手。"""
    W_, H_ = 54, 44
    c = Canvas(W_, H_)
    flesh = ramp((150, 96, 120), 6, 0.9)
    brass = ramp((196, 150, 86), 6, 0.9)
    yy, xx = np.mgrid[0:H_, 0:W_]
    tent = np.zeros((H_, W_), bool)
    for i, (x0, curl) in enumerate([(8, -1), (15, 1), (22, -1), (31, 1), (38, -1), (45, 1)]):
        for t in np.linspace(0, 1, 60):
            x = x0 + curl * 6 * np.sin(t * 3.2) + (x0 - 27) * 0.25 * t
            y = 22 + t * 20
            r = 2.6 * (1 - t) + 0.8
            tent |= (xx - x) ** 2 + (yy - y) ** 2 <= r * r
    top_light(c, tent, flesh, bands=0.9)
    for i, x0 in enumerate([8, 15, 22, 31, 38, 45]):                  # 吸盘
        for t in (0.35, 0.55, 0.75):
            c.put(int(x0 + (x0 - 27) * 0.25 * t), int(24 + t * 20), flesh[5])
    helm = (xx - 27) ** 2 / 15 ** 2 + (yy - 15) ** 2 / 13 ** 2 <= 1
    top_light(c, helm, brass, bands=1.0)
    collar = (np.abs(yy - 26) <= 2) & (np.abs(xx - 27) <= 14)
    c.fill_mask(collar, brass[1]); c.fill_mask(collar & (yy == 24), brass[3])
    for x in range(14, 41, 4):
        c.put(x, 26, brass[5])                                          # 铆钉
    port = (xx - 27) ** 2 + (yy - 14) ** 2 <= 36
    c.fill_mask(port, brass[0])
    glass = (xx - 27) ** 2 + (yy - 14) ** 2 <= 20
    c.fill_mask(glass, (60, 80, 96))
    c.fill_mask(glass & (xx < 26) & (yy < 13), (110, 140, 160))
    c.rect(26, 13, 28, 15, R)                                           # 眼睛 = 指示灯
    for gx, gy in [(15, 10), (39, 10), (27, 3)]:                         # 侧窗和顶上的阀
        c.fill_mask((xx - gx) ** 2 + (yy - gy) ** 2 <= 5, brass[1]); c.put(gx, gy, (90, 120, 140))
    c.line(40, 6, 46, 1, (90, 80, 70)); c.line(41, 6, 47, 1, (60, 54, 50))  # 管子
    return c


def typewriter():
    """书房的精英：长了腿的老打字机。纸卷在头顶，铅字杆像一排牙；打字的时候往前喷字母。"""
    W_, H_ = 56, 38
    c = Canvas(W_, H_)
    body = ramp((80, 84, 92), 6, 0.8)
    yy, xx = np.mgrid[0:H_, 0:W_]
    paper = (xx >= 16) & (xx <= 40) & (yy >= 0) & (yy <= 11)
    c.fill_mask(paper, (236, 230, 210))
    for y in range(3, 10, 2):
        c.line(19, y, 19 + random.randint(8, 18), y, (120, 110, 100))
    c.put(21, 9, R); c.put(22, 9, R)                                     # 纸上打出的红字……
    roller = (yy >= 10) & (yy <= 13) & (xx >= 6) & (xx <= 50)
    top_light(c, roller, body, bands=0.4)
    c.rect(4, 10, 6, 13, (200, 200, 206)); c.rect(50, 10, 53, 12, (200, 200, 206))   # 回车杆
    shell = c.poly([(6, 14), (50, 14), (54, 30), (2, 30)])
    top_light(c, shell, body, bands=1.0)
    for i in range(11):                                                  # 铅字杆，一排牙
        c.line(14 + i * 3, 14, 20 + i * 1.6, 19, body[5])
    for row, (y, x0, n) in enumerate([(21, 10, 12), (24, 8, 13), (27, 6, 14)]):
        for i in range(n):
            kx = x0 + i * 3 + row
            c.rect(kx, y, kx + 1, y + 1, (226, 220, 200)); c.put(kx + 1, y + 1, (170, 164, 150))
    c.rect(24, 18, 32, 19, (40, 40, 46))
    c.rect(27, 18, 29, 19, R)                                            # 指示灯
    for lx, d in [(8, -1), (18, 1), (38, -1), (48, 1)]:                  # 四条细腿
        c.line(lx, 31, lx + d * 3, 37, body[1]); c.line(lx + 1, 31, lx + 1 + d * 3, 37, body[0])
    return c


ELITES = {
    "octopus": ("harbor", "潜水头盔章鱼：从海里爬上栈桥，触手轮流砸地，头盔喷蒸汽", octopus()),
    "typewriter": ("study", "打字机：长腿的老打字机，往前喷一串字母子弹，回车时整台冲过来", typewriter()),
}

# ---------------------------------------------------------------- 预览：放进各自的屏幕里
LAYOUT = json.loads((L3 / "l3_layout.json").read_text())
SCREENS_IMG = np.array(Image.open(L3 / "l3_screens.png").convert("RGBA"))
MID_IMG = np.array(Image.open(L3 / "l3_mid.png").convert("RGBA"))
TINTS = {
    "color": None,
    "bw": [(34, 36, 44), (70, 72, 82), (112, 114, 124), (156, 158, 166), (204, 206, 210), (236, 236, 236)],
    "green": [(18, 36, 26), (32, 70, 46), (56, 116, 72), (96, 170, 104), (150, 220, 150), (206, 246, 196)],
    "amber": [(40, 22, 16), (86, 46, 22), (146, 84, 34), (204, 128, 54), (238, 178, 96), (252, 222, 160)],
}


def in_game(c, tint, y_world):
    """游戏里的样子：按屏幕的显示方式把亮度映射到色阶上（红灯不变），偶数行压暗一点（扫描线）。"""
    a = c.a.copy().astype(float)
    m = a[..., 3] > 0
    led = (a[..., 0] == R[0]) & (a[..., 1] == R[1]) & (a[..., 2] == R[2])
    ramp_ = TINTS[tint]
    if ramp_:
        Lm = (0.3 * a[..., 0] + 0.55 * a[..., 1] + 0.15 * a[..., 2]) / 255
        idx = np.clip((Lm * 1.15 * len(ramp_)).astype(int), 0, len(ramp_) - 1)
        pal = np.array(ramp_, float)
        a[..., :3] = np.where((m & ~led)[..., None], pal[idx], a[..., :3])
    rows = (np.arange(a.shape[0]) + y_world) % 2 == 0
    a[rows, :, :3] *= np.where(led[rows][..., None], 1.0, 0.93)
    return a.astype(np.uint8)


def scene_crop(name, sprite_c, place="floor"):
    s = next(s for s in LAYOUT["screens"] if s["name"] == name)
    x0, y0, x1, y1 = s["casing"]
    bg = MID_IMG[y0:y1 + 1, x0:x1 + 1].copy()
    scr = SCREENS_IMG[y0:y1 + 1, x0:x1 + 1]
    m = scr[..., 3] > 0
    bg[m] = scr[m]
    sh, sw = sprite_c.h, sprite_c.w
    sx0, sy0, sx1, _ = s["screen"]
    px = (sx0 + sx1) // 2 - sw // 2 - x0 + 10
    py = (s["floor"] - sh - y0) if place == "floor" else (s["floor"] - sh - 26 - y0)
    spr = in_game(sprite_c, s["tint"], py + y0)
    m2 = spr[..., 3] > 0
    bg[py:py + sh, px:px + sw][m2] = spr[m2]
    # 只截屏幕附近一块（240×135 = 游戏里放大 2 倍时一屏看到的大小），以怪为中心
    cx, cy = px + sw // 2, py + sh // 2
    ax = int(np.clip(cx - 120, 0, max(0, bg.shape[1] - 240)))
    ay = int(np.clip(cy - 80, 0, max(0, bg.shape[0] - 135)))
    return Image.fromarray(bg[ay:ay + 135, ax:ax + 240]), s["tint"]


FONT = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 22)
cells = []
for key, (scene, kind, desc, c) in SMALL.items():
    cells.append((key, scene, f"{kind} · {desc}", c, "air" if kind == "飞" else "floor"))
for key, (scene, desc, c) in ELITES.items():
    cells.append((key, scene, "精英 · " + desc, c, "floor"))

CW, CH = 1180, 470
sheet = Image.new("RGB", (CW * 2, CH * ((len(cells) + 1) // 2)), (24, 22, 30))
d = ImageDraw.Draw(sheet)
for i, (key, scene, desc, c, place) in enumerate(cells):
    ox, oy = (i % 2) * CW, (i // 2) * CH
    big = Image.fromarray(c.a).resize((c.w * 6, c.h * 6), Image.NEAREST)
    bg = Image.new("RGB", (360, 300), (44, 40, 54))
    bg.paste(big, ((360 - big.width) // 2, (300 - big.height) // 2), big)
    sheet.paste(bg, (ox + 20, oy + 60))
    crop, tint = scene_crop(scene, c, place)
    sheet.paste(crop.resize((720, 405), Image.NEAREST), (ox + 400, oy + 30))
    d.text((ox + 20, oy + 10), f"{key}（{scene} / {tint}）", fill=(236, 230, 210), font=FONT)
    d.text((ox + 20, oy + 440), desc, fill=(190, 186, 200), font=FONT)
    Image.fromarray(c.a).save(HERE / f"{key}.png")
sheet.save(HERE / "样图_怪物.png")
print("ok", len(cells))
