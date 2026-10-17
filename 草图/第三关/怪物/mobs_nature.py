"""海底、雪夜院子、夜里的港口、沙漠、森林的怪（照 mobs_kitchen_beach.py 的写法）。"""
import numpy as np

from mobkit import mob, part, flat, shade, FLY, HOP, DASH, SHOOT, ELITE

DARK = (52, 50, 62)
WHITE = (238, 236, 228)


def tube(c, pts, r0, r1):
    """沿一串点画一根由粗到细的管子（触手、尾巴），返回 mask。"""
    yy, xx = np.mgrid[0:c.h, 0:c.w]
    m = np.zeros((c.h, c.w), bool)
    n = len(pts) - 1
    for i in range(n):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        for t in np.linspace(0, 1, 12):
            k = (i + t) / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            r = r0 + (r1 - r0) * k
            m |= (xx + 0.5 - x) ** 2 + (yy + 0.5 - y) ** 2 <= r * r
    return m


# ================================================================ 海底（全是绿荧光屏）
CLOWN = (240, 132, 58)


@mob("aquarium", "aq_clownfish", FLY, 16, 10, "小丑鱼：在缸里游，追着光绕圈，俯冲时尾巴一甩撞过来")
def aq_clownfish(c, f):
    tail = c.poly([(11, 4), (16, 0), (15, 6)]) if f.up else c.poly([(11, 5), (15, 4), (16, 10)])
    part(c, tail, shade(CLOWN, -1))
    part(c, c.poly([(4, 3), (7, 0 if f.up else 1), (10, 3)]), shade(CLOWN, -1))      # 背鳍
    body = c.ellipse(6.5, 5, 6, 3.3)
    part(c, body, CLOWN)
    for x in (3, 8):                                         # 两道白条
        part(c, body & c.rect(x, 0, x + 1, 9), WHITE)
    part(c, c.poly([(5, 7), (9, 7), (7, 10)]), shade(CLOWN, -1))                     # 腹鳍
    f.led(c, 2, 4)


@mob("aquarium", "aq_chest", HOP, 14, 11, "缸底的宝箱摆件：锁眼是红灯，蹲下合盖，跳起来盖子弹开冒一串泡泡")
def aq_chest(c, f):
    wood, brass = (186, 128, 76), (230, 190, 96)
    if f.air:                                                 # 盖子掀开，露出金币和泡泡
        part(c, c.poly([(2, 4), (10, 0), (13, 2), (5, 5)]), shade(wood, 1))
        flat(c, c.rect(2, 4, 11, 5), (246, 214, 110))
        for x, y in ((3, 1), (5, 0), (1, 3)):
            c.put(x, y, (226, 240, 236))
    else:
        part(c, c.ellipse(6.5, 5.5, 6, 3.5) & c.rect(0, 0, 13, 5), shade(wood, 1))
        for x in (3, 10):
            part(c, c.ellipse(6.5, 5.5, 6, 3.5) & c.rect(x, 0, x, 5), brass)
    part(c, c.rect(1, 5, 12, 9), wood)
    flat(c, c.rect(1, 5, 12, 5), shade(brass, -2))           # 盖缝的铜边
    for x in (3, 10):
        part(c, c.rect(x, 6, x, 9), brass)
    part(c, c.rect(5, 6, 8, 8), brass)                        # 锁扣
    flat(c, c.rect(1, 10, 2, 10), shade(wood, -3)); flat(c, c.rect(11, 10, 12, 10), shade(wood, -3))
    f.led(c, 6, 7)


@mob("aquarium", "aq_shrimp", DASH, 16, 9, "小虾：长须在前面探来探去地爬，弓背一亮，尾巴一弹就窜过来")
def aq_shrimp(c, f):
    pink = (238, 150, 124)
    arch = 1 if f.windup else 0                                # 蓄力时背弓得更高
    part(c, c.poly([(10, 8), (14, 7), (13, 9), (9, 9)]), shade(pink, -1))            # 尾扇往肚子底下收
    part(c, c.ellipse(13.5, 6.5, 1.8, 1.8), pink)
    part(c, c.ellipse(12.5, 4 - arch * 0.5, 2.3, 2.3), pink)
    part(c, c.ellipse(9.5, 3.4 - arch, 2.6, 2.6), pink)
    part(c, c.ellipse(5.5, 4, 3.5, 2.6), shade(pink, 1))       # 头胸甲
    for x in (8, 11):
        flat(c, c.rect(x, 2 - arch, x, 4), shade(pink, -2))    # 体节缝
    for i, x in enumerate((4, 6, 8)):
        flat(c, c.rect(x, 6, x, 8 - (i + f.step) % 2), shade(pink, -2))
    c.line(2, 3, 0, 0, shade(pink, -1)); c.line(2, 4, 0, 6, shade(pink, -1))            # 长须
    f.led(c, 3, 3)


@mob("aquarium", "aq_cannon", SHOOT, 15, 10, "沉船摆件里的小铜炮：在缸底慢慢推着走，停下瞄准，打一颗气泡弹（直线）",
     bullet="rivet")
def aq_cannon(c, f):
    bronze, wood = (210, 166, 92), (140, 96, 66)
    part(c, c.poly([(5, 6), (13, 5), (14, 8), (5, 8)]), wood)                         # 炮架
    part(c, c.poly([(1, 3), (11, 2), (11, 6), (1, 5)]), bronze)                       # 炮管：炮尾粗、炮口细
    part(c, c.rect(0, 2, 1, 5), shade(bronze, 1))             # 炮口箍
    part(c, c.ellipse(12.5, 4, 1.5, 1.5), shade(bronze, -1))  # 炮尾的球
    for cx in (5.5, 11.5):
        part(c, c.ellipse(cx, 7.5, 2.5, 2.5), shade(wood, -1))
        c.put(int(cx), 7, shade(bronze, -1))                   # 轮毂
        c.put(int(cx) + (f.step if cx < 8 else 1 - f.step) * 2 - 1, 7 + (1 - f.step), shade(wood, 1))   # 辐条转一下
    f.led(c, 8, 2)                                             # 引信头
    f.muzzle(c, 0, 4)


@mob("aquarium", "aq_angler", ELITE, 46, 36,
     "灯笼鱼：额前挑着一只老灯泡，张开满是牙的大嘴横冲过来；一张嘴扇形喷出气泡；灯一闪叫来小丑鱼",
     moves=["charge", "spray", "summon"], elite_name="DEEP ANGLER", title="FOLLOW THE LIGHT", hp=950,
     bullet="rivet")
def aq_angler(c, f):
    body = (150, 124, 118)
    gape = 3 if (f.attack or f.pose) else 0
    part(c, c.poly([(38, 16), (46, 9), (46, 29), (38, 22)]), shade(body, -1))          # 尾鳍
    part(c, c.ellipse(26, 19, 17, 13), body, bands=0.7)
    part(c, c.poly([(28, 7), (33, 3), (35, 8)]), shade(body, 1))                      # 背鳍
    part(c, c.poly([(2, 22 + gape), (24, 21), (26, 31), (9, 31 + gape // 2)]), shade(body, -1))   # 下颌
    mouth = c.poly([(3, 17), (24, 20), (24, 21), (3, 21 + gape)])
    flat(c, mouth, (44, 36, 48))
    for x in range(5, 22, 4):                                  # 上下两排牙
        flat(c, c.poly([(x, 17), (x + 2, 17), (x + 1, 20)]), (236, 232, 214))
        flat(c, c.poly([(x + 1, 22 + gape), (x + 3, 22 + gape), (x + 2, 19 + gape)]), (236, 232, 214))
    feet = 1 if f.step else 0
    part(c, c.poly([(25, 29), (31, 29), (34, 35), (23, 35 - feet)]), shade(body, 1))   # 胸鳍当脚
    part(c, c.poly([(33, 28), (37, 28), (40, 35 - feet), (32, 35)]), body)
    lit = f.windup or f.attack or f.pose
    c.polyline([(19, 7), (16, 2), (11, 0), (6, 1), (4, 3)], shade(body, -1))           # 挑灯的杆
    part(c, c.rect(3, 3, 5, 4), (176, 176, 186))              # 灯头的螺口
    part(c, c.ellipse(4.5, 8, 3, 3.2), (252, 240, 170) if lit else (226, 220, 168))
    flat(c, c.rect(4, 7, 5, 8), (250, 176, 80))                # 灯丝
    flat(c, c.ellipse(21, 12, 2.6, 2.4), (60, 50, 60))         # 眼窝
    f.led(c, 20, 11, 2)


# ================================================================ 雪夜院子（彩色）
SNOW = (232, 238, 248)


@mob("snow_yard", "sy_snowman", HOP, 11, 14, "小雪人：顶着铁皮桶当帽子原地蹦，蹲下时围巾一甩，跳过来砸")
def sy_snowman(c, f):
    scarf = (72, 148, 104)
    c.line(0, 7, 2, 9, (112, 84, 66)); c.line(10, 7, 8, 9, (112, 84, 66))             # 树枝手
    part(c, c.ellipse(5.5, 10.2, 5, 3.8), SNOW)
    part(c, c.ellipse(5.5, 5, 3.4, 3), SNOW)
    part(c, c.poly([(3, 0), (8, 0), (9, 3), (2, 3)]), (150, 158, 176), rim=0, under=0)   # 铁皮桶
    part(c, c.rect(2, 7, 9, 8), scarf)
    tail_x = 9 if f.i in (1, 2) else 7                         # 蹲下 / 起跳时围巾甩出去
    flat(c, c.rect(tail_x, 8, tail_x + 1, 11), shade(scarf, -1))
    flat(c, c.rect(1, 5, 2, 5), (236, 140, 60))                # 胡萝卜鼻
    flat(c, c.rect(7, 4, 7, 4), DARK)                          # 煤球眼
    for y in (10, 12):
        flat(c, c.rect(5, y, 5, y), DARK)
    f.led(c, 4, 4)


@mob("snow_yard", "sy_bulb", FLY, 9, 13, "圣诞彩灯泡：从屋檐的灯串上挣下来，拖着电线扑向亮处，灯丝就是那颗红灯")
def sy_bulb(c, f):
    glass = (120, 210, 138)
    wire = (60, 92, 70)
    if f.up:
        c.line(3, 2, 0, 0, wire); c.line(5, 2, 8, 0, wire)
    else:
        c.line(3, 3, 0, 4, wire); c.line(5, 3, 8, 4, wire)
    part(c, c.rect(3, 1, 5, 4), (168, 166, 150))               # 螺口
    flat(c, c.rect(3, 2, 5, 2), (128, 126, 116))
    part(c, c.ellipse(4.5, 7.6, 3.3, 3) | c.poly([(1.4, 8), (7.6, 8), (5.6, 12.6), (3.4, 12.6)]) | c.rect(3, 5, 5, 6), glass)
    c.put(2, 7, (220, 248, 222))
    flat(c, c.rect(4, 6, 4, 7), shade(glass, -2))             # 灯丝支架
    f.led(c, 4, 8)


@mob("snow_yard", "sy_sled", DASH, 16, 9, "木雪橇：载着一团雪在院子里来回滑，车头小灯一亮就冲过来铲你")
def sy_sled(c, f):
    wood, iron = (198, 138, 84), (96, 104, 126)
    c.polyline([(15, 8), (2, 8), (0, 6), (0, 4), (1, 3)], iron)                        # 滑板，前头翘起
    for x in (4, 11):
        flat(c, c.rect(x, 6, x, 7), iron)
    part(c, c.rect(2, 4, 15, 5), wood)
    for x in (6, 10):
        flat(c, c.rect(x, 4, x, 5), shade(wood, -2))
    part(c, c.ellipse(9, 3.2, 3.6, 2.2) & c.rect(0, 0, 15, 3), SNOW)                 # 车上的雪
    flat(c, c.rect(2, 2, 2, 3), iron)                          # 车头小灯
    f.led(c, 2, 1)


@mob("snow_yard", "sy_stove", SHOOT, 12, 17, "铸铁小火炉：挪到院子里取暖，烟囱对准你，往外抛一块通红的炭（抛物线）",
     bullet="ember")
def sy_stove(c, f):
    iron = (132, 118, 116)
    part(c, c.rect(1, 1, 6, 2), shade(iron, 1))                # 烟囱弯头，朝左
    part(c, c.rect(5, 1, 6, 5), shade(iron, 1))
    part(c, c.rect(2, 5, 10, 6), shade(iron, 1))               # 顶板
    part(c, c.ellipse(6, 10.8, 4.6, 4.6), iron)
    hot = (250, 186, 92) if (f.aim or f.fire) else (238, 146, 62)
    part(c, c.rect(4, 9, 8, 12), hot)                           # 炉门里的火
    for x in (5, 7):
        flat(c, c.rect(x, 9, x, 12), shade(iron, -2))
    flat(c, c.rect(2, 15, 3, 16), shade(iron, -3)); flat(c, c.rect(8, 15, 9, 16), shade(iron, -3))
    f.led(c, 3, 7)
    f.muzzle(c, 0, 1)


@mob("snow_yard", "sy_blower", ELITE, 48, 34,
     "扫雪机：老式扫雪机，螺旋铰刀一转横推过来；出雪口扇形喷出冰块；顶上的雪一抖叫出小雪人",
     moves=["charge", "spray", "summon"], elite_name="SNOW BLOWER", title="LET IT SNOW", hp=1000,
     bullet="rivet")
def sy_blower(c, f):
    yel, metal = (230, 180, 70), (84, 88, 104)
    c.line(34, 20, 45, 4, metal); c.line(35, 20, 46, 4, shade(metal, -1))            # 推把
    part(c, c.rect(43, 2, 47, 4), (60, 60, 70))
    part(c, c.rect(22, 12, 39, 27), yel)                       # 发动机壳
    part(c, c.rect(24, 9, 34, 12), shade(yel, -1))
    flat(c, c.rect(26, 15, 35, 16), shade(yel, -3))            # 散热缝
    flat(c, c.rect(26, 19, 35, 20), shade(yel, -3))
    part(c, c.rect(14, 4, 18, 14), shade(yel, 1))              # 出雪筒
    part(c, c.poly([(9, 1), (19, 1), (19, 5), (10, 6)]), shade(yel, 1))
    scoop = c.ellipse(13, 21, 12, 10) & c.rect(1, 12, 24, 31)
    part(c, scoop, yel)
    inner = c.ellipse(13, 22, 9.5, 7.5) & c.rect(3, 15, 22, 30)
    flat(c, inner, (40, 40, 52))
    for i in range(4):                                         # 螺旋铰刀
        x = 6 + i * 4 + (2 if f.attack or f.step else 0)
        c.line(x, 16, x + 3, 28, (186, 190, 204))
    flat(c, inner & c.rect(0, 27, 47, 33), SNOW)               # 铲口里卷着的雪
    part(c, c.ellipse(31, 28.5, 5.5, 5.5), (56, 56, 66))       # 轮子
    part(c, c.ellipse(31, 28.5, 2, 2), (160, 164, 176))
    part(c, c.rect(1, 31, 24, 33), metal)                      # 铲刀
    part(c, c.ellipse(13, 13, 11, 3) & c.rect(0, 0, 25, 13) & ~c.rect(13, 0, 19, 13), SNOW)   # 壳上的积雪
    part(c, c.ellipse(30, 9, 6, 2) & c.rect(0, 0, 47, 9), SNOW)
    if f.attack or f.pose:                                     # 出雪口喷雪
        for x, y in ((6, 2), (4, 4), (7, 5), (2, 1)):
            c.put(x, y, SNOW)
    flat(c, c.rect(3, 13, 6, 15), (200, 202, 210))             # 车灯框
    f.led(c, 4, 13, 2)


# ================================================================ 夜里的港口（黑白）
@mob("harbor", "hb_gull", FLY, 16, 12, "海鸥：绕着灯塔的光打转，看到亮处就收翅俯冲下来啄")
def hb_gull(c, f):
    grey = (150, 156, 168)
    part(c, c.poly([(10, 6), (16, 5), (15, 8), (10, 8)]), grey)                     # 尾巴
    part(c, c.ellipse(7.5, 7, 5, 2.4), WHITE)
    part(c, c.ellipse(3, 5.5, 2.2, 2), WHITE)
    flat(c, c.rect(0, 6, 1, 6), (236, 196, 84))                # 嘴
    if f.up:                                                   # 翅膀举起来，黑翅尖
        part(c, c.poly([(5, 6), (10, 6), (15, 0), (10, 0)]), grey)
        flat(c, c.poly([(12, 0), (15, 0), (14, 2), (11, 2)]), DARK)
    else:                                                      # 翅膀压下去
        part(c, c.poly([(5, 7), (10, 7), (15, 12), (10, 12)]), grey)
        flat(c, c.poly([(11, 10), (14, 10), (15, 12), (12, 12)]), DARK)
    f.led(c, 2, 5)


@mob("harbor", "hb_buoy", HOP, 11, 16, "航标浮标：顶上的红灯就是眼睛，在栈桥上一蹦一蹦地朝你跳")
def hb_buoy(c, f):
    paint, band = (230, 228, 220), (86, 90, 104)
    flat(c, c.rect(4, 0, 6, 0), band)                          # 灯罩顶
    c.line(3, 5, 4, 1, band); c.line(7, 5, 6, 1, band)         # 灯架
    flat(c, c.rect(4, 1, 6, 3), (150, 154, 166))
    body = c.poly([(2, 5), (8, 5), (10, 12), (0, 12)])
    part(c, body, paint)
    part(c, body & c.rect(0, 8, 10, 9), band)                  # 一道深色环
    part(c, c.ellipse(5.5, 13.2, 5.5, 2.5) & c.rect(0, 12, 10, 15), band)            # 浮筒底
    flat(c, c.rect(5, 6, 5, 7), shade(paint, -2))              # 号码牌
    f.led(c, 5, 2)


@mob("harbor", "hb_crate", DASH, 13, 12, "货箱：码头上堆的木箱长了腿，来回踱步，从板缝里瞄你，一闪就撞过来")
def hb_crate(c, f):
    wood = (212, 184, 132)
    part(c, c.rect(1, 1, 11, 9), wood)
    for y in (4, 7):
        flat(c, c.rect(2, y, 10, y), shade(wood, -2))          # 板缝
    c.line(3, 2, 9, 8, shade(wood, 1)); c.line(9, 2, 3, 8, shade(wood, 1))            # 斜撑
    for x in (1, 11):
        part(c, c.rect(x, 1, x, 9), shade(wood, -1))
    flat(c, c.rect(6, 5, 6, 5), shade(wood, -3))
    for i, x in enumerate((3, 9)):
        flat(c, c.rect(x, 10, x, 11 - (i + f.step) % 2), (90, 84, 80))
    f.led(c, 3, 5)


@mob("harbor", "hb_foghorn", SHOOT, 14, 13, "雾笛：黄铜大喇叭架在小推车上，压力表的红针一抖，呜地吹出一发声波（直线）",
     bullet="rivet")
def hb_foghorn(c, f):
    brass, box = (214, 172, 90), (116, 112, 128)
    part(c, c.rect(6, 7, 12, 11), box)
    flat(c, c.rect(6, 12, 7, 12), DARK); flat(c, c.rect(11, 12, 12, 12), DARK)
    flat(c, c.rect(10, 4, 13, 7), shade(box, 1))               # 接管
    part(c, c.poly([(1, 0), (11, 3), (11, 5), (1, 8)]), brass)
    part(c, c.rect(0, 0, 1, 8), shade(brass, 1))               # 喇叭口
    flat(c, c.rect(0, 2, 0, 6), shade(brass, -3))
    flat(c, c.ellipse(9, 9.5, 1.8, 1.8), (226, 222, 206))      # 压力表
    f.led(c, 9, 9)
    f.muzzle(c, 0, 4)


@mob("harbor", "hb_octopus", ELITE, 54, 44,
     "潜水头盔章鱼：戴着老式铜潜水头盔从海里爬上栈桥，圆窗里是那只红眼；跳起来用六条触手砸地；头盔喷出一扇蒸汽弹；叫出浮标",
     moves=["slam", "spray", "summon"], elite_name="DEEP DIVER", title="FROM THE DEEP", hp=1050, bullet="rivet")
def hb_octopus(c, f):
    flesh, brass = (156, 100, 124), (200, 156, 88)
    tents = np.zeros((c.h, c.w), bool)
    sway = 1 if f.step else 0
    for i, (x0, curl) in enumerate([(9, -1), (16, 1), (23, -1), (31, 1), (38, -1), (45, 1)]):
        lift = (4 if i in (0, 1) else 0) if f.attack else 0
        s = curl * (1 if (i + sway) % 2 else -1)
        pts = [(x0, 22), (x0 + s * 2 + (x0 - 27) * 0.1, 29 - lift),
               (x0 - s * 3 + (x0 - 27) * 0.25, 36 - lift), (x0 + s + (x0 - 27) * 0.3, 43 - lift)]
        tents |= tube(c, pts, 3.2, 1.0)
    part(c, tents, flesh, bands=0.8)
    for x0 in (9, 16, 23, 31, 38, 45):                         # 吸盘
        for y in (31, 37):
            m = tents & c.rect(0, y, c.w - 1, y)
            xs = np.nonzero(m[y])[0]
            near = xs[np.abs(xs - x0 - (x0 - 27) * 0.2) < 3] if len(xs) else xs
            if len(near):
                c.put(int(near[len(near) // 2]), y, shade(flesh, 2))
    helm = c.ellipse(27, 15, 15, 13)
    part(c, helm, brass)
    collar = c.rect(13, 24, 41, 28)
    part(c, collar, shade(brass, -1))
    for x in range(15, 41, 4):
        c.put(x, 26, shade(brass, 3))                          # 铆钉
    flat(c, c.ellipse(27, 14.5, 6.5, 6.5), shade(brass, -3))
    glass = c.ellipse(27, 14.5, 4.8, 4.8)
    flat(c, glass, (64, 82, 98))
    flat(c, glass & c.rect(0, 0, 25, 12), (112, 140, 160))
    for gx, gy in ((15, 11), (39, 11), (27, 3)):               # 侧窗和顶阀
        part(c, c.ellipse(gx + 0.5, gy + 0.5, 2.4, 2.4), shade(brass, -1))
        c.put(gx, gy, (96, 124, 144))
    c.line(40, 5, 46, 0, (100, 92, 84)); c.line(41, 5, 47, 0, (70, 64, 60))           # 气管
    if f.windup or f.attack:                                   # 喷蒸汽
        for x, y in ((47, 2), (49, 1), (50, 4), (52, 2)):
            c.put(x, y, (226, 228, 232))
    f.led(c, 26, 13, 3)


# ================================================================ 沙漠（彩色 / 琥珀）
@mob("desert", "ds_vulture", FLY, 17, 13, "秃鹫：在烈日下盘旋，盯上亮处就收翅俯冲")
def ds_vulture(c, f):
    feather = (88, 70, 66)
    part(c, c.poly([(11, 7), (17, 6), (17, 9), (11, 9)]), shade(feather, -1))        # 尾巴
    part(c, c.ellipse(8.5, 7.5, 4.5, 2.6), feather)
    part(c, c.ellipse(4.5, 6.2, 1.8, 1.6), (226, 214, 196))    # 白领子
    part(c, c.ellipse(2.6, 4.6, 1.7, 1.6), (212, 150, 130))    # 秃头
    flat(c, c.rect(0, 5, 0, 6), (70, 60, 56))                  # 钩嘴
    if f.up:                                                   # 翅膀举起，末端是一根根张开的飞羽
        part(c, c.poly([(6, 7), (11, 7), (17, 0), (9, 0)]), feather)
        for x in (10, 13, 16):
            c.clear(x, 0)
    else:
        part(c, c.poly([(6, 8), (11, 8), (17, 13), (9, 13)]), shade(feather, -1))
        for x in (11, 14):
            c.clear(x, 12)
    f.led(c, 2, 4)


@mob("desert", "ds_jackrabbit", HOP, 12, 14, "长耳野兔：竖着两只大耳朵，压低身子一蹬，远远蹦过来")
def ds_jackrabbit(c, f):
    fur, belly = (136, 102, 80), (218, 200, 172)
    ear_tilt = 1 if f.air else 0
    part(c, c.poly([(3, 0 + ear_tilt), (5, 0), (6, 5), (4, 5)]), shade(fur, 1))
    part(c, c.poly([(6, 0), (7, 0 + ear_tilt), (8, 5), (6, 5)]), fur)
    flat(c, c.rect(5, 1, 5, 3), (212, 150, 140))              # 耳朵里
    part(c, c.ellipse(7.5, 10, 4.5, 3.4), fur)
    part(c, c.ellipse(4, 6.4, 2.7, 2.3), shade(fur, 1))
    part(c, c.ellipse(5, 11, 2, 1.6), belly)
    part(c, c.rect(7, 13, 11, 13), shade(fur, -1))             # 后脚
    part(c, c.rect(3, 12, 4, 13), shade(fur, -1))              # 前爪
    flat(c, c.rect(11, 8, 11, 9), belly)                       # 尾巴
    flat(c, c.rect(1, 7, 1, 7), (212, 150, 140))               # 鼻子
    f.led(c, 3, 6)


@mob("desert", "ds_wheel", DASH, 13, 13, "马车轮：从散架的篷车上掉下来的木轮，轮毂上一颗红灯，来回滚，蓄满劲就滚过来轧你")
def ds_wheel(c, f):
    wood, iron = (176, 124, 78), (92, 84, 88)
    rim = c.ellipse(6.5, 6.5, 6.5, 6.5) & ~c.ellipse(6.5, 6.5, 4.6, 4.6)
    part(c, rim, wood)
    flat(c, rim & ~c.ellipse(6.5, 6.5, 5.6, 5.6), iron)        # 铁箍
    spokes = [((6, 2), (6, 10)), ((2, 6), (10, 6)), ((3, 3), (9, 9)), ((9, 3), (3, 9))]
    if f.step or f.dash:                                       # 转了半格
        spokes = [((4, 2), (8, 10)), ((2, 8), (10, 4)), ((2, 4), (10, 8)), ((8, 2), (4, 10))]
    for (x0, y0), (x1, y1) in spokes:
        c.line(x0, y0, x1, y1, shade(wood, -1))
    part(c, c.rect(5, 5, 7, 7), shade(iron, 1))                # 轮毂
    f.led(c, 6, 6)


@mob("desert", "ds_cactus", SHOOT, 13, 17, "仙人掌：顶着一朵花，用两条根慢慢挪，停下来举起胳膊，朝你射一根刺（直线）",
     bullet="rivet")
def ds_cactus(c, f):
    green = (66, 140, 86)
    lift = 1 if (f.aim or f.fire) else 0
    part(c, c.rect(1, 4 - lift, 2, 10), green)                 # 左胳膊（朝前，开枪用）
    part(c, c.rect(1, 9, 5, 10), green)
    part(c, c.rect(10, 3, 11, 9), shade(green, -1))            # 右胳膊
    part(c, c.rect(8, 8, 11, 9), shade(green, -1))
    part(c, c.ellipse(6.5, 3, 2.5, 2.5) | c.rect(4, 3, 8, 14), green)
    flat(c, c.rect(7, 3, 7, 13), shade(green, -2))             # 棱
    for x, y in ((4, 7), (8, 11), (4, 12), (0, 6 - lift), (12, 5), (8, 5)):
        c.put(x, y, (238, 232, 196))                           # 刺
    flat(c, c.rect(5, 0, 7, 0), (232, 132, 168)); c.put(6, 1, (246, 196, 120))         # 花
    part(c, c.rect(4, 15, 5, 16), (130, 96, 70)); part(c, c.rect(8, 15, 9, 16), (130, 96, 70))
    f.led(c, 5, 5)
    f.muzzle(c, 1, 3 - lift)


@mob("desert", "ds_locomotive", ELITE, 56, 38,
     "蒸汽火车头：西部老火车头，鸣着汽笛横冲过场子；烟囱往上抛三块通红的煤；一停车就从车厢里滚出两只马车轮",
     moves=["charge", "volley", "summon"], elite_name="IRON HORSE", title="LAST TRAIN WEST", hp=1100,
     bullet="ember")
def ds_locomotive(c, f):
    iron, brass, cab = (74, 78, 96), (216, 172, 86), (150, 86, 62)
    part(c, c.rect(39, 9, 53, 29), cab)                         # 驾驶室
    part(c, c.rect(37, 6, 55, 8), shade(iron, 1))               # 车顶
    flat(c, c.rect(42, 12, 48, 18), (246, 196, 104) if (f.windup or f.attack) else (60, 52, 58))
    part(c, c.rect(10, 14, 40, 28), iron, bands=0.8)            # 锅炉
    for x in (19, 31):
        part(c, c.rect(x, 14, x, 28), brass)
    part(c, c.rect(6, 12, 10, 28), shade(iron, -1))             # 烟箱
    part(c, c.ellipse(26, 13, 3.4, 3), brass)                   # 汽包
    part(c, c.rect(13, 6, 17, 14), iron)                        # 烟囱
    part(c, c.poly([(10, 2), (20, 2), (17, 7), (13, 7)]), shade(iron, 1))
    if f.attack or f.pose or f.windup:                         # 冒烟
        part(c, c.ellipse(15, 1.2, 3, 1.4), (226, 222, 214))
        part(c, c.ellipse(22, 1.5, 2.2, 1.5), (210, 206, 200))
    part(c, c.rect(4, 8, 9, 13), brass)                         # 车头灯
    part(c, c.rect(3, 29, 55, 30), (56, 56, 70))                # 底盘
    catcher = c.poly([(0, 37), (7, 29), (10, 29), (10, 37)])
    part(c, catcher, shade(iron, 1))                            # 排障器
    for x in (3, 6, 9):
        flat(c, catcher & c.rect(x, 0, x, 37), shade(brass, -2))
    for cx, r in ((22, 5.5), (35, 5.5), (48, 4)):
        part(c, c.ellipse(cx, 37.9 - r, r, r), (60, 60, 74))
        flat(c, c.ellipse(cx, 37.9 - r, r, r) & ~c.ellipse(cx, 37.9 - r, r - 1.2, r - 1.2), shade(brass, -1))
        c.put(cx - 1, int(37.9 - r), brass)
    rod_y = 32 if f.step else 34
    c.line(21, rod_y, 36, rod_y, (200, 200, 210))               # 连杆
    f.led(c, 3, 10, 2)


# ================================================================ 森林（彩色 / 绿荧光）
@mob("forest", "fr_mushroom", HOP, 11, 11, "红蘑菇：伞盖一缩一弹地跳，落地抖下一圈孢子")
def fr_mushroom(c, f):
    cap, stem = (204, 76, 62), (232, 222, 196)
    part(c, c.rect(3, 5, 7, 10), stem)
    flat(c, c.rect(2, 10, 3, 10), shade(stem, -2)); flat(c, c.rect(7, 10, 8, 10), shade(stem, -2))
    part(c, c.ellipse(5.5, 4.4, 5.5, 4.4) & c.rect(0, 0, 10, 4), cap)
    flat(c, c.rect(1, 5, 9, 5), (204, 182, 150))               # 菌褶
    for x, y in ((3, 1), (7, 2), (1, 3)):
        flat(c, c.rect(x, y, x + 1, y), (246, 236, 220))
    if f.air:
        for x, y in ((0, 7), (10, 8), (1, 9)):
            c.put(x, y, (226, 214, 180))
    f.led(c, 4, 7)


@mob("forest", "fr_firefly", FLY, 13, 9, "萤火虫：屁股上拧着一颗老灯泡，在林子里打转，看见亮的就扑过去")
def fr_firefly(c, f):
    shell, glow = (72, 66, 70), (250, 214, 110)
    wing = (206, 218, 222)
    if not f.up:
        flat(c, c.poly([(4, 3), (11, 1), (12, 2), (7, 4)]), wing)
    part(c, c.ellipse(9.5, 5, 3, 2.6), glow)                    # 灯泡肚子
    flat(c, c.rect(9, 5, 10, 5), (236, 150, 60))                # 灯丝
    part(c, c.rect(6, 3, 7, 6), (170, 168, 156))                # 螺口
    part(c, c.ellipse(5, 4.5, 2.2, 2.2), shell)
    part(c, c.ellipse(2.5, 4.5, 2, 1.8), shell)
    c.line(1, 3, 0, 0, shell)                                   # 触角
    for x in (3, 5):
        flat(c, c.rect(x, 7, x, 8), shade(shell, -1))
    if f.up:
        flat(c, c.poly([(4, 2), (5, 0), (9, 0), (7, 3)]), wing)
    f.led(c, 1, 4)


@mob("forest", "fr_beetle", DASH, 16, 9, "锹甲：举着一对大颚在树根间来回爬，颚一张一亮，顶着冲过来夹一下")
def fr_beetle(c, f):
    shell = (118, 78, 58)
    open_ = 1 if (f.windup or f.dash) else 0
    c.polyline([(3, 3), (1, 1 - open_), (0, 2 - open_)], shade(shell, 1))               # 上颚
    c.polyline([(3, 5), (1, 6 + open_), (0, 5 + open_)], shade(shell, 1))
    c.put(2, 2 - open_ if open_ else 2, shade(shell, 1))
    part(c, c.ellipse(10.5, 4.5, 5.2, 3.4), shell)              # 鞘翅
    flat(c, c.rect(8, 2, 12, 2), shade(shell, 3))               # 亮光
    part(c, c.ellipse(5.5, 4.5, 2.3, 2.3), shade(shell, -1))
    part(c, c.rect(2, 3, 4, 5), shade(shell, -1))
    for i, x in enumerate((5, 8, 11)):
        flat(c, c.rect(x, 7, x, 8 - (i + f.step) % 2), shade(shell, -3))
    f.led(c, 3, 3)


@mob("forest", "fr_squirrel", SHOOT, 13, 14, "松鼠：抱着橡子慢慢走，停下来瞄一瞄，把橡子抛向你（抛物线）",
     bullet="ember")
def fr_squirrel(c, f):
    fur, belly = (194, 108, 60), (238, 216, 180)
    part(c, c.ellipse(10, 6, 3, 5.5) | c.ellipse(9.5, 1.6, 2.5, 1.6), shade(fur, 1))  # 大尾巴
    part(c, c.ellipse(6.5, 9.8, 3.2, 3.4), fur)
    part(c, c.ellipse(4, 5.2, 2.6, 2.3), fur)
    flat(c, c.rect(4, 2, 4, 3), shade(fur, -1))                 # 耳朵
    part(c, c.ellipse(5, 10.2, 1.6, 2), belly)
    part(c, c.rect(4, 13, 8, 13), shade(fur, -2))               # 脚
    hold_y = 8 if (f.aim or f.fire) else 9
    part(c, c.rect(1, hold_y, 2, hold_y), (118, 84, 52))        # 橡子帽
    part(c, c.rect(1, hold_y + 1, 2, hold_y + 2), (204, 158, 96))
    flat(c, c.rect(1, 6, 1, 6), (90, 60, 50))                   # 鼻子
    f.led(c, 3, 4)
    f.muzzle(c, 1, hold_y)


@mob("forest", "fr_stump", ELITE, 46, 40,
     "老树桩：背上还插着一把生锈的伐木锯，用树根当腿走过来；跳起来整个砸进地里；抛出一把松果；抖一抖长出小蘑菇",
     moves=["slam", "volley", "summon"], elite_name="OLD STUMP", title="ROOTS RUN DEEP", hp=1000, bullet="ember")
def fr_stump(c, f):
    bark, ring, moss = (124, 86, 64), (222, 192, 142), (110, 150, 82)
    for i, pts in enumerate(([(6, 30), (12, 30), (8, 39), (1, 39)],            # 三条树根当腿，走路时中间那条抬起来
                             [(18, 31), (25, 31), (25, 39), (16, 39)],
                             [(31, 30), (38, 30), (45, 39), (37, 39)])):
        dy = 2 if (f.step and i == 1) else 0
        part(c, c.poly([(x, y - (dy if y == 39 else 0)) for x, y in pts]), shade(bark, -1))
    trunk = c.poly([(6, 8), (38, 8), (40, 32), (4, 32)])
    part(c, trunk, bark, bands=0.6)
    for x in (11, 19, 28, 34):
        flat(c, trunk & c.rect(x, 12, x, 31) & ~c.rect(x, 20 + x % 5, x, 22 + x % 5), shade(bark, -2))   # 树皮纹
    # 锯子插在年轮上（在树桩顶面后面）
    blade = c.poly([(26, 7), (40, 0), (43, 3), (29, 9)])
    part(c, blade, (176, 166, 156))
    for i in range(5):
        c.put(28 + i * 3, 8 - i * 1 - (1 if i > 2 else 0), (140, 96, 70))           # 锈斑
    part(c, c.rect(41, 0, 45, 3), (150, 104, 64))               # 锯把
    top = c.ellipse(22, 8, 16.5, 4.2)
    part(c, top & ~blade | (top & c.rect(0, 9, 45, 12)), ring)
    flat(c, top & ~c.ellipse(22, 8, 13, 3) & c.rect(0, 0, 45, 8) & ~blade, shade(ring, -1))
    flat(c, c.ellipse(22, 8, 8, 2) & ~c.ellipse(22, 8, 6.5, 1.2) & ~blade, shade(ring, -2))
    c.put(22, 8, shade(ring, -3))
    part(c, c.ellipse(9, 13, 4, 2.4) & c.rect(0, 11, 45, 16), moss)   # 青苔
    part(c, c.ellipse(36, 22, 3, 2) & trunk, moss)
    for mx, my in ((36, 18), (39, 25)):                         # 侧面长的小蘑菇
        part(c, c.ellipse(mx + 0.5, my, 2.4, 1.6) & c.rect(0, 0, 45, my), (204, 76, 62))
        flat(c, c.rect(mx, my, mx, my + 1), (232, 222, 196))
    flat(c, c.ellipse(15, 18, 3.6, 3.2), (52, 36, 34))          # 树洞
    if f.attack or f.pose:
        flat(c, c.poly([(10, 25), (24, 25), (20, 29), (13, 29)]), (52, 36, 34))       # 张嘴
    else:
        c.polyline([(10, 26), (13, 25), (16, 27), (19, 25), (23, 26)], (52, 36, 34))
    f.led(c, 14, 17, 2)
