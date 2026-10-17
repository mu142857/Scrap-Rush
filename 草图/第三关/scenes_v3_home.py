"""第三关「一家四口的家」五个场景的第三版（2026-10-17）：厨房、客厅、卧室、儿童房、玄关。

为什么重画：屏幕放大到 444×245 以后，旧画法（按 150 宽设计）的家具全挤在一个角落，大屏空得像没画完。
这一版的做法：
- 家具按正常比例（门约 48 高、沙发约 20 高，主角 13 高），不放大；靠"更多组东西"把宽度铺满。
- 每个房间写成几"组"（一组 = 地上的家具 + 它头顶墙上的东西），按屏幕大小挑放几组：
  大屏（玻璃宽 ≥ 330）全放，中屏（≥ 190）放一半，小屏只放最有代表性的一两组。
  组和组之间的空按随机权重分，不是固定间隔。
- 墙不再是一整片：天花板 + 顶角线、壁纸（条纹 / 菱点）、挂镜线、护墙板、踢脚线，把高墙分成几层。
- 每组用家具顶面给单向平台（plat），高度在地面以上 18~45 格，相邻平台横向不超过 60 格。
- 地面那一条（tv.fy 往上 14 格）只放家具的下半截，不放又亮又碎的小东西，怪在地上走要看得清。
- 每个房间都挂一张四个船员（红、铜、蓝、绿）的合照 k.crew_photo。

只用 crt_wall_v2 / l3_scenes 里的工具，不改它们；清单 l3_registry 会自动用这里的 SCENES_V3。
"""
import random

import numpy as np

import crt_wall_v2 as k
import l3_scenes as sc
from crt_wall_v2 import shade, box, panel, floor_shadow

CREW = [(206, 72, 64), (190, 140, 96), (96, 136, 214), (110, 180, 100)]     # 红、铜、蓝、绿
WOODD = (118, 84, 72)
WOODL = (150, 110, 88)
LAMP_LIT = (246, 226, 168)          # 发光色：最亮通道 ≥ 240，光照色块不动它
BOOKS = [(180, 84, 80), (96, 120, 170), (200, 180, 120), (110, 150, 110), (150, 110, 160), (220, 210, 190)]


def S():
    return k.scr


# ================================================================ 尺寸、排组
def dims(tv):
    """返回 (屏宽, 墙高, 档)。档：L 大屏、M 中屏、S 小屏。"""
    rw = tv.sx1 - tv.sx0
    wall_h = tv.fy - tv.sy0
    cls = "L" if rw >= 330 else ("M" if rw >= 190 else "S")
    return rw, wall_h, cls


def place(tv, groups, seed=0):
    """groups：[(名字, 宽, 优先级)]，按从左到右的顺序写。按优先级（小的先）挑放得下的组，
    剩下的空按随机权重分到组和组之间（两头的边距权重小一点），不是等距排。返回 {名字: 左边 x}。"""
    rw = tv.sx1 - tv.sx0
    margin = max(4, rw // 45)
    avail = rw - 2 * margin
    chosen, used = [], 0
    for i in sorted(range(len(groups)), key=lambda i: groups[i][2]):
        w = groups[i][1]
        if used + w + 10 * len(chosen) <= avail:
            chosen.append(i)
            used += w
    chosen.sort()
    left = avail - used
    rr = random.Random(seed * 31 + rw)
    wts = [0.45] + [rr.uniform(0.7, 1.5) for _ in range(len(chosen) - 1)] + [0.45]
    s = sum(wts)
    pos, x = {}, tv.sx0 + margin + left * wts[0] / s
    for j, i in enumerate(chosen):
        pos[groups[i][0]] = int(x)
        x += groups[i][1] + left * wts[j + 1] / s
    return pos


def clampy(tv, y, pad=6):
    """墙上的东西别顶出天花板。"""
    return max(tv.sy0 + pad, y)


# ================================================================ 墙：天花板、壁纸、挂镜线、护墙板、踢脚线
def retone(mask, kk):
    """把 mask 里已经画好的颜色各自挪 kk 档（壁纸条纹用：跟着墙上的灯光档走，只暗 / 亮一档）。"""
    a = S().a
    m = mask & (a[..., 3] > 0)
    px = a[..., :3][m]
    if not len(px):
        return
    keys, inv = np.unique(px, axis=0, return_inverse=True)
    new = np.array([shade(tuple(int(v) for v in c), kk) for c in keys], np.uint8)
    a[..., :3][m] = new[inv.ravel()]


def dress_walls(tv, wallc, paper="stripe", wains=None, wains_h=None):
    """高墙分层：最上面一条天花板 + 顶角线；中间壁纸；大屏多一道挂镜线；下面护墙板 + 踢脚线。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wall_h, cls = dims(tv)
    inside = tv.screen_mask()
    XX, YY = k.XX, k.YY
    ceil = max(3, wall_h // 30)
    S().fill_mask(inside & (YY < y0 + ceil), shade(wallc[3], -1))               # 天花板（背光，偏冷）
    S().fill_mask(inside & (YY == y0 + ceil), shade(wallc[1], 1))                # 顶角线：亮的一道
    S().fill_mask(inside & (YY == y0 + ceil + 1), shade(wallc[2], -1))           # 下面一道影子
    wains_h = wains_h or (12 if cls != "S" else 8)
    rail = fy - wains_h
    pic = fy - int(wall_h * 0.62) if cls != "S" else None                         # 挂镜线（只在高墙上）
    top = (pic + 2) if pic else (y0 + ceil + 2)
    band = inside & (YY >= top) & (YY < rail - 1)
    if paper == "stripe":
        retone(band & (((XX - x0) % 10) < 3), -1)
    elif paper == "dots":
        retone(band & (((XX - x0) % 12 == 0) & ((YY - y0) % 12 == 0) | ((XX - x0) % 12 == 6) & ((YY - y0) % 12 == 6)), -1)
    elif paper == "tile":                                                          # 半高的瓷砖墙
        t = inside & (YY >= rail - int(wall_h * 0.22)) & (YY < rail)
        retone(t & ((((XX - x0) % 7) == 0) | (((YY - fy) % 6) == 0)), -1)
    if pic:
        S().fill_mask(inside & (YY == pic), shade(wallc[1], 1))
        S().fill_mask(inside & (YY == pic + 1), shade(wallc[2], -1))
    wc = wains or (shade(wallc[3], -1), shade(wallc[2], 0))
    S().fill_mask(inside & (YY >= rail) & (YY < fy), wc[0])                      # 护墙板：低对比，不抢地上怪的戏
    S().fill_mask(inside & (YY == rail), wc[1])
    S().fill_mask(inside & (YY == rail + 1), shade(wc[0], -1))
    S().fill_mask(inside & (YY >= fy - 2) & (YY < fy), shade(wc[0], -2))         # 踢脚线


# ================================================================ 墙上的东西
def tall_window(tv, x, top, w, h, curtain=(140, 112, 136), floor_len=True, moon=True):
    """窗 + 窗台 + 窗帘杆和两片窗帘（竖褶，内侧一道亮边，中间一条束带）。窗帘占窗两边各 12 格。"""
    fy = tv.fy
    k.window(x, top, w, h, frame=(150, 122, 116), moon=moon)
    box(x - 4, top + h + 3, x + w + 4, top + h + 4, (176, 150, 140), depth=0.04)
    if curtain is None:
        return
    rod = top - 7
    S().line(x - 13, rod, x + w + 13, rod, (96, 76, 72))
    for ex in (x - 14, x + w + 14):
        S().rect(ex - 1, rod - 1, ex, rod + 1, (120, 96, 88))
    bot = fy - 3 if floor_len else top + h + 9
    tie = top + int(h * 0.62)
    for cx0, cx1, inner in [(x - 12, x + 1, x + 1), (x + w - 1, x + w + 12, x + w - 1)]:
        S().rect(cx0, rod + 1, cx1, bot, curtain)
        for fx in range(cx0 + 3, cx1, 4):
            S().line(fx, rod + 2, fx, bot, shade(curtain, -1))
        S().line(inner, rod + 1, inner, bot, shade(curtain, 1))
        S().line(cx0, bot, cx1, bot, shade(curtain, -2))
        S().rect(cx0, tie, cx1, tie + 1, shade(curtain, -2))


def painting(x, y, w, h, kind="hill", fc=(112, 84, 80)):
    """挂画：框挤出一点厚度，里面是一小幅画（风景 / 海 / 色块），别留空框。"""
    box(x - 2, y - 2, x + w + 1, y + h + 1, fc, depth=0.02)
    S().rect(x, y, x + w - 1, y + h - 1, (206, 210, 214))
    if kind == "hill":
        S().rect(x, y + h // 2, x + w - 1, y + h - 1, (190, 196, 200))
        S().poly([(x, y + h), (x, y + h * 0.6), (x + w * 0.45, y + h * 0.35), (x + w, y + h * 0.7), (x + w, y + h)], (120, 146, 124))
        S().poly([(x + w * 0.45, y + h), (x + w * 0.7, y + h * 0.55), (x + w, y + h * 0.75), (x + w, y + h)], (100, 126, 110))
        S().rect(x + w - 6, y + 2, x + w - 4, y + 4, (236, 214, 160))
    elif kind == "sea":
        S().rect(x, int(y + h * 0.55), x + w - 1, y + h - 1, (110, 140, 172))
        S().line(x, int(y + h * 0.55), x + w - 1, int(y + h * 0.55), (150, 176, 200))
        S().poly([(x + w * 0.3, y + h * 0.52), (x + w * 0.42, y + h * 0.52), (x + w * 0.36, y + h * 0.2)], (236, 232, 222))
    else:                                                                    # 几块颜色
        S().rect(x, y, x + w // 2, y + h - 1, (190, 150, 156))
        S().rect(x + w // 2, y + h // 2, x + w - 1, y + h - 1, (130, 150, 176))
        S().rect(x + w // 3, y + h // 3, x + w * 2 // 3, y + h * 2 // 3, (222, 200, 140))


def mirror(x, y, w, h, fc=(170, 140, 110)):
    box(x - 2, y - 2, x + w + 1, y + h + 1, fc, depth=0.02)
    S().rect(x, y, x + w - 1, y + h - 1, (176, 190, 202))
    S().rect(x, y + h * 2 // 3, x + w - 1, y + h - 1, (160, 174, 190))
    for i in range(min(w, h) // 2):
        S().put(x + 2 + i, y + h // 2 - i, (226, 234, 240))
        S().put(x + 5 + i, y + h // 2 + 2 - i, (214, 224, 232))


def wall_shelf(x0, x1, y, c=WOODL):
    """墙上的搁板：两个三角托架 + 一块挤出顶面的板子。东西放在 y 上面（底边 y-1）。"""
    for bx in (x0 + 3, x1 - 5):
        S().poly([(bx, y + 3), (bx + 3, y + 3), (bx + 3, y + 8)], shade(c, -2))
    box(x0, y, x1, y + 2, c)


def book_row(x, yb, n, lean=True):
    bx = x
    for i in range(n):
        bw, bh = [2, 3, 3, 2, 3][i % 5], [8, 9, 7, 10, 8][(i * 3) % 5]
        c = BOOKS[(i * 7 + x) % len(BOOKS)]
        S().rect(bx, yb - bh + 1, bx + bw - 1, yb, c)
        S().line(bx, yb - bh + 1, bx, yb, shade(c, 1))
        bx += bw
    if lean:                                                             # 最后一本斜靠着
        c = BOOKS[(n + x) % len(BOOKS)]
        S().poly([(bx, yb + 1), (bx + 3, yb + 1), (bx + 7, yb - 7), (bx + 4, yb - 8)], c)
        bx += 7
    return bx


def vase(x, yb, c=(150, 170, 186), stems=True):
    box(x, yb - 6, x + 4, yb, c, depth=0.03)
    if stems:
        for dx, hh in [(1, 6), (3, 8), (4, 5)]:
            S().line(x + 2, yb - 7, x + dx, yb - 6 - hh, (96, 140, 100))
            S().put(x + dx, yb - 7 - hh, (226, 170, 180))


def jar(x, yb, c, h=6):
    box(x, yb - h, x + 4, yb, c, depth=0.03)
    S().rect(x, yb - h - 1, x + 4, yb - h, shade(c, -3))


def frame_cluster(x, y, n=3, seed=0):
    """一小组相框：大小不一、高低错开。"""
    rr = random.Random(seed)
    kinds = ["hill", "sea", "blocks"]
    cx = x
    for i in range(n):
        w, h = rr.choice([(10, 13), (14, 10), (8, 10), (12, 16)])
        painting(cx, y + rr.randint(-6, 6), w, h, kinds[(i + seed) % 3], fc=rr.choice([(112, 84, 80), (170, 140, 110), (90, 80, 96)]))
        cx += w + rr.randint(5, 8)
    return cx


def sconce(x, y):
    """壁灯：一块小托板 + 发光的半圆灯罩。"""
    S().rect(x - 1, y + 2, x + 1, y + 6, (110, 86, 76))
    S().poly([(x - 4, y + 3), (x + 5, y + 3), (x + 3, y - 3), (x - 2, y - 3)], LAMP_LIT)
    S().poly([(x + 1, y + 3), (x + 5, y + 3), (x + 3, y - 3), (x + 1, y - 3)], (232, 204, 150))


def hanging_plant(x, ceil, y):
    """吊兰：三根绳从天花板收到盆上，叶子从盆沿垂下来。"""
    for dx in (-4, 0, 4):
        S().line(x, ceil, x + dx, y, (150, 126, 110))
    box(x - 4, y, x + 4, y + 6, (196, 168, 150), depth=0.03)
    for i, (dx, ln) in enumerate([(-5, 14), (-3, 20), (2, 11), (5, 17), (0, 8)]):
        for t in range(ln):
            px = x + dx + (1 if (t // 4) % 2 else 0) * (1 if dx >= 0 else -1)
            S().put(px, y + 5 + t, (96, 140, 104))
            if t % 4 == 2:
                S().put(px + (1 if dx >= 0 else -1), y + 5 + t, (130, 176, 124))


def calendar(x, y):
    S().rect(x, y, x + 9, y + 12, (232, 226, 210))
    S().rect(x, y, x + 9, y + 2, (196, 96, 90))
    for gy in range(y + 4, y + 12, 2):
        for gx in range(x + 1, x + 9, 2):
            S().put(gx, gy, (176, 170, 160))
    S().rect(x + 5, y + 8, x + 6, y + 9, (206, 72, 64))                 # 圈出来的那天


# ================================================================ 地上的家具
def table_lamp(cx, yb):
    S().rect(cx, yb - 6, cx + 1, yb, (96, 80, 76))
    box(cx - 2, yb - 1, cx + 3, yb, (150, 120, 100))
    S().poly([(cx - 5, yb - 6), (cx + 6, yb - 6), (cx + 4, yb - 12), (cx - 3, yb - 12)], LAMP_LIT)
    S().poly([(cx + 2, yb - 6), (cx + 6, yb - 6), (cx + 4, yb - 12), (cx + 2, yb - 12)], (232, 204, 150))


def side_table(x, fy, w=12, h=15, c=WOODL):
    floor_shadow(x, x + w, fy, 2)
    box(x, fy - h, x + w, fy, c)
    panel(x + 2, fy - h + 3, x + w - 2, fy - h + 7, c)
    return fy - h


def radio(x, yb):
    """老收音机：木壳、布面喇叭、一个调台的刻度窗。"""
    c = (132, 92, 76)
    box(x, yb - 8, x + 12, yb, c)
    S().rect(x + 2, yb - 6, x + 6, yb - 2, (176, 150, 120))
    for gy in range(yb - 6, yb - 1, 2):
        S().line(x + 2, gy, x + 6, gy, (150, 124, 100))
    S().rect(x + 8, yb - 6, x + 10, yb - 4, (226, 200, 140))
    S().put(x + 9, yb - 2, (90, 70, 66))


def coffee_table(x0, x1, fy, c=(132, 96, 80)):
    floor_shadow(x0, x1, fy, 2)
    for lx in (x0 + 2, x1 - 3):
        S().rect(lx, fy - 7, lx + 1, fy, shade(c, -2))
    box(x0, fy - 9, x1, fy - 7, c)
    S().rect(x0 + 5, fy - 12, x0 + 13, fy - 10, (196, 186, 166)); S().rect(x0 + 6, fy - 14, x0 + 12, fy - 13, (150, 110, 160))   # 一摞书
    box(x1 - 9, fy - 13, x1 - 6, fy - 10, (226, 220, 206), depth=0.02)                  # 茶杯


def media_unit(x, fy, w=50):
    """电视柜 + 木壳显像管电视（兔耳天线）。返回电视顶面的 (x0, x1, y)。"""
    cab = (112, 82, 72)
    floor_shadow(x, x + w, fy, 3)
    box(x, fy - 12, x + w, fy, cab)
    panel(x + 3, fy - 10, x + w // 2 - 2, fy - 3, cab); panel(x + w // 2 + 1, fy - 10, x + w - 3, fy - 3, cab)
    S().put(x + w // 2 - 4, fy - 6, (220, 190, 130)); S().put(x + w // 2 + 3, fy - 6, (220, 190, 130))
    tx0 = x + (w - 28) // 2
    tc = (150, 112, 88)
    box(tx0, fy - 33, tx0 + 28, fy - 13, tc)
    S().rect(tx0 + 2, fy - 31, tx0 + 19, fy - 15, (70, 80, 96))
    S().rect(tx0 + 3, fy - 30, tx0 + 18, fy - 16, (120, 150, 190))
    for i, c in enumerate(CREW):                                        # 小电视里也是那四个人
        S().rect(tx0 + 5 + i * 3, fy - 24, tx0 + 6 + i * 3, fy - 19, c)
    S().put(tx0 + 4, fy - 29, (200, 220, 240)); S().put(tx0 + 5, fy - 29, (176, 200, 230))
    for gy in range(fy - 30, fy - 20, 2):
        S().line(tx0 + 21, gy, tx0 + 26, gy, shade(tc, -2))
    S().rect(tx0 + 22, fy - 18, tx0 + 23, fy - 17, (90, 70, 66)); S().rect(tx0 + 25, fy - 18, tx0 + 26, fy - 17, (90, 70, 66))
    S().line(tx0 + 12, fy - 34, tx0 + 6, fy - 46, (96, 86, 86)); S().line(tx0 + 15, fy - 34, tx0 + 22, fy - 45, (96, 86, 86))
    return tx0, tx0 + 28, fy - 33


def tall_plant(x, fy, h=36):
    """大盆栽（琴叶榕）：盆 + 细干 + 一串前后错开的叶片，左上朝光亮、右下暗。"""
    pot = (176, 120, 96)
    floor_shadow(x - 2, x + 12, fy, 3)
    S().line(x + 5, fy - 9, x + 5, fy - h + 4, (96, 74, 66))
    rr = random.Random(x)
    leaves = []
    for i in range(9):
        ly = fy - 12 - i * (h - 14) // 9
        lx = x + 5 + rr.choice([-6, -4, 3, 5]) * (1 if i % 2 else -1) // 1
        leaves.append((ly, lx))
    for ly, lx in leaves:
        lit = 1 if lx < x + 5 else -1
        c = shade((100, 146, 108), lit)
        S().poly([(lx - 4, ly + 1), (lx, ly - 3), (lx + 4, ly), (lx, ly + 3)], c)
        S().line(lx - 3, ly + 1, lx + 3, ly, shade(c, -1))
    box(x, fy - 9, x + 10, fy, pot, depth=0.04)
    S().line(x, fy - 9, x + 10, fy - 9, shade(pot, 2))


def stool(x, fy, c=WOODL):
    floor_shadow(x, x + 9, fy, 2)
    S().rect(x + 1, fy - 12, x + 2, fy, shade(c, -2)); S().rect(x + 7, fy - 12, x + 8, fy, shade(c, -2))
    S().line(x + 1, fy - 5, x + 8, fy - 5, shade(c, -2))
    box(x - 1, fy - 14, x + 10, fy - 12, c)


def chair_side(x, fy, face=1, c=WOODL):
    """侧面的椅子：face=1 朝右（靠背在左）。"""
    bx = x if face > 0 else x + 7
    box(bx, fy - 24, bx + 1, fy, shade(c, -1))
    box(x, fy - 11, x + 8, fy - 9, shade(c, -1))
    S().rect(x + (7 if face > 0 else 0), fy - 8, x + (8 if face > 0 else 1), fy, shade(c, -2))


# ================================================================ 客厅
def room_living(tv):
    """客厅（米色监控屏）：窗、书架和挂钟、沙发和茶几和一墙相框、扶手椅和落地灯、电视柜、第二扇窗。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wall_h, cls = dims(tv)
    sofa_w = 84 if cls != "S" else 64
    groups = [("winA", 50, 3), ("books", 44, 4), ("sofa", sofa_w + 8, 0), ("lamp", 52 if cls != "S" else 16, 1),
              ("media", 54, 2), ("winB", 48, 5)]
    pos = place(tv, groups, seed=1)
    lamp_y = clampy(tv, fy - min(58, int(wall_h * 0.5)))
    lamps = []
    if "lamp" in pos:
        lamps.append((pos["lamp"] + (32 if cls != "S" else 7), lamp_y))
    for g in ("winA", "winB"):
        if g in pos:
            lamps.append((pos[g] + 25, fy - int(wall_h * 0.45)))
    if "sofa" in pos and cls == "L":
        lamps.append((pos["sofa"] + sofa_w // 2, y0 + int(wall_h * 0.25)))
    main = lamps[0] if lamps else ((x0 + x1) // 2, y0 + 30)
    k.room_base(tv, k.WARM_WALL, k.WARM_FLOOR, main, lamps=lamps or None)
    dress_walls(tv, k.WARM_WALL, "stripe", wains=((150, 112, 104), (186, 146, 128)))
    win_h = int(np.clip(wall_h * 0.3, 24, 64))
    win_top = clampy(tv, fy - 34 - win_h, 14)

    if "winA" in pos:
        gx = pos["winA"]
        tall_window(tv, gx + 13, win_top, 24, win_h)
        tall_plant(gx + 40, fy, 34) if cls == "L" else None
    if "books" in pos:
        gx = pos["books"]
        k.bookshelf(gx + 3, fy, 36, 44)
        sc.plat(gx + 3, gx + 39, fy - 44)
        k.wall_clock(gx + 21, clampy(tv, fy - 64, 10))
        if cls == "L":
            painting(gx + 8, clampy(tv, fy - 104), 26, 18, "sea")
    if "sofa" in pos:
        gx = pos["sofa"]
        k.rug(gx + sofa_w // 2 + 4, fy, sofa_w * 0.62)
        # 沙发上方一墙相框：合照在正中，两边错落几幅小的
        cy = clampy(tv, fy - 52, 8)
        k.crew_photo(gx + sofa_w // 2 - 6, cy)
        if cls != "S":
            painting(gx + 6, cy - 6, 16, 20, "hill")
            frame_cluster(gx + sofa_w // 2 + 22, cy - 2, 2, seed=3)
        if cls == "L":
            hanging_plant(gx + sofa_w - 6, y0 + 4, fy - int(wall_h * 0.48))
            painting(gx + sofa_w // 2 - 14, clampy(tv, fy - 100), 34, 24, "blocks")
        k.sofa(gx + 4, gx + 4 + sofa_w, fy)
        sc.plat(gx + 7, gx + sofa_w + 1, fy - 21)
        if cls != "S":
            coffee_table(gx + sofa_w // 2 - 14, gx + sofa_w // 2 + 20, fy)
    if "lamp" in pos:
        gx = pos["lamp"]
        if cls != "S":
            k.armchair(gx + 3, fy)
            sc.plat(gx + 1, gx + 22, fy - 23)
            k.floor_lamp(gx + 32, fy, lamp_y)
            ty = side_table(gx + 38, fy, 12, 15)
            radio(gx + 38, ty - 1)
        else:
            k.floor_lamp(gx + 7, fy, lamp_y)
    if "media" in pos:
        gx = pos["media"]
        t0, t1, ty = media_unit(gx + 2, fy, 50)
        sc.plat(t0, t1, ty)
        wall_shelf(gx + 4, gx + 50, clampy(tv, fy - 62))
        sy_ = clampy(tv, fy - 62)
        book_row(gx + 8, sy_ - 1, 7)
        vase(gx + 40, sy_ - 1)
    if "winB" in pos:
        gx = pos["winB"]
        tall_window(tv, gx + 12, win_top + 6, 24, win_h - 6)
        k.plant(gx + 36, fy) if cls == "L" else None
    k.finish_room(tv, main)


# ================================================================ 厨房
def counter_run(tv, x0, x1, stove_x, sink_x, upper=True):
    """一排橱柜：下柜 + 台面 + 灶台（烤箱门、旋钮）+ 水槽（龙头）；上面瓷砖墙、吊柜、抽油烟机（管子通到天花板）。
    返回台面的 y。"""
    fy, y0 = tv.fy, tv.sy0
    rw, wall_h, cls = dims(tv)
    c = (176, 160, 146)
    top = fy - 19
    # 台面和吊柜之间的瓷砖墙
    up_bot = fy - 44
    S().rect(x0, up_bot, x1, top - 1, (214, 210, 196))
    for gy in range(top - 1, up_bot, -6):
        S().line(x0, gy, x1, gy, (190, 184, 170))
    for gx in range(x0 + 3, x1, 7):
        S().line(gx, up_bot, gx, top - 1, (190, 184, 170))
    floor_shadow(x0, x1, fy, 3)
    box(x0, fy - 16, x1, fy, c)
    dx = x0 + 3
    while dx < x1 - 9:
        if stove_x - 2 <= dx <= stove_x + 18:
            dx = stove_x + 21
            continue
        panel(dx, fy - 13, dx + 10, fy - 2, c); S().put(dx + 8, fy - 8, shade(c, -5))
        dx += 13
    # 灶台：烤箱门（深色玻璃窗）+ 一排旋钮
    oc = (196, 196, 196)
    S().rect(stove_x, fy - 16, stove_x + 18, fy - 1, oc)
    S().rect(stove_x + 3, fy - 10, stove_x + 15, fy - 3, (70, 70, 84))
    S().line(stove_x + 4, fy - 9, stove_x + 8, fy - 9, (120, 120, 140))
    S().line(stove_x + 3, fy - 12, stove_x + 15, fy - 12, shade(oc, -3))
    for i in range(4):
        S().put(stove_x + 3 + i * 4, fy - 14, (80, 76, 84))
    box(x0 - 1, top, x1 + 1, top + 2, (214, 204, 190))                    # 台面
    # 水槽：台面上一道深色缝 + 鹅颈龙头
    S().rect(sink_x, top, sink_x + 14, top, (120, 130, 146))
    S().line(sink_x + 7, top - 1, sink_x + 7, top - 7, (170, 176, 190)); S().line(sink_x + 7, top - 7, sink_x + 11, top - 7, (170, 176, 190))
    S().put(sink_x + 11, top - 6, (170, 176, 190))
    # 灶上的水壶
    box(stove_x + 4, top - 6, stove_x + 11, top - 1, (130, 150, 176))
    S().rect(stove_x + 6, top - 8, stove_x + 9, top - 7, (90, 96, 110))
    S().line(stove_x + 12, top - 4, stove_x + 14, top - 6, (130, 150, 176))
    # 台面上：一个果盘、一个砧板
    if x1 - x0 > 70:
        rx = sink_x + 22 if sink_x + 40 < x1 else x0 + 4
        box(rx, top - 3, rx + 10, top - 1, (176, 140, 104), depth=0.03)
        for i, fc in enumerate([(206, 110, 96), (220, 190, 110), (150, 180, 110)]):
            S().rect(rx + 1 + i * 3, top - 6, rx + 3 + i * 3, top - 4, fc)
    if not upper:
        return top
    # 吊柜（比视线低时露顶面），灶台上方换成抽油烟机，管子一直通到天花板
    ub_top = fy - 64
    for sx_, ex_ in [(x0, stove_x - 3), (stove_x + 22, x1)]:
        if ex_ - sx_ < 12:
            continue
        box(sx_, ub_top, ex_, up_bot - 1, c)
        d = sx_ + 2
        while d < ex_ - 9:
            panel(d, ub_top + 3, d + 10, up_bot - 4, c); S().put(d + 8 if d % 2 else d + 2, up_bot - 7, shade(c, -5))
            d += 13
    hc = (186, 186, 190)
    S().poly([(stove_x - 4, up_bot - 2), (stove_x + 22, up_bot - 2), (stove_x + 15, up_bot - 12), (stove_x + 3, up_bot - 12)], hc)
    S().line(stove_x - 4, up_bot - 2, stove_x + 22, up_bot - 2, shade(hc, -3))
    S().rect(stove_x + 6, y0 + 3, stove_x + 12, up_bot - 13, shade(hc, -1))
    S().line(stove_x + 12, y0 + 3, stove_x + 12, up_bot - 13, shade(hc, -3))
    # 吊柜下挂着的勺子、锅铲
    for i, uc in enumerate([(160, 160, 170), (176, 130, 100), (160, 160, 170)]):
        ux = sink_x - 14 + i * 4
        if x0 + 2 < ux < x1 - 2:
            S().line(ux, up_bot + 1, ux, up_bot + 7, uc); S().rect(ux - 1, up_bot + 8, ux + 1, up_bot + 10, uc)
    return top


def hutch(x, fy, w=34):
    """碗柜：下面两扇门、一层台面，上面敞开的两层搁板摆着盘子和杯子。返回台面 y。"""
    c = (150, 168, 176)
    floor_shadow(x, x + w, fy, 4)
    box(x + 2, fy - 52, x + w - 2, fy - 20, c)
    S().rect(x + 4, fy - 49, x + w - 4, fy - 21, shade(c, -3))               # 里面是暗的
    for sy_ in (fy - 38, fy - 29):
        S().rect(x + 4, sy_, x + w - 4, sy_ + 1, shade(c, 1))
    for i in range(4):                                                         # 竖着立的盘子
        px = x + 6 + i * 6
        S().fill_mask((k.XX - px) ** 2 + (k.YY - (fy - 42)) ** 2 <= 7, (226, 222, 210))
        S().put(px, fy - 42, (190, 176, 196))
    for i, cc in enumerate(CREW):                                              # 四个人的杯子
        cx = x + 6 + i * 6
        S().rect(cx, fy - 34, cx + 3, fy - 30, cc); S().put(cx + 4, fy - 32, cc)
    box(x, fy - 55, x + w, fy - 53, shade(c, 1))                              # 顶檐
    box(x, fy - 20, x + w, fy - 18, (206, 200, 190))                          # 台面
    box(x + 1, fy - 17, x + w - 1, fy, c)
    panel(x + 3, fy - 15, x + w // 2 - 2, fy - 3, c); panel(x + w // 2 + 1, fy - 15, x + w - 4, fy - 3, c)
    return fy - 20


def room_kitchen(tv):
    """厨房（木壳彩电）：冰箱和日历、一排橱柜（灶台、水槽、吊柜、抽油烟机、窗）、餐桌和插四根蜡烛的蛋糕、碗柜、调料架。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wall_h, cls = dims(tv)
    run_w = 118 if cls == "L" else (96 if cls == "M" else 70)
    groups = [("fridge", 34, 2), ("run", run_w, 0), ("dine", 66, 1), ("hutch", 38, 3), ("spice", 34, 4)]
    if cls == "S":
        groups = [("run", run_w, 0), ("fridge", 26, 1)]
    pos = place(tv, groups, seed=2)
    lamp_y = clampy(tv, fy - min(62, int(wall_h * 0.5)))
    lamps = []
    if "dine" in pos:
        lamps.append((pos["dine"] + 34, lamp_y))
    if "run" in pos:
        lamps.append((pos["run"] + run_w // 2 + (14 if cls != "S" else 0), lamp_y - 8))
    if "spice" in pos:
        lamps.append((pos["spice"] + 16, lamp_y))
    main = lamps[0]
    k.room_base(tv, [(222, 206, 160), (206, 188, 146), (186, 166, 132), (160, 140, 120), (132, 114, 108)], k.TILE_FLOOR, main, lamps=lamps)
    for gx in range(x0, x1, 8):                                               # 地砖缝
        S().line(gx, fy + 1, gx, tv.sy1, (150, 142, 136))
    wallc = [(222, 206, 160), (206, 188, 146), (186, 166, 132), (160, 140, 120)]
    dress_walls(tv, wallc, "dots", wains=((176, 160, 140), (200, 186, 160)), wains_h=6)

    if "fridge" in pos:
        gx = pos["fridge"]
        if cls != "S":
            calendar(gx + 22, clampy(tv, fy - 66))
            k.fridge(gx + 4, fy, 22, 44)
            box(gx + 8, fy - 52, gx + 18, fy - 45, (206, 186, 140))          # 冰箱顶上的面包篮
            sc.plat(gx + 4, gx + 26, fy - 44)
        else:
            k.fridge(gx + 2, fy, 20, 40)
    if "run" in pos:
        gx = pos["run"]
        x_a, x_b = gx, gx + run_w
        stove = x_a + run_w // 2 + (6 if cls != "S" else -4)
        sink = x_a + 8
        if cls != "S":                                                         # 水槽上面一扇窗（有短窗帘）
            wtop = clampy(tv, fy - 44 - 34 - (12 if cls == "L" else 4), 14)
            k.window(sink - 2, wtop, 22, fy - 44 - 10 - wtop, frame=(150, 122, 116))
            S().rect(sink - 4, wtop - 3, sink + 22, wtop + 4, (206, 150, 150))
            for fx in range(sink - 3, sink + 22, 3):
                S().put(fx, wtop + 4, shade((206, 150, 150), -2))
        top = counter_run(tv, x_a, x_b, stove, sink if cls != "S" else x_a + 30, upper=(cls != "S"))
        if cls == "S":
            k.crew_photo(x_a + 8, clampy(tv, fy - 48, 10))
        sc.plat(x_a, x_b, top)
    if "dine" in pos:
        gx = pos["dine"]
        # 餐桌上方：一条摆盘子的搁板（能站，桌面只有 14 高不够）、合照、挂钟
        k.crew_photo(gx + 8, clampy(tv, fy - 66))
        k.wall_clock(gx + 50, clampy(tv, fy - 64), 6)
        wall_shelf(gx + 10, gx + 56, fy - 40)
        for i in range(5):
            px = gx + 15 + i * 9
            S().fill_mask((k.XX - px) ** 2 + (k.YY - (fy - 45)) ** 2 <= 10, (226, 222, 210))
            S().fill_mask((k.XX - px) ** 2 + (k.YY - (fy - 45)) ** 2 <= 3, [(206, 150, 140), (150, 170, 196), (206, 190, 130)][i % 3])
        sc.plat(gx + 10, gx + 56, fy - 40)
        k.table_chairs(gx + 13, fy, 40)
    if "hutch" in pos:
        gx = pos["hutch"]
        top = hutch(gx + 2, fy, 34)
        sc.plat(gx + 2, gx + 36, top)
        if cls == "L":
            painting(gx + 8, clampy(tv, fy - 84), 22, 16, "hill")
    if "spice" in pos:
        gx = pos["spice"]
        sy_ = fy - 36
        wall_shelf(gx + 2, gx + 32, sy_)
        for i, jc in enumerate([(196, 120, 96), (220, 200, 130), (150, 176, 120), (176, 160, 196), (206, 150, 120)]):
            jar(gx + 5 + i * 5, sy_ - 1, jc, 5 + (i % 2) * 2)
        sc.plat(gx + 2, gx + 32, sy_)
        stool(gx + 12, fy)
        if cls == "L":
            hanging_plant(gx + 17, y0 + 4, fy - int(wall_h * 0.5))
    # 餐桌上的吊灯（主光）、灶台上的一盏
    if "dine" in pos:
        k.hanging_lamp(pos["dine"] + 34, y0, lamp_y)
    if "run" in pos and cls == "S":
        k.hanging_lamp(lamps[0][0], y0, lamps[0][1])
    k.finish_room(tv, main)


# ================================================================ 卧室
def dresser(x, fy, w=34, h=24, c=(140, 104, 88)):
    floor_shadow(x, x + w, fy, 4)
    box(x, fy - h, x + w, fy, c)
    rows = 3
    rh = (h - 4) // rows
    for r in range(rows):
        ry = fy - h + 2 + r * rh
        panel(x + 2, ry, x + w // 2 - 1, ry + rh - 2, c); panel(x + w // 2 + 1, ry, x + w - 2, ry + rh - 2, c)
        S().put(x + w // 4, ry + rh // 2 - 1, (226, 196, 130)); S().put(x + 3 * w // 4, ry + rh // 2 - 1, (226, 196, 130))
    S().rect(x + 1, fy - 2, x + 2, fy, shade(c, -3)); S().rect(x + w - 2, fy - 2, x + w - 1, fy, shade(c, -3))
    return fy - h


def nightstand(x, fy, c=(140, 104, 88)):
    floor_shadow(x, x + 12, fy, 2)
    box(x, fy - 15, x + 12, fy, c)
    panel(x + 2, fy - 12, x + 10, fy - 8, c); panel(x + 2, fy - 6, x + 10, fy - 2, c)
    return fy - 15


def desk(x, fy, w=36, c=WOODL):
    """书桌：桌面、一侧抽屉柜、另一侧两条腿。返回桌面 y。"""
    floor_shadow(x, x + w, fy, 3)
    S().rect(x + w - 3, fy - 17, x + w - 2, fy, shade(c, -2))
    box(x + 1, fy - 17, x + 12, fy, c)
    panel(x + 3, fy - 14, x + 10, fy - 10, c); panel(x + 3, fy - 8, x + 10, fy - 2, c)
    box(x, fy - 19, x + w, fy - 18, shade(c, 1))
    return fy - 19


def typewriter(x, yb):
    c = (96, 104, 110)
    box(x, yb - 5, x + 14, yb, c)
    S().rect(x + 2, yb - 3, x + 12, yb - 2, (60, 64, 70))
    for kx in range(x + 2, x + 13, 2):
        S().put(kx, yb - 3, (200, 200, 196))
    S().rect(x + 3, yb - 11, x + 11, yb - 6, (236, 232, 220))                 # 夹着的纸
    S().line(x + 4, yb - 9, x + 9, yb - 9, (170, 166, 160))


def room_bedroom(tv):
    """卧室（灰色监控屏）：衣柜、床和两个床头柜和床头台灯、床头上方的搁板和合照、窗下的书桌和打字机、五斗柜和镜子。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wall_h, cls = dims(tv)
    bed_w = 60 if cls != "S" else 52
    groups = [("wardrobe", 36, 3), ("bed", bed_w + 30, 0), ("window", 52, 1), ("dresser", 44, 2)]
    if cls == "S":
        groups = [("bed", bed_w + 14, 0), ("dresser", 38, 1)]
    pos = place(tv, groups, seed=3)
    win_h = int(np.clip(wall_h * 0.3, 24, 60))
    lamps = []
    if "window" in pos:
        lamps.append((pos["window"] + 26, fy - 34 - win_h // 2))
    if "bed" in pos:
        lamps.append((pos["bed"] + 6, fy - 30))
    if "dresser" in pos and cls == "L":
        lamps.append((pos["dresser"] + 22, fy - 60))
    main = lamps[0]
    k.room_base(tv, k.BLUE_WALL, k.WARM_FLOOR, main, lamps=lamps)
    dress_walls(tv, k.BLUE_WALL, "dots", wains=((120, 128, 160), (156, 166, 192)))

    if "wardrobe" in pos:
        gx = pos["wardrobe"]
        k.wardrobe(gx + 3, fy, 30, 54)
        if cls == "L":
            painting(gx + 6, clampy(tv, fy - 100), 22, 28, "sea")
    if "bed" in pos:
        gx = pos["bed"]
        side = 14 if cls != "S" else 0
        bx = gx + side
        # 床头上方：搁板（能站）+ 合照 + 书
        shelf_y = fy - 38
        k.crew_photo(bx + bed_w // 2 - 4, clampy(tv, fy - 64, 8))
        wall_shelf(bx + 4, bx + 40, shelf_y)
        book_row(bx + 8, shelf_y - 1, 6)
        vase(bx + 32, shelf_y - 1, (176, 150, 186))
        sc.plat(bx + 4, bx + 40, shelf_y)
        if cls == "L":
            frame_cluster(bx + 2, clampy(tv, fy - 96), 3, seed=5)
        k.rug(bx + bed_w // 2 + 6, fy, bed_w * 0.55, (120, 110, 150), (140, 130, 168))
        if side:
            ty = nightstand(gx, fy)
            table_lamp(gx + 5, ty - 1)
        k.bed(bx, fy, bed_w)
        if cls != "S":
            ty = nightstand(bx + bed_w + 3, fy)
            box(bx + bed_w + 5, ty - 4, bx + bed_w + 10, ty - 1, (200, 196, 186), depth=0.03)   # 闹钟
            S().put(bx + bed_w + 7, ty - 3, (60, 60, 70))
    if "window" in pos:
        gx = pos["window"]
        tall_window(tv, gx + 14, clampy(tv, fy - 34 - win_h, 14), 24, win_h, curtain=(150, 140, 176), floor_len=False)
        dt = desk(gx + 8, fy, 34)
        typewriter(gx + 22, dt - 1)
        table_lamp(gx + 13, dt - 1)
        chair_side(gx + 42, fy, face=-1)
        sc.plat(gx + 8, gx + 42, dt)
    if "dresser" in pos:
        gx = pos["dresser"]
        dw = 34 if cls != "S" else 28
        top = dresser(gx + 3, fy, dw, 24)
        mirror(gx + 3 + dw // 2 - 8, clampy(tv, top - 30), 16, 22)
        box(gx + 7, top - 4, gx + 14, top - 1, (176, 120, 140), depth=0.03)     # 首饰盒
        vase(gx + dw - 4, top - 1, (150, 170, 186), stems=cls != "S")
        sc.plat(gx + 3, gx + 3 + dw, top)
        if cls == "L":
            tall_plant(gx + 40, fy, 30) if gx + 52 < x1 else None
    k.finish_room(tv, main)


# ================================================================ 儿童房
def cubby(x, fy, w=40, h=22, c=(176, 150, 120)):
    """矮格子柜：两层格子，下层放暗色收纳筐（贴地不抢眼），上层放书和玩具。返回顶面 y。"""
    floor_shadow(x, x + w, fy, 3)
    box(x, fy - h, x + w, fy, c)
    n = 3
    cw = (w - 4) // n
    for r in range(2):
        ry = fy - h + 2 + r * (h - 3) // 2
        for i in range(n):
            cx = x + 2 + i * cw
            S().rect(cx, ry, cx + cw - 2, ry + (h - 3) // 2 - 2, shade(c, -4))
            if r == 1:                                                     # 下层：收纳筐，颜色压暗
                bc = shade([(150, 120, 140), (120, 140, 150), (150, 140, 110)][i], -2)
                S().rect(cx + 1, ry + 2, cx + cw - 3, ry + (h - 3) // 2 - 2, bc)
                S().line(cx + 1, ry + 2, cx + cw - 3, ry + 2, shade(bc, 1))
            elif i == 0:
                book_row(cx + 1, ry + (h - 3) // 2 - 3, 3, lean=False)
            elif i == 1:                                                   # 一个泰迪熊
                bx_, by_ = cx + cw // 2 - 3, ry + (h - 3) // 2 - 3
                S().rect(bx_, by_ - 4, bx_ + 5, by_, (176, 130, 96)); S().rect(bx_ + 1, by_ - 7, bx_ + 4, by_ - 5, (176, 130, 96))
                S().put(bx_, by_ - 8, (176, 130, 96)); S().put(bx_ + 5, by_ - 8, (176, 130, 96)); S().put(bx_ + 2, by_ - 6, (60, 50, 50))
            else:
                S().rect(cx + 2, ry + 3, cx + cw - 4, ry + (h - 3) // 2 - 3, (206, 72, 64))   # 一辆小车
                S().put(cx + 3, ry + (h - 3) // 2 - 2, (40, 40, 50)); S().put(cx + cw - 5, ry + (h - 3) // 2 - 2, (40, 40, 50))
    return fy - h


def tent(x, fy, w=34, h=34):
    """帐篷（印第安小帐篷）：两片布，背光那片暗，开口是深色三角，顶上一面小旗。"""
    c = (220, 206, 180)
    floor_shadow(x, x + w, fy, 3)
    apex = (x + w // 2, fy - h)
    S().poly([(x, fy + 1), (apex[0], apex[1]), (x + w, fy + 1)], c)
    S().poly([(apex[0], apex[1]), (x + w, fy + 1), (apex[0] + 2, fy + 1)], shade(c, -2))
    for t in (0.35, 0.6):                                                  # 两道条纹
        yy = int(apex[1] + h * t)
        half = int(w / 2 * t)
        S().line(apex[0] - half, yy, apex[0] + half, yy, (190, 130, 120))
    S().poly([(apex[0] - 6, fy + 1), (apex[0], fy - h // 2), (apex[0] + 5, fy + 1)], (90, 80, 96))
    S().line(apex[0] - 2, apex[1] - 1, apex[0] - 4, apex[1] - 5, (110, 80, 70)); S().line(apex[0] + 2, apex[1] - 1, apex[0] + 4, apex[1] - 5, (110, 80, 70))
    S().poly([(apex[0] + 4, apex[1] - 5), (apex[0] + 10, apex[1] - 3), (apex[0] + 4, apex[1] - 1)], CREW[3])


def growth_chart(x, fy, y_top):
    """量身高的尺子：一条贴墙的纸，刻度，四个船员各一道彩色记号（高矮不一）。"""
    S().rect(x, y_top, x + 5, fy - 3, (232, 226, 206))
    for gy in range(fy - 6, y_top, -5):
        S().line(x, gy, x + (2 if (fy - gy) % 10 else 3), gy, (170, 160, 146))
    for i, (c, hh) in enumerate(zip(CREW, [26, 22, 30, 18])):
        S().rect(x + 1, fy - hh, x + 5, fy - hh, c)
        S().put(x + 6, fy - hh, c)


def kid_drawings(x, y, seed=0):
    """墙上胶带贴着的几张小孩画：一个太阳、一架飞船、一个房子。"""
    rr = random.Random(seed)
    for i in range(3):
        px, py = x + i * 13, y + rr.randint(-4, 4)
        S().rect(px, py, px + 9, py + 8, (236, 232, 220))
        S().put(px + 4, py - 1, (200, 196, 170)); S().put(px + 5, py - 1, (200, 196, 170))
        if i == 0:
            S().rect(px + 3, py + 2, px + 6, py + 5, (236, 190, 90))
        elif i == 1:
            S().line(px + 1, py + 5, px + 8, py + 3, (96, 136, 214)); S().put(px + 2, py + 6, (206, 72, 64))
        else:
            S().rect(px + 2, py + 4, px + 7, py + 7, (206, 120, 100)); S().line(px + 2, py + 4, px + 4, py + 2, (110, 180, 100)); S().line(px + 4, py + 2, px + 7, py + 4, (110, 180, 100))


def mobile(x, ceil, y):
    """天花板上垂下来的星球吊饰：一根横杆，三根线挂三个小星球。"""
    S().line(x, ceil, x, y, (150, 140, 130))
    S().line(x - 12, y, x + 12, y, (150, 130, 110))
    for dx, ln, c, r in [(-12, 10, (206, 150, 120), 3), (0, 16, (150, 176, 206), 4), (12, 8, (236, 214, 140), 2)]:
        S().line(x + dx, y, x + dx, y + ln, (150, 140, 130))
        sc.disc(x + dx, y + ln + r, r, c)
        S().put(x + dx - 1, y + ln + r - 1, shade(c, 2))
    S().line(x - 6, y + 23, x + 6, y + 21, (226, 196, 150))                  # 第二颗星球的环


def room_kids(tv):
    """儿童房（梅子色电视）：上下铺和星星贴纸、格子柜和泰迪熊、帐篷和火箭、书桌和小孩画、窗和星球吊饰、量身高的尺子。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wall_h, cls = dims(tv)
    groups = [("bunk", 54, 0), ("cubby", 46, 2), ("play", 56, 3), ("desk", 52, 1), ("window", 46, 4)]
    if cls == "S":
        groups = [("bunk", 52, 0), ("cubby", 40, 1)]
    pos = place(tv, groups, seed=4)
    lamp_y = clampy(tv, fy - min(66, int(wall_h * 0.5)))
    lamps = []
    if "desk" in pos:
        lamps.append((pos["desk"] + 10, fy - 30))
    if "cubby" in pos:
        lamps.append((pos["cubby"] + 22, lamp_y))
    if "window" in pos:
        lamps.append((pos["window"] + 23, fy - 70))
    if "bunk" in pos and cls == "S":
        lamps.insert(0, (pos["bunk"] + 40, lamp_y))
    main = lamps[0]
    k.room_base(tv, k.GREEN_WALL, k.WARM_FLOOR, main, lamps=lamps)
    dress_walls(tv, k.GREEN_WALL, "stripe", wains=((150, 160, 132), (186, 196, 166)), wains_h=8)

    if "bunk" in pos:
        gx = pos["bunk"]
        sy_a = clampy(tv, fy - int(wall_h * 0.7))
        if fy - 66 > sy_a + 4:
            k.stars(gx, sy_a, gx + 50, fy - 66, 4)
        k.crew_photo(gx + 14, clampy(tv, fy - 66 + (0 if cls != "S" else 10), 8))
        k.bunk(gx + 2, fy, 46)
        sc.plat(gx + 4, gx + 48, fy - 36)
    if "cubby" in pos:
        gx = pos["cubby"]
        cw_ = 40 if cls != "S" else 34
        top = cubby(gx + 3, fy, cw_, 22)
        sc.plat(gx + 3, gx + 3 + cw_, top)
        if cls != "S":
            k.rocket(gx + 30, top - 1) if cls == "L" else None
            growth_chart(gx + cw_ + 6 if cls == "L" else gx + 10, top - 4 if cls != "L" else fy, clampy(tv, fy - 60))
    if "play" in pos:
        gx = pos["play"]
        tent(gx + 4, fy, 34, 34)
        k.rocket(gx + 44, fy)
        wall_shelf(gx + 8, gx + 52, fy - 44)
        for i, tc in enumerate([(206, 120, 100), (120, 150, 196), (220, 196, 120)]):
            box(gx + 12 + i * 10, fy - 50, gx + 17 + i * 10, fy - 45, tc, depth=0.03)   # 积木
            S().put(gx + 14 + i * 10, fy - 50, shade(tc, 2))
        sc.plat(gx + 8, gx + 52, fy - 44)
    if "desk" in pos:
        gx = pos["desk"]
        kid_drawings(gx + 6, clampy(tv, fy - 52))
        dt = desk(gx + 4, fy, 32, (176, 150, 120))
        sc.disc(gx + 26, dt - 6, 4, (110, 150, 186)); S().rect(gx + 25, dt - 6, gx + 28, dt - 4, (120, 170, 110))   # 地球仪
        S().rect(gx + 26, dt - 2, gx + 27, dt - 1, (96, 80, 76))
        table_lamp(gx + 9, dt - 1)
        chair_side(gx + 40, fy, face=-1, c=(176, 150, 120))
        sc.plat(gx + 4, gx + 36, dt)
    if "window" in pos:
        gx = pos["window"]
        wh = int(np.clip(wall_h * 0.26, 22, 50))
        tall_window(tv, gx + 11, clampy(tv, fy - 40 - wh, 14), 24, wh, curtain=(206, 176, 140), floor_len=False)
        k.plant(gx + 18, fy)
    if cls != "S":
        mx = pos.get("cubby", pos.get("bunk", x0 + 30)) + 24
        mobile(mx, y0 + 4, clampy(tv, fy - int(wall_h * 0.55)))
        if fy - int(wall_h * 0.6) > y0 + 16:
            k.stars(x0 + 10, y0 + 12, x1 - 10, fy - int(wall_h * 0.6), 6 if cls == "L" else 3)
    k.hanging_lamp(lamps[-1][0] if cls == "S" else (pos.get("cubby", x0) + 22), y0, lamp_y) if cls != "L" or "cubby" in pos else None
    k.finish_room(tv, main)


# ================================================================ 玄关
def stairs(tv, x, steps=8, rise=5, run=6, c=(150, 112, 92)):
    """楼梯（侧面看）：一级级踏板挤出顶面，下面三角形墙里一扇储物小门；扶手和栏杆。
    第一跑通到休息平台，第二跑只画封闭的侧板（踩不上去，免得看着像能走）。返回 (各级踏板, 平台)。"""
    fy = tv.fy
    top_y = fy - steps * rise
    land_x0, land_x1 = x + steps * run, x + steps * run + 22
    # 第二跑：从平台往左上斜着回去，封闭侧板 + 扶手
    up = fy - steps * rise - 46
    S().poly([(land_x1, top_y - 2), (land_x1, up - 6), (x + 10, up + 30 - 6), (x + 10, up + 30 + 4)], shade(c, -2))
    S().line(land_x1, up - 7, x + 10, up + 30 - 7, shade(c, 1))
    for i in range(7):                                                        # 栏杆
        bx = x + 14 + i * (land_x1 - x - 18) // 7
        t = (bx - (x + 10)) / max(1, land_x1 - (x + 10))
        by = int(up + 30 - 6 - t * 30)
        S().line(bx, by - 1, bx, by - 12, shade(c, -1))
    S().line(x + 10, up + 30 - 19, land_x1, up - 19, shade(c, 1)); S().line(x + 10, up + 30 - 18, land_x1, up - 18, shade(c, -1))
    # 楼梯下的三角墙 + 储物小门
    S().poly([(x, fy + 1), (land_x0, top_y), (land_x1, top_y), (land_x1, fy + 1)], shade(c, -1))
    panel(land_x0 - 4, fy - 22, land_x0 + 10, fy - 2, shade(c, -1))
    S().put(land_x0 + 7, fy - 12, (226, 196, 130))
    floor_shadow(x, land_x1, fy, 3)
    treads = []
    for i in range(steps):
        sx_ = x + i * run
        sy_ = fy - (i + 1) * rise
        box(sx_, sy_, sx_ + run, sy_ + 1, c, depth=0.05)
        S().rect(sx_, sy_ + 2, sx_ + run, sy_ + rise, shade(c, -1))          # 踢面
        treads.append((sx_, sx_ + run, sy_))
    box(land_x0, top_y, land_x1, top_y + 2, c, depth=0.05)                   # 平台
    # 扶手：从第一级的立柱斜到平台的立柱
    box(x - 1, fy - rise - 16, x + 2, fy - rise, shade(c, 1))
    box(land_x1 - 3, top_y - 16, land_x1, top_y, shade(c, 1))
    S().line(x, fy - rise - 14, land_x1 - 2, top_y - 14, shade(c, 2)); S().line(x, fy - rise - 13, land_x1 - 2, top_y - 13, shade(c, -1))
    for i in range(1, steps, 2):
        bx = x + i * run + 2
        S().line(bx, fy - (i + 1) * rise - 1, bx, fy - (i + 1) * rise - 12, shade(c, -1))
    return treads, (land_x0, land_x1, top_y)


def console_table(x, fy, w=34, c=(132, 96, 80)):
    floor_shadow(x, x + w, fy, 3)
    for lx in (x + 2, x + w - 3):
        S().rect(lx, fy - 15, lx + 1, fy, shade(c, -2))
    S().line(x + 2, fy - 5, x + w - 2, fy - 5, shade(c, -2))
    box(x, fy - 19, x + w, fy - 16, c)
    panel(x + 4, fy - 15, x + w - 4, fy - 12, c)
    return fy - 19


def rotary_phone(x, yb):
    c = (176, 90, 84)
    S().poly([(x, yb), (x + 12, yb), (x + 10, yb - 5), (x + 2, yb - 5)], c)
    sc.disc(x + 6, yb - 3, 2, (226, 214, 196)); S().put(x + 6, yb - 3, shade(c, -2))
    S().rect(x - 1, yb - 8, x + 13, yb - 7, shade(c, 1)); S().rect(x - 1, yb - 7, x + 1, yb - 5, shade(c, 1)); S().rect(x + 11, yb - 7, x + 13, yb - 5, shade(c, 1))
    for t in range(6):                                                       # 卷曲的电话线
        S().put(x + 13 + t, yb - 1 + (t % 2), (120, 80, 76))


def bench(x, fy, w=36, c=WOODL):
    """换鞋凳：坐面 + 坐垫，下面一层放鞋的隔板（四双鞋压暗，不抢地面那一条）。"""
    floor_shadow(x, x + w, fy, 3)
    for lx in (x + 1, x + w - 2):
        S().rect(lx, fy - 11, lx + 1, fy, shade(c, -2))
    box(x, fy - 13, x + w, fy - 11, c)
    box(x + 3, fy - 15, x + w - 3, fy - 14, (150, 120, 150), depth=0.03)
    S().rect(x + 2, fy - 4, x + w - 2, fy - 3, shade(c, -1))
    for i, cc in enumerate(CREW):
        sx_ = x + 4 + i * 8
        dc = shade(cc, -2)
        S().rect(sx_, fy - 7, sx_ + 4, fy - 5, dc); S().put(sx_, fy - 8, dc)


def umbrella_stand(x, fy):
    box(x, fy - 12, x + 7, fy, (120, 130, 150), depth=0.04)
    for dx, h, cc in [(1, 22, (96, 120, 170)), (4, 19, (190, 110, 120))]:
        S().line(x + dx, fy - 12, x + dx, fy - h, (80, 70, 70))
        S().poly([(x + dx - 2, fy - h + 6), (x + dx + 2, fy - h + 6), (x + dx, fy - h - 2)], cc)
        S().put(x + dx + 1, fy - h - 3, (80, 70, 70))


def room_entry(tv):
    """玄关（离家最近，信号最差）：衣帽架和换鞋凳、大门（两边侧窗、门上气窗、两盏壁灯）、
    边桌上的转盘电话和镜子、上楼的楼梯（大屏）、伞架和盆栽。屏幕上几道雪花撕裂。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wall_h, cls = dims(tv)
    groups = [("coats", 54, 1), ("door", 54, 0), ("console", 42, 2), ("stairs", 108, 3), ("umb", 26, 4)]
    if cls == "S":
        groups = [("coats", 22, 1), ("door", 40, 0), ("umb", 20, 2)]
    pos = place(tv, groups, seed=5)
    lamp_y = clampy(tv, fy - min(70, int(wall_h * 0.55)))
    lamps = []
    if "door" in pos:
        lamps.append((pos["door"] + 27, lamp_y))
    if "console" in pos:
        lamps.append((pos["console"] + 20, fy - 40))
    if "stairs" in pos:
        lamps.append((pos["stairs"] + 70, fy - 90))
    main = lamps[0]
    k.room_base(tv, k.WARM_WALL, k.WARM_FLOOR, main, lamps=lamps)
    dress_walls(tv, k.WARM_WALL, "stripe", wains=((150, 112, 104), (186, 146, 128)))

    if "stairs" in pos:
        gx = pos["stairs"]
        treads, (lx0, lx1, ly) = stairs(tv, gx + 4)
        sc.plat(treads[3][0], treads[4][1], treads[3][2])                     # 第四级（离地 20）
        sc.plat(lx0, lx1, ly)                                                 # 休息平台（离地 40）
        painting(gx + 70, clampy(tv, ly - 34), 18, 14, "hill")
        if cls == "L":
            k.window(lx0 + 2, clampy(tv, ly - 90, 14), 16, 26, frame=(150, 122, 116))
    if "coats" in pos:
        gx = pos["coats"]
        if cls != "S":
            k.crew_photo(gx + 30, clampy(tv, fy - 52))
            bench(gx + 16, fy, 36)
            k.coat_rack(gx + 6, fy)
            sc.plat(gx + 16, gx + 52, fy - 13) if False else None             # 凳子太低（13），不算平台
        else:
            k.coat_rack(gx + 8, fy)
    if "door" in pos:
        gx = pos["door"]
        dx = gx + 15
        if cls != "S":
            for sx_ in (dx - 9, dx + 29):                                      # 门两边的细长侧窗
                S().rect(sx_ - 1, fy - 47, sx_ + 5, fy - 4, (150, 120, 112))
                S().rect(sx_, fy - 46, sx_ + 4, fy - 5, (226, 200, 150))
                S().rect(sx_, fy - 25, sx_ + 4, fy - 25, (150, 120, 112))
            S().rect(dx - 10, fy - 60, dx + 34, fy - 52, (150, 120, 112))     # 门上的半圆气窗
            S().rect(dx - 9, fy - 59, dx + 33, fy - 53, (226, 200, 150))
            for fx in range(dx - 4, dx + 32, 6):
                S().line(fx, fy - 59, fx + 2, fy - 53, (150, 120, 112))
            sconce(dx - 14, fy - 40); sconce(dx + 38, fy - 40)
        k.front_door(dx, fy, 24, 48)
        if cls == "S":
            k.crew_photo(dx + 30, clampy(tv, fy - 44, 8))
    if "console" in pos:
        gx = pos["console"]
        top = console_table(gx + 4, fy, 34)
        mirror(gx + 12, clampy(tv, top - 34), 18, 24)
        rotary_phone(gx + 7, top - 1)
        box(gx + 26, top - 3, gx + 34, top - 1, (150, 170, 186), depth=0.03)   # 放钥匙的碗
        S().put(gx + 29, top - 4, (226, 200, 120))
        sc.plat(gx + 4, gx + 38, top)
    if "umb" in pos:
        gx = pos["umb"]
        umbrella_stand(gx + 2, fy)
        if cls != "S":
            k.plant(gx + 14, fy)
        else:
            k.crew_photo(gx - 2, clampy(tv, fy - 60, 8)) if "door" not in pos else None
    k.hanging_lamp(main[0], y0, main[1])
    if cls == "L":
        hanging_plant(pos.get("coats", x0 + 30) + 30, y0 + 4, fy - int(wall_h * 0.5))
    # 雪花：天花板下一道宽的、半墙一道、窗台高度一道细的；地面那一条不放（怪要看得清）
    for a, b in [(0.22, 0.26), (0.55, 0.57), (0.78, 0.79)]:
        ya, yb = y0 + int(wall_h * a), y0 + int(wall_h * b)
        if yb < fy - 20:
            k.static_band(tv, ya, max(ya + 1, yb))
    k.finish_room(tv, main)


SCENES_V3 = {"kitchen": room_kitchen, "living": room_living, "bedroom": room_bedroom, "kids": room_kids, "entry": room_entry}
