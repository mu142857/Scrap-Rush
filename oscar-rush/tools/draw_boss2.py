"""第二关 Boss「总机 THE OPERATOR」和它的房间「总机室」。

    python3 tools/draw_boss2.py

Boss：一台成了精的巨型电话交换台。照怪物的统一画法（暗色机身、红色指示灯当眼睛、几条腿），
颜色用第二关的暗红 + 黄铜 + 中性灰（从 level2_back/props 取的色）。朝左，地面是画布最后一行。
会动的部分由游戏代码画：脸上的转盘拨号盘、头顶两只铃铛、转盘中间的红灯、插孔上方的信号小灯、天车缆绳。
开打后上半截（head）离开桌子（desk），吊在天花板的天车轨道上满屋追人、往下砸；桌子留在原地当平台。

房间：背景取第二关交换台大厅（level2 的 far/mid/back/props 四层，x=300 起），压暗；
前景：三块铜板拼的地面（"占线"时会轮流通电）、两张立在地上的矮长凳、天花板的天车轨道、黄铜格栅闸门。
竞技场 320×180，画布四边多 16 像素给震屏（352×212），坐标和 boss2_room.gd 对上。

输出 art/boss/：operator_head.png（会飞的上半截）、operator_desk.png（留在房间里的桌子）、room2_bg.png、room2_fg.png、gate2.png、preview_operator.png
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/boss"
## 预览图只给人看，不放进 art/（不然会被打进网页版包里）
PREVIEW = Path(__file__).resolve().parent.parent.parent / "草图/boss预览"


PAL = {
    # 暗红木（交换台）
    "R0": (36, 12, 6), "R1": (52, 16, 7), "R2": (61, 19, 7), "R3": (81, 25, 9), "R4": (96, 29, 10), "R5": (122, 46, 20),
    # 黄铜
    "B0": (72, 49, 33), "B1": (96, 66, 42), "B2": (117, 88, 53), "B3": (134, 117, 63), "B4": (147, 111, 68),
    "B5": (170, 150, 92), "B6": (181, 142, 96),
    # 灰
    "G0": (19, 17, 16), "G1": (24, 22, 20), "G2": (30, 27, 24), "G3": (56, 56, 56), "G4": (79, 79, 79),
    "G5": (99, 99, 99), "G6": (128, 128, 128),
}

W, H = 96, 112
GROUND = H - 1
DIAL = (48, 40, 12)        # 转盘：圆心 x, y, 半径（代码画）
BELLS = [(23, 9), (73, 9)]  # 两只铃铛的中心（代码画）
LED = (48, 40)              # 红灯 = 转盘中心
HORN = (6, 52)              # 送话器喇叭口（声波从这里出）
JACKS = (20, 24, 76, 60)    # 插孔板（插线从这里甩出去）
HOOKS = (30, 66)            # 拱顶上两个吊环（缆绳挂这里，代码画缆绳）


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

    def box(self, x0, y0, x1, y1, base, top, left, right, bottom):
        self.rect(x0, y0, x1, y1, base)
        self.rect(x0, y1, x1, y1, bottom)
        self.rect(x1, y0, x1, y1, right)
        self.rect(x0, y0, x0, y1, left)
        self.rect(x0, y0, x1, y0, top)

    def disk(self, cx, cy, r, c, ring=None):
        for y in range(self.h):
            for x in range(self.w):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d <= r + 0.3 and (ring is None or d > r - ring + 0.3):
                    self.put(x, y, c)

    def sag(self, x0, x1, y, depth, c, c2=None):
        """两个插孔之间垂下来的一根插线（抛物线）"""
        for x in range(x0, x1 + 1):
            t = (x - x0) / max(x1 - x0, 1)
            yy = round(y + depth * 4 * t * (1 - t))
            self.put(x, yy, c)
            if c2:
                self.put(x, yy + 1, c2)

    def rgba(self):
        out = np.zeros((self.h, self.w, 4), np.uint8)
        for y in range(self.h):
            for x in range(self.w):
                c = self.a[y, x]
                if c is not None:
                    out[y, x, :3] = PAL[c]
                    out[y, x, 3] = 255
        return out


def desk():
    """留在房间里的桌子：四条腿、下柜、插头架（台面就是一块平台，顶面是画布第 64 行）"""
    g = G(W, H)
    # 四条黄铜家具腿：上粗下细，脚是个小圆球
    for x in (22, 36, 60, 74):
        g.rect(x - 1, 104, x + 1, 106, "B2")
        g.rect(x, 107, x, GROUND - 2, "B1")
        g.rect(x - 1, GROUND - 1, x + 1, GROUND, "B3")
        g.put(x - 1, 104, "B5")
    # 下柜：暗红木箱，左上亮、右下暗，中间两扇门板
    g.box(14, 70, 82, 103, "R2", "R5", "R4", "R0", "R0")
    for dx0, dx1 in ((18, 46), (50, 78)):
        g.box(dx0, 74, dx1, 99, "R1", "R3", "R3", "R0", "R0")
        g.rect((dx0 + dx1) // 2 - 1, 86, (dx0 + dx1) // 2 + 1, 87, "B4")
    # 插头架：往左探出去的台面，黄铜包边，上面一排竖着的插头（总机飞起来以后插头留在桌上）
    g.rect(6, 64, 86, 69, "R3")
    g.rect(6, 64, 86, 64, "B5")
    g.rect(6, 69, 86, 69, "R0")
    for x in range(10, 84, 5):
        g.rect(x, 59, x, 63, "G5")
        g.put(x, 59, "G6")
        g.put(x, 63, "B2")
    return g


def head():
    """会飞的那半截：插孔板、拱顶、转盘槽、铃铛架、送话器。吊在天车的两根缆绳上"""
    g = G(W, H)
    # 插孔板：暗红底，一排排黄铜小孔，两道铜铭牌
    jx0, jy0, jx1, jy1 = JACKS
    g.box(jx0 - 2, jy0 - 4, jx1 + 2, jy1 + 3, "R1", "R4", "R3", "R0", "R0")
    for y in range(jy0, jy1, 4):
        for x in range(jx0 + 1, jx1, 4):
            g.put(x, y, "B6")
            g.put(x, y + 1, "B0")
    for y in (jy0 + 9, jy0 + 25):
        g.rect(jx0, y, jx1, y, "B3")
    # 插线：一根根从孔里垂下来，又插回别的孔
    for x0, x1, y, d in [(21, 37, 28, 9), (33, 61, 36, 12), (57, 73, 26, 8), (25, 45, 48, 7), (53, 75, 50, 6)]:
        g.sag(x0, x1, y, d, "B6", "B1")
    # 底边一道铜包边（飞起来以后看得到底）
    g.rect(jx0 - 2, jy1 + 3, jx1 + 2, jy1 + 3, "B1")
    # 拱顶：木头弧形顶，铜包边；两角各一个吊环（缆绳挂在这里）
    for y in range(10, 20):
        inset = max(0, 6 - (y - 10))
        g.rect(18 + inset, y, 78 - inset, y, "R3" if y > 11 else "R5")
    g.rect(20, 19, 76, 19, "B3")
    for hx in HOOKS:
        g.rect(hx - 1, 7, hx + 1, 9, "B2")
        g.put(hx, 8, "G0")
    # 转盘的凹槽（转盘本身代码画）
    cx, cy, r = DIAL
    g.disk(cx, cy, r + 2, "R0")
    g.disk(cx, cy, r + 1, "B1", ring=1)
    # 铃铛的支架（铃铛代码画）
    for bx, by in BELLS:
        g.rect(bx - 1, by + 6, bx + 1, 20, "B1")
    # 送话器：一根铜杆伸出去，顶上一个喇叭口
    g.rect(10, 56, 18, 57, "B2")
    g.rect(10, 56, 18, 56, "B5")
    hx, hy = HORN
    g.rect(hx - 1, hy - 3, hx + 3, hy + 3, "B2")
    g.rect(hx - 2, hy - 4, hx - 1, hy + 4, "B4")
    g.rect(hx - 2, hy - 4, hx - 2, hy + 4, "B6")
    g.rect(hx, hy - 1, hx + 1, hy + 1, "G0")
    return g


# —— 房间 ——
M = 24
AW, AH = 320, 180
CW, CH = AW + 2 * M, AH + 2 * M
FLOOR_Y, WALL, CEIL = 164, 8, 12
PLATFORMS = [(20, 70, 130), (108, 164, 124)]   # 两张话务员长凳（立在地上，不吊；上半空是 Boss 的天车道）
DESK_X = 262                                     # 桌子（总机飞走以后留下的那半截）中心，台面也是平台
SCONCES = [(WALL + 1, 58), (320 - WALL - 2, 58)]  # 两边墙上的壁灯（光由代码给）
PLATES = [(8, 80), (80, 152), (152, 224)]        # 玩家这边的三块铜地板（会通电）
BULBS = [60, 140, 220]                           # 天花板吊灯（代码不画，画在前景里，光由代码给）
CROP = (292, -8)


def px(img, x, y, c):
    if 0 <= x < img.shape[1] and 0 <= y < img.shape[0]:
        img[y, x, :3] = PAL[c]
        img[y, x, 3] = 255


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def limit_colors(arr, n=40):
    """收成 n 色、不抖动：暗角是连续渐变，不收的话一张背景有七百多种颜色，放大以后发糊、和前景的硬边像素对不上（美术巡检提的）"""
    im = Image.fromarray(arr).convert("RGB").quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return np.array(im.convert("RGBA"))


def background():
    # 第二关的美术重组过，原来取背景用的 level2_far/mid/back/props 已经没有了：
    # 这时直接用现有的 room2_bg.png，四边按边缘像素补到新画布大小（补出来的那圈都被前景的墙、天花板、地面盖住）
    if not (ROOT / "art/levels/level2_far.png").exists():
        old = np.array(Image.open(OUT / "room2_bg.png").convert("RGBA"))
        ph, pw = (CH - old.shape[0]) // 2, (CW - old.shape[1]) // 2
        if ph <= 0 and pw <= 0:
            return old
        return np.pad(old, ((ph, CH - old.shape[0] - ph), (pw, CW - old.shape[1] - pw), (0, 0)), mode="edge")
    layers = None
    for n in ["far", "mid", "back", "props"]:
        im = Image.open(ROOT / f"art/levels/level2_{n}.png").convert("RGBA")
        layers = im if layers is None else Image.alpha_composite(layers, im)
    x, y = CROP
    bg = np.array(layers.crop((x, y, x + CW, y + CH))).astype(float)
    yy, xx = np.mgrid[0:CH, 0:CW]
    d = np.hypot((xx - CW / 2) / (CW / 2), (yy - CH * 0.55) / (CH * 0.7))
    vign = np.clip(1.1 - 0.55 * d, 0.45, 1.0)
    # 背景压暗一半、偏冷一点：背景里的交换台桌子不能看着像平台，Boss（同样是暗红）要从背景里跳出来
    bg[..., :3] *= 0.42 * vign[..., None]
    bg[..., 0] *= 0.85
    bg[..., 2] *= 1.15
    bg[..., 3] = 255
    return limit_colors(bg.clip(0, 255).astype(np.uint8))


def foreground():
    img = np.zeros((CH, CW, 4), np.uint8)
    fy = FLOOR_Y + M
    # 地面：底下是暗灰钢板；玩家这边三块铜板，中间留黑缝；Boss 脚下是暗红木台
    rect(img, 0, fy, CW - 1, CH - 1, "G1")
    rect(img, 0, fy, CW - 1, fy, "G4")
    for x0, x1 in PLATES:
        X0, X1 = x0 + M + 1, x1 + M - 1
        rect(img, X0, fy, X1, fy + 3, "B2")
        rect(img, X0, fy, X1, fy, "B6")
        rect(img, X0, fy + 3, X1, fy + 3, "B0")
        for rx in range(X0 + 3, X1, 8):
            px(img, rx, fy + 1, "B5")
        rect(img, X1 + 1, fy, X1 + 1, fy + 4, "G0")
    rect(img, 224 + M, fy, 312 + M, fy + 3, "R3")
    rect(img, 224 + M, fy, 312 + M, fy, "R5")
    # 两边的墙：暗红木板，铜包边
    for x0, x1 in [(0, WALL + M - 1), (CW - WALL - M, CW - 1)]:
        rect(img, x0, 0, x1, fy - 1, "R1")
        edge = x1 if x0 == 0 else x0
        rect(img, edge, 0, edge, fy - 1, "B3")
        for ry in range(10, fy, 12):
            px(img, (edge - 3) if x0 == 0 else (edge + 3), ry, "B5")
    # 天花板：一根黑梁，下面挂一条工字钢天车轨道（总机的滑车在上面跑，代码画）
    cy = CEIL + M
    rect(img, 0, 0, CW - 1, cy, "G2")
    rect(img, 0, cy, CW - 1, cy, "B3")
    rect(img, M + WALL, cy + 1, CW - M - WALL - 1, cy + 4, "G3")
    rect(img, M + WALL, cy + 1, CW - M - WALL - 1, cy + 1, "G5")
    rect(img, M + WALL, cy + 4, CW - M - WALL - 1, cy + 4, "G1")
    for rx in range(M + WALL + 4, CW - M - WALL, 16):
        px(img, rx, cy + 2, "G6")
        rect(img, rx, cy - 3, rx, cy, "G4")
    # 壁灯：铜底座 + 一个小灯罩
    for sx, sy in SCONCES:
        X, Y = sx + M, sy + M
        rect(img, X - 1, Y, X + 1, Y + 4, "B2")
        rect(img, X - 2, Y - 2, X + 2, Y - 1, "B5")
    # 话务员长凳：暗红木板面 + 铜包边，两条铜腿立在地上，中间一根横撑
    for x0, x1, top in PLATFORMS:
        X0, X1, T = x0 + M, x1 + M, top + M
        for rx in (X0 + 3, X1 - 3):
            rect(img, rx - 1, T + 4, rx, fy - 1, "B1")
            rect(img, rx - 1, T + 4, rx - 1, fy - 1, "B3")
        rect(img, X0 + 3, (T + fy) // 2, X1 - 3, (T + fy) // 2, "B0")
        rect(img, X0, T, X1, T, "B6")
        rect(img, X0, T + 1, X1, T + 3, "R3")
        rect(img, X0, T + 4, X1, T + 4, "R0")
        for rx in range(X0 + 2, X1, 6):
            px(img, rx, T + 2, "B4")
    return img


def gate():
    g = np.zeros((40, WALL + 2, 4), np.uint8)
    rect(g, 0, 0, WALL + 1, 39, "G1")
    for x in range(0, WALL + 2, 3):
        rect(g, x, 0, x, 39, "B3")
    for y in (0, 13, 26, 39):
        rect(g, 0, y, WALL + 1, y, "B5")
    return g


def main():
    PREVIEW.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    hd, dk = head().rgba(), desk().rgba()
    Image.fromarray(hd).save(OUT / "operator_head.png")
    Image.fromarray(dk).save(OUT / "operator_desk.png")
    b = np.where(hd[..., 3:4] > 0, hd, dk)
    bg, fg, gt = background(), foreground(), gate()
    Image.fromarray(bg).save(OUT / "room2_bg.png")
    Image.fromarray(fg).save(OUT / "room2_fg.png")
    Image.fromarray(gt).save(OUT / "gate2.png")
    prev = Image.fromarray(bg).convert("RGBA")
    prev.alpha_composite(Image.fromarray(fg))
    prev.alpha_composite(Image.fromarray(b), (262 + M - W // 2, FLOOR_Y + M - H + 1))
    hero = Image.open(ROOT / "art/chars/red_body.png").convert("RGBA").crop((0, 0, 16, 20))
    prev.alpha_composite(hero, (40 + M - 8, FLOOR_Y + M - 20))
    prev.resize((CW * 3, CH * 3), Image.NEAREST).save(PREVIEW / "preview_operator.png")
    print("wrote operator_head.png operator_desk.png room2_bg.png room2_fg.png gate2.png preview_operator.png")


if __name__ == "__main__":
    main()
