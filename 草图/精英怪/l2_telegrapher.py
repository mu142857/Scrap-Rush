"""第二关 E2 的精英怪：电报员（TELEGRAPHER）。"人加机器"：披袍的电报员推着一辆电报车。

    python3 l2_telegrapher.py      # 草图预览 telegrapher_preview.png（6 倍，带主角比例尺）
                                   # + 导出 oscar-rush/art/enemies/telegrapher.png

照 Oscar 的帽兜人形画（xiao-oscar：light_planes 一个光源、斜楔褶子、帽兜开口最暗、一个红点当眼睛、
下摆参差、身体前倾），和第二关的接线员、引座员一个画法（复用 小怪/l2_robed.py 的小工具）。
- 人：暗绿灰的长袍（交换局里的接线员是灰紫、引座员是黑，这个偏绿），尖帽兜往后耷拉，帽兜前沿伸出一片
  绿色赛璐珞遮光帽檐（老电报员的标志），帽檐底下一个红点当眼睛。身子往前探，两只手推着车把。
- 车：木头箱子、两只辐条轮，箱子上一只黄铜电报键（按键 + 杠杆），后头一卷纸带，纸带从箱子前沿垂下来；
  车头立着一根小电线杆，顶上一颗绿玻璃绝缘子（急电那招从这里甩线）。
全部朝左，地面是最后一行。动画靠整像素挪部件，不每帧重新上色。

帧（45×34）：
  0~3 推车走（轮子辐条转、下摆飘、身子一起一伏）
  4 拍电报前摇（手抬到电报键上方）     5 拍下去（按键压下、键头冒火星）
  6 急电前摇（手举过头顶抡一圈电线）   7 甩出去（手往前上方伸）
  8 推车撞前摇（身子后仰、车往回拉 2 格） 9 撞（身子前探、车往前推 4 格）
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "oscar-rush/art/enemies"
sys.path.insert(0, str(HERE.parent / "小怪"))
sys.path.insert(0, "/Users/jiamulin/Desktop/程序programs/AI Oscar")
from l2_robed import EYE, LIGHT, blank, face, feet, hem, line, mask, put  # noqa: E402
from oscarkit.canvas import rgba  # noqa: E402
from oscarkit.paint import breathe, light_planes, over, shift_rows  # noqa: E402
from oscarkit.palette import ramp  # noqa: E402
from oscarkit.shade import ragged_hem  # noqa: E402

W, H = 45, 34
G = H - 1                                                              # 地面那一行
ROBE = ramp((86, 98, 92), n=9, L_span=0.6, hue_shift=8)              # 暗绿灰长袍
WOOD = ramp((92, 68, 50), n=6, L_span=0.34, hue_shift=10)              # 车的木头
BRASS = [(96, 74, 46), (150, 116, 64), (196, 160, 98), (232, 204, 140)]
SHADE = [(46, 92, 62), (78, 138, 86)]                                  # 绿色遮光帽檐（暗、亮）
GLASS = [(46, 92, 62), (110, 160, 104)]                                # 绝缘子（和帽檐同一种绿）
TAPE = [WOOD[4], WOOD[5]]                                              # 纸带（木头色阶最亮的两档）
DARK = (18, 20, 20)
OPEN = [".##.",
        "####",
        "####",
        ".##."]
FACE_AT = (24, 9)                                                      # 帽兜开口左上角
EYE_PX = (FACE_AT[0] + 1, FACE_AT[1] + 1)                              # 红点（游戏里的 led_pixel）
CART_X = 3                                                             # 车箱左沿（推车撞时前后挪）


# ---------------------------------------------------------------- 人
def body():
    # 尖帽兜往后上方耷拉（照邪帽），帽兜前沿罩住脸，背往后拱，袍子往下张开拖地
    outline = [(23, 9), (25, 5), (29, 3), (34, 2), (38, 1), (37, 4), (38, 8), (39, 14), (41, 22), (43, G),
               (21, G), (22, 26), (23, 19), (22, 13)]
    m = mask(W, H, outline)
    m = ragged_hem(m, depth=2, seed=11)
    m[G, 23:41] = True
    img = light_planes(m, ROBE, light=LIGHT, contrast=0.65, ambient=0.55, top_dark=0.55, rim=1,
                       folds=[((28, 11), (25, 31), 4), ((33, 10), (32, 31), 4), ((38, 15), (40, 31), 2)])
    img = face(img, FACE_AT[0], FACE_AT[1], OPEN, DARK, ROBE[6], (1, 1))
    # 遮光帽檐：帽兜前沿伸出来的一片绿，上亮下暗，盖在开口上面
    for x in range(21, 28):
        put(img, x, 8, SHADE[1] if x < 26 else SHADE[0])
    for x in range(20, 25):
        put(img, x, 9, SHADE[0])
    return img


def arm(pose):
    """袖子。pose: push 推车把、raise 手抬到电报键上方、tap 拍下去、coil 举过头顶、throw 往前上方甩、
    pull 往回拉（撞前摇）、shove 往前推（撞）。返回 (图, 手的位置)。"""
    shapes = {
        "push": ([(27, 15), (31, 16), (24, 22), (19, 22), (20, 20)], (19, 21)),
        "raise": ([(27, 15), (31, 16), (22, 17), (15, 16), (15, 14), (22, 14)], (14, 15)),
        "tap": ([(27, 15), (31, 16), (22, 19), (15, 19), (15, 17), (22, 16)], (14, 18)),
        "coil": ([(29, 14), (32, 15), (33, 7), (31, 4), (29, 5), (28, 10)], (31, 3)),
        "throw": ([(27, 15), (30, 16), (21, 14), (15, 11), (16, 9), (22, 12)], (14, 10)),
        "pull": ([(28, 15), (32, 16), (27, 21), (22, 22), (23, 20)], (21, 21)),
        "shove": ([(26, 15), (30, 16), (21, 22), (16, 22), (17, 20)], (15, 21)),
    }
    pts, hand = shapes[pose]
    img = light_planes(mask(W, H, pts), ROBE, light=LIGHT, contrast=0.5, ambient=0.5, rim=2)
    put(img, *hand, ROBE[2])                                           # 袖口里露出来的手
    return img, hand


# ---------------------------------------------------------------- 车
def cart(phase=0, dx=0, key_down=False, spark=False):
    """电报车。phase：轮子辐条转到哪一格（0/1）；dx：整辆车左右挪；key_down：电报键压下去。"""
    img = blank(W, H)
    x0 = CART_X + dx
    # 车箱：上沿亮、左沿亮一档、右沿和底边暗（光从左上来），前脸一块黄铜铭牌
    for y in range(20, 27):
        for x in range(x0, x0 + 16):
            c = WOOD[3]
            if y == 20:
                c = WOOD[5]
            elif y == 26:
                c = WOOD[1]
            elif x == x0:
                c = WOOD[4]
            elif x == x0 + 15:
                c = WOOD[2]
            elif (x - x0) in (5, 10):
                c = WOOD[2]                                            # 木板缝
            put(img, x, y, c)
    for x in range(x0 + 6, x0 + 10):
        put(img, x, 23, BRASS[1] if x < x0 + 9 else BRASS[0])
    put(img, x0 + 6, 23, BRASS[2])
    # 车把：从车箱后上角伸到人手里
    line(img, x0 + 16, 21, x0 + 17, 21, WOOD[2])
    # 轮子：半径 3 的辐条轮，轮圈暗、辐条亮一档，轴心黄铜
    for cx in (x0 + 4, x0 + 12):
        cy = G - 3
        for y in range(cy - 3, cy + 4):
            for x in range(cx - 3, cx + 4):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if 2.4 < d <= 3.4:
                    put(img, x, y, WOOD[1] if y > cy else WOOD[2])
        spokes = [(0, -2), (0, 2), (-2, 0), (2, 0)] if phase == 0 else [(-1, -1), (1, 1), (-1, 1), (1, -1)]
        for sx, sy in spokes:
            put(img, cx + sx, cy + sy, WOOD[3])
        put(img, cx, cy, BRASS[1])
    # 电报键：黄铜底座、杠杆、键头（压下去时杠杆放平、键头低一格）
    for x in range(x0 + 4, x0 + 10):
        put(img, x, 19, BRASS[0])
    put(img, x0 + 8, 18, BRASS[1])                                     # 支点
    if key_down:
        line(img, x0 + 3, 18, x0 + 9, 18, BRASS[2])
        put(img, x0 + 3, 18, BRASS[3])
    else:
        line(img, x0 + 3, 16, x0 + 9, 17, BRASS[2])
        put(img, x0 + 3, 16, BRASS[3])
        put(img, x0 + 3, 17, BRASS[1])
    if spark:
        for p in [(x0 + 2, 17), (x0 + 1, 16), (x0 + 3, 15)]:
            put(img, *p, BRASS[3])
    # 纸带卷：后头一卷，纸带从卷上拉出来，搭过箱子前沿垂下去
    for p in [(x0 + 12, 18), (x0 + 13, 18), (x0 + 12, 19), (x0 + 13, 19)]:
        put(img, *p, TAPE[0])
    put(img, x0 + 12, 18, TAPE[1])
    for x in range(x0 + 1, x0 + 12):
        put(img, x, 20, TAPE[1] if x % 3 else TAPE[0])                 # 纸带上一个个小孔
    for y in range(21, 25):
        put(img, x0 - 1, y, TAPE[0] if y % 2 else TAPE[1])
    # 车头的小电线杆：一根木杆、一道横担、顶上一颗绿玻璃绝缘子
    for y in range(8, 20):
        put(img, x0 + 1, y, WOOD[3] if y > 9 else WOOD[4])
    line(img, x0 - 1, 10, x0 + 3, 10, WOOD[2])
    put(img, x0 + 1, 7, GLASS[0])
    put(img, x0 + 1, 6, GLASS[1])
    put(img, x0 - 1, 9, GLASS[0])
    put(img, x0 + 3, 9, GLASS[0])
    return img


def coil(img, hand):
    """举过头顶的一圈电线（急电前摇）。"""
    out = img.copy()
    hx, hy = hand
    for dx, dy in [(-2, -1), (-1, -2), (0, -2), (1, -2), (2, -1), (2, 0), (1, 1), (-1, 1), (-2, 0)]:
        put(out, hx + dx, hy + dy, BRASS[1] if dy < 0 else BRASS[0])
    return out


# ---------------------------------------------------------------- 帧
def frames():
    me = body()
    out = []
    for f in range(4):                                                 # 推车走
        b = breathe(me, 1 if f in (1, 2) else 0, at=0.4)
        b = hem(b, f)
        b = feet(b, f, (26, 34), ROBE[1], G)
        a, _ = arm("push")
        if f in (1, 2):
            a = np.concatenate([a[1:], np.zeros_like(a[:1])])
        out.append(over(over(cart(phase=f // 2 % 2 if f < 2 else (f + 1) % 2), b), a))
    lean_back = shift_rows(me, [1 if y < 20 else 0 for y in range(H)])
    lean_fwd = shift_rows(me, [-1 if y < 20 else 0 for y in range(H)])
    a, _ = arm("raise")
    out.append(over(over(cart(), feet(me, 0, (26, 34), ROBE[1], G)), a))
    a, _ = arm("tap")
    out.append(over(over(cart(key_down=True, spark=True), feet(lean_fwd, 1, (26, 34), ROBE[1], G)), a))
    a, hand = arm("coil")
    out.append(coil(over(over(cart(), feet(lean_back, 0, (26, 34), ROBE[1], G)), a), hand))
    a, _ = arm("throw")
    out.append(over(over(cart(), feet(lean_fwd, 1, (26, 34), ROBE[1], G)), a))
    a, _ = arm("pull")
    out.append(over(over(cart(dx=2), feet(lean_back, 0, (26, 34), ROBE[1], G)), a))
    a, _ = arm("shove")
    out.append(over(over(cart(dx=-3), feet(lean_fwd, 1, (26, 34), ROBE[1], G)), a))
    return out


def main():
    fr = frames()
    sheet = np.concatenate(fr, axis=1)
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(sheet).save(OUT / "telegrapher.png")
    # 预览：6 倍，每格下面写帧号，右边放主角比例尺
    S, BG, GAP = 6, (104, 102, 110), 6
    hero = None
    hp = ROOT / "oscar-rush/art/chars/red_body.png"
    if hp.exists():
        hero = np.asarray(Image.open(hp).convert("RGBA"))[:, :16]
    names = ["走1", "走2", "走3", "走4", "拍·前摇", "拍", "急电·前摇", "甩线", "撞·前摇", "撞"]
    cols = 5
    rows = (len(fr) + cols - 1) // cols
    cw, ch = W * S + GAP * 4, H * S + 40
    img = Image.new("RGB", (cw * cols + 140, ch * rows + 50), BG)
    d = ImageDraw.Draw(img)
    font = None
    for p in [ROOT / "oscar-rush/fonts/PixelFont.ttf", Path("/System/Library/Fonts/PingFang.ttc")]:
        try:
            font = ImageFont.truetype(str(p), 20)
            break
        except OSError:
            pass
    d.text((12, 10), "Scrap Rush · 第二关 E2 精英：电报员 TELEGRAPHER（6 倍）", fill=(235, 232, 228), font=font)
    for i, f in enumerate(fr):
        x, y = 12 + (i % cols) * cw, 46 + (i // cols) * ch
        im = Image.fromarray(f).resize((W * S, H * S), Image.NEAREST)
        img.paste(im, (x, y), im)
        d.text((x, y + H * S + 4), f"{i} {names[i]}", fill=(225, 222, 218), font=font)
    if hero is not None:
        im = Image.fromarray(hero).resize((hero.shape[1] * S, hero.shape[0] * S), Image.NEAREST)
        img.paste(im, (cw * cols + 20, 46 + H * S - im.size[1]), im)
    img.save(HERE / "telegrapher_preview.png")
    print("telegrapher", sheet.shape[1], "x", sheet.shape[0], "帧宽", W, "帧数", len(fr), "红灯", EYE_PX)


if __name__ == "__main__":
    main()
