"""第二关的三种披袍人形小怪（作者 10-17："第二关的怪物和第一关太像了，多加点披着袍子的人形怪"）。

    python3 l2_robed.py      # 草图预览 robed_preview.png（6 倍）+ 逐帧 robed_frames.png，
                             # 再导出 oscar-rush/art/enemies/hooded_operator.png、usher.png、audience.png

照 Oscar 的帽兜人形画（xiao-oscar skill：VVVVVVV、邪教 boss、邪帽）：
一个光源方向（左上），大块亮面 / 暗面，斜的楔形褶子加一道亮棱，帽兜开口是最暗的尖椭圆，里面一个红点当眼睛，
下摆参差，身体前倾。用 oscarkit.paint.light_planes 上色，只上一次色，动画靠整像素挪部件（breathe、下摆飘），
不每帧重新上色。三只都朝左，地面是最后一行。

- 接线员 hooded_operator：灰紫色长袍拖地、尖帽兜前面伸出一个话筒（老式接线员耳机），袖子里垂下一盘电话线，
  线头是插头。电话线甩出去的那一下是代码画的（hooded_operator.gd）。
  帧：0~3 走（下摆拖地飘、两只脚从下摆底下轮流露出来），4 抡起来（手举到脑后），5 甩出去（手往前伸直）。
- 引座员 usher：黑斗篷，圆帽兜上一顶小圆帽，斗篷下摆往外张，手里提一支手电。光束是代码画的（usher.gd）。
  帧：0~3 走，4 举手电瞄（手平伸），5 闪（手电亮、往后一挫）。
- 观众 audience：裹着胶片当袍子，胶片带一圈圈斜着缠，带子上一排齿孔。平时坐着（缩成一团），人一靠近就站起来扑过去。
  帧：0、1 坐着（喘气），2 站起来一半，3、4 站着走（摇摇晃晃），5 蹲下蓄力，6 扑（整个往前探，两只手伸出去）。
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "oscar-rush/art/enemies"
sys.path.insert(0, "/Users/jiamulin/Desktop/程序programs/AI Oscar")
from oscarkit.canvas import rgba  # noqa: E402
from oscarkit.paint import breathe, light_planes, over, shift_rows  # noqa: E402
from oscarkit.palette import ramp  # noqa: E402
from oscarkit.shade import ragged_hem  # noqa: E402

LIGHT = (-1.0, -0.8)                    # 左上来的光（和第一关一样，光从上面来）
EYE = (255, 71, 48)                     # 和机器怪的红灯同一个红


def mask(W, H, pts):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(pts, fill=1)
    return np.asarray(m).astype(bool)


def blank(W, H):
    return np.zeros((H, W, 4), np.uint8)


def put(img, x, y, col):
    if 0 <= y < img.shape[0] and 0 <= x < img.shape[1]:
        img[y, x] = rgba(col)


def line(img, x0, y0, x1, y1, col):
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        put(img, x0, y0, col)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def face(img, x0, y0, rows, dark, rim_col, eye_at):
    """帽兜开口：最暗的尖椭圆，开口上沿亮一档（帽檐接到光），里面一个红点。"""
    out = img.copy()
    for dy, r in enumerate(rows):
        for dx, ch in enumerate(r):
            if ch == "#":
                out[y0 + dy, x0 + dx] = rgba(dark)
    for dx, ch in enumerate(rows[0]):
        if ch == "#" and out[y0 - 1, x0 + dx, 3]:
            out[y0 - 1, x0 + dx] = rgba(rim_col)
    out[y0 + eye_at[1], x0 + eye_at[0]] = rgba(EYE)
    return out


def hem(img, f, rows=4):
    """下摆最底下几行左右挪一格，脚不动（走路时袍子飘）。"""
    H = img.shape[0]
    ys = np.nonzero((img[..., 3] > 0).any(1))[0]
    y1 = ys.max()
    offs = [0] * H
    # 整条下摆一起挪（一行一行错开挪会碎出单个像素）
    for k in range(rows - 1):
        offs[y1 - k] = [0, 1, 0, -1][f % 4]
    return shift_rows(img, offs)


def feet(img, f, xs, col, ground):
    """两只脚从下摆底下轮流露出来：f 偶数左脚、奇数右脚往前一格。"""
    out = img.copy()
    a, b = xs
    if f % 2 == 0:
        put(out, a - 1, ground, col)
        put(out, a, ground, col)
    else:
        put(out, b - 1, ground, col)
        put(out, b, ground, col)
    return out


def pad(img, n=2):
    """顶上补 n 行空白（breathe 要往上挪，帽尖不能顶着画布边）。"""
    return np.concatenate([np.zeros((n,) + img.shape[1:], img.dtype), img])


def lift(img, n):
    """整张往上挪 n 行（落地帧以外的整体起伏）。"""
    if n <= 0:
        return img
    out = np.zeros_like(img)
    out[:-n] = img[n:]
    return out


# ================================================================ 接线员
OP_W, OP_H = 22, 26
OP_R = ramp((132, 120, 136), n=9, L_span=0.6, hue_shift=8)            # 灰紫长袍
OP_A = [(96, 74, 46), (150, 116, 64), (196, 160, 98)]                   # 黄铜：话筒、插头
OP_DARK = (20, 17, 22)
OP_OPEN = [".##.",
           "####",
           "####",
           ".##."]


def op_body():
    W, H = OP_W, OP_H
    # 尖帽兜往前耷拉，背往后拱，袍子往下变宽，拖到地上
    # 尖帽兜的尖往后上方翘（照邪帽），帽兜前沿罩住脸
    outline = [(8, 5), (10, 2), (13, 1), (17, 0), (16, 3), (17, 6), (18, 11), (19, 17), (21, 25), (4, 25), (5, 19),
               (6, 13), (7, 8)]
    m = mask(W, H, outline)
    m = ragged_hem(m, depth=2, seed=3)
    m[H - 1, 6:19] = True                                                # 拖地：最后一行大部分贴地
    img = light_planes(m, OP_R, light=LIGHT, contrast=0.65, ambient=0.55, top_dark=0.55, rim=1,
                       folds=[((11, 9), (8, 24), 4), ((15, 8), (14, 24), 4), ((18, 14), (19, 24), 2)])
    img = face(img, 8, 4, OP_OPEN, OP_DARK, OP_R[6], (1, 1))
    # 话筒：从帽兜里伸到嘴前面的一根弯管，头上一个小喇叭口
    for x, y, c in [(8, 8, OP_A[0]), (7, 9, OP_A[0]), (6, 9, OP_A[1]), (5, 10, OP_A[1]), (4, 10, OP_A[2]),
                    (3, 10, OP_A[2]), (3, 11, OP_A[1]), (4, 11, OP_A[1])]:
        put(img, x, y, c)
    return img


def op_arm(pose):
    """袖子 + 手里的电话线。pose: 0 垂着，1 抡到脑后，2 往前甩直。"""
    W, H = OP_W, OP_H
    img = blank(W, H)
    if pose == 0:
        m = mask(W, H, [(10, 11), (13, 12), (9, 17), (5, 17), (6, 15)])
        hand = (5, 17)
    elif pose == 1:
        m = mask(W, H, [(12, 11), (15, 11), (17, 5), (18, 3), (16, 3), (13, 8)])
        hand = (17, 2)
    else:
        m = mask(W, H, [(10, 11), (12, 13), (5, 14), (1, 14), (1, 12)])
        hand = (0, 13)
    img = over(img, light_planes(m, OP_R, light=LIGHT, contrast=0.5, ambient=0.5, rim=2))
    put(img, *hand, OP_R[2])                                             # 手（袖口里露出来的一点）
    if pose == 0:
        # 一盘电话线垂下来：锯齿一样一格左一格右，线头是黄铜插头
        x, y = hand
        for i in range(5):
            put(img, x - (i % 2), y + 1 + i, OP_R[4])
        put(img, x, y + 6, OP_A[1])
        put(img, x, y + 7, OP_A[2])
    return img


def operator_frames():
    body = pad(op_body())
    H = OP_H + 2
    frames = []
    for f in range(4):
        b = breathe(body, 1 if f in (1, 2) else 0, at=0.45)
        b = hem(b, f)
        b = feet(b, f, (7, 15), OP_R[1], H - 1)
        arm = pad(op_arm(0))
        if f in (1, 2):                                                  # 手臂跟着身子起伏
            arm = lift(arm, 1)
        frames.append(over(b, arm))
    # 抡：身子往后仰一格（上半身往右挪），手举到脑后
    back = shift_rows(body, [1 if y < 16 else 0 for y in range(H)])
    frames.append(over(feet(back, 0, (7, 15), OP_R[1], H - 1), pad(op_arm(1))))
    # 甩：身子往前探一格
    fwd = shift_rows(body, [-1 if y < 16 else 0 for y in range(H)])
    frames.append(over(feet(fwd, 1, (7, 15), OP_R[1], H - 1), pad(op_arm(2))))
    return frames


# ================================================================ 引座员
US_W, US_H = 22, 26
US_R = ramp((78, 70, 86), n=9, L_span=0.6, hue_shift=10)                # 黑斗篷（带一点紫）
US_A = [(120, 92, 48), (214, 170, 96), (255, 236, 196)]                 # 手电：黄铜筒、镜片
US_DARK = (12, 10, 14)
US_OPEN = [".##.",
           "####",
           "####",
           ".##."]


def us_body():
    W, H = US_W, US_H
    # 圆帽兜 + 顶上一顶小圆帽；斗篷从肩膀往下张开，下摆宽
    outline = [(9, 4), (10, 2), (13, 2), (15, 3), (16, 6), (16, 8), (18, 10), (19, 15), (21, 25), (2, 25), (4, 17),
               (6, 11), (8, 9), (8, 6)]
    m = mask(W, H, outline)
    m = ragged_hem(m, depth=2, seed=8)
    img = light_planes(m, US_R, light=LIGHT, contrast=0.85, ambient=0.5, top_dark=0.45,
                       folds=[((9, 11), (4, 24), 3), ((13, 10), (11, 24), 4), ((17, 12), (19, 24), 3)])
    img = face(img, 9, 4, US_OPEN, US_DARK, US_R[6], (1, 1))
    # 小圆帽：帽顶亮、帽檐暗
    for x in range(10, 15):
        put(img, x, 1, US_R[6])
        put(img, x, 2, US_R[4])
    for x in range(11, 14):
        put(img, x, 0, US_R[7])
    put(img, 9, 2, US_R[3])
    put(img, 15, 2, US_R[3])
    return img


def us_arm(pose):
    """从斗篷缝里伸出来的手和手电。pose: 0 垂着照地，1 平举瞄准，2 亮（往后挫一格）。"""
    W, H = US_W, US_H
    img = blank(W, H)
    if pose == 0:
        m = mask(W, H, [(9, 12), (11, 13), (7, 17), (5, 17), (6, 15)])
        img = over(img, light_planes(m, US_R, light=LIGHT, contrast=0.6, ambient=0.8))
        # 手电往下斜着：筒 3 格、镜片 1 格
        for x, y, c in [(5, 18, US_A[0]), (4, 18, US_A[0]), (3, 19, US_A[1]), (4, 19, US_A[0])]:
            put(img, x, y, c)
    else:
        dx = 1 if pose == 2 else 0
        m = mask(W, H, [(9 + dx, 11), (11 + dx, 13), (5 + dx, 14), (4 + dx, 12)])
        img = over(img, light_planes(m, US_R, light=LIGHT, contrast=0.6, ambient=0.8))
        for x in range(1 + dx, 4 + dx):
            put(img, x, 12, US_A[1] if x == 2 + dx else US_A[0])
            put(img, x, 13, US_A[0])
        put(img, dx, 12, US_A[2] if pose == 2 else US_A[1])
        put(img, dx, 13, US_A[2] if pose == 2 else US_A[1])
    return img


def usher_frames():
    body = pad(us_body())
    H = US_H + 2
    frames = []
    for f in range(4):
        b = breathe(body, 1 if f in (1, 2) else 0, at=0.45)
        b = hem(b, f, rows=5)
        b = feet(b, f, (6, 16), US_R[1], H - 1)
        arm = pad(us_arm(0))
        if f in (1, 2):
            arm = lift(arm, 1)
        frames.append(over(b, arm))
    frames.append(over(feet(body, 0, (6, 16), US_R[1], H - 1), pad(us_arm(1))))
    back = shift_rows(body, [1 if y < 18 else 0 for y in range(H)])
    frames.append(over(feet(back, 0, (6, 16), US_R[1], H - 1), pad(us_arm(2))))
    return frames


# ================================================================ 观众
AU_W, AU_H = 24, 24
AU_R = ramp((116, 88, 66), n=9, L_span=0.6, hue_shift=8)                # 胶片的琥珀褐
AU_DARK = (22, 14, 12)
AU_OPEN = [".#.",
           "###",
           "###",
           ".#."]


def film_bands(img, m, bands, phase=0):
    """胶片缠成的带子：沿着斜线一条深色缝，缝上方一排亮的齿孔（每隔一格一个）。"""
    out = img.copy()
    H, W = m.shape
    def inside(x, y):
        # 只画在身子里面（离轮廓至少一格），不然轮廓上一圈深色像描边
        return all(0 <= yy < H and 0 <= xx < W and m[yy, xx] for xx, yy in
                   [(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)])
    for (x0, y0, x1, y1) in bands:
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n)
            y = round(y0 + (y1 - y0) * i / n)
            # 一条胶片带：两行深色，上面那行每隔 3 格一个亮齿孔
            if inside(x, y):
                out[y, x] = rgba(AU_R[2])
            if inside(x, y - 1):
                out[y - 1, x] = rgba(AU_R[8] if (i + phase) % 3 == 1 else AU_R[3])
    return out


def au_seated():
    """坐着：缩成一团，头往前垂，膝盖顶在前面，背是一个圆拱。"""
    W, H = AU_W, AU_H
    outline = [(8, 12), (10, 10), (13, 10), (16, 12), (18, 15), (19, 19), (19, 23), (4, 23), (4, 19), (6, 17),
               (7, 15)]
    m = mask(W, H, outline)
    img = light_planes(m, AU_R, light=LIGHT, contrast=0.45, ambient=0.6, top_dark=0.3, rim=1)
    img = film_bands(img, m, [(7, 17, 19, 13), (4, 21, 19, 18)])
    img = face(img, 8, 12, AU_OPEN, AU_DARK, AU_R[6], (1, 1))
    # 膝盖：两团亮一点的凸起
    for x in (4, 5):
        put(img, x, 19, AU_R[5])
    return img


def au_standing(lean=0):
    """站着：瘦长的一卷，头上缠的胶片收成一个圆顶。lean 往前探（上半身往左挪）。"""
    W, H = AU_W, AU_H
    outline = [(10, 4), (12, 2), (14, 2), (16, 4), (16, 8), (17, 12), (18, 17), (18, 23), (7, 23), (8, 17), (8, 12),
               (9, 8)]
    m = mask(W, H, outline)
    m = ragged_hem(m, depth=2, seed=5)
    img = light_planes(m, AU_R, light=LIGHT, contrast=0.6, ambient=0.55, top_dark=0.4, rim=1)
    img = film_bands(img, m, [(8, 12, 17, 8), (8, 18, 18, 14)])
    img = face(img, 10, 4, AU_OPEN, AU_DARK, AU_R[6], (1, 1))
    if lean:
        img = shift_rows(img, [-round(lean * max(0, 14 - y) / 7) for y in range(H)])
    return img


def au_arms(kind, lean=0):
    W, H = AU_W, AU_H
    img = blank(W, H)
    if kind == "hang":                                                    # 垂着，散开的胶片头
        m = mask(W, H, [(9, 9), (11, 11), (8, 16), (7, 16)])
        img = over(img, light_planes(m, AU_R, light=LIGHT, contrast=0.5, ambient=0.75))
        put(img, 7, 17, AU_R[3])
        put(img, 6, 18, AU_R[2])
    else:                                                                 # 往前扑：两只手伸出去
        dx = -lean
        m = mask(W, H, [(9 + dx, 7), (11 + dx, 9), (3 + dx, 11), (2 + dx, 9)])
        img = over(img, light_planes(m, AU_R, light=LIGHT, contrast=0.5, ambient=0.8))
        m2 = mask(W, H, [(10 + dx, 10), (12 + dx, 12), (4 + dx, 14), (3 + dx, 12)])
        img = over(light_planes(m2, AU_R, light=LIGHT, contrast=0.5, ambient=0.55), img)
        put(img, 1 + dx, 9, AU_R[2])
        put(img, 2 + dx, 13, AU_R[2])
    return img


def audience_frames():
    seated = au_seated()
    frames = [seated, breathe(seated, 1, at=0.5)]
    # 站起来一半：身子拉长一截，头还垂着
    stand = au_standing()
    half = np.zeros_like(stand)
    half[5:] = stand[:-5]
    half = over(au_seated(), half)
    frames.append(half)
    for f in range(2):
        b = shift_rows(stand, [(1 if f else -1) if y < 10 else 0 for y in range(AU_H)])   # 摇摇晃晃
        b = hem(b, f * 2, rows=3)
        b = feet(b, f, (10, 16), AU_R[1], AU_H - 1)
        arms = au_arms("hang")
        if f:
            arms = shift_rows(arms, [1 if y < 10 else 0 for y in range(AU_H)])
        frames.append(over(b, arms))
    # 蹲下蓄力：上半身压低两行
    crouch = np.zeros_like(stand)
    crouch[2:] = stand[:-2]
    crouch = over(crouch, au_arms("hang"))
    frames.append(crouch)
    frames.append(over(au_standing(lean=3), au_arms("reach", lean=3)))
    return frames


# ================================================================ 导出、预览
def trim_all(frames):
    al = np.zeros(frames[0].shape[:2], bool)
    for f in frames:
        al |= f[..., 3] > 0
    ys, xs = np.nonzero(al)
    H = frames[0].shape[0]
    assert ys.max() == H - 1, "地面要是最后一行"
    x0, x1 = xs.min(), xs.max()
    if (x1 - x0 + 1) % 2:
        x1 = min(x1 + 1, frames[0].shape[1] - 1) if x1 + 1 < frames[0].shape[1] else x1
        if (x1 - x0 + 1) % 2:
            x0 -= 1
    return [f[ys.min():, x0:x1 + 1] for f in frames], (x0, ys.min())


def save_strip(name, frames):
    h, w = frames[0].shape[:2]
    out = np.zeros((h, w * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        out[:, i * w:(i + 1) * w] = f
    Image.fromarray(out).save(OUT / f"{name}.png")
    return w, h


MONSTERS = [("hooded_operator", "接线员", operator_frames, [(0, "走"), (4, "抡"), (5, "甩")]),
            ("usher", "引座员", usher_frames, [(0, "走"), (4, "瞄"), (5, "闪")]),
            ("audience", "观众", audience_frames, [(0, "坐着"), (3, "站起来走"), (6, "扑")])]


def main():
    font = None
    for p in [ROOT / "oscar-rush/fonts/PixelFont.ttf", Path("/System/Library/Fonts/PingFang.ttc")]:
        try:
            font = ImageFont.truetype(str(p), 22)
            break
        except OSError:
            pass
    hero = None
    hp = ROOT / "oscar-rush/art/chars/red_body.png"
    if hp.exists():
        hb = np.asarray(Image.open(hp).convert("RGBA"))[:, :16].copy()
        st = np.asarray(Image.open(hp.with_name("red_strip.png")).convert("RGBA"))[:, :16]
        mm = st[..., 3] > 0
        hb[mm] = st[mm]
        hero = hb
    S, BG = 6, (104, 102, 110)
    allf = {}
    for name, title, fn, show in MONSTERS:
        fr, origin = trim_all(fn())
        w, h = save_strip(name, fr)
        allf[name] = fr
        print(f"{name}.png: {len(fr)} 帧，每帧 {w}x{h}，裁掉的左上角 {origin}")
    # 草图预览：每只一行：走路第 0 帧 + 两个动作帧 + 主角比例尺
    rows = []
    for name, title, fn, show in MONSTERS:
        fr = allf[name]
        rows.append((title, [fr[i] for i, _ in show], [t for _, t in show]))
    cell_h = 30 * S + 50
    img = Image.new("RGB", (1100, 60 + cell_h * len(rows)), BG)
    d = ImageDraw.Draw(img)
    d.text((16, 12), "Scrap Rush · 第二关披袍人形小怪（照 Oscar 帽兜人形，6 倍；每行：走 / 两个动作 / 主角比例尺）",
           fill=(235, 232, 228), font=font)
    for i, (title, fr, labels) in enumerate(rows):
        y0 = 50 + i * cell_h
        d.text((16, y0), title, fill=(235, 232, 228), font=font)
        base_y = y0 + cell_h - 14
        x = 130
        for f, lab in zip(fr + ([hero] if hero is not None else []), labels + ["主角"]):
            im = Image.fromarray(f).resize((f.shape[1] * S, f.shape[0] * S), Image.NEAREST)
            img.paste(im, (x, base_y - im.size[1]), im)
            d.text((x, base_y + 2), lab, fill=(220, 218, 214), font=ImageFont.truetype(font.path, 16) if font else None)
            x += im.size[0] + 40
    img.save(HERE / "robed_preview.png")
    # 逐帧
    s2 = 6
    fw = max(f[0].shape[1] for f in allf.values())
    fh = max(f[0].shape[0] for f in allf.values())
    n = max(len(f) for f in allf.values())
    sheet = Image.new("RGB", (n * (fw * s2 + 10) + 10, len(allf) * (fh * s2 + 10) + 10), BG)
    for r, fr in enumerate(allf.values()):
        for i, f in enumerate(fr):
            im = Image.fromarray(f).resize((f.shape[1] * s2, f.shape[0] * s2), Image.NEAREST)
            sheet.paste(im, (10 + i * (fw * s2 + 10), 10 + r * (fh * s2 + 10) + (fh - f.shape[0]) * s2), im)
    sheet.save(HERE / "robed_frames.png")


if __name__ == "__main__":
    main()
