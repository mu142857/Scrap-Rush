"""胶片画框里的 11 个经典电影镜头（像素致敬），每个 90×64，只用 8 档褐色调。

每个函数签名 scene(c, x0, y0, w, h, T)：在 c 上 (x0, y0) 处画一格，T 是暗→亮 8 档的颜色表。
都只画剪影和大块明暗，靠构图让人认出来，不照抄任何一帧。
"""
import math

import numpy as np


def _q(T, v):
    return T[int(np.clip(round(v * (len(T) - 1)), 0, len(T) - 1))]


def sky(c, x0, y0, w, h, T, top, bot, y_end=None):
    """竖直分档渐变，top/bot 是 0~1 的亮度。"""
    y_end = h if y_end is None else y_end
    for y in range(y_end):
        v = top + (bot - top) * y / max(1, y_end - 1)
        c.rect(x0, y0 + y, x0 + w - 1, y0 + y, _q(T, v))


def shaded_disc(c, cx, cy, r, T, lo, hi, light=(-0.5, -0.6)):
    """一块分档的圆：朝光的一侧亮。lo/hi 是 T 的下标。"""
    lx, ly = light
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            dx, dy = (x - cx) / r, (y - cy) / r
            d2 = dx * dx + dy * dy
            if d2 > 1:
                continue
            nz = math.sqrt(1 - d2)
            lam = max(0.0, lx * dx + ly * dy + 0.7 * nz)
            v = lo + (hi - lo) * min(1.0, lam)
            c.put(x, y, T[int(round(v))])


def gear(c, cx, cy, r, teeth, col, hole_col, phase=0.0):
    c.ellipse(cx, cy, r - 2, r - 2, col)
    for k in range(teeth):
        a = phase + 2 * math.pi * k / teeth
        for t in range(-1, 2):
            for d in range(r - 3, r + 2):
                x = cx + d * math.cos(a) - t * math.sin(a)
                y = cy + d * math.sin(a) + t * math.cos(a)
                c.put(int(round(x)), int(round(y)), col)
    for k in range(5):
        a = phase + 2 * math.pi * k / 5
        c.ellipse(int(cx + r * 0.5 * math.cos(a)), int(cy + r * 0.5 * math.sin(a)), max(1, r // 6), max(1, r // 6),
                  hole_col)
    c.ellipse(cx, cy, max(1, r // 6), max(1, r // 6), hole_col)


# ------------------------------------------------------------------ 1 月球旅行记（1902）
def trip_to_moon(c, x0, y0, w, h, T):
    sky(c, x0, y0, w, h, T, 0.12, 0.3)
    for sx, sy in ((6, 6), (14, 18), (30, 4), (8, 40), (84, 8), (80, 44), (22, 30)):
        c.put(x0 + sx, y0 + sy, T[6])
    cx, cy, r = x0 + 48, y0 + 30, 23
    shaded_disc(c, cx, cy, r, T, 4, 7)
    # 脸：眯着的左眼、鼻子、往下撇的嘴，都用最暗的两档
    c.rect(cx - 12, cy - 6, cx - 5, cy - 5, T[1])
    c.rect(cx - 11, cy - 8, cx - 6, cy - 8, T[2])         # 眉毛
    c.line(cx - 1, cy - 4, cx - 4, cy + 4, T[2])
    c.line(cx - 4, cy + 4, cx, cy + 5, T[2])
    c.line(cx - 10, cy + 11, cx + 3, cy + 12, T[1])
    c.line(cx + 3, cy + 12, cx + 7, cy + 9, T[1])
    c.line(cx - 10, cy + 12, cx - 12, cy + 10, T[1])
    c.ellipse(cx - 15, cy + 4, 3, 2, T[5])                # 脸颊
    # 右眼里插着火箭：子弹形，白色，尾巴朝右上
    tip = (cx + 6, cy - 5)
    tail = (cx + 30, cy - 25)
    n = 30
    for t in range(n + 1):
        f = t / n
        px = tip[0] + (tail[0] - tip[0]) * f
        py = tip[1] + (tail[1] - tip[1]) * f
        rad = 1 if t < 3 else 2 if t < 6 else 4
        for o in range(-rad, rad + 1):
            col = T[7] if o < -1 else T[6] if o < 2 else T[4]
            c.put(int(round(px + o * 0.75)), int(round(py + o * 0.75)), col)
            c.put(int(round(px + o * 0.75 + 0.5)), int(round(py + o * 0.75)), col)
    for o in range(-5, 6):
        c.put(tail[0] - 3 + int(round(o * 0.75)), tail[1] + 3 + int(round(o * 0.75)), T[2])   # 箍
        c.put(tail[0] - 8 + int(round(o * 0.75)), tail[1] + 8 + int(round(o * 0.75)), T[2])
    c.ellipse(cx + 6, cy - 5, 3, 3, T[2])                 # 插进去的眼窝
    # 溅出来的月球表面
    for dx, dy in ((5, -3), (9, -9), (3, -9), (10, -4)):
        c.put(cx + dx, cy + dy, T[2])
    # 底下一排云
    for k, ex in enumerate(range(-4, w + 6, 12)):
        c.ellipse(x0 + ex, y0 + h - 2, 8, 6 - (k % 2), T[2])
        c.ellipse(x0 + ex - 2, y0 + h - 5, 4, 3, T[3])


# ------------------------------------------------------------------ 2 火车进站（1896）
def arrival_of_train(c, x0, y0, w, h, T):
    sky(c, x0, y0, w, h, T, 0.75, 0.62, y_end=36)
    c.rect(x0, y0 + 36, x0 + w - 1, y0 + h - 1, T[3])
    vp = (x0 + 78, y0 + 30)
    # 站台：从左下伸向灭点
    c.poly([(x0, y0 + h - 1), (x0, y0 + 42), vp, (x0 + 46, y0 + h - 1)], T[5])
    c.line(x0 + 46, y0 + h - 1, vp[0], vp[1], T[6])
    # 站棚顶
    c.poly([(x0, y0), (x0 + w - 1, y0), (x0 + w - 1, y0 + 6), vp, (x0, y0 + 12)], T[2])
    for k in range(0, w, 10):
        c.line(x0 + k, y0 + 3, x0 + k + 5, y0 + 8, T[1])
    # 铁轨
    c.line(x0 + 56, y0 + h - 1, vp[0], vp[1], T[2])
    c.line(x0 + 86, y0 + h - 1, vp[0] + 2, vp[1], T[2])
    # 火车头：从灭点冲过来，近处最大
    body = [(vp[0] + 2, vp[1] - 2), (x0 + 88, y0 + 14), (x0 + 88, y0 + 60), (vp[0] + 2, vp[1] + 3)]
    c.poly(body, T[1])
    fx, fy = x0 + 74, y0 + 38
    c.ellipse(fx, fy, 11, 13, T[0])                       # 车头正面
    c.ellipse(fx, fy, 8, 10, T[1])
    c.ellipse(fx - 2, fy - 4, 2, 2, T[7])                 # 车灯
    c.rect(fx - 3, fy - 24, fx + 2, fy - 13, T[0])        # 烟囱
    c.rect(fx - 4, fy - 25, fx + 3, fy - 24, T[1])
    c.rect(fx - 12, fy + 10, fx + 12, fy + 13, T[0])      # 排障器
    # 烟往后飘向灭点
    for k, (sx, sy, r) in enumerate(((fx - 2, fy - 30, 6), (fx - 12, fy - 32, 5), (fx - 22, fy - 31, 4),
                                     (fx - 30, fy - 29, 3))):
        c.ellipse(sx, sy, r, r - 1, T[6 - (k % 2)])
    # 站台上等车的人：越远越小
    for px, ph in ((x0 + 8, 15), (x0 + 17, 13), (x0 + 26, 10), (x0 + 34, 8)):
        base = y0 + 56 - (px - x0) // 3
        c.rect(px, base - ph + 3, px + 2, base, T[1])
        c.rect(px, base - ph, px + 2, base - ph + 1, T[2])     # 脸
        c.rect(px - 1, base - ph - 1, px + 3, base - ph - 1, T[0])  # 帽檐
        c.put(px + 1, base - ph - 2, T[0])


# ------------------------------------------------------------------ 3 摩登时代（1936）
def modern_times(c, x0, y0, w, h, T):
    sky(c, x0, y0, w, h, T, 0.7, 0.55)
    gear(c, x0 + 16, y0 + 46, 26, 12, T[2], T[4], phase=0.1)
    gear(c, x0 + 80, y0 + 14, 20, 10, T[3], T[5], phase=0.3)
    gear(c, x0 + 84, y0 + 56, 12, 8, T[2], T[4])
    # 流浪汉：圆顶礼帽、小胡子、窄上衣、肥裤子、大鞋，手里一把扳手
    gx, gy = x0 + 50, y0 + 60
    c.rect(gx - 4, gy - 1, gx - 1, gy, T[0])              # 鞋，外八字
    c.rect(gx + 2, gy - 1, gx + 6, gy, T[0])
    c.poly([(gx - 3, gy - 2), (gx - 4, gy - 13), (gx + 5, gy - 13), (gx + 5, gy - 2), (gx + 3, gy - 2),
            (gx + 1, gy - 9), (gx - 1, gy - 2)], T[1])    # 肥裤子
    c.rect(gx - 3, gy - 22, gx + 4, gy - 13, T[0])        # 上衣
    c.put(gx + 1, gy - 20, T[2])
    c.rect(gx - 1, gy - 27, gx + 3, gy - 23, T[6])        # 脸
    c.rect(gx, gy - 24, gx + 2, gy - 24, T[0])            # 小胡子
    c.put(gx + 2, gy - 26, T[0])
    c.ellipse(gx + 1, gy - 30, 3, 2, T[0])                # 圆顶礼帽
    c.rect(gx - 3, gy - 28, gx + 5, gy - 28, T[0])
    c.line(gx + 4, gy - 20, gx + 11, gy - 25, T[0])       # 举起的胳膊
    c.rect(gx + 10, gy - 29, gx + 12, gy - 26, T[1])      # 扳手
    c.put(gx + 10, gy - 30, T[1])
    c.put(gx + 12, gy - 30, T[1])
    c.line(gx - 3, gy - 20, gx - 6, gy - 12, T[0])        # 另一只手和拐杖
    c.line(gx - 6, gy - 12, gx - 6, gy - 1, T[2])
    c.put(gx - 5, gy - 12, T[2])


# ------------------------------------------------------------------ 4 大都会（1927）
def metropolis(c, x0, y0, w, h, T):
    sky(c, x0, y0, w, h, T, 0.05, 0.18)
    # 背后的高楼
    for bx, bh in ((2, 30), (12, 44), (70, 40), (80, 26), (62, 22)):
        c.rect(x0 + bx, y0 + h - bh, x0 + bx + 8, y0 + h - 1, T[1])
        for wy in range(y0 + h - bh + 3, y0 + h - 2, 4):
            c.put(x0 + bx + 3, wy, T[4])
    cx = x0 + 45
    # 机器人玛丽亚：圆头、细腰、金属身体，左边受光
    c.ellipse(cx, y0 + 15, 4, 5, T[5])
    c.rect(cx - 3, y0 + 13, cx + 3, y0 + 13, T[2])        # 眼缝
    c.put(cx - 2, y0 + 12, T[7])
    c.rect(cx - 1, y0 + 20, cx + 1, y0 + 22, T[4])        # 脖子
    c.poly([(cx - 7, y0 + 23), (cx + 7, y0 + 23), (cx + 3, y0 + 34), (cx + 5, y0 + 40), (cx - 5, y0 + 40),
            (cx - 3, y0 + 34)], T[4])
    c.ellipse(cx - 3, y0 + 27, 2, 2, T[6])                # 胸甲
    c.ellipse(cx + 3, y0 + 27, 2, 2, T[5])
    c.rect(cx - 4, y0 + 41, cx - 1, y0 + h - 4, T[4])     # 腿
    c.rect(cx + 1, y0 + 41, cx + 4, y0 + h - 4, T[3])
    c.line(cx - 6, y0 + 24, cx - 8, y0 + 38, T[5])        # 手臂垂着
    c.line(cx + 6, y0 + 24, cx + 8, y0 + 38, T[3])
    c.rect(cx - 6, y0 + 23, cx - 6, y0 + 40, T[6])        # 左侧受光的一条
    # 一圈圈上下移动的光环（变身那一幕）
    for k, (ry, rx, col) in enumerate(((10, 18, 7), (26, 24, 6), (42, 28, 5), (56, 22, 6))):
        for a in range(0, 360, 3):
            x = cx + rx * math.cos(math.radians(a))
            y = y0 + ry + 3 * math.sin(math.radians(a))
            front = math.sin(math.radians(a)) > 0
            # 环在身体前面的半圈画上，后面的半圈被身体挡住
            if front or abs(x - cx) > 8:
                c.put(int(round(x)), int(round(y)), T[col] if front else T[col - 2])


# ------------------------------------------------------------------ 5 诺斯费拉图（1922）
def nosferatu(c, x0, y0, w, h, T):
    # 被烛光照亮的墙：中间亮，往四周暗
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - 30) / 60, (y - 40) / 50)
            c.put(x0 + x, y0 + y, _q(T, 0.78 - 0.5 * d))
    # 楼梯和扶手：从左下往右上
    for k in range(8):
        sx, sy = x0 + 4 + k * 10, y0 + h - 2 - k * 6
        c.rect(sx, sy, sx + 10, sy + 1, T[3])
    c.line(x0 + 2, y0 + h - 14, x0 + w - 2, y0 + 6, T[2])
    for k in range(0, w, 7):
        c.line(x0 + k + 2, y0 + h - 14 - int(k * 0.62), x0 + k + 2, y0 + h - 5 - int(k * 0.62), T[3])
    # 影子：驼背、尖耳朵、鹰钩鼻，一只手伸在前面，指甲又长又弯
    s = T[0]
    bx, by = x0 + 40, y0 + 56
    c.poly([(bx - 6, by), (bx - 8, by - 20), (bx - 4, by - 32), (bx + 4, by - 34), (bx + 6, by - 24),
            (bx + 4, by - 10), (bx + 2, by)], s)                                  # 身子
    c.ellipse(bx + 3, by - 38, 4, 5, s)                                           # 头
    c.line(bx + 1, by - 42, bx - 1, by - 47, s)                                   # 尖耳朵
    c.line(bx + 2, by - 42, bx, by - 46, s)
    c.line(bx + 7, by - 39, bx + 10, by - 36, s)                                  # 鹰钩鼻
    c.line(bx + 10, by - 36, bx + 9, by - 34, s)
    c.line(bx + 5, by - 30, bx + 18, by - 34, s)                                  # 伸出的手臂
    c.line(bx + 5, by - 29, bx + 18, by - 33, s)
    for k in range(4):                                                            # 长手指
        c.line(bx + 18, by - 34 + k, bx + 26, by - 38 + k * 2, s)
        c.put(bx + 27, by - 37 + k * 2, s)


# ------------------------------------------------------------------ 6 金刚（1933）
def king_kong(c, x0, y0, w, h, T):
    sky(c, x0, y0, w, h, T, 0.55, 0.8)
    # 远处城市
    for k, bh in enumerate((10, 16, 8, 13, 18, 9, 14, 11, 7, 15)):
        c.rect(x0 + k * 9, y0 + h - bh, x0 + k * 9 + 8, y0 + h - 1, T[3])
    # 帝国大厦：一层层收窄，顶上一根尖塔
    cx = x0 + 46
    tiers = ((14, 40), (11, 28), (8, 20), (5, 14), (3, 9), (1, 4))
    y = y0 + h
    for half, th in tiers:
        top = y - th // 2 if half > 5 else y - 5
        c.rect(cx - half, top, cx + half, y - 1, T[1])
        c.rect(cx - half, top, cx - half + 1, y - 1, T[2])
        y = top
    c.line(cx, y, cx, y - 8, T[1])
    # 金刚：扒在塔顶下面，弓背、一手抓塔、一手往右上挥
    kx, ky = cx + 2, y + 14
    k = T[0]
    c.ellipse(kx + 2, ky + 2, 6, 8, k)                    # 身体
    c.ellipse(kx + 1, ky - 7, 4, 4, k)                    # 头
    c.rect(kx - 2, ky - 5, kx + 4, ky - 3, k)             # 下巴
    c.put(kx + 3, ky - 8, T[3])                           # 眼睛反光
    c.poly([(kx - 3, ky - 3), (kx - 8, ky - 10), (kx - 6, ky - 12), (kx - 1, ky - 4)], k)   # 抓塔的手
    c.poly([(kx + 6, ky - 2), (kx + 14, ky - 14), (kx + 17, ky - 13), (kx + 9, ky + 1)], k)  # 挥舞的手
    c.ellipse(kx + 16, ky - 15, 2, 2, k)
    c.poly([(kx - 2, ky + 8), (kx - 5, ky + 16), (kx - 2, ky + 16), (kx + 1, ky + 9)], k)    # 腿
    c.poly([(kx + 4, ky + 8), (kx + 7, ky + 16), (kx + 9, ky + 15), (kx + 7, ky + 8)], k)
    # 双翼机
    for px, py in ((x0 + 72, y0 + 8), (x0 + 16, y0 + 14), (x0 + 82, y0 + 24)):
        c.rect(px - 3, py, px + 3, py, T[1])
        c.rect(px - 3, py + 2, px + 3, py + 2, T[1])
        c.rect(px - 1, py - 1, px + 1, py + 3, T[1])
        c.put(px + 4, py + 1, T[2])


# ------------------------------------------------------------------ 7 安全至下（1923）
def safety_last(c, x0, y0, w, h, T):
    # 大楼外墙，往下看是街道
    c.rect(x0, y0, x0 + w - 1, y0 + h - 1, T[4])
    for wy in range(y0 + 2, y0 + h, 9):
        for wx in range(x0 + 3, x0 + w, 12):
            c.rect(wx, wy, wx + 5, wy + 5, T[2])
            c.rect(wx, wy, wx + 5, wy, T[3])
    c.rect(x0 + 64, y0, x0 + w - 1, y0 + h - 1, T[1])     # 楼外的空：远远的街
    for k in range(5):
        c.rect(x0 + 68 + k * 4, y0 + h - 6, x0 + 69 + k * 4, y0 + h - 5, T[3])   # 小汽车
    c.line(x0 + 64, y0 + h - 3, x0 + w - 1, y0 + h - 8, T[2])
    # 大钟
    cx, cy, r = x0 + 50, y0 + 20, 14
    c.ellipse(cx, cy, r + 2, r + 2, T[1])
    c.ellipse(cx, cy, r, r, T[7])
    for k in range(12):
        a = math.radians(k * 30)
        c.put(int(cx + (r - 2) * math.cos(a)), int(cy + (r - 2) * math.sin(a)), T[1])
    c.line(cx, cy, cx, cy - 10, T[0])                     # 时针
    # 分针被他拽着往下掰
    hx, hy = cx - 9, cy + 9
    c.line(cx, cy, hx, hy, T[0])
    c.line(cx + 1, cy, hx + 1, hy, T[0])
    # 他：草帽、圆眼镜、西装，两条腿悬空
    c.rect(hx - 1, hy + 1, hx + 1, hy + 3, T[6])          # 手
    c.rect(hx - 3, hy + 4, hx + 3, hy + 15, T[0])         # 身体
    c.rect(hx - 2, hy + 6, hx + 2, hy + 6, T[6])          # 衬衫领
    c.line(hx + 3, hy + 4, hx + 1, hy + 1, T[0])          # 抓着指针的胳膊
    c.rect(hx - 6, hy + 2, hx - 3, hy + 6, T[6])          # 脸往外扭着
    c.put(hx - 5, hy + 4, T[0])
    c.put(hx - 3, hy + 4, T[0])
    c.rect(hx - 8, hy + 1, hx - 1, hy + 1, T[1])          # 草帽
    c.rect(hx - 6, hy - 1, hx - 3, hy, T[1])
    c.line(hx - 2, hy + 16, hx - 5, hy + 24, T[0])        # 悬空的腿
    c.line(hx + 2, hy + 16, hx + 4, hy + 23, T[0])
    c.rect(hx - 7, hy + 24, hx - 5, hy + 25, T[0])
    c.rect(hx + 4, hy + 23, hx + 6, hy + 24, T[0])


# ------------------------------------------------------------------ 8 E.T.（1982）
def et(c, x0, y0, w, h, T):
    sky(c, x0, y0, w, h, T, 0.08, 0.25)
    for sx, sy in ((5, 5), (18, 12), (80, 6), (86, 30), (10, 26)):
        c.put(x0 + sx, y0 + sy, T[5])
    cx, cy, r = x0 + 50, y0 + 28, 24
    shaded_disc(c, cx, cy, r, T, 5, 7, light=(-0.2, -0.3))
    for mx, my, mr in ((-8, -6, 4), (6, 4, 5), (-4, 10, 3)):   # 月海
        c.ellipse(cx + mx, cy + my, mr, mr - 1, T[5])
    # 自行车剪影：两个轮子、车架、弓着背的人、车筐里裹着毯子的小外星人
    s = T[0]
    bx, by = cx - 2, cy + 4
    for wx in (bx - 9, bx + 9):
        for a in range(0, 360, 10):
            c.put(int(round(wx + 5 * math.cos(math.radians(a)))), int(round(by + 5 * math.sin(math.radians(a)))), s)
    c.line(bx - 9, by, bx, by, s)
    c.line(bx, by, bx + 9, by, s)
    c.line(bx - 9, by, bx - 3, by - 7, s)
    c.line(bx, by, bx + 5, by - 7, s)
    c.line(bx - 3, by - 7, bx + 5, by - 7, s)
    c.ellipse(bx - 3, by - 13, 3, 5, s)                    # 骑车的人
    c.ellipse(bx - 2, by - 20, 2, 2, s)
    c.line(bx, by - 13, bx + 6, by - 9, s)                 # 手扶车把
    c.rect(bx + 6, by - 12, bx + 11, by - 8, s)            # 车筐
    c.ellipse(bx + 9, by - 15, 2, 3, s)                    # 筐里的小脑袋和兜帽
    c.put(bx + 11, by - 17, s)
    # 底下一排松树
    for k, tx in enumerate(range(-2, w + 4, 7)):
        th = 10 + (k * 5) % 7
        c.poly([(x0 + tx, y0 + h - 1 - th), (x0 + tx - 4, y0 + h - 1), (x0 + tx + 4, y0 + h - 1)], s)


# ------------------------------------------------------------------ 9 指环王：你不能过去（2001）
def lotr_bridge(c, x0, y0, w, h, T):
    # 地底大厅：全黑，炎魔身后的火把四周照亮
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - 68) / 40, (y - 26) / 34)
            c.put(x0 + x, y0 + y, _q(T, 0.78 - 0.62 * min(1, d)))
    # 炎魔：右边一大块剪影，弯角、张开的翅膀，轮廓一圈火
    bx, by = x0 + 70, y0 + 30
    body = [(bx - 8, by + 26), (bx - 10, by + 4), (bx - 26, by - 16), (bx - 14, by - 10), (bx - 8, by - 14),
            (bx - 6, by - 22), (bx - 9, by - 28), (bx - 3, by - 24), (bx + 3, by - 24), (bx + 9, by - 28),
            (bx + 6, by - 22), (bx + 8, by - 14), (bx + 14, by - 10), (bx + 26, by - 18), (bx + 12, by + 4),
            (bx + 10, by + 26)]
    flame = [(x + (2 if x > bx else -2), y - 2) for x, y in body]
    c.poly(flame, T[7])
    c.poly(body, T[0])
    c.rect(bx - 3, by - 18, bx - 2, by - 17, T[6])        # 眼睛
    c.rect(bx + 2, by - 18, bx + 3, by - 17, T[6])
    c.line(bx + 12, by - 4, bx + 20, by + 14, T[6])       # 火鞭
    c.line(bx + 20, by + 14, bx + 16, by + 22, T[5])
    # 窄桥：从左到右一道细细的拱，底下是深渊
    for x in range(w):
        y = y0 + 48 - int(4 * math.sin(math.pi * x / (w - 1)))
        c.rect(x0 + x, y, x0 + x, y + 2, T[2])
        c.put(x0 + x, y, T[4])
        c.rect(x0 + x, y + 3, x0 + x, y0 + h - 1, _q(T, 0.06))
    # 甘道夫：被自己杖头的白光照亮，比炎魔小得多但最亮
    gx, gy = x0 + 24, y0 + 50 - 3
    c.ellipse(gx + 6, gy - 30, 9, 9, T[3])                                            # 杖头的光晕
    c.ellipse(gx + 6, gy - 30, 5, 5, T[5])
    c.poly([(gx - 6, gy), (gx - 4, gy - 16), (gx + 4, gy - 16), (gx + 6, gy)], T[5])   # 袍子
    c.poly([(gx + 1, gy), (gx + 2, gy - 16), (gx + 4, gy - 16), (gx + 6, gy)], T[4])   # 背光的半边
    c.rect(gx - 3, gy - 20, gx + 2, gy - 16, T[5])                                    # 头和胡子
    c.rect(gx - 1, gy - 16, gx + 1, gy - 12, T[6])
    c.poly([(gx - 7, gy - 20), (gx + 6, gy - 20), (gx + 1, gy - 24), (gx + 4, gy - 31), (gx - 2, gy - 24)], T[4])  # 尖帽
    c.line(gx + 4, gy - 14, gx + 6, gy - 26, T[5])                                    # 举起的胳膊
    c.line(gx + 6, gy - 34, gx + 6, gy, T[2])                                         # 法杖
    c.line(gx + 7, gy - 34, gx + 7, gy, T[3])
    c.ellipse(gx + 6, gy - 34, 2, 2, T[7])                                            # 杖头
    c.line(gx - 5, gy - 12, gx - 11, gy - 20, T[2])                                   # 另一只手的剑
    c.line(gx - 11, gy - 20, gx - 15, gy - 26, T[7])


# ------------------------------------------------------------------ 10 指环王：护戒队走在山脊上（2001）
def lotr_fellowship(c, x0, y0, w, h, T):
    sky(c, x0, y0, w, h, T, 0.85, 0.6)
    c.ellipse(x0 + 64, y0 + 40, 12, 12, T[7])              # 夕阳
    # 远山
    c.poly([(x0, y0 + 36), (x0 + 16, y0 + 22), (x0 + 30, y0 + 32), (x0 + 50, y0 + 16), (x0 + 72, y0 + 30),
            (x0 + w - 1, y0 + 20), (x0 + w - 1, y0 + 46), (x0, y0 + 46)], T[4])
    # 近处的山脊：缓缓往右上，九个人走在上面
    ridge = lambda x: y0 + 52 - int(x * 0.08)
    c.poly([(x0, ridge(0)), (x0 + w - 1, ridge(w - 1)), (x0 + w - 1, y0 + h - 1), (x0, y0 + h - 1)], T[0])
    k = T[0]
    # (相对 x, 身高, 特征)：甘道夫带头，阿拉贡，莱戈拉斯背弓，金雳矮而宽，波罗莫，四个霍比特人
    people = [(80, 20, "hat"), (71, 19, ""), (63, 19, "bow"), (55, 13, "wide"), (47, 19, "shield"),
              (39, 12, ""), (33, 12, ""), (27, 11, ""), (21, 11, "")]
    for px, ph, kind in people:
        x = x0 + px
        base = ridge(px) - 1
        hw = 3 if kind == "wide" else 2
        c.poly([(x - hw, base - 2), (x - hw + 1, base - ph + 4), (x + hw - 1, base - ph + 4), (x + hw, base - 2)], k)
        c.ellipse(x, base - ph + 2, 1, 2, k)                       # 头
        c.line(x - 1, base - 2, x - 3, base, k)                     # 迈开的两条腿
        c.line(x + 1, base - 2, x + 2, base, k)
        if kind == "hat":
            c.poly([(x - 4, base - ph + 1), (x + 4, base - ph + 1), (x - 1, base - ph - 6)], k)
            c.line(x + 4, base - ph + 2, x + 4, base, k)            # 法杖
        if kind == "bow":
            c.line(x - 3, base - ph + 3, x - 4, base - ph + 9, k)
            c.line(x - 4, base - ph + 9, x - 3, base - ph + 15, k)
        if kind == "shield":
            c.ellipse(x - 3, base - ph + 9, 2, 3, k)
        if kind == "wide":
            c.line(x + 3, base - ph + 3, x + 5, base - ph + 1, k)   # 斧头
            c.rect(x + 4, base - ph, x + 6, base - ph + 1, k)


# ------------------------------------------------------------------ 11 哈利波特：霍格沃茨（2001）
def hogwarts(c, x0, y0, w, h, T):
    sky(c, x0, y0, w, h, T, 0.1, 0.32, y_end=46)
    for sx, sy in ((6, 4), (22, 10), (40, 3), (12, 22), (52, 14), (86, 34)):
        c.put(x0 + sx, y0 + sy, T[5])
    shaded_disc(c, x0 + 70, y0 + 14, 11, T, 5, 7, light=(-0.2, -0.3))
    # 湖面
    for y in range(46, h):
        c.rect(x0, y0 + y, x0 + w - 1, y0 + y, _q(T, 0.14 + 0.06 * ((y - 46) % 4 == 0)))
    # 城堡：悬崖上几座粗细不一的塔（锥形尖顶）+ 带城垛的城墙 + 大礼堂的高窗
    k = T[0]
    c.poly([(x0 + 2, y0 + 47), (x0 + 8, y0 + 40), (x0 + 62, y0 + 38), (x0 + 72, y0 + 47)], k)   # 悬崖
    c.rect(x0 + 8, y0 + 30, x0 + 60, y0 + 40, k)                                                 # 城墙
    for cx in range(x0 + 8, x0 + 60, 3):
        c.put(cx, y0 + 29, k)                                                                    # 城垛
    c.rect(x0 + 22, y0 + 22, x0 + 42, y0 + 30, k)                                                # 大礼堂
    c.poly([(x0 + 21, y0 + 22), (x0 + 43, y0 + 22), (x0 + 32, y0 + 15)], k)
    for wx in range(x0 + 24, x0 + 42, 4):
        c.rect(wx, y0 + 24, wx, y0 + 28, T[6])                                                   # 高窗
    towers = [(12, 26, 3), (19, 14, 2), (50, 30, 4), (57, 18, 2), (45, 12, 2)]                   # (x, 高, 半宽)
    for tx, th, tw in towers:
        x = x0 + tx
        top = y0 + 38 - th
        c.rect(x - tw, top, x + tw, y0 + 38, k)
        c.poly([(x - tw - 1, top), (x + tw + 1, top), (x, top - tw * 3 - 2)], k)
        for wy in range(top + 3, y0 + 30, 5):
            c.put(x, wy, T[6])
    for wx in range(x0 + 10, x0 + 60, 5):
        if wx < x0 + 22 or wx > x0 + 42:
            c.put(wx, y0 + 34, T[6])
    # 窗户倒影在湖里
    for rx in range(x0 + 12, x0 + 60, 6):
        c.rect(rx, y0 + 49, rx, y0 + 52, T[4])
        c.put(rx, y0 + 55, T[3])
    # 骑扫帚的人飞过月亮：扫帚斜着，斗篷往后飘
    bx, by = x0 + 70, y0 + 15
    s = T[0]
    c.line(bx - 9, by + 3, bx + 8, by - 2, s)                                         # 扫帚杆
    c.poly([(bx - 9, by + 3), (bx - 14, by + 1), (bx - 14, by + 6)], s)              # 扫帚尾
    c.rect(bx - 2, by - 5, bx + 1, by, s)                                             # 身子
    c.ellipse(bx + 1, by - 7, 1, 1, s)                                                # 头
    c.poly([(bx - 2, by - 4), (bx - 8, by - 6), (bx - 3, by - 1)], s)                 # 斗篷
    c.line(bx, by, bx - 2, by + 3, s)                                                 # 腿
    # 猫头鹰
    ox, oy = x0 + 30, y0 + 8
    c.line(ox - 3, oy - 1, ox, oy + 1, T[6])
    c.line(ox, oy + 1, ox + 3, oy - 1, T[6])
    c.put(ox, oy, T[6])


SCENES = [trip_to_moon, arrival_of_train, lotr_bridge, modern_times, metropolis, hogwarts, nosferatu, king_kong,
          lotr_fellowship, safety_last, et]
NAMES = ["月球旅行记", "火车进站", "指环王：你不能过去", "摩登时代", "大都会", "哈利波特：霍格沃茨", "诺斯费拉图", "金刚",
         "指环王：护戒队", "安全至下", "E.T."]
