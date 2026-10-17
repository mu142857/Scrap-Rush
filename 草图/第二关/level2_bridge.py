"""第二关胶片天桥样图：一长条胶片横在屏幕中间，上下都是黑的，连接前半和后半。480×270，1 倍像素。

画法跟 Oscar 的场景2.aseprite 走：柔和的分档渐变、圆形高光、中性灰金属 + 黄铜，不用三角切面。
重点是胶片的质感：
  - 片基是背光的琥珀色醋酸片，有一道斜着扫过的光泽带
  - 齿孔是圆角矩形，透光，上沿有一像素的厚度阴影
  - 片边印着边码（一串小点）
  - 画框里是录像里的家：分档渐变的天空、暗角、颗粒、竖划痕、毛发
  - 一处接片胶带
  - 底边一像素暗线是胶片的厚度

分层（对应 parallax_scene.gd 的镜头比例）：
  far 0.55      远处：投在黑暗里的巨大模糊画面、远处下垂的胶片
  machines 0.8  吊杆、夹子、配重球（Oscar 的球）
  film 1.0      胶片天桥（碰撞层）
  near 1.0      前景：一段失焦的胶片从上面垂下来、灰尘
fx：burn（左边追人的烧穿边）、player（比例参考），只用于预览。
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, "/Users/jiamulin/Desktop/程序programs/AI Oscar")
sys.path.insert(0, str(Path(__file__).parent))
from oscarkit.canvas import Canvas  # noqa: E402
from oscarkit.light import smooth_noise  # noqa: E402
from film_scenes import SCENES  # noqa: E402

HERE = Path(__file__).parent
OUT = HERE / "样图"
OUT.mkdir(exist_ok=True)
GAME = Path("/Users/jiamulin/Desktop/程序programs/小游戏/Oscar Rush/oscar-rush")

W, H = 480, 270

# ---------------------------------------------------------------- 尺寸
# 胶片 90 高（作者 10-17：要更宽）。画框 90×64 里放经典电影镜头。
# 上齿孔边离地面 77，主角跳不上去，不当平台用。
FILM_TOP = 90                # 上齿孔边顶面
RAIL = 13
FRAME_Y0 = FILM_TOP + RAIL   # 103
FRAME_H = 64
FLOOR = FRAME_Y0 + FRAME_H   # 167，下齿孔边顶面（地面）
FILM_BOT = FLOOR + RAIL      # 180
PERF = 23                    # 齿孔间距，4 个对一个画框
PITCH = PERF * 4             # 92：画框 90 + 片框线 2
PERF_W, PERF_H = 9, 6

# ---------------------------------------------------------------- 调色
# 暗部是 Oscar 场景2 那种中性偏暖的灰，胶片是背光的琥珀色
VOID = (17, 16, 16)
RAIL_R = [(36, 24, 19), (52, 35, 25), (72, 49, 33), (96, 66, 42), (126, 89, 55), (160, 118, 72)]
SEPIA = [(62, 41, 28), (88, 60, 39), (118, 83, 53), (152, 110, 70), (186, 141, 92), (216, 176, 122),
         (238, 210, 160), (250, 234, 196)]
PERF_LIGHT = (248, 228, 180)
PERF_SHADE = (206, 168, 112)
EDGE_CODE = (190, 150, 92)
FRAME_LINE = (28, 19, 15)
GREY = [(40, 40, 40), (56, 56, 56), (67, 67, 67), (79, 79, 79), (99, 99, 99), (115, 115, 115),
        (128, 128, 128), (145, 145, 145), (171, 171, 171)]     # Oscar 场景2 的金属灰
BRASS = [(70, 58, 30), (105, 95, 62), (127, 110, 56), (134, 117, 63), (170, 150, 92)]


def q(ramp, v):
    """v in [0,1] → ramp 里的一档。"""
    i = int(np.clip(round(v * (len(ramp) - 1)), 0, len(ramp) - 1))
    return ramp[i]


def shift(ramp, col, k):
    """在 ramp 里把 col 挪 k 档（col 必须在 ramp 里，不在就原样返回）。"""
    try:
        i = ramp.index(tuple(col))
    except ValueError:
        return tuple(col)
    return ramp[int(np.clip(i + k, 0, len(ramp) - 1))]


def ball(c, cx, cy, r, ramp=GREY, light=(-0.45, -0.55)):
    """Oscar 的金属球：同心的分档明暗，左上一块圆高光，右下一圈暗的反光边。"""
    lx, ly = light
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            dx, dy = (x - cx) / r, (y - cy) / r
            d2 = dx * dx + dy * dy
            if d2 > 1:
                continue
            nz = math.sqrt(1 - d2)
            lam = max(0, -lx * -dx + -ly * -dy + 0.6 * nz) / 1.25
            v = 0.15 + 0.7 * lam
            if d2 > 0.8 and dx + dy > 0.3:
                v = 0.25                              # 背光边的反光
            c.put(x, y, q(ramp[1:-1], v))
    # 高光
    hx, hy = int(cx + lx * r * 0.5), int(cy + ly * r * 0.5)
    hr = max(1, r // 5)
    c.ellipse(hx, hy, hr, max(1, hr - 1), ramp[-1])


# ================================================================ film：胶片天桥
def draw_film(x0=0, x1=W, seed=0):
    full = x1
    c = Canvas(x1 + PITCH, H)         # 多画一格，最后一格画完再裁掉
    rng = np.random.default_rng(seed)
    gloss_n = smooth_noise(H, x1 + PITCH, 90, 30, seed=seed + 1)

    def gloss(x, y):
        """斜着扫过的光泽带：每 170 像素一条，宽 26，往右上斜。"""
        t = (x + (y - FILM_TOP) * 0.9) % 230
        return 1 if t < 16 else 0

    # 两条齿孔边
    for ry in (FILM_TOP, FLOOR):
        for y in range(ry, ry + RAIL):
            for x in range(x0, x1):
                r = y - ry
                if r == 0:
                    v = 4                            # 上沿受光
                elif r == RAIL - 1:
                    v = 0                            # 下沿是胶片厚度
                elif r == 1:
                    v = 3
                else:
                    v = 2 + (1 if gloss_n[y, x] > 0.25 else 0) - (1 if r >= RAIL - 4 else 0)
                v += gloss(x, y)
                c.put(x, y, RAIL_R[int(np.clip(v, 0, len(RAIL_R) - 1))])
        # 齿孔：圆角矩形，透光，上沿一像素阴影
        for px in range(x0 + 7, x1, PERF):
            hx0, hy0 = px, ry + 3
            for y in range(hy0, hy0 + PERF_H):
                for x in range(hx0, hx0 + PERF_W):
                    if (x in (hx0, hx0 + PERF_W - 1)) and (y in (hy0, hy0 + PERF_H - 1)):
                        continue                      # 圆角
                    if y == hy0 or x == hx0:
                        col = PERF_SHADE              # 孔的上沿、左沿是胶片厚度的阴影
                    else:
                        col = PERF_LIGHT
                    c.put(x, y, col)
        # 边码：齿孔之间的一串小点，每个画框一组，像印在片边的编号
        for fx in range(x0, x1, PITCH):
            code = rng.integers(0, 2, 7)
            for k, b in enumerate(code):
                if b:
                    c.put(fx + 18 + k * 2 + (k // 4), ry + RAIL - 3, EDGE_CODE)
            # 每格一个片号：两小竖一点
            c.rect(fx + 64, ry + RAIL - 3, fx + 64, ry + RAIL - 3, EDGE_CODE)
            c.rect(fx + 66, ry + RAIL - 3, fx + 67, ry + RAIL - 3, EDGE_CODE)

    # 画框
    k = 0
    for fx in range(x0, x1, PITCH):
        c.rect(fx, FRAME_Y0, fx + 1, FLOOR - 1, FRAME_LINE)
        movie_frame(c, fx + 2, FRAME_Y0, PITCH - 2, FRAME_H, (k + seed) % len(SCENES), rng)
        k += 1

    # 整条胶片的光泽带也扫过画框（提亮一档）
    for y in range(FRAME_Y0, FLOOR):
        for x in range(x0, x1):
            if gloss(x, y):
                col = tuple(int(v) for v in c.a[y, x, :3])
                c.put(x, y, shift(SEPIA, col, 1))

    # 一处接片：一条透明胶带横跨片框线，胶带边是亮线，下面的东西提亮一档
    sx = x0 + PITCH * 3 - 5
    for y in range(FILM_TOP, FILM_BOT):
        for x in range(sx, sx + 11):
            col = tuple(int(v) for v in c.a[y, x, :3])
            col2 = shift(RAIL_R, col, 1) if col in RAIL_R else shift(SEPIA, col, 1)
            c.put(x, y, col2)
        c.put(sx, y, SEPIA[5] if (y // 3) % 2 else SEPIA[4])
        c.put(sx + 10, y, SEPIA[4])
    return Canvas(full, H, arr=c.a[:, :full])


def movie_frame(c, x0, y0, w, h, kind, rng):
    """画框里的一个经典电影镜头，再加老胶片的暗角、颗粒、竖划痕、毛发。"""
    tmp = Canvas(w, h)                 # 先画在格子自己的画布上，出格的部分自然被裁掉
    SCENES[kind](tmp, 0, 0, w, h, SEPIA)
    m = tmp.a[..., 3] > 0
    c.a[y0:y0 + h, x0:x0 + w][m] = tmp.a[m]
    # 暗角：四角压暗一到两档
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            dx, dy = (x - x0 - w / 2) / (w / 2), (y - y0 - h / 2) / (h / 2)
            r = dx * dx * 0.6 + dy * dy * 0.8
            k = 2 if r > 1.05 else 1 if r > 0.7 else 0
            if k:
                col = tuple(int(v) for v in c.a[y, x, :3])
                c.put(x, y, shift(SEPIA, col, -k))
    # 颗粒
    for _ in range(14):
        x, y = x0 + int(rng.integers(1, w - 1)), y0 + int(rng.integers(1, h - 1))
        col = tuple(int(v) for v in c.a[y, x, :3])
        c.put(x, y, shift(SEPIA, col, int(rng.choice([-2, 2]))))
    # 竖划痕：一条断断续续的亮线
    if rng.random() < 0.7:
        sx = x0 + int(rng.integers(3, w - 3))
        for y in range(y0, y0 + h):
            if rng.random() < 0.75:
                col = tuple(int(v) for v in c.a[y, sx, :3])
                c.put(sx, y, shift(SEPIA, col, 2))
    # 毛发：偶尔一根弯的暗线（老放映机的经典瑕疵）
    if rng.random() < 0.35:
        hx, hy = x0 + int(rng.integers(6, w - 14)), y0 + int(rng.integers(4, h - 10))
        for t in range(13):
            c.put(hx + t, hy + int(2 * math.sin(t / 2.2)), SEPIA[0])


# ================================================================ far：投在黑暗里的画面、远处的胶片
def draw_far():
    c = Canvas(W, H)
    c.rect(0, 0, W - 1, H - 1, VOID)
    dim = [(21, 19, 18), (27, 24, 21), (34, 29, 25), (42, 35, 28)]
    # 远处巨大的投影：一家人围着电视，非常暗，边缘分档发虚
    px0, py0, pw, ph = 200, -6, 230, 112
    for y in range(py0, py0 + ph):
        for x in range(px0, px0 + pw):
            dx, dy = (x - px0 - pw / 2) / (pw / 2), (y - py0 - ph / 2) / (ph / 2)
            r = dx * dx * 0.8 + dy * dy
            if r > 1:
                continue
            c.put(x, y, dim[3] if r < 0.35 else dim[2] if r < 0.7 else dim[1])
    g = py0 + ph - 30
    c.rect(px0 + 88, g - 34, px0 + 140, g + 4, dim[0])        # 电视
    c.rect(px0 + 95, g - 27, px0 + 133, g - 7, dim[3])
    for hx, hh in ((px0 + 52, 28), (px0 + 66, 22), (px0 + 160, 25), (px0 + 174, 19)):
        c.rect(hx, g - hh, hx + 9, g + 4, dim[0])
        c.ellipse(hx + 4, g - hh - 6, 5, 5, dim[0])
    # 远处下垂的胶片（悬链线），细、暗
    for (ax, ay, bx, by, sag) in ((-20, 60, 200, 40, 40), (260, 214, 520, 236, 30), (-10, 228, 170, 250, 26)):
        for x in range(ax, bx):
            t = (x - ax) / (bx - ax)
            y = int(ay + (by - ay) * t + sag * 4 * t * (1 - t))
            for o in range(7):
                col = dim[2] if o in (0, 6) else dim[1]
                if o in (1, 5) and x % 4 == 0:
                    col = dim[3]
                c.put(x, y + o, col)
    return c


# ================================================================ machines：吊杆、夹子、配重球
def hanger(c, x, ball_y=None):
    # 吊杆从上面垂下来（Oscar 的细杆，两档灰）
    for y in range(0, FILM_TOP - 4):
        c.put(x, y, GREY[4])
        c.put(x + 1, y, GREY[2])
    # 杆上的小球节（Oscar 原稿里那颗）
    ball(c, x, FILM_TOP - 24, 3)
    if ball_y:
        ball(c, x, ball_y, 14)
    # 黄铜夹子夹住上齿孔边
    c.rect(x - 5, FILM_TOP - 5, x + 6, FILM_TOP - 1, BRASS[2])
    c.rect(x - 5, FILM_TOP - 5, x + 6, FILM_TOP - 5, BRASS[4])
    c.rect(x - 5, FILM_TOP - 1, x + 6, FILM_TOP - 1, BRASS[0])
    c.rect(x - 5, FILM_TOP, x - 4, FILM_TOP + 3, BRASS[1])
    c.rect(x + 5, FILM_TOP, x + 6, FILM_TOP + 3, BRASS[1])
    c.put(x - 1, FILM_TOP - 3, GREY[7])


def draw_machines():
    c = Canvas(W, H)
    hanger(c, 96, ball_y=34)
    hanger(c, 330)
    # 天桥底下吊着的一个线圈（Oscar 的线圈，缩小）
    cx, cy = 210, 214
    for y in range(cy - 7, cy + 8):
        for x in range(cx - 22, cx + 23):
            v = 0.75 - 0.5 * abs(y - cy) / 8 - 0.25 * (x - cx + 22) / 45
            c.put(x, y, q(GREY[1:7], v))
    for x in (cx - 22, cx - 21, cx + 21, cx + 22):
        for y in range(cy - 9, cy + 10):
            c.put(x, y, GREY[2] if x > cx else GREY[4])
    for x in range(cx - 5, cx + 6):
        for y in range(cy - 9, cy + 10):
            c.put(x, y, BRASS[3] if x % 2 else BRASS[1])
    for y in range(FILM_BOT, cy - 9):
        c.put(cx, y, GREY[4])
    return c


# ================================================================ near：前景失焦的胶片、灰尘
def draw_near():
    c = Canvas(W, H)
    dark = [(10, 9, 9), (16, 13, 12), (24, 19, 16)]
    # 右边一段很近、失焦的胶片从上面垂下来，只看到轮廓和透光的齿孔
    x0 = 440
    for y in range(0, 70):
        for x in range(x0, x0 + 40):
            c.put(x, y, dark[1] if 5 < x - x0 < 35 else dark[2])
        if y % 14 < 8:
            c.rect(x0 + 1, y, x0 + 4, y, (70, 50, 34))
            c.rect(x0 + 36, y, x0 + 39, y, (70, 50, 34))
    for y in range(70, 78):
        w = 40 - (y - 70) * 3
        for x in range(x0 + (40 - w) // 2, x0 + (40 + w) // 2):
            c.put(x, y, dark[1])
    # 灰尘：天桥周围漂着几颗被照亮的
    rng = np.random.default_rng(3)
    for _ in range(18):
        x, y = int(rng.integers(0, W)), int(rng.integers(70, 200))
        if FILM_TOP - 2 <= y <= FILM_BOT + 1:
            continue
        c.put(x, y, (120, 96, 64) if rng.random() < 0.6 else (200, 168, 112))
    return c


# ================================================================ fx（预览用）
def draw_burn():
    c = Canvas(W, H)
    rng = np.random.default_rng(5)
    edge = smooth_noise(H, W, 20, 9, seed=8)[:, 0]
    for y in range(FILM_TOP - 30, FILM_BOT + 30):
        on_film = FILM_TOP <= y < FILM_BOT
        e = (22 if on_film else 10) + edge[y] * 8
        for x in range(0, int(e) + 8):
            d = e - x
            if d > 16:
                col = (255, 244, 214)
            elif d > 9:
                col = (250, 206, 100)
            elif d > 4:
                col = (226, 120, 54)
            elif d > 0:
                col = (110, 46, 32)
            elif on_film and rng.random() < 0.3:
                col = (64, 30, 26)                 # 焦黑的胶片碎边
            else:
                continue
            c.put(x, y, col)
    for _ in range(20):
        x, y = int(rng.integers(26, 64)), int(rng.integers(FILM_TOP - 30, FILM_BOT + 30))
        c.put(x, y, (250, 206, 100) if rng.random() < 0.5 else (226, 120, 54))
    return c


def paste_sprite(c, path, x0, foot_y, cols=16):
    if not path.exists():
        return 0
    a = np.array(Image.open(path).convert("RGBA"))[:, :cols]
    ys, xs = np.nonzero(a[..., 3])
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = a.shape[:2]
    sub = c.a[foot_y - h:foot_y, x0:x0 + w]
    m = a[..., 3] > 0
    sub[m] = a[m]
    return w


def draw_player():
    c = Canvas(W, H)
    body = np.array(Image.open(GAME / "art/chars/red_body.png").convert("RGBA"))
    strip = np.array(Image.open(GAME / "art/chars/red_strip.png").convert("RGBA"))
    body[strip[..., 3] > 0] = strip[strip[..., 3] > 0]
    tmp = OUT / "_red.png"
    Image.fromarray(body).save(tmp)
    w = paste_sprite(c, tmp, 150, FLOOR)
    tmp.unlink()
    c.rect(150 + w + 1, FLOOR - 7, 150 + w + 3, FLOOR - 4, (250, 220, 150))   # 马灯
    paste_sprite(c, GAME / "art/enemies/crawler.png", 290, FLOOR)
    # 站在上齿孔边上的一只扑灯蛾位置示意
    paste_sprite(c, GAME / "art/enemies/moth.png", 380, FILM_TOP)
    return c


def over(dst, src):
    m = src.a[..., 3] > 0
    dst.a[m] = src.a[m]


def main():
    far = draw_far()
    machines = draw_machines()
    film = draw_film()
    near = draw_near()
    layers = {"far": far, "machines": machines, "film": film, "near": near}
    for name, cv in layers.items():
        cv.save(OUT / f"level2_bridge_{name}.png")
    draw_burn().save(OUT / "level2_bridge_fx_burn.png")

    comp = far.copy()
    for cv in (machines, film, near):
        over(comp, cv)
    comp.save(OUT / "level2_bridge.png")
    play = comp.copy()
    over(play, draw_player())
    over(play, draw_burn())
    play.save(OUT / "level2_bridge_play_3x.png", scale=3)
    # 胶片特写：6 倍看质感
    Image.fromarray(film.a[FILM_TOP - 4:FILM_BOT + 4, 0:W]).resize((W * 3, (FILM_BOT - FILM_TOP + 8) * 3),
                                                                       Image.NEAREST).save(OUT / "level2_bridge_film_3x.png")
    print("ok")


if __name__ == "__main__":
    main()


def contact_sheet():
    """所有电影镜头每行 4 个排开，4 倍，方便一格一格看。"""
    old_w = globals()["W"]
    globals()["W"] = PITCH * 4
    rows = []
    for r in range(3):
        f = draw_film(0, PITCH * 4, seed=r * 4)
        rows.append(f.a[FILM_TOP - 2:FILM_BOT + 2])
    globals()["W"] = old_w
    a = np.concatenate(rows, 0)
    Image.fromarray(a).resize((a.shape[1] * 4, a.shape[0] * 4), Image.NEAREST).save(OUT / "level2_movies_4x.png")


if __name__ == "__main__" and "--sheet" in sys.argv:
    contact_sheet()
