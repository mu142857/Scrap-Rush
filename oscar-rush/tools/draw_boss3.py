"""第三关最终 Boss「老电视 THE SET」、它的房间「最深处」，和结局用的家乡画面。

    python3 tools/draw_boss3.py

Boss：一台巨大的木壳老电视，照第三关的画法（Oscar 的光照色块：每个面按左上的光切成一档档，
暖棕木头 + 灰塑料，颜色取自 l3_* 图层）。朝左（屏幕正对玩家），地面是画布最后一行。
屏幕里的频道内容、两个旋钮、电源红灯、天线尖上的电火花由游戏代码画。

房间：背景是第三关电视墙的一角，整面压暗、褪色（屏幕全关了，只有 Boss 一台亮着）；
前景：木地板 + 中间一块旧地毯（家的感觉）、三台用电线吊着的旧电视当平台、木头闸门。
结局：从第三关终点那块"家乡"屏幕切出来的画面 hometown.png（444×245）。

输出 art/boss/：tv_body.png、room3_bg.png、room3_fg.png、gate3.png、hometown.png、preview_tv.png
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/boss"

PAL = {
    # 木头（暗 → 亮），取自第三关电视框
    "W0": (36, 20, 14), "W1": (40, 22, 16), "W2": (79, 42, 20), "W3": (86, 46, 22), "W4": (134, 77, 31),
    "W5": (146, 84, 34), "W6": (187, 117, 49), "W7": (204, 128, 54), "W8": (218, 163, 88), "W9": (238, 178, 96),
    # 灰塑料 / 屏幕框
    "P0": (25, 27, 34), "P1": (39, 44, 56), "P2": (80, 86, 104), "P3": (120, 128, 146), "P4": (170, 176, 196),
    # 地毯
    "C0": (70, 24, 22), "C1": (98, 36, 30), "C2": (128, 52, 38), "C3": (170, 120, 70),
}

W, H = 128, 120
GROUND = H - 1
SCREEN = (20, 42, 88, 92)        # 屏幕玻璃（代码画内容）
KNOBS = [(105, 50), (105, 63)]    # 两个旋钮（代码画）
LED = (104, 99)                  # 电源红灯（代码画）
ANTENNA_TIPS = [(36, 4), (93, 2)]


class G:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.full((h, w), None, dtype=object)

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def poly(self, pts, c):
        ys = [p[1] for p in pts]
        for y in range(min(ys), max(ys) + 1):
            xs = []
            for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]):
                if (y0 <= y < y1) or (y1 <= y < y0):
                    xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for a, b in zip(xs[::2], xs[1::2]):
                for x in range(int(round(a)), int(round(b)) + 1):
                    self.put(x, y, c)

    def rgba(self):
        out = np.zeros((self.h, self.w, 4), np.uint8)
        for y in range(self.h):
            for x in range(self.w):
                c = self.a[y, x]
                if c is not None:
                    out[y, x, :3] = PAL[c]
                    out[y, x, 3] = 255
        return out


def body():
    g = G(W, H)
    # 四条往外撇的木头小腿
    for x, lean in [(18, -3), (34, -1), (94, 1), (110, 3)]:
        for y in range(104, GROUND + 1):
            k = (y - 104) / (GROUND - 104)
            xx = round(x + lean * k)
            g.rect(xx - 1, y, xx + 1, y, "W4" if lean < 0 else "W2")
            g.put(xx - 1, y, "W6")
        g.rect(round(x + lean) - 2, GROUND, round(x + lean) + 2, GROUND, "W2")
    # 机壳：正面一大块，左上亮右下暗；顶面一条更亮（看得到一点顶）
    g.rect(8, 34, 120, 104, "W4")
    g.rect(8, 30, 120, 33, "W8")
    g.rect(8, 30, 120, 30, "W9")
    g.rect(118, 34, 120, 104, "W2")        # 右侧面暗
    g.rect(8, 103, 120, 104, "W1")         # 底边阴影
    g.rect(8, 34, 9, 102, "W6")            # 左边亮棱
    # 正面按光照切几块（色块派：亮面一档、暗面一档）
    g.poly([(10, 34), (40, 34), (14, 70), (10, 70)], "W5")
    g.poly([(70, 104), (117, 60), (117, 104)], "W3")
    g.poly([(40, 104), (60, 96), (117, 96), (117, 104)], "W2")
    # 屏幕框：深灰塑料圆角框，玻璃那块代码画
    sx0, sy0, sx1, sy1 = SCREEN
    g.rect(sx0 - 4, sy0 - 4, sx1 + 4, sy1 + 4, "P1")
    g.rect(sx0 - 4, sy0 - 4, sx1 + 4, sy0 - 4, "P2")
    g.rect(sx0 - 4, sy0 - 4, sx0 - 4, sy1 + 4, "P2")
    for cx, cy in [(sx0 - 4, sy0 - 4), (sx1 + 4, sy0 - 4), (sx0 - 4, sy1 + 4), (sx1 + 4, sy1 + 4)]:
        g.put(cx, cy, None)
    g.rect(sx0, sy0, sx1, sy1, "P0")
    # 右边的控制面板：灰塑料，两个旋钮的底座、喇叭格栅
    g.rect(95, 40, 115, 96, "P2")
    g.rect(95, 40, 115, 40, "P3")
    g.rect(95, 40, 95, 96, "P3")
    g.rect(115, 40, 115, 96, "P1")
    for kx, ky in KNOBS:
        g.rect(kx - 5, ky - 5, kx + 5, ky + 5, "P1")
    for y in range(74, 94, 2):
        g.rect(98, y, 112, y, "P1")
    g.rect(101, 97, 107, 101, "W2")       # 电源灯底座
    # 兔耳天线：底座 + 两根细杆
    g.rect(58, 26, 70, 29, "P2")
    g.rect(58, 26, 70, 26, "P3")
    for tx, ty in ANTENNA_TIPS:
        g.line(64, 26, tx, ty, "P3")
        g.line(65, 26, tx + 1, ty, "P1")
        g.rect(tx - 1, ty - 1, tx + 1, ty + 1, "P4")
    return g


# —— 房间 ——
M = 16
AW, AH = 320, 180
CW, CH = AW + 2 * M, AH + 2 * M
FLOOR_Y, WALL, CEIL = 164, 8, 12
PLATFORMS = [(22, 74, 124), (106, 158, 98), (34, 86, 70)]
CROP = (2600, 420)


def px(img, x, y, c):
    if 0 <= x < img.shape[1] and 0 <= y < img.shape[0]:
        img[y, x, :3] = PAL[c]
        img[y, x, 3] = 255


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def l3_composite():
    base = None
    for n in ["l3_far", "l3_mid", "l3_screens", "l3_near"]:
        im = Image.open(ROOT / f"art/levels/{n}.png").convert("RGBA")
        base = im if base is None else Image.alpha_composite(base, im)
    return base


def background(base):
    x, y = CROP
    bg = np.array(base.crop((x, y, x + CW, y + CH))).astype(float)
    # 电视墙全关了：去饱和、压得很暗，四角更暗
    gray = bg[..., :3].mean(axis=2, keepdims=True)
    bg[..., :3] = bg[..., :3] * 0.35 + gray * 0.65
    yy, xx = np.mgrid[0:CH, 0:CW]
    d = np.hypot((xx - CW * 0.6) / (CW / 2), (yy - CH * 0.55) / (CH * 0.7))
    vign = np.clip(1.0 - 0.6 * d, 0.3, 1.0)
    bg[..., :3] *= 0.32 * vign[..., None]
    bg[..., 2] *= 1.12
    bg[..., 3] = 255
    return bg.clip(0, 255).astype(np.uint8)


def foreground():
    img = np.zeros((CH, CW, 4), np.uint8)
    fy = FLOOR_Y + M
    # 木地板：一条条木板，接缝暗
    rect(img, 0, fy, CW - 1, CH - 1, "W2")
    rect(img, 0, fy, CW - 1, fy, "W6")
    for x in range(0, CW, 22):
        rect(img, x, fy + 1, x, CH - 1, "W0")
    for y in range(fy + 6, CH, 6):
        rect(img, 0, y, CW - 1, y, "W1")
    # 中间一块旧地毯：暗红底、浅色花边
    x0, x1 = 60 + M, 230 + M
    rect(img, x0, fy, x1, fy + 2, "C1")
    rect(img, x0, fy, x1, fy, "C2")
    for x in range(x0 + 2, x1 - 1, 4):
        px(img, x, fy + 1, "C3")
    rect(img, x0 - 2, fy, x0 - 1, fy + 1, "C3")
    rect(img, x1 + 1, fy, x1 + 2, fy + 1, "C3")
    # 两边的墙：暗木板
    for xa, xb in [(0, WALL + M - 1), (CW - WALL - M, CW - 1)]:
        rect(img, xa, 0, xb, fy - 1, "W1")
        edge = xb if xa == 0 else xa
        rect(img, edge, 0, edge, fy - 1, "W4")
    # 天花板：一根暗梁，垂下几根电线
    cy = CEIL + M
    rect(img, 0, 0, CW - 1, cy, "P0")
    rect(img, 0, cy, CW - 1, cy, "P2")
    # 吊着的旧电视当平台：两根电线吊着，顶面是平台，下面一个关着的小屏幕
    for xa, xb, top in PLATFORMS:
        X0, X1, T = xa + M, xb + M, top + M
        for rx in (X0 + 6, X1 - 6):
            rect(img, rx, cy + 1, rx, T - 1, "P1")
        rect(img, X0, T, X1, T + 14, "W4")
        rect(img, X0, T, X1, T, "W9")
        rect(img, X0, T + 1, X1, T + 1, "W7")
        rect(img, X1 - 1, T + 1, X1, T + 14, "W2")
        rect(img, X0 + 4, T + 4, X1 - 12, T + 12, "P1")
        rect(img, X0 + 5, T + 5, X1 - 13, T + 11, "P0")
        rect(img, X1 - 9, T + 5, X1 - 4, T + 6, "P2")
        rect(img, X1 - 9, T + 9, X1 - 4, T + 9, "P1")
    return img


def gate():
    g = np.zeros((40, WALL + 2, 4), np.uint8)
    rect(g, 0, 0, WALL + 1, 39, "W3")
    rect(g, 0, 0, 0, 39, "W6")
    for y in range(4, 40, 9):
        rect(g, 0, y, WALL + 1, y, "W1")
    return g


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tv = body().rgba()
    Image.fromarray(tv).save(OUT / "tv_body.png")
    base = l3_composite()
    bg, fg, gt = background(base), foreground(), gate()
    Image.fromarray(bg).save(OUT / "room3_bg.png")
    Image.fromarray(fg).save(OUT / "room3_fg.png")
    Image.fromarray(gt).save(OUT / "gate3.png")
    # 家乡画面：第三关终点那块屏幕（hometown，rect 4503,108 → 4946,352）
    base.crop((4503, 108, 4947, 353)).save(OUT / "hometown.png")
    prev = Image.fromarray(bg).convert("RGBA")
    prev.alpha_composite(Image.fromarray(fg))
    prev.alpha_composite(Image.fromarray(tv), (256 + M - W // 2, FLOOR_Y + M - H + 1))
    hero = Image.open(ROOT / "art/chars/red_body.png").convert("RGBA").crop((0, 0, 16, 20))
    prev.alpha_composite(hero, (40 + M - 8, FLOOR_Y + M - 20))
    prev.resize((CW * 3, CH * 3), Image.NEAREST).save(OUT / "preview_tv.png")
    print("wrote tv_body.png room3_bg.png room3_fg.png gate3.png hometown.png preview_tv.png")


if __name__ == "__main__":
    main()
