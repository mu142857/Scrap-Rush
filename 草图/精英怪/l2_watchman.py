"""第二关 E2 的精英怪：守夜巨人（WATCHMAN）。活的、砸地的大块头（作者 10-17："加一些不是机器的、有生命的，
还没有那种砸地的大块头精英"）。

    python3 l2_watchman.py      # 草图预览 watchman_preview.png（4 倍，带主角比例尺）+ 导出 oscar-rush/art/enemies/watchman.png
                                # 并打印每帧红眼的位置（游戏脚本里的 led_by_frame）

交换局里驼背的守夜人：身形巨大，披着厚重的毛皮长袍，背上驮着一大捆电话线圈，两只拖到地上的大拳头裹着破布，
帽兜压得很低，最暗的帽兜里一个红点当眼睛（和第二关的接线员、引座员一样）。
照 Oscar 的帽兜人形画（light_planes 一个光源、斜楔褶子、帽兜开口最暗、下摆参差、身子前倾），只上一次色，
动作靠整像素挪部件。朝左，地面是最后一行。

帧（89×70，身子中线在第 44 列）：
  0 站着（吸气）  1 站着（呼气，背塌下来一格）  2、3 走（两只脚、两只拳头轮流往前）
  4 双拳举过头顶（砸地前摇）  5 砸地（整个人往前趴，双拳砸在身前地上；跳砸落地也用这帧）
  6 蹲（跳砸前摇）  7 空中（双拳举在前上方）  8 扫臂前摇（前臂抡到身后）  9 扫臂（胳膊横着甩到身前）
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
from l2_robed import EYE, LIGHT, blank, face, mask, put  # noqa: E402
from oscarkit.canvas import rgba  # noqa: E402
from oscarkit.paint import light_planes, over, shift_rows  # noqa: E402
from oscarkit.palette import ramp  # noqa: E402
from oscarkit.shade import ragged_hem  # noqa: E402

W, H = 89, 70
G = H - 1
FUR = ramp((96, 84, 76), n=9, L_span=0.64, hue_shift=8)               # 暗暖灰的毛皮长袍
COPPER = [(70, 44, 30), (112, 70, 42), (156, 100, 58), (196, 138, 84)]  # 背上的电话线圈
DARK = (16, 13, 13)
OPEN = ["..##..",
        ".####.",
        "######",
        ".####.",
        "..##.."]
FACE_AT = (18, 25)


def disk(cx, cy, r):
    yy, xx = np.mgrid[0:H, 0:W]
    return (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r + 0.3


def poly(pts):
    return mask(W, H, pts)


# ---------------------------------------------------------------- 身子
def body():
    # 驼背：肩背是一个大鼓包（最高点在背上），袍子往下收一点，底下露出两条粗腿
    outline = [(30, 20), (36, 11), (46, 6), (56, 7), (63, 13), (67, 24), (68, 38), (66, 52), (65, 64), (31, 64),
               (30, 52), (31, 38), (29, 28)]
    m = poly(outline)
    m = ragged_hem(m, depth=3, seed=21)
    # 毛皮：肩背上一圈参差的毛边（往上戳出来的几撮）
    for x, y in [(36, 11), (41, 8), (47, 6), (53, 6), (59, 9), (64, 14), (67, 21)]:
        m[y - 1, x] = True
        m[y - 1, x + 1] = True
        m[y - 2, x] = True
    img = light_planes(m, FUR, light=LIGHT, contrast=0.7, ambient=0.5, rim=1,
                       folds=[((40, 26), (36, 62), 5), ((50, 20), (48, 62), 6), ((60, 24), (62, 62), 4)])
    # 两条粗腿：袍子底下露出来，最暗
    legs = poly([(34, 62), (40, 62), (41, G), (32, G)]) | poly([(53, 62), (59, 62), (61, G), (52, G)])
    img = over(light_planes(legs, FUR, light=LIGHT, contrast=0.4, ambient=0.25), img)
    # 帽兜：比背低、往前耷拉，帽尖往后上方翘；单独上色，压暗（帽兜里吃光）
    hood = poly([(16, 26), (19, 20), (26, 16), (34, 13), (38, 15), (36, 22), (34, 32), (28, 38), (20, 37), (16, 32)])
    img = over(img, light_planes(hood, FUR, light=LIGHT, contrast=0.6, ambient=0.42, top_dark=0.4, rim=1,
                                 folds=[((30, 16), (24, 36), 3)]))
    img = face(img, FACE_AT[0], FACE_AT[1], OPEN, DARK, FUR[5], (2, 2))
    return img


def coils(img, dy=0):
    """背上驮着的一大捆电话线圈：三个叠在一起的线圈（亮的外圈 + 暗的里圈），一根线头垂下来。"""
    out = img.copy()
    for cx, cy, rx, ry in [(50, 13, 9, 6), (58, 17, 7, 5), (44, 16, 6, 4)]:
        for y in range(cy - ry - 1, cy + ry + 2):
            for x in range(cx - rx - 1, cx + rx + 2):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if 0.55 <= d <= 1.05:
                    c = COPPER[2] if y < cy else COPPER[1]
                    if y == cy - ry:
                        c = COPPER[3]
                    put(out, x, y + dy, c)
                elif d < 0.55:
                    put(out, x, y + dy, COPPER[0])
    for i, (x, y) in enumerate([(64, 20), (65, 22), (66, 24), (66, 26), (65, 28), (66, 30)]):
        put(out, x, y + dy, COPPER[1] if i % 2 else COPPER[2])
    return out


def arm(shoulder, fist, r=6, width=5):
    """一条胳膊（粗袖子）+ 一只裹着破布的大拳头。返回 mask。"""
    sx, sy = shoulder
    fx, fy = fist
    v = np.array([fx - sx, fy - sy], float)
    n = np.array([-v[1], v[0]]) / (np.hypot(*v) or 1.0)
    w0, w1 = width * 0.75, width * 1.25                                    # 前臂越往拳头越粗
    pts = [(sx + n[0] * w0, sy + n[1] * w0), (fx + n[0] * w1, fy + n[1] * w1),
           (fx - n[0] * w1, fy - n[1] * w1), (sx - n[0] * w0, sy - n[1] * w0)]
    return poly([tuple(map(round, p)) for p in pts]) | disk(fx, fy, r)


def paint_arm(m, knuckles, far=False):
    img = light_planes(m, FUR, light=LIGHT, contrast=0.55, ambient=0.34 if far else 0.68, rim=1)
    for x, y in knuckles:                                              # 指节：破布底下鼓起来的一排亮点
        put(img, x, y, FUR[6] if not far else FUR[4])
    return img


ARMS = {
    # 名字: (近处那条 (肩, 拳, 指节), 远处那条 (肩, 拳, 指节))
    "rest": (((36, 30), (24, 59), [(18, 55), (19, 54), (21, 53), (23, 52)]), ((52, 30), (46, 61), [(42, 58), (43, 57)])),
    "stepL": (((36, 30), (20, 58), [(14, 54), (15, 53), (17, 52), (19, 51)]), ((52, 30), (50, 61), [(46, 58), (47, 57)])),
    "stepR": (((36, 30), (28, 60), [(22, 56), (23, 55), (25, 54), (27, 53)]), ((52, 30), (42, 60), [(38, 57), (39, 56)])),
    "raise": (((38, 24), (26, 6), [(20, 3), (21, 2), (23, 1)]), ((50, 22), (40, 5), [(36, 2), (37, 1)])),
    "slam": (((34, 34), (14, 61), [(8, 57), (9, 56), (11, 55), (13, 54)]), ((48, 34), (28, 62), [(24, 59), (25, 58)])),
    "crouch": (((38, 36), (30, 61), [(24, 57), (25, 56), (27, 55)]), ((54, 36), (56, 62), [(52, 59), (53, 58)])),
    "air": (((38, 26), (22, 8), [(16, 5), (17, 4), (19, 3)]), ((50, 24), (36, 6), [(32, 3), (33, 2)])),
    "sweep_back": (((38, 30), (64, 40), [(66, 36), (67, 37), (68, 38)]), ((52, 30), (48, 61), [(44, 58), (45, 57)])),
    "sweep": (((34, 32), (7, 48), [(1, 44), (2, 43), (4, 42), (6, 41)]), ((52, 30), (48, 61), [(44, 58), (45, 57)])),
}


def feet(img, f):
    """袍子底下露出的两只大脚：f=0 都在、1 左脚往前、2 右脚往前。"""
    out = img.copy()
    spots = {0: [(31, 41), (51, 61)], 1: [(28, 38), (52, 62)], 2: [(33, 43), (49, 59)]}[f]
    for a, b in spots:
        for x in range(a, b + 1):
            put(out, x, G, FUR[1])
        put(out, a, G - 1, FUR[2])
    return out


def bend(img, dx, dy, cut=44):
    """上半身（cut 行以上）往前挪 dx、往下压 dy（砸地、蹲），下半身不动。"""
    top = np.zeros_like(img)
    top[:cut] = img[:cut]
    bottom = img.copy()
    bottom[:cut] = 0
    moved = np.zeros_like(img)
    ys, xs = np.nonzero(top[..., 3])
    for y, x in zip(ys, xs):
        ny, nx = y + dy, x + dx
        if 0 <= ny < H and 0 <= nx < W:
            moved[ny, nx] = top[y, x]
    return over(bottom, moved)


def pose(name, me, f=0):
    (near, far) = ARMS[name]
    a_far = paint_arm(arm(far[0], far[1], r=6, width=4), far[2], far=True)
    a_near = paint_arm(arm(near[0], near[1], r=8, width=5), near[2])
    return over(over(a_far, feet(me, f)), a_near) if name != "sweep_back" else over(over(feet(me, f), a_far), a_near)


def frames():
    me = coils(body())
    breathe_out = bend(me, 0, 1, cut=40)                                # 呼气：背塌下来一格
    out = [pose("rest", me), pose("rest", breathe_out), pose("stepL", me, 1), pose("stepR", me, 2)]
    out.append(pose("raise", shift_rows(me, [1 if y < 40 else 0 for y in range(H)])))   # 往后仰一格
    slam_body = bend(shift_rows(me, [-round(7 * (62 - y) / 62) if y < 62 else 0 for y in range(H)]), 0, 5, cut=58)
    out.append(pose("slam", slam_body))
    out.append(pose("crouch", bend(me, 0, 6, cut=56)))
    out.append(pose("air", me))
    out.append(pose("sweep_back", shift_rows(me, [1 if y < 44 else 0 for y in range(H)])))
    out.append(pose("sweep", shift_rows(me, [-2 if y < 44 else 0 for y in range(H)])))
    return out


def eye_of(f):
    m = np.all(f[..., :3] == np.array(EYE), -1) & (f[..., 3] > 0)
    ys, xs = np.nonzero(m)
    return (int(xs[0]), int(ys[0])) if len(xs) else None


def main():
    fr = frames()
    sheet = np.concatenate(fr, axis=1)
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(sheet).save(OUT / "watchman.png")
    S, BG, GAP = 4, (104, 102, 110), 6
    names = ["站·吸", "站·呼", "走1", "走2", "举拳", "砸地", "蹲", "空中", "扫·前摇", "扫"]
    cols = 5
    rows = (len(fr) + cols - 1) // cols
    cw, ch = W * S + GAP * 3, H * S + 34
    img = Image.new("RGB", (cw * cols + 110, ch * rows + 50), BG)
    d = ImageDraw.Draw(img)
    font = None
    for p in [ROOT / "oscar-rush/fonts/PixelFont.ttf", Path("/System/Library/Fonts/PingFang.ttc")]:
        try:
            font = ImageFont.truetype(str(p), 20)
            break
        except OSError:
            pass
    d.text((12, 10), "Scrap Rush · 第二关 E2 精英：守夜巨人 WATCHMAN（4 倍；右边是主角比例尺）", fill=(235, 232, 228), font=font)
    for i, f in enumerate(fr):
        x, y = 12 + (i % cols) * cw, 46 + (i // cols) * ch
        im = Image.fromarray(f).resize((W * S, H * S), Image.NEAREST)
        img.paste(im, (x, y), im)
        d.text((x, y + H * S + 4), f"{i} {names[i]}", fill=(225, 222, 218), font=font)
    hp = ROOT / "oscar-rush/art/chars/red_body.png"
    if hp.exists():
        hero = np.asarray(Image.open(hp).convert("RGBA"))[:, :16]
        im = Image.fromarray(hero).resize((hero.shape[1] * S, hero.shape[0] * S), Image.NEAREST)
        img.paste(im, (cw * cols + 20, 46 + H * S - im.size[1]), im)
    img.save(HERE / "watchman_preview.png")
    leds = {i: eye_of(f) for i, f in enumerate(fr)}
    print("watchman", sheet.shape[1], "x", sheet.shape[0], "帧宽", W, "帧数", len(fr))
    print("led_by_frame", leds)


if __name__ == "__main__":
    main()
