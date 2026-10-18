"""第二关开场动画的素材（10-18 作者：第二关开头"电影胶片很快地过去"，要电影感、流畅）。

  art/levels/level2_intro_strip.png   一条胶片：上下齿孔边 + 14 格画面，每格 96×64，格距 100，高 88。
                                      画面是第二关的地方（从游戏用的整张图里截，1 倍像素）和精英的剪影，统一调成老胶片的棕褐色。
                                      最后一格是接线员大厅的气动管口：动画在这一格卡住、烧白，接着就是气动管冲刺。
  art/levels/level2_intro_leader.png  倒计时片头 3、2、1：160×90 一张，每个数字 6 张（扫过的扇形一张比一张大），6 列 × 3 行。
  art/levels/level2_intro_burn.png    烧穿用的噪声：160×90 灰度，中间小、四周大，游戏里按阈值一圈圈烧开。

游戏里 scripts/levels/level2_intro.gd 把它们放大 2~3 倍显示（最近邻，像素是方的）。
跑法："/Users/jiamulin/Desktop/程序programs/AI Oscar/.venv/bin/python" level2_intro_art.py
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, "/Users/jiamulin/Desktop/程序programs/AI Oscar")
import level2_bridge as LB  # noqa: E402
from oscarkit.canvas import Canvas  # noqa: E402
from oscarkit.light import smooth_noise  # noqa: E402

GAME = Path("/Users/jiamulin/Desktop/程序programs/小游戏/Oscar Rush/oscar-rush")
ART = GAME / "art/levels"
ENEMIES = GAME / "art/enemies"
PREVIEW = HERE / "样图"

SEPIA = LB.SEPIA                      # 8 档，暗 → 亮
RAIL = LB.RAIL_R
PERF = LB.PERF_LIGHT
LINE = LB.FRAME_LINE
CELL_W, CELL_H, PITCH, RAIL_H = 96, 64, 100, 12
H = CELL_H + RAIL_H * 2


def load_map():
    """游戏用的整张图（main 层两条拼起来），透明的地方填暗色。"""
    parts = [np.array(Image.open(ART / f"level2_main_{i}.png").convert("RGBA")) for i in range(2)]
    a = np.concatenate(parts, axis=1)
    rgb = a[..., :3].astype(float)
    rgb[a[..., 3] == 0] = (17, 16, 16)
    return rgb


def sepia(rgb, lo=3, hi=97, gamma=0.9):
    """一块画面调成老胶片：亮度拉满、分成 8 档、套棕褐色；四角暗一档。"""
    lum = rgb[..., 0] * 0.3 + rgb[..., 1] * 0.59 + rgb[..., 2] * 0.11
    a, b = np.percentile(lum, lo), np.percentile(lum, hi)
    v = np.clip((lum - a) / max(b - a, 1.0), 0, 1) ** gamma
    idx = np.clip(np.round(v * 7), 0, 7).astype(int)
    h, w = idx.shape
    yy, xx = np.mgrid[0:h, 0:w]
    r = ((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2
    idx = np.clip(idx - (r > 1.1) - (r > 1.6), 0, 7)
    return np.array(SEPIA, dtype=np.uint8)[idx]


def crop(m, x, y, w=CELL_W, h=CELL_H, scale=1):
    """从地图截一块；scale=2 是特写（截一半大小，每格放大 2 倍）。"""
    if scale == 1:
        return m[y:y + h, x:x + w]
    sub = m[y:y + h // scale, x:x + w // scale]
    return sub.repeat(scale, axis=0).repeat(scale, axis=1)


def shrink(rgb, k):
    """缩小 k 倍（每 k×k 格取平均），远景全景用；之后 sepia() 会再分成 8 档，不会糊。"""
    h, w = rgb.shape[0] // k, rgb.shape[1] // k
    return rgb[:h * k, :w * k].reshape(h, k, w, k, 3).mean(axis=(1, 3))


def silhouette(name, frames, crop_top=0):
    """精英剪影：亮的聚光灯底子、一条地面线，怪是最暗的一档，朝上的边亮一档，眼睛 / 指示灯留成最亮的点。"""
    sheet = np.array(Image.open(ENEMIES / f"{name}.png").convert("RGBA"))
    fw = sheet.shape[1] // frames
    spr = sheet[crop_top:, :fw]
    out = np.zeros((CELL_H, CELL_W, 3), dtype=np.uint8)
    yy, xx = np.mgrid[0:CELL_H, 0:CELL_W]
    r = np.hypot((xx - CELL_W / 2) / 52.0, (yy - 26) / 40.0)
    band = np.clip(6 - np.floor(r * 4), 3, 6).astype(int)      # 一圈圈分档的聚光灯
    out[:] = np.array(SEPIA, dtype=np.uint8)[band]
    floor_y = 56
    out[floor_y:] = SEPIA[2]
    out[floor_y] = SEPIA[4]
    # 怪站在地面线上、左右居中（太高的从下面截掉，像镜头只拍到上半身）
    alpha = spr[..., 3] > 0
    ys, xs = np.nonzero(alpha)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    spr, alpha = spr[y0:y1 + 1, x0:x1 + 1], alpha[y0:y1 + 1, x0:x1 + 1]
    sh, sw = alpha.shape
    oy = floor_y + 1 - sh
    ox = (CELL_W - sw) // 2
    for y in range(sh):
        for x in range(sw):
            ty, tx = oy + y, ox + x
            if not alpha[y, x] or not (0 <= ty < CELL_H and 0 <= tx < CELL_W):
                continue
            p = spr[y, x, :3].astype(int)
            col = SEPIA[0]
            if (y == 0 or not alpha[y - 1, x]) or (x == 0 or not alpha[y, x - 1]):
                col = SEPIA[1]                                  # 左上的轮廓亮一档（光从上面来）
            if p[0] > 170 and p[0] - p[2] > 60:
                col = PERF                                      # 红眼睛 / 红灯
            out[ty, tx] = col
    return out


def rail(c, x0, x1, ry):
    """齿孔边：深色片基、一排亮的方齿孔（每格 4 个）、片边编号小点。"""
    for x in range(x0, x1):
        for y in range(ry, ry + RAIL_H):
            c.put(x, y, RAIL[1] if (y - ry) in (0, RAIL_H - 1) else RAIL[2])
    for k in range((x1 - x0) // 25):
        px = x0 + k * 25 + 8
        for y in range(ry + 3, ry + 9):
            for x in range(px, px + 8):
                edge = y in (ry + 3, ry + 8) or x in (px, px + 7)
                c.put(x, y, LB.PERF_SHADE if edge else PERF)
    rng = np.random.default_rng(ry)
    for k in range((x1 - x0) // PITCH):
        for j in range(5):
            if rng.random() < 0.6:
                c.put(x0 + k * PITCH + 40 + j * 3, ry + RAIL_H - 2 if ry == 0 else ry + 1, LB.EDGE_CODE)


def build_strip():
    m = load_map()
    cells = [
        sepia(crop(m, 196, 474)),                   # 接线员大厅：插线板、电话
        sepia(crop(m, 228, 486, scale=2)),          # 电话特写
        silhouette("switchboard", 6),               # 总机台
        sepia(crop(m, 590, 360)),                   # 继电器机房
        silhouette("watchman", 10, crop_top=4),     # 守夜巨人
        sepia(crop(m, 198, 152)),                   # 电话簿仓库：挂钟、书架
        silhouette("chief_operator", 8),            # 总接线长
        sepia(crop(m, 818, 206)),                   # 片库：墙上的"家"
        silhouette("film_editor", 8),               # 剪辑师
        sepia(crop(m, 2920, 222)),                  # 放映室：放映机
        silhouette("projector", 20),                # 放映机
        sepia(shrink(m[150:150 + CELL_H * 4, 3296:3296 + CELL_W * 4], 4)),   # 放映厅全景（缩小 4 倍）：银幕、台阶座位、包厢
        silhouette("gramophone", 6),                # 留声机
        sepia(crop(m, 388, 506, scale=2)),          # 最后一格：气动管口特写（卡在这里烧白，接气动管冲刺）
    ]
    W = PITCH * len(cells)
    c = Canvas(W, H)
    for x in range(W):
        for y in range(RAIL_H, RAIL_H + CELL_H):
            c.put(x, y, LINE)
    for i, cell in enumerate(cells):
        x0 = i * PITCH + (PITCH - CELL_W) // 2
        c.a[RAIL_H:RAIL_H + CELL_H, x0:x0 + CELL_W, :3] = cell
        c.a[RAIL_H:RAIL_H + CELL_H, x0:x0 + CELL_W, 3] = 255
    rail(c, 0, W, 0)
    rail(c, 0, W, RAIL_H + CELL_H)
    # 胶片上的旧伤：几道竖划痕、几颗灰点（印在片子上，跟着片子走；放映时另外还有满屏的闪烁和划痕）
    rng = np.random.default_rng(11)
    for _ in range(18):
        x = int(rng.integers(0, W))
        y0 = RAIL_H + int(rng.integers(0, CELL_H // 2))
        for y in range(y0, min(RAIL_H + CELL_H, y0 + int(rng.integers(8, 40)))):
            c.put(x, y, SEPIA[6])
    for _ in range(60):
        c.put(int(rng.integers(0, W)), RAIL_H + int(rng.integers(0, CELL_H)), SEPIA[1])
    c.save(ART / "level2_intro_strip.png")
    c.save(PREVIEW / "level2_intro_strip_preview.png", scale=2)
    return len(cells)


DIGITS = {
    3: [(0, 0, 1, 0.16), (0.2, 0.42, 1, 0.58), (0, 0.84, 1, 1), (0.8, 0, 1, 1)],
    2: [(0, 0, 1, 0.16), (0.8, 0, 1, 0.58), (0, 0.42, 1, 0.58), (0, 0.42, 0.2, 1), (0, 0.84, 1, 1)],
    1: [(0.4, 0, 0.62, 1), (0.16, 0.06, 0.42, 0.2), (0.12, 0.86, 0.9, 1)],
}


def leader_frame(digit, sweep_deg):
    """一张倒计时片头：亮底、两圈同心圆、十字线、扫过的扇形暗一档、中间一个粗数字。"""
    w, h = 160, 90
    c = Canvas(w, h)
    cx, cy = w // 2, h // 2
    R = 38
    sweep = math.radians(sweep_deg)
    for y in range(h):
        for x in range(w):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            a = math.atan2(dx, -dy) % (2 * math.pi)
            v = 5 if d < R else 4
            if d > R + 22:
                v = 3
            if d < R and a < sweep:
                v = 3
            if abs(d - R) < 1.0 or abs(d - R * 0.72) < 0.7:
                v = 1
            if (dx == 0 or dy == 0) and d < R + 8:
                v = 1
            c.put(x, y, SEPIA[v])
    gw, gh = 22, 34
    gx, gy = cx - gw // 2, cy - gh // 2
    for (a0, b0, a1, b1) in DIGITS[digit]:
        for y in range(gy + round(b0 * gh), gy + round(b1 * gh)):
            for x in range(gx + round(a0 * gw), gx + round(a1 * gw)):
                c.put(x, y, SEPIA[0])
    return c


def build_leader():
    sheet = Canvas(160 * 6, 90 * 3)
    for row, digit in enumerate((3, 2, 1)):
        for k in range(6):
            f = leader_frame(digit, 60 * (k + 1) - 1)
            sheet.a[row * 90:(row + 1) * 90, k * 160:(k + 1) * 160] = f.a
    sheet.save(ART / "level2_intro_leader.png")
    sheet.save(PREVIEW / "level2_intro_leader_preview.png", scale=1)


def build_burn():
    """烧穿噪声：中间 0、四周 1，再叠一层斑驳，像胶片在片门里被灯烤化，一圈圈往外烧。"""
    w, h = 160, 90
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)) / math.sqrt(2)
    n = smooth_noise(h, w, 9, 9)
    n = (n - n.min()) / (n.max() - n.min())
    v = np.clip(r * 0.7 + n * 0.45 - 0.05, 0, 1)
    img = (v * 255).astype(np.uint8)
    Image.fromarray(img, "L").save(ART / "level2_intro_burn.png")


if __name__ == "__main__":
    n = build_strip()
    build_leader()
    build_burn()
    print("ok cells", n)
