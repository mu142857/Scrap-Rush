"""第一关 Boss「司炉 THE STOKER」：成了精的老锅炉。照精英怪草图（草图/精英怪/elites.py）的画法：
暖调深灰一个色相，亮框 + 暗芯，光从上面来，不描边，腿是几根细线，一只红色指示灯当眼睛。
朝左。地面是画布最后一行。分图层输出，游戏里各层分开动：

    python3 tools/draw_boss.py

输出 art/boss/：
  stoker_legs.png   四条活塞腿（不动）
  stoker_body.png   锅炉身、烟囱、汽笛、管子、压力表盘（待机时整体上下呼吸 1 像素）
  stoker_door.png   炉门 2 帧：关着（格栅）/ 打开（门板甩到一边）
  stoker_arm.png    煤铲臂 3 帧：垂着 / 举起 / 铲到底
  preview_stoker.png  放大 4 倍的总览，给人看
压力表指针、红灯、炉膛火光由游戏代码画（会动、会发光）。坐标见 BODY / ARM 常量，代码里要对上。
"""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "art/boss"
## 预览图只给人看，不放进 art/（不然会被打进网页版包里）
PREVIEW = Path(__file__).resolve().parent.parent.parent / "草图/boss预览"


# 调色板：和精英怪草图一样（0~9 取自 Oscar 的爬虫，暗 → 亮），加了几档锈色和煤火
PAL = {
    0: "#121110", 1: "#1a1918", 2: "#1d1b1a", 3: "#242221", 4: "#2a2828",
    5: "#32302e", 6: "#3b3835", 7: "#4b4742", 8: "#4f4b47", 9: "#5c5752",
    "r1": "#302926", "r2": "#362f2c", "r3": "#45362e", "r4": "#5a4434",
    "S": "#8a847c", "s": "#6e6862",            # 压力表盘
    "o1": "#7a2a14", "o2": "#c4501e", "o3": "#ff9a3c", "o4": "#ffd27a",  # 煤火
}
RGB = {k: tuple(int(v[i:i + 2], 16) for i in (1, 3, 5)) for k, v in PAL.items()}

W, H = 84, 96          # 身体图层的画布；地面 = 最后一行 y=95，原点在画布底边中间
GROUND = H - 1
DOOR = (22, 62, 41, 78)        # 炉门的格子（含门框）
GAUGE = (28, 49, 8)            # 压力表：圆心 x, y, 半径
LED = (19, 41)                 # 红灯
CHIMNEY_TOP = (54, 7)          # 烟囱口（余烬从这里喷）
SHOULDER = (16, 56)            # 煤铲臂的肩膀，在身体画布里的位置
ARM_W, ARM_H = 48, 64          # 煤铲臂画布；肩膀在臂画布里的 (44, 24)，底边和地面对齐
ARM_SHOULDER = (44, 24)


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

    def box(self, x0, y0, x1, y1, base=4, top=8, left=7, right=5, bottom=3):
        self.rect(x0, y0, x1, y1, base)
        self.rect(x0, y1, x1, y1, bottom)
        self.rect(x1, y0, x1, y1, right)
        self.rect(x0, y0, x0, y1, left)
        self.rect(x0, y0, x1, y0, top)

    def line(self, x0, y0, x1, y1, c, w=1):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            for k in range(w):
                self.put(x0 + (k if abs(dy) > dx else 0), y0 + (0 if abs(dy) > dx else k), c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def disk(self, cx, cy, r, c, ring=None):
        for y in range(self.h):
            for x in range(self.w):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d <= r + 0.3 and (ring is None or d > r - ring + 0.3):
                    self.put(x, y, c)

    def rgba(self):
        out = np.zeros((self.h, self.w, 4), np.uint8)
        for y in range(self.h):
            for x in range(self.w):
                c = self.a[y, x]
                if c is not None:
                    out[y, x, :3] = RGB[c]
                    out[y, x, 3] = 255
        return out


def legs():
    g = G(W, H)
    for x, lean in [(23, -2), (35, -1), (55, 1), (67, 2)]:
        # 活塞腿：上面一截粗的缸，下面一根细杆斜着落地，脚掌 4 格
        g.box(x - 2, 82, x + 2, 87, base=5, top=8, left=7, right=4, bottom=3)
        g.line(x, 88, x + lean, GROUND - 1, 6)
        g.line(x + 1, 88, x + lean + 1, GROUND - 1, 4)
        g.rect(x + lean - 2, GROUND, x + lean + 2, GROUND, 5)
        g.put(x + lean - 2, GROUND, 7)
    return g


def body():
    g = G(W, H)
    # 锅炉：一个大圆角铁筒
    x0, y0, x1, y1 = 16, 34, 73, 84
    g.box(x0, y0, x1, y1, base=4, top=9, left=7, right=5, bottom=3)
    for (cx, cy) in [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]:
        g.put(cx, cy, None)
    # 筒身上下两道箍，箍上一排铆钉
    for by in (39, 79):
        g.rect(x0 + 1, by, x1 - 1, by + 1, 6)
        for rx in range(x0 + 3, x1 - 1, 4):
            g.put(rx, by, 9)
    # 竖着的接缝
    for sx in (47, 62):
        g.rect(sx, y0 + 1, sx, y1 - 1, 3)
        for ry in range(y0 + 8, y1 - 2, 5):
            g.put(sx + 1, ry, 8)
    # 背光的右半边整体暗一档（光从左上来）
    for y in range(y0 + 1, y1):
        for x in range(64, x1):
            if g.a[y, x] == 4:
                g.a[y, x] = 3
    # 顶上的穹顶
    g.box(22, 27, 67, 34, base=5, top=9, left=8, right=4, bottom=4)
    g.put(22, 27, None)
    g.put(67, 27, None)
    # 烟囱：一根粗管子，口上一圈帽檐，里面黑
    cx, ctop = CHIMNEY_TOP
    g.box(cx - 5, ctop + 2, cx + 4, 27, base=4, top=8, left=7, right=3, bottom=4)
    g.box(cx - 7, ctop, cx + 6, ctop + 2, base=6, top=9, left=8, right=4, bottom=3)
    g.rect(cx - 4, ctop, cx + 3, ctop, 0)
    for ry in range(ctop + 6, 26, 5):
        g.rect(cx - 4, ry, cx + 3, ry, 5)
    # 汽笛：锈色的一小根
    g.rect(31, 21, 33, 27, "r3")
    g.rect(30, 19, 34, 21, "r4")
    g.put(32, 18, "r3")
    # 背后的管子：从穹顶绕到身后插进筒身，锈色
    for (px, py) in [(68, 30), (70, 30), (72, 30), (74, 31), (75, 33)]:
        g.rect(px, py, px + 1, py + 1, "r3")
    g.rect(75, 34, 76, 70, "r2")
    g.rect(75, 34, 75, 70, "r3")
    g.rect(73, 70, 76, 72, "r3")
    # 压力表：亮表盘、暗外圈、几根刻度（指针由代码画）
    gx, gy, gr = GAUGE
    g.disk(gx, gy, gr + 1, 3)
    g.disk(gx, gy, gr, "s")
    g.disk(gx, gy, gr - 1, "S")
    for ang in range(-135, 136, 45):
        import math
        a = math.radians(ang - 90)
        g.put(round(gx + math.cos(a) * (gr - 1)), round(gy + math.sin(a) * (gr - 1)), 5)
    # 红区（表盘右上那一段）
    for ang in (100, 115, 130):
        a = math.radians(ang - 90)
        g.put(round(gx + math.cos(a) * (gr - 1)), round(gy + math.sin(a) * (gr - 1)), "o2")
    g.put(gx, gy, 2)
    # 红灯底座（灯由代码画）
    lx, ly = LED
    g.rect(lx - 1, ly - 1, lx + 2, ly + 1, 2)
    # 炉门位置先挖成最暗（火光和门板由别的图层画在上面）
    dx0, dy0, dx1, dy1 = DOOR
    g.box(dx0 - 1, dy0 - 1, dx1 + 1, dy1 + 1, base=2, top=7, left=6, right=3, bottom=3)
    g.rect(dx0 + 1, dy0 + 1, dx1 - 1, dy1 - 1, 1)
    # 炉门下面的灰槽
    g.rect(dx0, dy1 + 2, dx1, dy1 + 3, 2)
    g.rect(dx0 + 2, dy1 + 2, dx1 - 2, dy1 + 2, "o1")
    return g


def door(open_):
    g = G(W, H)
    dx0, dy0, dx1, dy1 = DOOR
    if not open_:
        # 关着：门框 + 竖格栅，格栅之间留空（透出后面的火光）
        g.box(dx0, dy0, dx1, dy1, base=5, top=9, left=8, right=4, bottom=3)
        g.rect(dx0 + 1, dy0 + 2, dx1 - 1, dy1 - 2, None)
        for x in range(dx0 + 2, dx1 - 1, 3):
            g.rect(x, dy0 + 2, x, dy1 - 2, 6)
            g.put(x, dy0 + 2, 9)
        # 门把手
        g.rect(dx1 - 3, dy0 + 7, dx1 - 1, dy0 + 8, "r4")
    else:
        # 打开：门板甩到左边，只看到一条侧面；炉口整个敞开
        g.rect(dx0 - 4, dy0 - 1, dx0 - 2, dy1 + 1, 6)
        g.rect(dx0 - 4, dy0 - 1, dx0 - 4, dy1 + 1, 8)
        g.rect(dx0 - 2, dy0 - 1, dx0 - 2, dy1 + 1, 3)
        for y in range(dy0 + 1, dy1, 3):
            g.put(dx0 - 3, y, 9)
    return g


def arm(pose):
    """pose: 0 垂着，1 举起（铲里有烧红的煤），2 铲到底（贴地往前推）"""
    g = G(ARM_W, ARM_H)
    sx, sy = ARM_SHOULDER
    elbow, hand = {
        0: ((34, 36), (22, 46)),
        1: ((36, 10), (24, 2)),
        2: ((30, 44), (12, 56)),
    }[pose]
    # 肩关节
    g.box(sx - 3, sy - 3, sx + 3, sy + 3, base=5, top=9, left=8, right=4, bottom=3)
    # 两截活塞：粗缸 + 细杆
    g.line(sx, sy, *elbow, 6, w=3)
    g.line(sx, sy - 1, elbow[0], elbow[1] - 1, 8)
    g.box(elbow[0] - 2, elbow[1] - 2, elbow[0] + 2, elbow[1] + 2, base=5, top=9, left=8, right=4, bottom=3)
    g.line(*elbow, *hand, 5, w=2)
    g.line(elbow[0], elbow[1] - 1, hand[0], hand[1] - 1, 7)
    # 煤铲：一块往前翘的铲面
    hx, hy = hand
    if pose == 1:
        # 举过头顶，铲口朝上，装着烧红的煤
        g.rect(hx - 10, hy - 1, hx, hy + 1, 6)
        g.rect(hx - 10, hy - 1, hx, hy - 1, 9)
        g.rect(hx - 11, hy - 4, hx - 10, hy + 1, 6)
        for x, c in [(hx - 9, "o3"), (hx - 8, "o4"), (hx - 7, "o2"), (hx - 6, "o3"), (hx - 4, "o2"), (hx - 3, "o3")]:
            g.put(x, hy - 2, c)
        g.put(hx - 7, hy - 3, "o3")
        g.put(hx - 5, hy - 3, "o2")
    else:
        g.rect(hx - 11, hy, hx, hy + 2, 6)
        g.rect(hx - 11, hy, hx, hy, 9)
        g.rect(hx - 12, hy - 3, hx - 11, hy + 2, 7)
        g.rect(hx - 11, hy + 3, hx, hy + 3, 3)
        if pose == 2:
            # 铲到底：铲面下面蹭出火星
            for x in (hx - 12, hx - 9, hx - 5):
                g.put(x, hy + 4, "o3")
    return g


def save(arr, name):
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr).save(OUT / name)
    print("wrote", name, arr.shape[1], "x", arr.shape[0])


def main():
    PREVIEW.mkdir(parents=True, exist_ok=True)
    lg, bd = legs().rgba(), body().rgba()
    dr = [door(False).rgba(), door(True).rgba()]
    am = [arm(p).rgba() for p in range(3)]
    save(lg, "stoker_legs.png")
    save(bd, "stoker_body.png")
    save(np.concatenate(dr, axis=1), "stoker_door.png")
    save(np.concatenate(am, axis=1), "stoker_arm.png")

    # 总览：三个姿势并排，地面一条线，旁边放主角做比例尺
    preview = []
    for pose in range(3):
        canvas = Image.new("RGBA", (W + 40, H), (40, 40, 46, 255))
        ax = SHOULDER[0] - ARM_SHOULDER[0] + 40
        ay = SHOULDER[1] - ARM_SHOULDER[1]
        for layer, pos in [(lg, (40, 0)), (bd, (40, 0)), (dr[1 if pose == 2 else 0], (40, 0)), (am[pose], (ax, ay))]:
            canvas.alpha_composite(Image.fromarray(layer), pos)
        hero = Image.open(OUT.parent / "chars/red_body.png").convert("RGBA").crop((0, 0, 16, 20))
        canvas.alpha_composite(hero, (2, H - 20))
        preview.append(canvas)
    sheet = Image.new("RGBA", (sum(p.width for p in preview) + 8 * 2, H), (30, 30, 34, 255))
    x = 0
    for p in preview:
        sheet.alpha_composite(p, (x, 0))
        x += p.width + 8
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(PREVIEW / "preview_stoker.png")
    print("wrote preview_stoker.png")


if __name__ == "__main__":
    main()
