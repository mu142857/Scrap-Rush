"""第一关 Boss 房间「炉膛间」的美术。

    python3 tools/draw_boss_room.py

背景：取 Oscar 第一关场景（场景1.aseprite 拆出来的 far/beams/machines/truss 四层）中间那片
左右对称的倒三角桁架，压暗、偏暖红，再加两根插进天花板的大锈管（锅炉的管道）。
前景自己画，和普通关卡拉开差别：黄黑警戒条、吊在链子上的三块平台、铆钉钢板地面、蒸汽格栅。

房间（竞技场）是 320×180 个游戏像素，画布四边各多留 16 像素给震屏，所以图是 352×212，
竞技场坐标 (x, y) 对应画布 (x+16, y+16)。碰撞和格栅的位置见 ROOM 常量，游戏代码里要对上。
输出 art/boss/：room_bg.png、room_fg.png、gate.png（闸门，代码里上下滑）、preview_room.png
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/boss"
## 预览图只给人看，不放进 art/（不然会被打进网页版包里）
PREVIEW = Path(__file__).resolve().parent.parent.parent / "草图/boss预览"

M = 24                      # 画布四边多出来的边
AW, AH = 320, 180           # 竞技场
CW, CH = AW + 2 * M, AH + 2 * M
CROP = (372, -8)             # 从场景1 取背景的位置（左上角）

# 竞技场坐标。改了这里，boss_room.gd 里的 FLOOR_Y / PLATFORMS / VENTS 也要改
FLOOR_Y = 164
WALL = 8
CEIL = 12
PLATFORMS = [(20, 76, 128), (100, 156, 104), (30, 86, 78)]   # (x0, x1, 顶面 y)
VENTS = [50, 128, 196]                                         # 格栅中心 x
PIPES = [236, 296]                                             # Boss 背后的大管子

PAL = {
    0: (18, 17, 16), 1: (26, 25, 24), 2: (29, 27, 26), 3: (36, 34, 33), 4: (42, 40, 40),
    5: (50, 48, 46), 6: (59, 56, 53), 7: (75, 71, 66), 8: (79, 75, 71), 9: (92, 87, 82),
    "y": (201, 154, 46), "Y": (226, 184, 72), "k": (30, 26, 22),      # 警戒条黄、亮黄、黑
    "r2": (54, 47, 44), "r3": (69, 54, 46), "r4": (90, 68, 52),       # 锈
}


def px(img, x, y, c):
    if 0 <= x < img.shape[1] and 0 <= y < img.shape[0]:
        img[y, x, :3] = PAL[c]
        img[y, x, 3] = 255


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def hazard(img, x0, y0, x1, y1, phase=0, width=3):
    """黄黑斜条：每条 width 像素宽，往右上斜"""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            stripe = ((x + y + phase) // width) % 2
            px(img, x, y, "y" if stripe == 0 else "k")
    # 顶边亮一档
    for x in range(x0, x1 + 1):
        if ((x + y0 + phase) // width) % 2 == 0:
            px(img, x, y0, "Y")


def limit_colors(arr, n=40):
    """收成 n 色、不抖动：暗角是连续渐变，不收的话一张背景有七百多种颜色，放大以后发糊、和前景的硬边像素对不上（美术巡检提的）"""
    im = Image.fromarray(arr).convert("RGB").quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return np.array(im.convert("RGBA"))


def background():
    layers = None
    for name in ["far", "beams", "machines", "truss"]:
        im = Image.open(ROOT / f"art/levels/scene1_{name}.png").convert("RGBA")
        layers = im if layers is None else Image.alpha_composite(layers, im)
    x, y = CROP
    bg = np.array(layers.crop((x, y, x + CW, y + CH))).astype(float)
    # 压暗、偏暖红（锅炉房里热），四角再暗一点
    yy, xx = np.mgrid[0:CH, 0:CW]
    d = np.hypot((xx - CW / 2) / (CW / 2), (yy - CH * 0.6) / (CH * 0.7))
    vign = np.clip(1.15 - 0.55 * d, 0.45, 1.0)
    bg[..., 0] *= 0.82 * vign
    bg[..., 1] *= 0.70 * vign
    bg[..., 2] *= 0.68 * vign
    bg[..., 3] = 255
    out = bg.clip(0, 255).astype(np.uint8)
    # Boss 背后两根大锈管，从天花板一直插到地面
    for cx in PIPES:
        x0 = cx + M - 4
        rect(out, x0, 0, x0 + 8, FLOOR_Y + M, "r2")
        rect(out, x0, 0, x0 + 1, FLOOR_Y + M, "r4")
        rect(out, x0 + 2, 0, x0 + 2, FLOOR_Y + M, "r3")
        rect(out, x0 + 8, 0, x0 + 8, FLOOR_Y + M, 2)
        for fy in range(30, FLOOR_Y + M, 34):        # 法兰盘
            rect(out, x0 - 1, fy, x0 + 9, fy + 2, "r3")
            rect(out, x0 - 1, fy, x0 + 9, fy, "r4")
    return limit_colors(out)


def foreground():
    img = np.zeros((CH, CW, 4), np.uint8)
    # —— 地面：铆钉钢板，顶边最亮；下面一道警戒条 ——
    fy = FLOOR_Y + M
    rect(img, 0, fy, CW - 1, CH - 1, 4)
    rect(img, 0, fy, CW - 1, fy, 9)
    rect(img, 0, fy + 1, CW - 1, fy + 1, 7)
    hazard(img, 0, fy + 3, CW - 1, fy + 6)
    rect(img, 0, fy + 7, CW - 1, fy + 7, 2)
    for x in range(0, CW, 32):
        rect(img, x, fy + 8, x, CH - 1, 2)
        for ry in range(fy + 10, CH, 6):
            px(img, x + 3, ry, 8)
            px(img, x + 28, ry, 8)
    # 蒸汽格栅：地面上挖一条带框的缝
    for vx in VENTS:
        x0 = vx + M - 8
        rect(img, x0, fy, x0 + 16, fy + 2, 2)
        rect(img, x0, fy, x0 + 16, fy, 7)
        for gx in range(x0 + 1, x0 + 16, 3):
            rect(img, gx, fy + 1, gx, fy + 2, 0)
    # —— 两边的墙：粗钢柱，底部刷警戒条（闸门由代码单独画） ——
    for x0, x1 in [(0, WALL + M - 1), (CW - WALL - M, CW - 1)]:
        rect(img, x0, 0, x1, fy - 1, 3)
        edge = x1 if x0 == 0 else x0
        rect(img, edge, 0, edge, fy - 1, 7)
        for ry in range(8, fy, 10):
            px(img, (edge - 2) if x0 == 0 else (edge + 2), ry, 8)
        hazard(img, x0, fy - 10, x1, fy - 1, phase=1)
    # —— 天花板：一根大工字梁，上面挂警报灯的底座 ——
    cy = CEIL + M
    rect(img, 0, 0, CW - 1, cy, 3)
    rect(img, 0, cy, CW - 1, cy, 7)
    rect(img, 0, cy - 4, CW - 1, cy - 4, 5)
    for rx in range(4, CW, 6):
        px(img, rx, cy - 2, 8)
    for lx in (80, 240):
        rect(img, lx + M - 3, cy + 1, lx + M + 3, cy + 3, 5)
        rect(img, lx + M - 3, cy + 1, lx + M + 3, cy + 1, 8)
    # —— 吊着的平台：链子 + 钢板 + 正面警戒条 ——
    for x0, x1, top in PLATFORMS:
        X0, X1, T = x0 + M, x1 + M, top + M
        for chx in (X0 + 4, X1 - 4):
            for ry in range(cy + 1, T):
                px(img, chx, ry, 6 if ry % 4 < 2 else 8)
                if ry % 4 == 2:
                    px(img, chx - 1, ry, 5)
                    px(img, chx + 1, ry, 5)
        rect(img, X0, T, X1, T, 9)
        hazard(img, X0, T + 1, X1, T + 3, phase=x0)
        rect(img, X0, T + 4, X1, T + 4, 3)
        rect(img, X0 + 2, T + 5, X1 - 2, T + 5, 1)    # 底下一条影子
    return img


def gate():
    g = np.zeros((40, WALL + 2, 4), np.uint8)
    hazard(g, 0, 0, WALL + 1, 39, width=4)
    rect(g, 0, 0, WALL + 1, 0, 9)
    rect(g, 0, 39, WALL + 1, 39, 2)
    return g


def main():
    PREVIEW.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    bg, fg, gt = background(), foreground(), gate()
    Image.fromarray(bg).save(OUT / "room_bg.png")
    Image.fromarray(fg).save(OUT / "room_fg.png")
    Image.fromarray(gt).save(OUT / "gate.png")
    prev = Image.fromarray(bg).convert("RGBA")
    prev.alpha_composite(Image.fromarray(fg))
    for layer in ["stoker_legs", "stoker_body", "stoker_door"]:
        im = Image.open(OUT / f"{layer}.png").convert("RGBA")
        if layer == "stoker_door":
            im = im.crop((0, 0, 84, 96))
        prev.alpha_composite(im, (258 + M - 42, FLOOR_Y + M - 96 + 1))
    prev.alpha_composite(Image.fromarray(gt), (M - 1, FLOOR_Y + M - 40))
    hero = Image.open(ROOT / "art/chars/red_body.png").convert("RGBA").crop((0, 0, 16, 20))
    prev.alpha_composite(hero, (40 + M - 8, FLOOR_Y + M - 20))
    prev.resize((CW * 3, CH * 3), Image.NEAREST).save(PREVIEW / "preview_room.png")
    print("wrote room_bg.png room_fg.png gate.png preview_room.png")


if __name__ == "__main__":
    main()
