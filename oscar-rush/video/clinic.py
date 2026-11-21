"""《情绪稳定》诊室：160×90 像素画面，放大 9 倍出 1440×810（角色和关卡里一样是 20 像素高，镜头推近一点）。
红衣（病人）站左边，蓝鸟（医生）在桌子后面。角色直接用游戏里的 art/chars/*_body.png、*_strip.png。
光照照游戏的做法：整屏压暗（DARKNESS），台灯一盏暖光，按档位分层（不做平滑渐变）。

python3 clinic.py still out.png                 静帧
python3 clinic.py clip 名字 秒数 out.mp4         一段动画（名字见 CLIPS）
"""
import sys, math, subprocess, os, random
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "..", "art", "chars")
W, H = 160, 90
SCALE = 9
FLOOR = 80
FPS = 30

def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

# ---------- 背景 ----------
WALL = rgb("#2a2632")
WALL_D = rgb("#221f29")
LINE = rgb("#3a3544")      # 家具轮廓（比墙亮一点，不描黑边）
LINE_L = rgb("#4a4456")
FLOOR_C = rgb("#1b1820")
WOOD = rgb("#3b2a26")
WOOD_L = rgb("#4f3830")
WOOD_D = rgb("#2a1e1c")
PAPER = rgb("#d8d2c4")
NIGHT = rgb("#141a2a")


def rect(img, x0, y0, x1, y1, c):
    for y in range(max(0, y0), min(H, y1)):
        for x in range(max(0, x0), min(W, x1)):
            img[y][x] = c


def hline(img, x0, x1, y, c):
    rect(img, x0, y, x1, y + 1, c)


def vline(img, x, y0, y1, c):
    rect(img, x, y0, x + 1, y1, c)


def frame(img, x0, y0, x1, y1, c):
    hline(img, x0, x1, y0, c); hline(img, x0, x1, y1 - 1, c)
    vline(img, x0, y0, y1, c); vline(img, x1 - 1, y0, y1, c)


def background():
    img = [[WALL for _ in range(W)] for _ in range(H)]
    rect(img, 0, 0, W, 4, WALL_D)
    hline(img, 0, W, 4, LINE)
    rect(img, 0, FLOOR - 2, W, FLOOR, WALL_D)
    hline(img, 0, W, FLOOR - 2, LINE)
    rect(img, 0, FLOOR, W, H, FLOOR_C)
    hline(img, 0, W, FLOOR, LINE)
    # 窗（左上，夜里，百叶帘拉下一半）
    x0, y0, x1, y1 = 8, 14, 38, 46
    rect(img, x0, y0, x1, y1, NIGHT)
    frame(img, x0, y0, x1, y1, LINE_L)
    vline(img, 23, y0, y1, LINE_L)
    for y in range(y0 + 2, 29, 3):
        hline(img, x0 + 1, x1 - 1, y, LINE)
    hline(img, x0 + 1, x1 - 1, 29, LINE_L)
    for (x, y) in [(12, 41), (19, 38), (29, 42), (34, 36)]:
        img[y][x] = rgb("#5a5a3a")
    # 挂钟
    cx, cy, r = 70, 18, 5
    for y in range(cy - r - 1, cy + r + 2):
        for x in range(cx - r - 1, cx + r + 2):
            d = math.hypot(x - cx, y - cy)
            if d <= r + 0.5:
                img[y][x] = rgb("#3e3a48") if d > r - 0.7 else rgb("#8a8478")
    vline(img, cx, cy - 3, cy + 1, WALL_D)
    hline(img, cx, cx + 3, cy, WALL_D)
    # 医生身后：裱起来的证书
    x0, y0, x1, y1 = 98, 30, 118, 46
    frame(img, x0, y0, x1, y1, WOOD_L)
    rect(img, x0 + 2, y0 + 2, x1 - 2, y1 - 2, rgb("#9a9486"))
    hline(img, x0 + 4, x1 - 4, y0 + 5, rgb("#7a7468"))
    hline(img, x0 + 6, x1 - 6, y0 + 8, rgb("#7a7468"))
    rect(img, x1 - 7, y1 - 6, x1 - 4, y1 - 3, rgb("#8a3a32"))
    # 右边：文件柜（露出一半在画外）
    x0, y0, x1 = 140, 40, 162
    rect(img, x0, y0, x1, FLOOR, rgb("#302c38"))
    frame(img, x0, y0, x1, FLOOR, LINE_L)
    for k in range(3):
        yy = y0 + 2 + k * 12
        frame(img, x0 + 2, yy, x1 - 1, yy + 11, LINE)
        hline(img, x0 + 7, x0 + 12, yy + 4, LINE_L)
    # 文件柜上一盆绿萝：叶子是一团实心的块，垂下来一枝
    rect(img, 145, 34, 152, 40, rgb("#4a3a34"))
    leaf = rgb("#3e5a44"); leaf_l = rgb("#4c6c52")
    for (x0_, x1_, y) in [(146, 151, 31), (144, 154, 32), (143, 155, 33), (144, 146, 34), (151, 155, 34)]:
        hline(img, x0_, x1_, y, leaf)
    hline(img, 147, 151, 31, leaf_l)
    for (x, y) in [(154, 35), (155, 35), (155, 36), (155, 37), (156, 38), (156, 39), (156, 40), (156, 41), (157, 42), (157, 43)]:
        img[y][x] = leaf
    # 左边：一把空着的病人椅（病人没坐）
    x0 = 30
    vline(img, x0, 56, FLOOR, LINE_L)
    vline(img, x0 + 1, 56, 70, LINE_L)
    rect(img, x0, 68, x0 + 12, 70, LINE_L)
    vline(img, x0 + 11, 70, FLOOR, LINE)
    return img


# ---------- 桌子（画在角色前面） ----------
DESK_X0, DESK_X1, DESK_TOP = 74, 136, 70


def desk(img):
    rect(img, DESK_X0, DESK_TOP, DESK_X1, DESK_TOP + 2, WOOD_L)     # 桌面
    rect(img, DESK_X0 + 2, DESK_TOP + 2, DESK_X1 - 2, FLOOR, WOOD)  # 挡板
    rect(img, DESK_X0 + 2, DESK_TOP + 2, DESK_X1 - 2, DESK_TOP + 3, WOOD_D)
    hline(img, DESK_X0 + 6, DESK_X1 - 6, DESK_TOP + 6, WOOD_D)
    # 台灯：灯座在桌面右边，弯脖子，灯罩朝左下
    lamp = rgb("#504a40")
    for (x, y) in [(127, 69), (128, 69), (129, 69), (128, 68), (128, 67), (128, 66), (128, 65),
                   (127, 64), (126, 63), (125, 62)]:
        img[y][x] = lamp
    shade = rgb("#6a5a40")
    hline(img, 121, 126, 61, shade)
    hline(img, 120, 125, 62, shade)
    img[63][121] = rgb("#ffe6b0"); img[63][122] = rgb("#ffe6b0")   # 灯泡
    # 笔筒（挪到医生右手边）
    rect(img, 131, 65, 134, 70, rgb("#3a3a44"))
    img[63][132] = rgb("#7a6a50"); img[64][132] = rgb("#7a6a50"); img[64][133] = rgb("#5a5a7a")
    # 桌牌"医生"：立在桌面靠病人那头，朝镜头
    plate(img)


PLATE_X, PLATE_W, PLATE_H = 75, 26, 14


def plate(img):
    from PIL import ImageDraw, ImageFont
    x0, y1 = PLATE_X, DESK_TOP
    y0 = y1 - PLATE_H
    rect(img, x0, y0, x0 + PLATE_W, y1, rgb("#3e3028"))         # 木座
    rect(img, x0 + 1, y0 + 1, x0 + PLATE_W - 1, y1 - 1, rgb("#e2d6b8"))  # 牌面
    t = Image.new("L", (PLATE_W, PLATE_H), 0)
    d = ImageDraw.Draw(t)
    d.fontmode = "1"
    f = ImageFont.truetype(os.path.join(HERE, "..", "fonts", "PixelFont.ttf"), 12)
    bb = d.textbbox((0, 0), "医生", font=f)
    d.text(((PLATE_W - (bb[2] - bb[0])) // 2 - bb[0], (PLATE_H - (bb[3] - bb[1])) // 2 - bb[1]), "医生", font=f, fill=255)
    for y in range(PLATE_H):
        for x in range(PLATE_W):
            if t.getpixel((x, y)) > 128:
                img[y0 + y][x0 + x] = rgb("#3a2a24")


LAMP = (121.5, 63.5)


# ---------- 光照 ----------
DARK = (0.36, 0.35, 0.41)
LAMP_C = (1.0, 0.82, 0.58)
STEPS = 12


def light_at(x, y):
    # 台灯：灯罩朝左下，光锥落在桌面和两个人身上；锥外只有一点点漏光
    dx, dy = x - LAMP[0], y - LAMP[1]
    d = math.hypot(dx * 0.8, dy * 1.1)
    k = max(0.0, 1.0 - d / 62.0)
    ang = math.atan2(dy, dx)            # 朝左下大约是 2.4 弧度
    cone = max(0.0, math.cos(ang - 2.5))
    k *= 0.35 + 0.65 * cone
    k = round(k * STEPS) / STEPS        # 分档
    k = k ** 1.3 * 1.25
    # 红衣身上自己的一点光（游戏里主角身边一直有一圈亮条颜色的光）
    d2 = math.hypot(x - RED_LIGHT[0], (y - RED_LIGHT[1]) * 0.8)
    k2 = round(max(0.0, 1.0 - d2 / 26.0) * STEPS) / STEPS * 0.45
    return tuple(DARK[i] + LAMP_C[i] * k + RED_C[i] * k2 for i in range(3))


RED_LIGHT = (51.0, 68.0)
RED_C = (1.0, 0.75, 0.75)


_LIGHT = None


def lit(img, glow=()):
    global _LIGHT
    if _LIGHT is None:
        _LIGHT = [[light_at(x, y) for x in range(W)] for y in range(H)]
    out = Image.new("RGB", (W, H))
    px = out.load()
    for y in range(H):
        for x in range(W):
            c = img[y][x]
            if (x, y) in glow:     # 自发光（角色身上的亮条、灯泡）不吃光照
                px[x, y] = c
                continue
            L = _LIGHT[y][x]
            px[x, y] = tuple(min(255, int(c[i] * L[i])) for i in range(3))
    return out


# ---------- 角色 ----------
def load_frames(name):
    body = Image.open(os.path.join(ART, f"{name}_body.png")).convert("RGBA")
    strip = Image.open(os.path.join(ART, f"{name}_strip.png")).convert("RGBA")
    fw = body.width // 7
    return [body.crop((i * fw, 0, (i + 1) * fw, body.height)) for i in range(7)], \
           [strip.crop((i * fw, 0, (i + 1) * fw, strip.height)) for i in range(7)]


RED_B, RED_S = load_frames("red")
BIRD_B, BIRD_S = load_frames("bird")


def blit(img, glow, spr, x0, y0, flip=False, is_glow=False, clip_y=None):
    w, h = spr.size
    for y in range(h):
        for x in range(w):
            sx = w - 1 - x if flip else x
            p = spr.getpixel((sx, y))
            if p[3] == 0:
                continue
            X, Y = x0 + x, y0 + y
            if not (0 <= X < W and 0 <= Y < H):
                continue
            if clip_y is not None and Y >= clip_y:
                continue
            img[Y][X] = p[:3]
            if is_glow:
                glow.add((X, Y))
            else:
                glow.discard((X, Y))


BIRD_D = rgb("#29304a")
BIRD_E = rgb("#2f3650")
BIRD_GLOW = rgb("#c9d4ff")
PEN = rgb("#c8b070")


COAT = {rgb("#292f45"): rgb("#c8c8c4"), rgb("#232a3d"): rgb("#a8aaae"), rgb("#1e2337"): rgb("#9a9ca2")}


def coat(img, glow, bx, by):
    """白大褂：身子（精灵第 7 行往下）换成白灰两档，头和亮条不动；领口留一道 V 字露出里面的蓝"""
    for y in range(by + 7, min(by + 12, DESK_TOP)):
        for x in range(bx, bx + 16):
            if (x, y) in glow:
                continue
            c = img[y][x]
            if c in COAT:
                img[y][x] = COAT[c]
    # 领口：脖子下面两格保持深蓝
    for (dx, dy) in [(6, 7), (7, 8)]:
        img[by + dy][bx + dx] = rgb("#2f3650")


def bird_pose(img, glow, bx, by, pose, pen):
    """蓝鸟朝左（翻转）。pose: idle / hand（举手）。pen: None / hold（翼尖拿着笔）/ desk（笔放在桌上）。
    bx, by：精灵左上角。精灵翻转后：头在左上、喙朝左。"""
    blit(img, glow, BIRD_B[0], bx, by, flip=True, clip_y=DESK_TOP)
    coat(img, glow, bx, by)
    if pose == "idle":
        blit(img, glow, BIRD_S[0], bx, by, flip=True, is_glow=True)
        if pen == "hold":
            # 翅膀前端（亮条左端）夹着一支笔，斜着
            sx = bx + 15 - 9    # 亮条最左边那格
            for (dx, dy) in [(-1, 0), (-2, -1), (-3, -2)]:
                img[by + 7 + dy][sx + dx] = PEN
                glow.discard((sx + dx, by + 7 + dy))
    else:
        # 举手：亮条（翅膀）从肩膀竖起来，翼尖举过头顶
        base_x = bx + 15 - 9 + 3   # 肩膀
        pts = [(base_x, by + 7), (base_x - 1, by + 6), (base_x - 1, by + 5), (base_x - 2, by + 4),
               (base_x - 2, by + 3), (base_x - 2, by + 2), (base_x - 2, by + 1), (base_x - 3, by + 0)]
        # 翅膀的身子（暗色）贴在亮条后面一格
        for (x, y) in pts[:-1]:
            img[y][x + 1] = BIRD_E
            glow.discard((x + 1, y))
        for (x, y) in pts:
            img[y][x] = BIRD_GLOW
            glow.add((x, y))
        # 原来那条横着的亮条只剩肩膀一小截
        for x in range(base_x + 1, base_x + 3):
            img[by + 7][x] = BIRD_GLOW
            glow.add((x, by + 7))
    if pen == "desk":
        for x in range(112, 115):
            img[DESK_TOP - 1][x] = PEN
            glow.discard((x, DESK_TOP - 1))


def red_pose(img, glow, rx, ry, frame=0):
    blit(img, glow, RED_B[frame], rx, ry)
    blit(img, glow, RED_S[frame], rx, ry, is_glow=True)


REPORT_DX = [0]
# 报告：放在桌面靠近病人一侧
def report(img, glow, page):
    if page is None:
        return
    x0 = 103 + REPORT_DX[0]
    c = PAPER if page == 1 else rgb("#c8c2b4")
    for x in range(x0, x0 + 9):
        img[DESK_TOP - 1][x] = c
    if page == 2:
        img[DESK_TOP - 2][x0 + 8] = c   # 翻过来的那页翘着角


# ---------- 合成一帧 ----------
BG = None


def compose(st):
    global BG
    REPORT_DX[0] = st.get("report_dx", 0)
    if BG is None:
        BG = background()
    img = [row[:] for row in BG]
    glow = {(180, 101), (181, 101)}
    # 角色呼吸：每 2 秒上下 1 像素（只在 idle 时）
    t = st.get("t", 0.0)
    rb = 1 if (int(t * 1.0) % 2 == 1 and st.get("breathe", True)) else 0
    red_pose(img, glow, 44, FLOOR - 20 + rb)
    report(img, glow, st.get("report"))
    bb = 1 if (int(t * 1.0 + 0.5) % 2 == 1 and st.get("breathe", True)) else 0
    bird_pose(img, glow, 103, FLOOR - 20 + bb - 6, st.get("bird", "idle"), st.get("pen"))
    desk(img)
    report_on = st.get("report")
    report(img, glow, report_on)
    if st.get("pen") == "desk":
        for x in range(112, 115):
            img[DESK_TOP - 1][x] = PEN
    out = lit(img, glow)
    return out.resize((W * SCALE, H * SCALE), Image.NEAREST)


# ---------- 动画片段 ----------
def clip_states(name, secs):
    """返回每帧的状态字典"""
    n = int(secs * FPS)
    out = []
    for i in range(n):
        t = i / FPS
        st = {"t": t, "report": 1}
        if name == "loop_pen":          # 对话循环：医生手里拿着笔
            st.update(bird="idle", pen="hold")
        elif name == "loop":            # 对话循环：笔在桌上
            st.update(bird="idle", pen="desk")
        elif name == "put_pen":         # 医生停半秒，把笔放下（第 2 秒放下）
            st.update(bird="idle", pen="hold" if t < 2.0 else "desk")
        elif name == "hand":            # 医生举手（第 2 秒举），举着
            st.update(bird="hand" if t >= 2.0 else "idle", pen="desk")
        elif name == "hand_down":       # 医生举着手，第 2 秒放下
            st.update(bird="hand" if t < 2.0 else "idle", pen="desk")
        elif name == "flip_give":      # 结尾：医生把桌上的报告翻到第二页，推到病人那边（第 2 秒翻、第 3 秒推）
            st.update(bird="idle", pen="hold", report=1 if t < 2.0 else 2)
            st["report_dx"] = 0 if t < 3.0 else -min(8, int((t - 3.0) * 16))
        elif name == "pen_hand":        # 结尾：医生重新拿起笔（第 2 秒），举手（第 4 秒）
            st.update(bird="hand" if t >= 4.0 else "idle", pen="desk" if t < 2.0 else "hold")
        out.append(st)
    return out


def render_clip(name, secs, path):
    tmp = path + ".frames"
    os.makedirs(tmp, exist_ok=True)
    last = None
    for i, st in enumerate(clip_states(name, secs)):
        key = (st.get("bird"), st.get("pen"), st.get("report"), st.get("report_dx", 0), int(st["t"]) % 2, int(st["t"] + 0.5) % 2)
        if key != last:
            im = compose(st)
            last = key
        im.save(os.path.join(tmp, "%05d.png" % i))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(tmp, "%05d.png"),
                    "-c:v", "libx264", "-crf", "12", "-pix_fmt", "yuv420p", path], check=True)
    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)


if __name__ == "__main__":
    if sys.argv[1] == "still":
        compose({"t": 0.0, "report": 1, "bird": sys.argv[3] if len(sys.argv) > 3 else "idle", "pen": "hold"}).save(sys.argv[2])
    elif sys.argv[1] == "clip":
        render_clip(sys.argv[2], float(sys.argv[3]), sys.argv[4])
