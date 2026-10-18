"""第三关最终 Boss「老电视 THE SET」、它的房间「最深处」，和结局用的家乡画面。

    python3 tools/draw_boss3.py

Boss：一台长了四条细木腿、会满地乱跑的木壳老电视（腿由游戏代码画），照第三关的画法（Oscar 的光照色块：每个面按左上的光切成一档档，
暖棕木头 + 灰塑料，颜色取自 l3_* 图层）。朝左（屏幕正对玩家），地面是画布最后一行。
屏幕里的频道内容、两个旋钮、电源红灯、天线尖上的电火花由游戏代码画。

房间：背景是第三关电视墙的一角，整面压暗、褪色（屏幕全关了，只有 Boss 一台亮着）；
前景：木地板 + 中间一块旧地毯（家的感觉）、两边墙上的低搁板、三台用电线吊着的旧电视当平台、木头闸门。
结局用的家乡画面 hometown.png 由 草图/第三关/export_level3.py 导出，不归这个脚本。

输出 art/boss/：tv_body.png、room3_bg.png、room3_fg.png、gate3.png、preview_tv.png
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/boss"
## 预览图只给人看，不放进 art/（不然会被打进网页版包里）
PREVIEW = Path(__file__).resolve().parent.parent.parent / "草图/boss预览"


PAL = {
    # 木头（暗 → 亮），取自第三关电视框
    "W0": (36, 20, 14), "W1": (40, 22, 16), "W2": (79, 42, 20), "W3": (86, 46, 22), "W4": (134, 77, 31),
    "W5": (146, 84, 34), "W6": (187, 117, 49), "W7": (204, 128, 54), "W8": (218, 163, 88), "W9": (238, 178, 96),
    # 灰塑料 / 屏幕框
    "P0": (25, 27, 34), "P1": (39, 44, 56), "P2": (80, 86, 104), "P3": (120, 128, 146), "P4": (170, 176, 196),
    # 地毯
    "C0": (70, 24, 22), "C1": (98, 36, 30), "C2": (128, 52, 38), "C3": (170, 120, 70),
}

W, H = 88, 79
GROUND = H - 1                   # 腿由代码画（会走、会蹲、会跳），画布底下 12 行留给腿
CASE = (4, 22, 84, 66)           # 木壳
SCREEN = (12, 30, 58, 60)        # 屏幕玻璃（代码画内容）
KNOBS = [(72, 36), (72, 46)]     # 两个旋钮（代码画）
LED = (71, 62)                   # 电源红灯（代码画）
ANTENNA_TIPS = [(24, 3), (66, 1)]


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
    x0, y0, x1, y1 = CASE
    # 机壳：正面一大块，左上亮右下暗；顶面一条更亮（看得到一点顶）
    g.rect(x0, y0 + 4, x1, y1, "W4")
    g.rect(x0, y0, x1, y0 + 3, "W8")
    g.rect(x0, y0, x1, y0, "W9")
    g.rect(x1 - 2, y0 + 4, x1, y1, "W2")        # 右侧面暗
    g.rect(x0, y1 - 1, x1, y1, "W1")            # 底边阴影
    g.rect(x0, y0 + 4, x0 + 1, y1 - 2, "W6")    # 左边亮棱
    # 正面按光照切几块（色块派：亮面一档、暗面一档）
    g.poly([(x0 + 2, y0 + 4), (x0 + 22, y0 + 4), (x0 + 5, y0 + 26), (x0 + 2, y0 + 26)], "W5")
    g.poly([(x0 + 42, y1), (x1 - 3, y0 + 18), (x1 - 3, y1)], "W3")
    g.poly([(x0 + 24, y1), (x0 + 38, y1 - 5), (x1 - 3, y1 - 5), (x1 - 3, y1)], "W2")
    # 底下四个腿座（腿本身代码画）
    for lx in (14, 30, 58, 74):
        g.rect(lx - 2, y1 + 1, lx + 2, y1 + 2, "W2")
        g.put(lx - 2, y1 + 1, "W6")
    # 屏幕框：深灰塑料圆角框，玻璃那块代码画
    sx0, sy0, sx1, sy1 = SCREEN
    g.rect(sx0 - 3, sy0 - 3, sx1 + 3, sy1 + 3, "P1")
    g.rect(sx0 - 3, sy0 - 3, sx1 + 3, sy0 - 3, "P2")
    g.rect(sx0 - 3, sy0 - 3, sx0 - 3, sy1 + 3, "P2")
    for cx, cy in [(sx0 - 3, sy0 - 3), (sx1 + 3, sy0 - 3), (sx0 - 3, sy1 + 3), (sx1 + 3, sy1 + 3)]:
        g.put(cx, cy, None)
    g.rect(sx0, sy0, sx1, sy1, "P0")
    # 右边的控制面板：灰塑料，两个旋钮的底座、喇叭格栅
    g.rect(64, 28, 80, 62, "P2")
    g.rect(64, 28, 80, 28, "P3")
    g.rect(64, 28, 64, 62, "P3")
    g.rect(80, 28, 80, 62, "P1")
    for kx, ky in KNOBS:
        g.rect(kx - 4, ky - 4, kx + 4, ky + 4, "P1")
    for y in range(52, 59, 2):
        g.rect(67, y, 77, y, "P1")
    g.rect(69, 60, 73, 63, "W2")          # 电源灯底座
    # 兔耳天线：底座 + 两根细杆
    g.rect(38, 18, 50, 21, "P2")
    g.rect(38, 18, 50, 18, "P3")
    for tx, ty in ANTENNA_TIPS:
        g.line(44, 18, tx, ty, "P3")
        g.line(45, 18, tx + 1, ty, "P1")
        g.rect(tx - 1, ty - 1, tx + 1, ty + 1, "P4")
    return g


# —— 房间 ——
M = 24
AW, AH = 320, 180
CW, CH = AW + 2 * M, AH + 2 * M
FLOOR_Y, WALL, CEIL = 164, 8, 12
# 老电视会在地上来回冲撞、跳砸，所以场地是"往上躲"：
#   两边墙上一块低搁板（踏脚用，挡不住冲撞）→ 两台吊着的旧电视（高过老电视的壳，冲撞时躲这里）→ 正中最高一台
SHELVES = [(8, 52, 130), (268, 312, 130)]
HANGING = [(36, 92, 94), (228, 284, 94), (134, 186, 62)]
PLATFORMS = SHELVES + HANGING
CROP = (2592, 412)


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


def limit_colors(arr, n=40):
    """收成 n 色、不抖动：暗角是连续渐变，不收的话一张背景有七百多种颜色，放大以后发糊、和前景的硬边像素对不上（美术巡检提的）"""
    im = Image.fromarray(arr).convert("RGB").quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return np.array(im.convert("RGBA"))


def background(base):
    x, y = CROP
    bg = np.array(base.crop((x, y, x + CW, y + CH))).astype(float)
    # 电视墙全关了：去饱和、压得很暗，四角更暗
    gray = bg[..., :3].mean(axis=2, keepdims=True)
    bg[..., :3] = bg[..., :3] * 0.35 + gray * 0.65
    yy, xx = np.mgrid[0:CH, 0:CW]
    d = np.hypot((xx - CW * 0.6) / (CW / 2), (yy - CH * 0.55) / (CH * 0.7))
    # 夜间打磨：原来 ×0.32、暗角最低 0.3，中位亮度只有 16/255，沙发、相框都看不见。提到 ×0.5、暗角最低 0.45，还是暗，但看得出是一间屋子
    vign = np.clip(1.0 - 0.5 * d, 0.45, 1.0)
    bg[..., :3] *= 0.5 * vign[..., None]
    bg[..., 2] *= 1.12
    bg[..., 3] = 255
    return limit_colors(bg.clip(0, 255).astype(np.uint8))


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
    # 墙上的搁板：一块木板，两个铁三角托架，上面摆几盒录像带
    for xa, xb, top in SHELVES:
        X0, X1, T = xa + M, xb + M, top + M
        rect(img, X0, T, X1, T + 2, "W5")
        rect(img, X0, T, X1, T, "W8")
        rect(img, X0, T + 3, X1, T + 3, "W1")
        wall_x = X0 if xa <= WALL else X1
        inner = X1 - 6 if xa <= WALL else X0 + 6
        for bx in (X0 + 10, X1 - 10):
            for k in range(8):
                px(img, bx, T + 4 + k, "P1")
            for k in range(8):
                xx = round(bx + (wall_x - bx) * k / 8)
                px(img, xx, T + 4 + k, "P1")
        for i, tx in enumerate(range(min(X0, X1) + 14, max(X0, X1) - 12, 5)):
            rect(img, tx, T - 7, tx + 3, T - 1, "P1" if i % 2 else "P0")
            rect(img, tx + 1, T - 5, tx + 2, T - 4, "C3" if i % 3 == 0 else "P3")
    # 吊着的旧电视当平台：两根电线吊着，顶面是平台，下面一个关着的小屏幕
    for xa, xb, top in HANGING:
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
    PREVIEW.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    tv = body().rgba()
    Image.fromarray(tv).save(OUT / "tv_body.png")
    base = l3_composite()
    bg, fg, gt = background(base), foreground(), gate()
    Image.fromarray(bg).save(OUT / "room3_bg.png")
    Image.fromarray(fg).save(OUT / "room3_fg.png")
    Image.fromarray(gt).save(OUT / "gate3.png")
    # 家乡画面 hometown.png 不在这里生成了：第三关地图改过，改由 草图/第三关/export_level3.py 按当前家乡屏幕导出（剧情会话负责）
    prev = Image.fromarray(bg).convert("RGBA")
    prev.alpha_composite(Image.fromarray(fg))
    prev.alpha_composite(Image.fromarray(tv), (200 + M - W // 2, FLOOR_Y + M - H + 1))
    hero = Image.open(ROOT / "art/chars/red_body.png").convert("RGBA").crop((0, 0, 16, 20))
    prev.alpha_composite(hero, (40 + M - 8, FLOOR_Y + M - 20))
    prev.resize((CW * 3, CH * 3), Image.NEAREST).save(PREVIEW / "preview_tv.png")
    print("wrote tv_body.png room3_bg.png room3_fg.png gate3.png preview_tv.png")


if __name__ == "__main__":
    main()
