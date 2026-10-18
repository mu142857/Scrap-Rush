"""第二关的两个披袍人形精英怪（作者 10-17：E3 和第一场换卷战各补一个新精英，配合披袍人形小怪）。

    python3 l2_robed_elites.py   # 草图预览 robed_elites_preview.png（6 倍）、逐帧 robed_elites_frames.png，
                                 # 再导出 oscar-rush/art/enemies/chief_operator.png、film_editor.png

画法和披袍小怪（草图/小怪/l2_robed.py）一样，照 Oscar 的帽兜人形：光从左上来，大块亮面和暗面，斜的楔形褶子，
帽兜开口最暗、里面一个红点，下摆参差。oscarkit.paint.light_planes 只上一次色，动画靠整像素挪部件。都朝左，地面是最后一行。

- 总接线长 chief_operator（E3 电话簿仓库）：高个子，深紫黑长袍拖地，尖帽兜上箍一圈黄铜耳机、前面伸着话筒；
  背后插着五根电话线，像一把扇子往后上方翘，线头都是黄铜插头。
  帧：0、1 飘（下摆飘、背后的线晃），2 拽线预警（手举过头，攥着插头），3 拽线（手往前伸直），
      4 转线（两手张开，背后的线全炸开），5 叫班（两手举起来）。
  甩出去的线、绕身转的线都是代码画的（chief_operator.gd）。
- 剪辑师 film_editor（第一场换卷战，胶片天桥）：驼背高个子，褐色长大褂，帽兜上压着一顶剪辑师的遮光帽檐，
  肩上搭着两条胶片（带齿孔），手里一把和半个人一样长的大剪刀。
  帧：0、1 走，2 冲刺预警（压低身子、剪刀张开举起来），3 冲刺（往前扑、剪刀张开朝前），
      4 剪（剪刀合上），5 跳剪落下（剪刀举过头顶张开，要往下剪）。
  跳剪时的闪烁、落点标记、冲刺的速度线都是代码画的（film_editor.gd）。
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "oscar-rush/art/enemies"
sys.path.insert(0, str(HERE.parent / "小怪"))
import l2_robed as R  # noqa: E402  画笔、帽兜开口、下摆飘、补边（同时把 oscarkit 加进了 sys.path）
from oscarkit.canvas import rgba  # noqa: E402
from oscarkit.paint import breathe, light_planes, over, shift_rows  # noqa: E402
from oscarkit.palette import ramp  # noqa: E402
from oscarkit.shade import ragged_hem  # noqa: E402

LIGHT = R.LIGHT
put, line, mask, blank, face, hem, feet, pad = R.put, R.line, R.mask, R.blank, R.face, R.hem, R.feet, R.pad


def crouch(img, n, at=0.55):
    """上半身往下压 n 行（breathe 反过来）：at 以上的部分整体下移，压掉中间 n 行，脚不动。"""
    if n <= 0:
        return img.copy()
    ys = np.nonzero((img[..., 3] > 0).any(1))[0]
    y0, y1 = ys.min(), ys.max()
    cut = y0 + int(at * (y1 - y0))
    out = img.copy()
    out[y0:y0 + n] = 0
    out[y0 + n:cut + 1] = img[y0:cut + 1 - n]
    return out


def lean(img, k, below=None):
    """往前探：越往上挪得越多（顶上挪 k 格），below 以下不动。"""
    H = img.shape[0]
    ys = np.nonzero((img[..., 3] > 0).any(1))[0]
    y0 = ys.min()
    b = below if below is not None else ys.max()
    return shift_rows(img, [-round(k * max(0, b - y) / max(1, b - y0)) for y in range(H)])


# ================================================================ 总接线长
CO_W, CO_H = 46, 52
CO_R = ramp((90, 76, 100), n=9, L_span=0.6, hue_shift=3)               # 深紫黑长袍
CO_A = [(104, 80, 46), (164, 128, 70), (214, 176, 108)]                 # 黄铜：耳机、话筒、插头
# 脸用黄铜那三档（受光的皮肤和黄铜同一个暖色相，不多开色相）；胡子用长袍最亮的两档（灰白）
SKIN = None
BEARD = None
SKIN = CO_A
BEARD = [CO_R[7], CO_R[8]]
CO_DARK = CO_R[0]                                                       # 帽兜里：长袍最暗的一档（不另起一个色相）
CO_OPEN = [".##.",
           "####",
           "####",
           "####",
           ".##."]
# 背后五根线的根和线头（每根中间折一下）：[(根), (折点), (线头)]
CO_CORDS = [[(28, 14), (33, 8), (36, 1)], [(29, 16), (36, 12), (41, 6)], [(30, 19), (38, 18), (44, 14)],
            [(31, 23), (38, 25), (43, 23)], [(27, 12), (29, 6), (30, 0)]]


def co_body():
    W, H = CO_W, CO_H
    outline = [(15, 9), (18, 5), (22, 3), (27, 0), (26, 4), (27, 8), (29, 14), (31, 22), (33, 34), (36, 51),
               (6, 51), (8, 40), (10, 29), (11, 21), (13, 15), (14, 11)]
    m = mask(W, H, outline)
    m = ragged_hem(m, depth=2, seed=11)
    img = light_planes(m, CO_R, light=LIGHT, contrast=0.75, ambient=0.55, top_dark=0.5, rim=1,
                       folds=[((17, 18), (12, 50), 5), ((22, 16), (22, 50), 5), ((27, 20), (31, 50), 4),
                              ((14, 30), (9, 50), 3)])
    img = face(img, 15, 9, CO_OPEN, CO_DARK, CO_R[6], (0, 2))
    # 活人的脸：帽兜里一个鹰钩鼻、颧骨受光，下巴垂出一把白胡子盖在胸前（眼睛由代码画，会眨、会看人）
    put(img, 16, 12, SKIN[2])
    put(img, 15, 12, SKIN[1])
    put(img, 17, 12, SKIN[0])
    for x, y, c in [(15, 13, BEARD[1]), (16, 13, BEARD[1]), (17, 13, BEARD[0]), (15, 14, BEARD[1]), (16, 14, BEARD[1]),
                    (17, 14, BEARD[0]), (16, 15, BEARD[1]), (17, 15, BEARD[0]), (16, 16, BEARD[0])]:
        put(img, x, y, c)
    # 黄铜耳机箍在帽兜上，前面伸出话筒
    for x, y in [(19, 7), (20, 6), (21, 6), (22, 6), (23, 6), (24, 7)]:
        put(img, x, y, CO_A[2] if x < 22 else CO_A[1])
    for x, y in [(14, 13), (13, 14), (12, 15), (11, 15), (10, 16), (10, 17), (11, 17)]:
        put(img, x, y, CO_A[1] if (x, y) != (10, 16) else CO_A[2])
    # 胸前一排黄铜扣（领班的制服）
    for y in (22, 26, 30):
        put(img, 16, y, CO_A[1])
    return img


def co_cords(sway=0, splay=0):
    """背后五根电话线 + 黄铜插头。sway 让线头左右晃一格，splay 让线全炸开（转线）。"""
    W, H = CO_W, CO_H
    img = blank(W, H)
    for i, (root, mid, tip) in enumerate(CO_CORDS):
        dx = sway * (1 if i % 2 else -1)
        tx, ty = tip[0] + dx + splay * (1 if i < 4 else 0), tip[1] - splay * (1 if i in (0, 4) else 0)
        mx, my = mid[0] + dx // 2, mid[1]
        line(img, *root, mx, my, CO_R[3])
        line(img, mx, my, tx, ty, CO_R[4])
        # 线上一格亮一格暗，像螺旋电话线
        for (x, y) in [(mx, my)]:
            put(img, x, y, CO_R[6])
        put(img, tx, ty, CO_A[2])
        put(img, tx + 1, ty, CO_A[1])
        put(img, tx, ty + 1, CO_A[0])
    return img


def co_arm(pose):
    """袖子。pose: 0 垂着攥一盘线，1 举过头攥插头，2 往前伸直，3 张开（转线），4 举起来（叫班）。"""
    W, H = CO_W, CO_H
    img = blank(W, H)
    shapes = {
        0: [(15, 19), (19, 21), (13, 30), (9, 30), (10, 27)],
        1: [(15, 19), (18, 21), (13, 12), (11, 6), (9, 7), (11, 14)],
        2: [(15, 19), (18, 22), (8, 24), (3, 24), (3, 21)],
        3: [(15, 19), (18, 22), (8, 27), (2, 29), (2, 26)],
        4: [(15, 19), (18, 21), (12, 9), (9, 4), (7, 5), (10, 13)],
    }
    hands = {0: (9, 30), 1: (9, 6), 2: (2, 23), 3: (1, 28), 4: (7, 4)}
    m = mask(W, H, shapes[pose])
    img = over(img, light_planes(m, CO_R, light=LIGHT, contrast=0.5, ambient=0.6, rim=2))
    hx, hy = hands[pose]
    put(img, hx, hy, CO_R[2])
    if pose == 0:                                     # 一盘线垂下来，线头是插头
        for i in range(6):
            put(img, hx - (i % 2), hy + 1 + i, CO_R[5])
        put(img, hx, hy + 7, CO_A[1])
        put(img, hx, hy + 8, CO_A[2])
    if pose == 1:                                     # 手里攥着插头
        put(img, hx - 1, hy - 1, CO_A[2])
        put(img, hx, hy - 1, CO_A[1])
    if pose == 3:                                     # 另一只手往后张开
        m2 = mask(W, H, [(26, 20), (29, 22), (37, 30), (36, 32), (27, 26)])
        img = over(light_planes(m2, CO_R, light=LIGHT, contrast=0.5, ambient=0.45), img)
    if pose == 4:
        m2 = mask(W, H, [(24, 18), (27, 19), (32, 9), (31, 6), (29, 7), (25, 15)])
        img = over(light_planes(m2, CO_R, light=LIGHT, contrast=0.5, ambient=0.45), img)
    return img


def chief_frames():
    body = pad(co_body(), 3)
    H = CO_H + 3
    frames = []
    for f in range(2):
        b = breathe(body, f, at=0.4)
        b = hem(b, f * 2, rows=5)
        b = feet(b, f, (12, 28), CO_R[1], H - 1)
        cords = pad(co_cords(sway=1 if f else 0), 3)
        arm = pad(co_arm(0), 3)
        if f:
            cords = R.lift(cords, 1)
            arm = R.lift(arm, 1)
        frames.append(over(over(cords, b), arm))
    still = feet(body, 0, (12, 28), CO_R[1], H - 1)
    frames.append(over(over(pad(co_cords(), 3), still), pad(co_arm(1), 3)))
    frames.append(over(over(pad(co_cords(sway=1), 3), lean(still, 2, below=30)), pad(co_arm(2), 3)))
    frames.append(over(over(pad(co_cords(splay=2), 3), still), pad(co_arm(3), 3)))
    frames.append(over(over(pad(co_cords(splay=1), 3), R.lift(still, 1)), pad(co_arm(4), 3)))
    # 6 挨打后仰：上半身往后一仰，手护在胸前，背后的线甩乱
    frames.append(over(over(pad(co_cords(sway=-1, splay=1), 3), lean(still, -3, below=34)), lean(pad(co_arm(0), 3), -3, below=34)))
    # 7 倒下：整个人瘫下去，袍子堆在地上，线耷拉下来
    heap = crouch(still, 16, at=0.75)
    frames.append(over(_down(pad(co_cords(sway=1), 3), 14), heap))
    return frames


# ================================================================ 剪辑师
FE_W, FE_H = 50, 48
FE_R = ramp((96, 78, 62), n=9, L_span=0.6, hue_shift=8)                 # 褐色长大褂
FE_F = ramp((150, 112, 72), n=5, L_span=0.4, hue_shift=8)               # 搭在肩上的胶片（琥珀）
FE_S = [(92, 94, 100), (150, 152, 158), (206, 208, 212), (240, 240, 236)]  # 剪刀的钢
FE_DARK = (16, 12, 10)
FE_OPEN = [".##",
           "###",
           "###",
           ".#."]


FE_PADL = 18


def padl(img, n=FE_PADL):
    """左边补 n 列空白。"""
    return np.concatenate([np.zeros((img.shape[0], n, 4), img.dtype), img], axis=1)


def fe_body():
    W, H = FE_W, FE_H
    # 驼背：头往前探，背上一个圆拱，大褂往下张开
    outline = [(22, 6), (25, 3), (30, 3), (33, 6), (34, 11), (37, 16), (38, 25), (39, 35), (41, 47), (13, 47),
               (15, 36), (16, 27), (17, 20), (19, 15), (21, 11)]
    m = mask(W, H, outline)
    m = ragged_hem(m, depth=2, seed=21)
    img = light_planes(m, FE_R, light=LIGHT, contrast=0.75, ambient=0.55, top_dark=0.45, rim=1,
                       folds=[((20, 18), (16, 46), 4), ((26, 17), (26, 46), 5), ((33, 19), (37, 46), 4)])
    img = face(img, 22, 10, FE_OPEN, FE_DARK, FE_R[6], (0, 1))
    # 活人的脸：长鼻子从帽兜里伸出来，下巴一点胡茬（眼睛由代码画）
    put(img, 21, 12, SKIN[2])
    put(img, 22, 12, SKIN[1])
    put(img, 23, 12, SKIN[0])
    put(img, 22, 13, SKIN[0])
    # 遮光帽檐：一条往前伸出去的暗檐，上沿亮一档
    for x in range(17, 28):
        put(img, x, 9, FE_R[1])
        put(img, x, 8, FE_R[3] if x < 25 else FE_R[4])
    put(img, 17, 9, FE_R[2])
    # 胶片搭在肩上：前面一条垂到腰，后面一条垂到背
    for (x0, y0, x1, y1) in [(23, 15, 20, 33), (32, 14, 36, 30)]:
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n)
            y = round(y0 + (y1 - y0) * i / n)
            for dx in range(3):
                put(img, x + dx, y, FE_F[2] if dx == 1 else FE_F[1])
            if i % 3 == 1:                                     # 两边的齿孔
                put(img, x, y, FE_F[4])
                put(img, x + 2, y, FE_F[4])
        put(img, x1, y1 + 1, FE_F[1])
        put(img, x1 + 2, y1 + 1, FE_F[0])
    return img


def shears(img, hinge, a0, a1, length=20, handle=6):
    """一把大剪刀：铰链在 hinge，两片刀刃朝 a0、a1 方向（弧度）伸 length 格，另一头两个把手圈。"""
    import math
    out = img.copy()
    hx, hy = hinge
    for k, a in enumerate((a0, a1)):
        dx, dy = math.cos(a), math.sin(a)
        nx, ny = -dy, dx                                    # 刀刃的法线（刀背那一侧）
        if ny > 0 or (ny == 0 and nx > 0):                  # 刀背朝上（光从上面来，刀背亮）
            nx, ny = -nx, -ny
        for i in range(1, length + 1):
            x, y = hx + dx * i, hy + dy * i
            # 刀身前 2/3 宽两格，刀尖一格；刀背亮、刃口暗一档
            put(out, round(x), round(y), FE_S[2])
            if i < length * 0.7:
                put(out, round(x + nx), round(y + ny), FE_S[3] if k == 0 else FE_S[2])
            if i < length * 0.35:
                put(out, round(x - nx), round(y - ny), FE_S[1])
        # 把手：从铰链往反方向，末端一个圈
        for i in range(1, handle + 1):
            put(out, round(hx - dx * i), round(hy - dy * i), FE_S[0])
        ex, ey = round(hx - dx * (handle + 2)), round(hy - dy * (handle + 2))
        for ox, oy in [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (-1, 1), (1, -1)]:
            put(out, ex + ox, ey + oy, FE_S[1] if oy <= 0 else FE_S[0])
    put(out, hx, hy, FE_S[3])
    return out


def fe_arm(pose):
    """手和剪刀。pose: 0 提着剪刀尖朝下，1 举起来张开，2 往前张开，3 往前合上，4 举过头顶张开（往下剪）。"""
    import math
    W, H = FE_W, FE_H
    img = blank(W, H)
    arms = {0: [(18, 18), (22, 20), (17, 29), (14, 29), (15, 25)],
            1: [(18, 18), (22, 20), (15, 14), (12, 11), (14, 9)],
            2: [(18, 18), (22, 21), (10, 24), (8, 22)],
            3: [(18, 18), (22, 21), (10, 24), (8, 22)],
            4: [(18, 18), (22, 20), (20, 9), (19, 4), (16, 5)]}
    m = mask(W, H, arms[pose])
    img = over(img, light_planes(m, FE_R, light=LIGHT, contrast=0.5, ambient=0.6, rim=2))
    # 剪刀往前伸出身子很远：画布左边补 FE_PADL 格再画剪刀
    img = padl(img)
    if pose == 0:
        img = shears(img, (14 + FE_PADL, 30), math.radians(116), math.radians(106), length=17, handle=3)
    elif pose == 1:
        img = shears(img, (12 + FE_PADL, 11), math.radians(195), math.radians(240), length=20, handle=3)
    elif pose == 2:
        img = shears(img, (9 + FE_PADL, 24), math.radians(162), math.radians(198), length=22, handle=3)
    elif pose == 3:
        img = shears(img, (9 + FE_PADL, 24), math.radians(177), math.radians(183), length=22, handle=3)
    else:
        img = shears(img, (18 + FE_PADL, 5), math.radians(195), math.radians(245), length=20, handle=3)
    return img


def editor_frames():
    body = padl(pad(fe_body(), 3))
    H = FE_H + 3
    frames = []
    for f in range(2):
        b = breathe(body, f, at=0.4)
        b = hem(b, f * 2, rows=4)
        b = feet(b, f, (19 + FE_PADL, 33 + FE_PADL), FE_R[1], H - 1)
        arm = pad(fe_arm(0), 3)
        if f:
            arm = R.lift(arm, 1)
        frames.append(over(b, arm))
    low = crouch(feet(body, 0, (19 + FE_PADL, 33 + FE_PADL), FE_R[1], H - 1), 4)
    frames.append(over(low, _down(pad(fe_arm(1), 3), 4)))
    sprint = lean(crouch(feet(body, 1, (19 + FE_PADL, 33 + FE_PADL), FE_R[1], H - 1), 6), 5, below=36)
    frames.append(over(sprint, _down(_left(pad(fe_arm(2), 3), 4), 7)))
    frames.append(over(sprint, _down(_left(pad(fe_arm(3), 3), 4), 7)))
    frames.append(over(R.lift(feet(body, 0, (19 + FE_PADL, 33 + FE_PADL), FE_R[1], H - 1), 0), pad(fe_arm(4), 3)))
    stand = feet(body, 0, (19 + FE_PADL, 33 + FE_PADL), FE_R[1], H - 1)
    # 6 挨打后仰：往后一仰，剪刀垂下去
    frames.append(over(lean(stand, -3, below=32), lean(pad(fe_arm(0), 3), -3, below=32)))
    # 7 倒下：瘫成一堆，剪刀掉在身前的地上
    heap = crouch(stand, 16, at=0.75)
    import math
    blade = shears(blank(FE_W + FE_PADL, H), (14 + FE_PADL, H - 2), math.radians(178), math.radians(186), length=18, handle=3)
    frames.append(over(heap, blade))
    return frames


def _down(img, n):
    out = np.zeros_like(img)
    out[n:] = img[:-n]
    return out


def _left(img, n):
    out = np.zeros_like(img)
    out[:, :-n] = img[:, n:]
    return out


# ================================================================ 导出、预览
def save_strip(name, frames):
    h, w = frames[0].shape[:2]
    out = np.zeros((h, w * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        out[:, i * w:(i + 1) * w] = f
    Image.fromarray(out).save(OUT / f"{name}.png")
    return w, h


def center_trim(frames, anchor):
    """所有帧用同一个外框，左右以身子中线 anchor 为中心对称（EnemyBase 把脚底中点放在帧的正中间，
    朝右时整帧翻转；身子不在正中间的话，转身时会整个跳一下）。返回裁好的帧和裁掉的左上角。"""
    al = np.zeros(frames[0].shape[:2], bool)
    for f in frames:
        al |= f[..., 3] > 0
    ys, xs = np.nonzero(al)
    H, W = frames[0].shape[:2]
    assert ys.max() == H - 1, "地面要是最后一行"
    half = max(anchor - xs.min(), xs.max() + 1 - anchor)
    x0 = anchor - half
    out = []
    for f in frames:
        g = np.zeros((H - ys.min(), half * 2, 4), np.uint8)
        src = f[ys.min():]
        lo, hi = max(0, x0), min(W, anchor + half)
        g[:, lo - x0:hi - x0] = src[:, lo:hi]
        out.append(g)
    return out, (x0, ys.min())


# 身子中线（画布 x）：总接线长的长袍中线，剪辑师的大褂中线（加上左边补的 FE_PADL）
MONSTERS = [("chief_operator", "总接线长（E3）", chief_frames, [(0, "飘"), (2, "拽线预警"), (3, "拽线"), (4, "转线"), (5, "叫班"), (6, "挨打后仰"), (7, "倒下")]),
            ("film_editor", "剪辑师（第一场换卷战）", editor_frames, [(0, "走"), (2, "冲刺预警"), (3, "冲刺"), (4, "剪"), (5, "跳剪落下"), (6, "挨打后仰"), (7, "倒下")])]


ANCHOR = {"chief_operator": 21, "film_editor": 27 + FE_PADL}


def eye_pixels(frames):
    out = []
    for f in frames:
        ys, xs = np.nonzero((f[..., 0] == R.EYE[0]) & (f[..., 1] == R.EYE[1]) & (f[..., 2] == R.EYE[2]) & (f[..., 3] > 0))
        out.append((int(xs[0]), int(ys[0])) if len(xs) else None)
    return out


def main():
    font = None
    for p in [ROOT / "oscar-rush/fonts/PixelFont.ttf", Path("/System/Library/Fonts/PingFang.ttc")]:
        try:
            font = ImageFont.truetype(str(p), 22)
            break
        except OSError:
            pass
    small = ImageFont.truetype(font.path, 16) if font else None
    hero = None
    hp = ROOT / "oscar-rush/art/chars/red_body.png"
    if hp.exists():
        hb = np.asarray(Image.open(hp).convert("RGBA"))[:, :16].copy()
        st = np.asarray(Image.open(hp.with_name("red_strip.png")).convert("RGBA"))[:, :16]
        mm = st[..., 3] > 0
        hb[mm] = st[mm]
        hero = hb
    S, BG = 5, (104, 102, 110)
    allf = {}
    for name, title, fn, show in MONSTERS:
        fr, origin = center_trim(fn(), ANCHOR[name])
        eyes = eye_pixels(fr)
        dark = CO_DARK if name == "chief_operator" else FE_DARK
        for f in fr:
            m = (f[..., 0] == R.EYE[0]) & (f[..., 1] == R.EYE[1]) & (f[..., 2] == R.EYE[2]) & (f[..., 3] > 0)
            f[m] = rgba(dark)
        w, h = save_strip(name, fr)
        allf[name] = fr
        print(f"{name}.png: {len(fr)} 帧，每帧 {w}x{h}；前面那只眼睛每帧 {eyes}")
    cell_h = 56 * S + 50
    img = Image.new("RGB", (1500, 60 + cell_h * len(MONSTERS)), BG)
    d = ImageDraw.Draw(img)
    d.text((16, 12), "Scrap Rush · 第二关披袍人形精英（照 Oscar 帽兜人形，5 倍；每行：各个动作 / 主角比例尺）",
           fill=(235, 232, 228), font=font)
    for i, (name, title, fn, show) in enumerate(MONSTERS):
        y0 = 50 + i * cell_h
        d.text((16, y0), title, fill=(235, 232, 228), font=font)
        base_y = y0 + cell_h - 16
        x = 40
        items = [(allf[name][k], t) for k, t in show] + ([(hero, "主角")] if hero is not None else [])
        for f, lab in items:
            im = Image.fromarray(f).resize((f.shape[1] * S, f.shape[0] * S), Image.NEAREST)
            img.paste(im, (x, base_y - im.size[1]), im)
            d.text((x, base_y + 2), lab, fill=(220, 218, 214), font=small)
            x += im.size[0] + 26
    img.save(HERE / "robed_elites_preview.png")
    s2 = 5
    fw = max(f[0].shape[1] for f in allf.values())
    fh = max(f[0].shape[0] for f in allf.values())
    n = max(len(f) for f in allf.values())
    sheet = Image.new("RGB", (n * (fw * s2 + 10) + 10, len(allf) * (fh * s2 + 10) + 10), BG)
    for r, fr in enumerate(allf.values()):
        for i, f in enumerate(fr):
            im = Image.fromarray(f).resize((f.shape[1] * s2, f.shape[0] * s2), Image.NEAREST)
            sheet.paste(im, (10 + i * (fw * s2 + 10), 10 + r * (fh * s2 + 10) + (fh - f.shape[0]) * s2), im)
    sheet.save(HERE / "robed_elites_frames.png")


if __name__ == "__main__":
    main()
