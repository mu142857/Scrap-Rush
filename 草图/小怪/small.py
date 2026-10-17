"""16 种小怪的草图（爬虫已经有 Oscar 的原稿），照爬虫画风，和精英怪共用调色板和画笔。

    python3 small.py             # 输出到本文件夹：每只一张 1 倍 PNG（待机、动作两格）+ 一张放大的总览图

全部朝左，地面是画布最后一行；飞的、挂着的不贴地。主角约 13 格高：
小怪 6~14 格，中怪（两发打死的）12~16 格，大块头洗衣机 20 格。
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "精英怪"))
from elites import G, legs, trim_pair  # noqa: E402


# ---------------------------------------------------------------- 1. 扑灯蛾：灯座身子 + 两片铁皮翅膀
def moth(p):
    g = G(13, 11)
    if p == 0:
        g.poly([(6, 4), (1, 0), (0, 3), (4, 6)], 6)                     # 翅膀平展
        g.poly([(7, 4), (12, 1), (12, 4), (8, 6)], 5)
        g.path([(1, 0), (6, 4)], 8)
        g.path([(12, 1), (7, 4)], 7)
    else:
        g.poly([(6, 4), (3, 0), (2, 2), (5, 6)], 6)                     # 翅膀往上收
        g.poly([(7, 4), (10, 0), (11, 2), (8, 6)], 5)
        g.path([(3, 0), (6, 4)], 8)
        g.pts([(1, 8), (3, 9)], 6)                                       # 扑下去时的速度点
    g.rect(5, 3, 7, 8, 4)                                               # 灯座身子，一圈螺纹
    g.rect(5, 3, 7, 3, 8)
    g.pts([(5, 5), (7, 5), (5, 7), (7, 7)], 6)
    g.put(6, 9, 3)
    g.led(5, 4)
    return g.rgba()


# ---------------------------------------------------------------- 3. 汽壶：老水壶，壶嘴朝上
def kettle(p):
    g = G(16, 22)
    g.poly([(3, 21), (2, 16), (4, 12), (11, 12), (13, 16), (12, 21)], 5)
    g.rect(3, 12, 12, 12, 8)
    g.pts([(2, 16), (3, 14), (3, 13)], 7)
    g.rect(3, 21, 12, 21, 3)
    g.rect(13, 16, 12, 21, 4)
    g.rect(6, 10, 9, 11, 6)                                             # 壶盖 + 钮
    g.rect(6, 10, 9, 10, 8)
    g.pts([(7, 9), (8, 9)], 7)
    g.path([(4, 12), (3, 8), (7, 6), (11, 8), (11, 12)], 4)             # 提手
    g.path([(3, 8), (7, 6)], 6)
    g.path([(12, 15), (14, 13), (15, 10)], 6)                           # 壶嘴（朝上）
    g.path([(13, 16), (15, 13), (15, 11)], 4)
    g.rect(4, 17, 11, 17, 3)                                            # 腰线
    g.led(6, 15)
    g.pts([(1, 21), (14, 21)], 3)                                       # 两只小脚
    if p == 1:                                                          # 喷汽：一柱往上顶
        for y in range(0, 10):
            w = 1 if y > 6 else 2
            for x in range(15 - w, 16 + w - 1):
                g.put(x, y, "s" if (x + y) % 3 else "S")
    return g.rgba()


# ---------------------------------------------------------------- 4. 弹簧跳蚤：铁皮罐头坐在弹簧上
def flea(p):
    g = G(11, 18)
    top = 6 if p == 0 else 0
    g.box(2, top, 8, top + 6, base=4, top=8, left=7, right=5, bottom=3)
    g.rect(3, top + 2, 7, top + 2, 6)                                   # 罐头的箍
    g.led(3, top + 4)
    sp_top, sp_bot = top + 7, 17
    n = (sp_bot - sp_top)
    for i in range(n + 1):                                              # 弹簧：左右来回折
        x = 4 if (i // 1) % 2 == 0 else 6
        g.put(x, sp_top + i, 6 if x == 4 else 4)
    g.rect(3, 17, 7, 17, 5)                                             # 底座
    if p == 1:
        g.pts([(1, 17), (9, 17), (0, 16), (10, 16)], "s")
    return g.rgba()


# ---------------------------------------------------------------- 5. 电线蛇：从天花板垂下来的插头
def wire_snake(p):
    g = G(14, 22)
    if p == 0:
        g.rect(6, 0, 6, 14, 3)                                          # 电线
        g.rect(7, 0, 7, 14, 1)
        for y in range(1, 14, 3):
            g.put(6, y, 5)
        g.box(4, 15, 9, 19, base=4, top=7, left=7, right=5, bottom=3)   # 插头
        g.led(6, 17)
        g.pts([(5, 20), (5, 21), (8, 20), (8, 21)], 8)                  # 两根插脚
    else:                                                               # 扑下来：电线甩成弧，插脚朝前
        g.path([(6, 0), (6, 5), (5, 9), (3, 12)], 3)
        g.path([(7, 0), (7, 5), (6, 9), (4, 12)], 1)
        g.poly([(0, 13), (4, 11), (7, 15), (3, 17)], 4)
        g.path([(0, 13), (4, 11)], 7)
        g.put(3, 14, "L")
        g.pts([(0, 16), (0, 17), (2, 18), (2, 19)], 8)
        g.pts([(1, 19), (3, 21)], "S")                                  # 火花
    return g.rgba()


# ---------------------------------------------------------------- 6. 保险丝甲虫：陶瓷保险丝当身子
def fuse(p):
    g = G(15, 9)
    g.rect(3, 1, 11, 5, 6)                                              # 瓷管（亮一些）
    g.rect(3, 1, 11, 1, 8)
    g.rect(3, 5, 11, 5, 4)
    g.box(1, 1, 3, 5, base=5, top=9, left=7, right=4, bottom=3)         # 两头的铜帽
    g.box(11, 1, 13, 5, base=5, top=9, left=6, right=4, bottom=3)
    g.rect(5, 3, 9, 3, "r3")                                            # 里面那根熔丝
    g.led(2, 3)
    legs(g, [(4, 6), (7, 6), (10, 6)], 8, spread=1)
    if p == 1:                                                          # 要炸了：熔丝烧红，往外冒火花
        g.rect(5, 3, 9, 3, "L")
        g.pts([(6, 0), (9, 0), (4, 0), (12, 0), (0, 4), (14, 3)], "S")
    return g.rgba()


# ---------------------------------------------------------------- 7. 拾荒者：带伸缩夹子的小推车
def scavenger(p):
    g = G(26, 14)
    ox = 10
    g.box(ox + 2, 4, ox + 13, 10, base=4, top=8, left=7, right=5, bottom=3)   # 车斗
    for x in range(ox + 4, ox + 13, 2):
        g.rect(x, 5, x, 9, 2)                                           # 格栅（照爬虫）
    g.led(ox + 3, 6)
    g.path([(ox + 13, 4), (ox + 15, 1)], 5)                             # 推把
    g.disk(ox + 4, 12, 1.5, 3)
    g.disk(ox + 11, 12, 1.5, 3)
    g.pts([(ox + 4, 12), (ox + 11, 12)], 7)
    if p == 0:
        g.path([(ox + 2, 5), (ox - 1, 3), (ox - 2, 5)], 5)              # 夹子收着
        g.pts([(ox - 3, 6), (ox - 1, 6)], 7)
    else:                                                               # 伸出去夹东西（比如马灯）
        g.path([(ox + 2, 5), (ox - 3, 4), (ox - 6, 6), (ox - 8, 8)], 5)
        for x, y in [(ox - 1, 4), (ox - 5, 5)]:
            g.put(x, y, 7)                                              # 伸缩臂的关节
        g.pts([(0, 9), (1, 8), (1, 10), (3, 10), (3, 8)], 7)            # 夹爪张开
    return g.rgba()


# ---------------------------------------------------------------- 8. 雪花幽灵：飘着的小显像管，屏幕全是雪花
def ghost(p):
    g = G(13, 17)
    rng = np.random.default_rng(3)
    g.box(1, 0, 11, 8, base=4, top=8, left=7, right=5, bottom=3)
    for y in range(2, 7):                                               # 雪花屏
        for x in range(3, 10):
            g.put(x, y, [5, 7, 9, 3][rng.integers(0, 4)])
    g.led(6, 4)
    g.pts([(4, 0), (3, -1)], 6)
    # 底下是撕成一缕缕的尾巴（像信号线散开）
    for x, ln in [(3, 5), (5, 7), (7, 4), (9, 6)]:
        for y in range(9, 9 + ln):
            if (y + x) % 4 != 0:
                g.put(x + (1 if y > 12 else 0), y, 4 if y < 12 else 3)
    out = g.rgba()
    if p == 1:                                                          # 没被光照到：只剩一点点轮廓
        keep = (np.add.outer(np.arange(out.shape[0]), np.arange(out.shape[1])) % 3) == 0
        out[..., 3] = np.where(keep, out[..., 3], 0)
        out[4, 6, 3] = 255
    return out


# ---------------------------------------------------------------- 9. 打字机炮台
def typewriter(p):
    g = G(30, 14)
    ox = 10
    g.rect(ox + 4, 0, ox + 14, 3, 9)                                    # 夹在滚筒上的纸（最亮）
    g.rect(ox + 4, 3, ox + 14, 3, 7)
    g.rect(ox + 1, 4, ox + 18, 5, 6)                                    # 滚筒
    g.rect(ox + 1, 4, ox + 18, 4, 8)
    g.pts([(ox, 4), (ox, 5), (ox + 19, 4), (ox + 19, 5)], 7)
    g.box(ox + 2, 6, ox + 17, 11, base=3, top=7, left=7, right=5, bottom=2)
    for r, y in enumerate((8, 10)):                                     # 两排圆键
        for x in range(ox + 4 + r, ox + 16, 2):
            g.put(x, y, 7 if r == 0 else 6)
    g.led(ox + 9, 7)
    g.pts([(ox + 3, 12), (ox + 3, 13), (ox + 16, 12), (ox + 16, 13)], 4)
    if p == 1:                                                          # 一排字母子弹（3×3 的小方块字）
        for i, gx in enumerate((0, 4, 8)):
            glyph = [(0, 0), (1, 0), (2, 0), (0, 1), (2, 1), (0, 2), (2, 2)] if i == 1 else \
                    [(0, 0), (1, 0), (2, 0), (1, 1), (1, 2)]
            for dx, dy in glyph:
                g.put(gx + dx, 6 + dy, 9)
        g.pts([(ox + 19, 1), (ox + 18, 0)], 8)                          # 回车拉杆抬起
    else:
        g.line(ox + 19, 3, ox + 21, 2, 7)
    return g.rgba()


# ---------------------------------------------------------------- 10. 磁带缠绕者
# 轮廓：扁平的磁带高高架在四条拱起来的蜘蛛腿上，底下垂着一团乱磁带
def tape(p):
    g = G(26, 21)
    ox = 2
    # 拱腿（先画，身子盖在上面）：根部在身子两侧，膝盖往上拱，脚落得很开
    for root, knee, foot in [((ox + 5, 5), (ox + 2, 1), (ox - 2, 20)), ((ox + 7, 8), (ox + 4, 10), (ox + 1, 20)),
                             ((ox + 18, 5), (ox + 21, 1), (ox + 23, 20)), ((ox + 16, 8), (ox + 19, 11), (ox + 20, 20))]:
        g.line(*root, *knee, 5)
        g.line(*knee, *foot, 4)
    g.box(ox + 5, 3, ox + 18, 8, base=4, top=8, left=7, right=5, bottom=3)
    g.rect(ox + 7, 4, ox + 16, 4, "r2")                                 # 标签
    g.rect(ox + 8, 5, ox + 15, 6, 1)                                    # 窗
    g.disk(ox + 9.5, 5.5, 0.9, 6)
    g.disk(ox + 14.5, 5.5, 0.9, 6)
    g.rect(ox + 9, 8, ox + 14, 8, 2)                                    # 出带口
    g.led(ox + 11, 7, 2)
    if p == 0:                                                          # 垂着一团乱磁带
        g.path([(ox + 10, 9), (ox + 9, 12), (ox + 11, 14), (ox + 12, 11), (ox + 13, 15), (ox + 14, 12),
                (ox + 13, 9)], "r3")
        g.pts([(ox + 9, 13), (ox + 12, 13), (ox + 14, 14)], "r2")
    else:                                                               # 吐出一条磁带，波浪形往前飞
        g.path([(ox + 10, 9), (ox + 9, 11), (ox + 11, 12)], "r3")
        for x in range(0, ox + 10):
            y = 11 + round(1.5 * math.sin(x * 0.9))
            g.put(x, y, "r3")
            if x % 3 == 0:
                g.put(x, y + 1, "r2")
    return g.rgba()


# ---------------------------------------------------------------- 11. 电动剃须刀
# 轮廓：贴地的、往前倾的楔形，刀头像鸟嘴朝前下方，身后拖一根电线尾巴
def shaver(p):
    g = G(27, 10)
    ox = 2
    tail = [(ox + 17, 4), (ox + 19, 3), (ox + 21, 5), (ox + 24, 4)] if p == 0 else [(ox + 17, 4), (ox + 24, 4)]
    g.path(tail, 3)
    g.pts([(ox + 24, 3), (ox + 24, 5)], 6)                              # 电线头上的插头
    g.poly([(ox + 2, 7), (ox + 5, 2), (ox + 15, 1), (ox + 17, 3), (ox + 15, 7)], 4)
    g.path([(ox + 5, 2), (ox + 15, 1)], 8)                              # 顶边亮
    g.path([(ox + 2, 7), (ox + 15, 7)], 3)
    g.rect(ox + 9, 3, ox + 12, 3, 6)                                    # 开关
    # 刀头：一排亮的梳齿，比身子往前探出一格
    for x, y in [(ox + 1, 6), (ox + 2, 4), (ox + 1, 4), (ox + 3, 3), (ox + 2, 5), (ox + 1, 7)]:
        g.put(x, y, 9 if (x + y) % 2 else 7)
    g.led(ox + 6, 3)
    for root, foot in [((ox + 6, 8), (ox + 4, 9)), ((ox + 10, 8), (ox + 9, 9)), ((ox + 14, 8), (ox + 15, 9))]:
        g.line(*root, *foot, 4)
    if p == 1:                                                          # 冲刺：刀光 + 身后速度线
        g.path([(0, 1), (1, 3), (1, 7), (0, 9)], 9)
        for y in (2, 6):
            for x in range(ox + 19, 27, 2):
                g.put(x, y, 6)
    return g.rgba()


# ---------------------------------------------------------------- 12. 电视龟：背着一台显像管，正面打不动
def tv_turtle(p):
    g = G(22, 16)
    g.box(3, 1, 17, 11, base=4, top=8, left=7, right=5, bottom=3)       # 电视壳
    g.rect(2, 2, 2, 11, 6)                                              # 正面（朝左）的屏框
    g.rect(0, 3, 1, 10, 2)                                              # 屏幕鼓出来一点，深色
    g.pts([(0, 4), (1, 3), (0, 5)], 6)                                  # 屏幕反光
    for x in range(8, 16, 2):
        g.rect(x, 3, x, 8, 2)                                           # 后壳散热格栅
    g.path([(12, 1), (10, -2)], 6)
    g.path([(14, 1), (17, -1)], 6)                                      # 两根天线
    g.led(5, 2)
    if p == 0:
        legs(g, [(5, 12), (9, 12), (13, 12), (16, 12)], 15, spread=1)
    else:                                                               # 缩起来挡：腿收进去，屏幕"当"地一闪
        g.rect(4, 12, 16, 15, 3)
        g.rect(4, 15, 16, 15, 2)
        g.rect(0, 3, 1, 10, 7)
        g.pts([(0, 4), (1, 3), (0, 5), (0, 6)], 9)
    return g.rgba()


# ---------------------------------------------------------------- 13. 烤面包机
# 轮廓：高高的圆顶老式镀铬烤面包机，顶上冒出两片吐司，两只矮墩墩的脚，侧面一根拉杆
def toaster(p):
    g = G(19, 21)
    ox, oy = 3, 2
    g.rect(ox, oy + 5, ox + 12, oy + 15, 5)
    for x, y in [(ox, oy + 5), (ox + 12, oy + 5), (ox, oy + 15), (ox + 12, oy + 15)]:
        g.a[y, x] = None                                                # 四个角削圆
    g.rect(ox + 1, oy + 5, ox + 11, oy + 5, 9)
    g.rect(ox + 1, oy + 6, ox + 11, oy + 6, 8)
    g.rect(ox, oy + 6, ox, oy + 14, 7)
    g.rect(ox + 12, oy + 6, ox + 12, oy + 14, 4)
    g.rect(ox + 1, oy + 15, ox + 11, oy + 15, 3)
    for x in (ox + 3, ox + 6, ox + 9):                                  # 竖的镀铬棱
        g.rect(x, oy + 8, x, oy + 14, 7)
        g.put(x, oy + 8, 8)
    g.led(ox + 2, oy + 10)
    g.rect(ox + 13, oy + 7, ox + 13, oy + 13, 3)                        # 拉杆槽 + 拉杆
    lever_y = oy + 8 if p == 0 else oy + 13
    g.rect(ox + 13, lever_y, ox + 14, lever_y, 8)
    g.rect(ox + 2, oy + 5, ox + 4, oy + 5, 1)                           # 两条面包槽
    g.rect(ox + 8, oy + 5, ox + 10, oy + 5, 1)
    if p == 0:                                                          # 两片吐司探出头
        for x0, top in [(ox + 2, oy + 2), (ox + 8, oy + 1)]:
            g.rect(x0, top, x0 + 2, oy + 4, "r2")
            g.rect(x0, top, x0 + 2, top, "r3")
            g.put(x0 + 2, oy + 4, "r1")
    else:                                                               # 两片吐司弹飞出去
        for (x0, y0) in [(0, 1), (5, -1)]:
            g.poly([(x0, y0 + 2), (x0 + 2, y0), (x0 + 4, y0 + 2), (x0 + 2, y0 + 4)], "r2")
            g.path([(x0, y0 + 2), (x0 + 2, y0)], "r3")
    for x0 in (ox + 1, ox + 9):                                         # 矮墩墩的脚
        g.rect(x0, oy + 16, x0 + 2, oy + 18, 4)
        g.rect(x0, oy + 16, x0 + 2, oy + 16, 6)
    return g.rgba()


# ---------------------------------------------------------------- 14. 滚筒洗衣机：慢、皮厚，蹦起来砸地
def washer(p):
    g = G(26, 26)
    ox = 4
    up = 0 if p == 0 else 4
    g.box(ox, 2 - up + 2, ox + 17, 21 - up, base=4, top=8, left=7, right=5, bottom=3)
    g.rect(ox + 1, 5 - up, ox + 16, 6 - up, 6)                          # 顶上的控制条
    g.disk(ox + 13.5, 5.5 - up, 0.8, 8)
    g.led(ox + 3, 5 - up, 2)
    g.disk(ox + 8.5, 13.5 - up, 5.2, 7)                                 # 圆门
    g.disk(ox + 8.5, 13.5 - up, 4.2, 1)
    g.disk(ox + 8.5, 13.5 - up, 2.0, 3, ring=1)                         # 里面的滚筒
    g.pts([(ox + 6, 11 - up), (ox + 7, 10 - up)], 6)                    # 门玻璃反光
    if p == 0:
        legs(g, [(ox + 2, 22), (ox + 7, 22), (ox + 11, 22), (ox + 16, 22)], 25, spread=1)
    else:                                                               # 蹦起来：腿蜷着，地上往两边推出震波
        for x in (ox + 2, ox + 7, ox + 11, ox + 16):
            g.line(x, 18, x - 1, 20, 4)
        for x0, d in [(ox - 4, -1), (ox + 21, 1)]:
            for i in range(3):
                g.put(x0 + d * i * 2, 25, "s")
                g.put(x0 + d * i * 2 + d, 24, "s" if i < 2 else 6)
    return g.rgba()


# ---------------------------------------------------------------- 15. 手摇电话：混在废铁里装死，走近就摇铃叫人
def phone(p):
    g = G(18, 22)
    ox = 4
    g.box(ox, 4, ox + 9, 19, base="r1", top=8, left=7, right=5, bottom=3)  # 木头匣子（锈色那一档）
    g.rect(ox + 2, 13, ox + 7, 17, 2)
    g.rect(ox + 2, 13, ox + 7, 13, 4)
    shake = 0 if p == 0 else 1
    for bx in (ox + 2, ox + 7):                                         # 顶上两个铃
        g.disk(bx + (shake if bx > ox + 4 else -shake), 2.5, 1.8, 7)
        g.put(bx + (shake if bx > ox + 4 else -shake), 1, 9)
    g.path([(ox, 9), (ox - 2, 9), (ox - 3, 11)], 6)                     # 话筒（朝左伸出来）
    g.rect(ox - 4, 11, ox - 2, 12, 7)
    g.line(ox + 10, 8, ox + 12, 10 if p == 0 else 6, 6)                 # 侧面摇把
    g.put(ox + 12, 10 if p == 0 else 6, 8)
    g.led(ox + 4, 7)
    legs(g, [(ox + 2, 20), (ox + 7, 20)], 21, spread=1)
    if p == 1:                                                          # 铃响：两边震出的短线
        g.pts([(ox - 1, 0), (ox - 2, 2), (ox + 11, 0), (ox + 12, 2)], 8)
    return g.rgba()


# ---------------------------------------------------------------- 16. 幻灯机：红光锁定你，再射出去
def projector(p):
    g = G(34, 13)
    ox = 16
    g.box(ox + 3, 2, ox + 15, 9, base=4, top=8, left=7, right=5, bottom=3)
    g.rect(ox + 6, 0, ox + 11, 1, 6)                                    # 顶上的散热罩
    g.rect(ox + 6, 0, ox + 11, 0, 8)
    g.rect(ox, 4, ox + 2, 7, 5)                                         # 镜头筒（朝左）
    g.rect(ox, 4, ox + 2, 4, 8)
    g.rect(ox + 16, 4, ox + 17, 7, 6)                                   # 后面插着的幻灯片盒
    for x in range(ox + 6, ox + 14, 2):
        g.rect(x, 4, x, 7, 2)
    g.put(ox, 5, "L")                                                   # 红灯就是镜头
    g.put(ox, 6, "L")
    legs(g, [(ox + 5, 10), (ox + 13, 10)], 12, spread=1)
    if p == 1:                                                          # 一道红色瞄准线
        for x in range(0, ox):
            g.put(x, 5 + (1 if x < 6 else 0), "l" if x % 2 else "L")
    return g.rgba()


# ---------------------------------------------------------------- 17. 胶片盘：一盘盘贴着地面滚过来
def reel(p):
    g = G(22, 13)
    ox = 8
    cx, cy = ox + 6, 6
    g.disk(cx, cy, 6, 6)
    g.disk(cx, cy, 5, 4)
    g.disk(cx, cy, 4, "r1")                                             # 缠着的胶片（锈色）
    rot = 0 if p == 0 else 0.6
    for k in range(3):                                                  # 三个镂空孔，转起来换位置
        a = rot + k * 2 * math.pi / 3
        g.disk(cx + 2.6 * math.cos(a), cy + 2.6 * math.sin(a), 0.9, 1)
    g.pts([(cx - 3, cy - 5), (cx - 4, cy - 4), (cx - 5, cy - 3)], 8)    # 顶上的亮边
    g.disk(cx, cy, 0.7, 6)
    g.led(cx, cy)
    if p == 1:                                                          # 滚动：后面拖一截胶片 + 速度线
        g.path([(cx + 5, cy + 4), (cx + 8, cy + 6), (21, cy + 6)], "r2")
        for y in (2, 5):
            for x in range(cx + 8, 22, 2):
                g.put(x, y, 6)
    return g.rgba()


SMALL = [
    ("moth", "扑灯蛾", moth), ("kettle", "汽壶", kettle), ("flea", "弹簧跳蚤", flea),
    ("wire_snake", "电线蛇", wire_snake), ("fuse", "保险丝甲虫", fuse), ("scavenger", "拾荒者", scavenger),
    ("ghost", "雪花幽灵", ghost), ("typewriter", "打字机炮台", typewriter), ("tape", "磁带缠绕者", tape),
    ("shaver", "电动剃须刀", shaver), ("tv_turtle", "电视龟", tv_turtle), ("toaster", "烤面包机", toaster),
    ("washer", "滚筒洗衣机", washer), ("phone", "手摇电话", phone), ("projector", "幻灯机", projector),
    ("reel", "胶片盘", reel),
]
ACTION = {"moth": "扑下来", "kettle": "喷汽", "flea": "弹起", "wire_snake": "扑下来", "fuse": "要炸了",
          "scavenger": "伸夹子", "ghost": "没被照到", "typewriter": "射字母", "tape": "吐磁带",
          "shaver": "冲刺", "tv_turtle": "缩起来挡", "toaster": "弹吐司", "washer": "蹦起来砸",
          "phone": "摇铃叫人", "projector": "红光锁定", "reel": "滚过来"}


def main():
    font = ImageFont.truetype(str(HERE.parents[1] / "oscar-rush/fonts/PixelFont.ttf"), 22)
    small_font = ImageFont.truetype(str(HERE.parents[1] / "oscar-rush/fonts/PixelFont.ttf"), 18)
    crawler = np.asarray(Image.open(HERE.parents[1] / "oscar-rush/art/enemies/crawler.png").convert("RGBA"))[:, :36]
    hp = HERE.parents[1] / "oscar-rush/art/chars/red_body.png"
    hero = np.asarray(Image.open(hp).convert("RGBA"))[:, :16].copy()
    strip = np.asarray(Image.open(hp.with_name("red_strip.png")).convert("RGBA"))[:, :16]
    hero[strip[..., 3] > 0] = strip[strip[..., 3] > 0]
    S, BG, GAP = 6, (104, 102, 110), 4
    items = []
    for name, title, fn in SMALL:
        fr = trim_pair([fn(0), fn(1)])
        h = max(f.shape[0] for f in fr)
        sheet = np.zeros((h, sum(f.shape[1] for f in fr) + GAP, 4), np.uint8)
        x = 0
        for f in fr:
            sheet[h - f.shape[0]:, x:x + f.shape[1]] = f
            x += f.shape[1] + GAP
        Image.fromarray(sheet).save(HERE / f"{name}.png")
        items.append((name, title, fr))
    cols, cell_w = 4, 470
    cell_h = max(max(f.shape[0] for f in fr) for _, _, fr in items) * S + 70
    rows = math.ceil(len(items) / cols)
    head = 60 + crawler.shape[0] * S + 30
    img = Image.new("RGB", (cols * cell_w + 20, head + rows * cell_h), BG)
    d = ImageDraw.Draw(img)
    d.text((16, 12), "Scrap Rush · 小怪草图（照爬虫画风，6 倍放大；每格：待机 / 动作）", fill=(235, 232, 228), font=font)
    x = 16
    for f, label in [(crawler, "爬虫（Oscar 原稿）"), (hero, "主角")]:
        im = Image.fromarray(f).resize((f.shape[1] * S, f.shape[0] * S), Image.NEAREST)
        img.paste(im, (x, head - 20 - im.size[1]), im)
        d.text((x, head - 18), label, fill=(210, 206, 200), font=small_font)
        x += im.size[0] + 60
    for i, (name, title, fr) in enumerate(items):
        cx, cy = 10 + (i % cols) * cell_w, head + (i // cols) * cell_h
        d.text((cx + 6, cy + 6), f"{i + 1 if i == 0 else i + 2}. {title}", fill=(235, 232, 228), font=font)
        d.text((cx + 6, cy + cell_h - 28), f"待机 / {ACTION[name]}", fill=(190, 186, 180), font=small_font)
        base = cy + cell_h - 34
        x = cx + 10
        for f in fr:
            im = Image.fromarray(f).resize((f.shape[1] * S, f.shape[0] * S), Image.NEAREST)
            img.paste(im, (x, base - im.size[1]), im)
            x += im.size[0] + 18
    img.save(HERE / "小怪草图.png")
    print("ok", [(t, fr[0].shape[1], fr[0].shape[0]) for _, t, fr in items])


if __name__ == "__main__":
    main()
