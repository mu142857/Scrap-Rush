"""太空、游乐园（ferris）、天气预报、彩条测试卡、雪花屏的怪（写法照 mobs_kitchen_beach.py）。

weather / test_card / static 是"电视本身"的画面：怪是信号、图标、彩条、雪花变出来的东西。
"""
import math
import random

import numpy as np

from mobkit import mob, part, flat, shade, ramp, FLY, HOP, DASH, SHOOT, ELITE
from oscarkit.shade import top_light, ragged_hem

DARK = (58, 56, 66)


def ascii_art(c, rows, pal, ox=0, oy=0):
    """逐像素手写：rows 里每个字母查 pal 上色，'.' 透明。"""
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                c.put(ox + x, oy + y, pal[ch])


# ================================================================ 太空
HULL = (184, 190, 204)          # 银色船壳
GLASS = (110, 190, 214)
GOLD = (214, 170, 84)           # 登月舱的金箔
ORANGE = (226, 140, 74)         # 土星橙


@mob("space", "space_ufo", FLY, 15, 10, "小飞碟：底下一圈灯轮流闪，循着亮光飞过来，绕两圈再俯冲撞人")
def space_ufo(c, f):
    part(c, c.ellipse(7.5, 4.2, 3.6, 3.6) & c.rect(0, 0, 14, 4), GLASS)         # 玻璃罩
    flat(c, c.rect(6, 1, 6, 1), (214, 240, 244))                                 # 罩子上的高光
    part(c, c.ellipse(7.5, 5.8, 7.5, 2.0), HULL)                                 # 碟身
    part(c, c.rect(3, 7, 11, 7), shade(HULL, -2), rim=0)                         # 底盘
    for i, x in enumerate((3, 5, 7, 9, 11)):                                     # 底下一圈灯，轮流亮
        lit = f.dive or (i + f.up) % 2 == 0
        flat(c, c.rect(x, 8, x, 8), (250, 224, 118) if lit else (112, 108, 104))
    f.led(c, 7, 3)                                                                # 罩子里的外星人眼睛


@mob("space", "space_lander", HOP, 13, 14, "登月舱：金箔下半身、四条支脚，蹲一下喷口一点火就蹦过来")
def space_lander(c, f):
    flat(c, c.rect(9, 0, 9, 1), shade(HULL, -2))                                 # 天线
    part(c, c.rect(3, 2, 10, 6) | c.rect(4, 1, 9, 1), HULL)                      # 上升级（座舱）
    flat(c, c.rect(3, 3, 5, 4), (40, 48, 78))                                    # 三角窗（简化成小方窗）
    part(c, c.rect(1, 7, 11, 10), GOLD)                                          # 下降级
    for x in (4, 8):
        flat(c, c.rect(x, 8, x, 10), shade(GOLD, -2))
    leg = (124, 122, 132)
    c.line(1, 10, 0, 12, leg); c.line(11, 10, 12, 12, leg)
    flat(c, c.rect(4, 11, 4, 12), leg); flat(c, c.rect(8, 11, 8, 12), leg)
    for x0 in (0, 3, 8, 11):                                                     # 脚垫
        flat(c, c.rect(x0, 13, x0 + 1, 13), shade(leg, 1))
    if f.air:                                                                     # 空中：喷口点火
        flat(c, c.rect(5, 11, 7, 11), ORANGE)
        flat(c, c.rect(6, 12, 6, 12), (250, 220, 120))
    f.led(c, 4, 3)


@mob("space", "space_sputnik", DASH, 19, 12, "斯普特尼克卫星：拖着四根天线当腿在地上爬，滴一声亮一下就冲过来扎人")
def space_sputnik(c, f):
    ant = (150, 154, 168)
    s = f.step
    for k, ((x0, y0), x1) in enumerate(zip([(8, 2), (10, 4), (10, 7), (8, 9)], [18, 15, 12, 9])):   # 四根往后拖的天线
        x1 += s if k % 2 else -s                                                 # 两两交替迈步
        c.line(x0, y0, x1, 10, ant)
        c.put(x1, 11, shade(ant, 2))
    part(c, c.ellipse(6, 5.5, 4.6, 4.6), HULL, span=1.1)                        # 抛光的铝球
    flat(c, c.rect(4, 2, 5, 2), (236, 240, 246))
    f.led(c, 3, 4)


@mob("space", "space_robot", SHOOT, 13, 16, "发条铁皮机器人：背上的发条转着慢慢走，停下来举起射线枪打一发（直线）")
def space_robot(c, f):
    tin = (116, 152, 204)
    flat(c, c.rect(6, 1, 6, 1), shade(HULL, -2)); flat(c, c.rect(6, 0, 6, 0), (240, 200, 96))   # 天线
    part(c, c.rect(3, 2, 9, 5), tin)                                             # 脑袋
    flat(c, c.rect(4, 3, 8, 4), (40, 44, 62))                                    # 面罩
    flat(c, c.rect(7, 3, 7, 3), (92, 98, 124))                                   # 另一只眼没亮
    flat(c, c.rect(5, 6, 7, 6), shade(tin, -3))
    part(c, c.rect(2, 7, 10, 11), tin)                                           # 身子
    flat(c, c.rect(4, 8, 7, 9), (232, 192, 96)); flat(c, c.rect(5, 8, 5, 8), (150, 110, 60))   # 胸前的仪表
    key = (232, 192, 96)
    flat(c, c.rect(11, 9, 11, 9), key)                                           # 发条钥匙（转：两帧换方向）
    flat(c, c.rect(12, 7, 12, 11) if f.step == 0 else c.rect(11, 10, 12, 10) | c.rect(12, 8, 12, 9), key)
    part(c, c.rect(1, 8, 2, 10), shade(tin, -1))                                 # 举枪的手
    flat(c, c.rect(0, 9, 2, 9), ORANGE); flat(c, c.rect(1, 10, 1, 10), shade(ORANGE, -2))   # 射线枪
    for x in (3, 7):
        part(c, c.rect(x, 12, x + 2, 14), shade(tin, -2), rim=0)
        flat(c, c.rect(x - 1, 15, x + 2, 15), DARK)
    f.led(c, 5, 3)
    f.muzzle(c, 0, 9)


@mob("space", "space_rocket", ELITE, 30, 46, "复古火箭：点火升空再整枚砸下来；舷窗一亮，尾翼扇形打出一排铆钉；舱门一开放出小飞碟",
     moves=["slam", "spray", "summon"], elite_name="RETRO ROCKET", title="T-MINUS ZERO", hp=1000, bullet="rivet")
def space_rocket(c, f):
    fin = shade(ORANGE, -1)
    part(c, c.poly([(9, 24), (9, 38), (3, 46), (1, 46), (1, 41)]), fin)        # 左右尾翼
    part(c, c.poly([(21, 24), (29, 41), (29, 46), (27, 46), (21, 38)]), fin)
    part(c, c.rect(9, 9, 20, 35) | c.rect(10, 36, 19, 37), HULL, bands=0.6)      # 船身
    flat(c, c.rect(9, 9, 9, 35), shade(HULL, 2))                                 # 迎光的一条亮棱
    part(c, c.poly([(15, 0), (21, 9.5), (9, 9.5)]), ORANGE)                      # 鼻锥
    part(c, c.rect(9, 27, 20, 29), ORANGE, rim=0)                                # 腰上一圈橙带
    for y in (12, 22, 32):                                                       # 铆钉
        for x in (11, 18):
            flat(c, c.rect(x, y, x, y), shade(HULL, -2))
    flat(c, c.ellipse(15, 17, 4, 4), (198, 158, 92))                             # 舷窗：黄铜圈 + 暗玻璃
    flat(c, c.ellipse(15, 17, 2.7, 2.7), (36, 44, 74))
    part(c, c.rect(14, 36, 15, 46), shade(fin, -1))                              # 正面那片尾翼（侧着看）
    flat(c, c.rect(11, 38, 13, 40), (70, 66, 76)); flat(c, c.rect(16, 38, 18, 40), (70, 66, 76))   # 喷口
    if f.air or f.attack or f.pose:                                              # 点火
        flat(c, c.poly([(11, 41), (19, 41), (15, 46)]), (250, 214, 110))
        flat(c, c.poly([(13, 41), (17, 41), (15, 44)]), (255, 244, 200))
    if f.pose:                                                                    # 亮相：舱门打开
        flat(c, c.rect(17, 20, 20, 25), (36, 44, 74))
    f.led(c, 14, 16, 2)


# ================================================================ 游乐园（夜）
TEAL = (82, 188, 196)
CREAM = (240, 230, 212)
BRASS = (222, 180, 92)
GREEN = (92, 172, 112)


@mob("ferris", "ferris_balloon", FLY, 9, 16, "跑丢的氢气球：拖着绳子飘，看见亮光就飘过去绕两圈再一头撞下来")
def ferris_balloon(c, f):
    part(c, c.ellipse(4.5, 5, 4.5, 5.2), TEAL, span=0.9)
    flat(c, c.rect(2, 2, 2, 3), (206, 244, 236))                                 # 反光
    flat(c, c.rect(3, 10, 5, 10), shade(TEAL, -2)); flat(c, c.rect(4, 11, 4, 11), shade(TEAL, -2))   # 打的结
    sway = [0, 1, 1, 0] if f.up else [0, -1, -1, 0]
    for i, y in enumerate(range(12, 16)):
        c.put(4 + sway[i], y, (206, 200, 218))                                   # 绳子
    f.led(c, 3, 4)


@mob("ferris", "ferris_horse", HOP, 15, 16, "旋转木马的马：还插在铜杆上，蹲一下就连杆带马像弹簧高跷一样蹦过来")
def ferris_horse(c, f):
    pal = {"W": shade(CREAM, 1), "w": CREAM, "v": shade(CREAM, -2), "u": shade(CREAM, -4),
           "M": shade(BRASS, 1), "m": BRASS, "n": shade(BRASS, -2), "P": shade(BRASS, 2), "p": shade(BRASS, -1),
           "d": (112, 92, 86)}
    ascii_art(c, [
        ".........P.....",
        "...MM....P.....",
        "..WWWM...P.....",
        ".WWWWWM..P.....",
        "WWwwwWm..P.....",
        "vw..wwWm.P.....",
        ".....wWWWPWWWM.",
        ".....wwwmPmwwnM",
        ".....wwwwPwwwvm",
        "....vwvvvPvvw.n",
        "...vu.v..P..v..",
        "..d...u..P..u..",
        ".........P..d..",
        ".........p.....",
        "........ppp....",
        ".......nnnnn...",
    ], pal)
    f.led(c, 2, 3)


@mob("ferris", "ferris_bumper", DASH, 17, 10, "碰碰车：车顶的导电杆擦着天花板冒火花，来回开；火花一闪就整台撞过来")
def ferris_bumper(c, f):
    car = (92, 148, 232)
    pole = (156, 152, 168)
    flat(c, c.rect(14, 1, 14, 3), pole)                                          # 导电杆
    flat(c, c.rect(13, 0, 15, 0), shade(pole, 1))
    if f.windup or f.dash:
        flat(c, c.rect(12, 0, 12, 0), (252, 232, 130)); flat(c, c.rect(16, 0, 16, 0), (252, 232, 130))
    part(c, c.rect(11, 3, 15, 6), shade(car, -1))                                # 椅背
    part(c, c.rect(1, 5, 15, 7) | c.rect(2, 4, 7, 4), car)                       # 车身
    flat(c, c.rect(6, 3, 7, 3), DARK); flat(c, c.rect(7, 4, 7, 4), DARK)         # 方向盘
    rub = (52, 50, 62)
    flat(c, c.rect(0, 8, 16, 9) | c.rect(0, 6, 0, 9) | c.rect(16, 6, 16, 9), rub)   # 一圈橡胶围边
    flat(c, c.rect(1, 8, 15, 8), shade(rub, 1))
    f.led(c, 1, 6)                                                               # 车灯


@mob("ferris", "ferris_popcorn", SHOOT, 12, 17, "爆米花车：吱呀吱呀推着走，停下来锅一抖，朝你抛一把爆米花（抛物线）")
def ferris_popcorn(c, f):
    part(c, c.rect(3, 0, 8, 0) | c.rect(1, 1, 10, 2), GREEN)                     # 车顶
    for x in range(1, 11):
        if x % 3 == 0:
            flat(c, c.rect(x, 0 if 3 <= x <= 8 else 1, x, 2), CREAM)             # 顶棚条纹
    flat(c, c.rect(2, 3, 9, 9), (176, 200, 204))                                 # 玻璃柜
    flat(c, c.rect(5, 3, 6, 4), (166, 170, 182))                                 # 吊着的锅
    rng = random.Random(5)
    for y in range(5, 10):                                                       # 堆着的爆米花
        for x in range(2, 10):
            if y > 6 or rng.random() < (0.35 if y == 5 else 0.7):
                c.put(x, y, (248, 236, 190) if rng.random() < 0.6 else (236, 204, 116))
    part(c, c.rect(1, 3, 1, 9) | c.rect(10, 3, 10, 9), shade(GREEN, -1), rim=0)   # 立柱
    part(c, c.rect(1, 10, 10, 14), GREEN)                                        # 车柜
    flat(c, c.rect(1, 11, 10, 11), CREAM)                                        # 奶白腰线
    flat(c, c.rect(11, 9, 11, 12), shade(GREEN, -2))                             # 推把
    flat(c, c.ellipse(7.5, 15, 2, 2), DARK)                                      # 轮子
    flat(c, c.rect(7, 15, 7, 15), (150, 146, 160))
    flat(c, c.rect(2, 15, 2, 16), DARK)
    f.led(c, 3, 13)
    f.muzzle(c, 2, 3)


@mob("ferris", "ferris_wheel", ELITE, 40, 46, "迷你摩天轮：轮子一直在转；整个滚着冲过场子；把吊舱当炮弹抛三颗；放出氢气球",
     moves=["charge", "volley", "summon"], elite_name="BIG WHEEL", title="ONE MORE RIDE", hp=950, bullet="ember")
def ferris_wheel(c, f):
    frame_ = (138, 122, 170)
    cx, cy, R = 20, 18, 16.5
    c.line(19, 19, 5, 44, frame_); c.line(20, 19, 6, 44, frame_)                 # A 字架
    c.line(21, 19, 35, 44, shade(frame_, -1)); c.line(20, 19, 34, 44, shade(frame_, -1))
    flat(c, c.rect(3, 45, 9, 45), shade(frame_, -2)); flat(c, c.rect(31, 45, 37, 45), shade(frame_, -2))
    a0 = f.i * math.pi / 24
    for k in range(8):                                                           # 辐条（每帧转一点）
        a = a0 + k * math.pi / 4
        c.line(cx, cy, cx + R * math.cos(a), cy + R * math.sin(a), (196, 186, 222))
    flat(c, c.ellipse(cx + 0.5, cy + 0.5, R, R) & ~c.ellipse(cx + 0.5, cy + 0.5, R - 1.3, R - 1.3), (226, 218, 240))
    for k in range(16):                                                          # 一圈灯泡，隔一个亮
        a = a0 + k * math.pi / 8
        x, y = round(cx + 0.5 + R * math.cos(a) - 0.5), round(cy + 0.5 + R * math.sin(a) - 0.5)
        c.put(x, y, (252, 226, 120) if (k + f.i) % 2 == 0 else (186, 150, 96))
    gcols = [(96, 146, 232), (244, 204, 92), (104, 196, 128)]
    for k in range(6):                                                           # 吊舱：挂在轮缘上，永远朝下
        a = a0 + k * math.pi / 3 + math.pi / 6
        gx, gy = round(cx + R * math.cos(a)), round(cy + R * math.sin(a))
        col = gcols[k % 3]
        part(c, c.rect(gx - 2, gy + 1, gx + 2, gy + 3), col)
        flat(c, c.rect(gx, gy, gx, gy), (196, 186, 222))
    part(c, c.ellipse(cx + 0.5, cy + 0.5, 3, 3), (176, 166, 204))               # 轮毂
    f.led(c, 19, 17, 2)


# ================================================================ 天气预报
CLOUD = (226, 232, 242)
SUN = (248, 204, 82)
NAVY = (34, 44, 100)


@mob("weather", "weather_cloud", FLY, 15, 13, "雨云图标：从天气图上飘下来，雨点一甩一甩当翅膀，往亮处扑，俯冲时一头砸下")
def weather_cloud(c, f):
    m = (c.ellipse(4.5, 7, 3.6, 3) | c.ellipse(8.5, 5.2, 4.5, 4.5) | c.ellipse(12, 7.5, 3, 2.6)
         | c.rect(2, 7, 13, 9)) & c.rect(0, 0, 14, 9)
    part(c, m, CLOUD, span=0.9)
    rain = (150, 204, 248)
    for i, x in enumerate((3, 6, 9, 12)):
        y = 11 + ((i + f.up) % 2)
        flat(c, c.rect(x, y - 1, x, y), rain)
    f.led(c, 5, 7)


@mob("weather", "weather_sun", HOP, 13, 13, "太阳图标：一圈光芒，蹲一下光芒一缩就弹过来，落地砸出一片晴天")
def weather_sun(c, f):
    ray = shade(SUN, -2)
    for x0, y0, x1, y1 in [(6, 0, 6, 1), (0, 6, 1, 6), (11, 6, 12, 6), (6, 11, 6, 12),
                           (2, 2, 3, 3), (9, 2, 10, 3), (2, 9, 3, 10), (9, 9, 10, 10)]:
        c.line(x0, y0, x1, y1, ray)
    part(c, c.ellipse(6.5, 6.5, 3.7, 3.7), SUN)
    flat(c, c.rect(5, 12, 7, 12), ray)                                           # 脚下那根光芒压扁成脚
    f.led(c, 4, 5)


@mob("weather", "weather_ticker", DASH, 20, 8, "滚动字幕：从屏幕底下爬出来的一截字幕条，字一直往后滚，闪一下就整条刷过来")
def weather_ticker(c, f):
    part(c, c.rect(1, 1, 19, 5) | c.rect(0, 2, 0, 4), NAVY)
    off = f.i                                                                    # 字往后滚
    for x in range(3, 19):
        if (x + off) % 5 < 3:
            c.put(x, 3, (232, 236, 244))
    leg = shade(NAVY, -2)
    for i, x in enumerate((2, 5, 8, 11, 14, 17)):
        lift = (i + f.step) % 2
        flat(c, c.rect(x, 6, x, 7 - lift), leg)
    f.led(c, 1, 2)


@mob("weather", "weather_thermo", SHOOT, 9, 17, "温度计：踮着脚慢慢挪，停下来从顶上挤出一颗冰珠朝你抛过来（抛物线）")
def weather_thermo(c, f):
    glass = (232, 238, 246)
    part(c, c.rect(2, 1, 6, 11) | c.rect(3, 0, 5, 0), glass)
    blue = (72, 124, 224)
    flat(c, c.rect(4, 4 - (1 if f.aim or f.fire else 0), 4, 11), blue)          # 蓝色液柱（瞄准时涨上去）
    for y in (3, 5, 7, 9):
        flat(c, c.rect(6, y, 6, y), (130, 140, 166))                             # 刻度
    part(c, c.ellipse(4.5, 13.5, 2.6, 2.4), blue)                                # 液泡
    flat(c, c.rect(2, 16, 3, 16), shade(blue, -3)); flat(c, c.rect(5, 16, 6, 16), shade(blue, -3))
    f.led(c, 3, 2)
    f.muzzle(c, 4, 0)


@mob("weather", "weather_storm", ELITE, 44, 38, "雷暴云：踩着雨柱走，朝你抛三颗冰雹；跳起来砸下一道闪电；分出两朵雨云",
     moves=["volley", "slam", "summon"], elite_name="STORM FRONT", title="100% CHANCE OF PAIN", hp=950, bullet="ember")
def weather_storm(c, f):
    storm = (112, 122, 150)
    m = (c.ellipse(12, 14, 10, 9) | c.ellipse(24, 10.5, 12, 10) | c.ellipse(35, 15, 8.5, 8)
         | c.ellipse(22, 19, 19, 6.5)) & c.rect(0, 0, 43, 24)
    part(c, m, storm, bands=0.8)
    flat(c, c.rect(4, 24, 40, 24) & m, shade(storm, -3))
    rain = (168, 200, 240)
    for i, x in enumerate(range(6, 42, 4)):                                      # 雨柱当腿
        for y in range(25, 38):
            if (y + i * 2 + f.i) % 4 != 0 or y == 37 and i % 2 == f.step:
                c.put(x, y, rain if (y + i) % 3 else shade(rain, -2))
    bolt = (252, 230, 110)
    if f.attack or f.pose:                                                       # 劈下一道闪电
        c.polyline([(22, 22), (18, 28), (23, 29), (19, 37)], bolt)
        c.polyline([(23, 22), (19, 28), (24, 29), (20, 37)], bolt)
    elif f.windup:
        c.polyline([(28, 8), (25, 13), (29, 14), (26, 19)], bolt)
    flat(c, c.ellipse(12, 13, 3, 2.2), shade(storm, -4))                        # 眼窝
    f.led(c, 11, 12, 2)


# ================================================================ 彩条测试卡
BARS = [(204, 204, 204), (204, 196, 82), (82, 196, 198), (84, 186, 92), (196, 84, 196), (196, 72, 72), (72, 76, 204)]


@mob("test_card", "test_reticle", FLY, 13, 13, "测试卡上的十字圆：一边飞一边转（十字 / 斜叉），对准亮处扑过去俯冲")
def test_reticle(c, f):
    flat(c, c.ellipse(6.5, 6.5, 6.5, 6.5) & ~c.ellipse(6.5, 6.5, 5.3, 5.3), (238, 238, 236))
    flat(c, c.ellipse(6.5, 6.5, 5.3, 5.3) & ~c.ellipse(6.5, 6.5, 4.4, 4.4), (64, 64, 76))
    cross = (238, 238, 236)
    if f.up:
        c.rect(6, 2, 6, 10, cross); c.rect(2, 6, 10, 6, cross)
    else:
        c.line(3, 3, 9, 9, cross); c.line(9, 3, 3, 9, cross)
    f.led(c, 6, 6)


@mob("test_card", "test_bars", DASH, 15, 10, "彩条蜈蚣：从测试卡上撕下来的一截彩条，底下一排小黑脚，来回爬，一闪就横着冲过来")
def test_bars(c, f):
    for i, col in enumerate(BARS[1:5] + BARS[6:]):
        x = i * 3
        flat(c, c.rect(x, 0, x + 2, 0), shade(col, 2))
        flat(c, c.rect(x, 1, x + 2, 5), col)
        flat(c, c.rect(x, 6, x + 2, 6), shade(col, -2))
    for i, x in enumerate(range(1, 15, 2)):
        lift = (i + f.step) % 2
        flat(c, c.rect(x, 7, x, 9 - lift), (40, 40, 50))
    f.led(c, 1, 2)


@mob("test_card", "test_jack", HOP, 11, 17, "弹簧盒小丑：测试卡上那个小丑玩偶，挤眼睛，蹲回盒子里再连盒子一起弹过来")
def test_jack(c, f):
    hat = BARS[1]
    part(c, c.poly([(5.5, 0), (8.5, 4.5), (2.5, 4.5)]), hat, rim=0)             # 尖帽
    face = c.ellipse(5.5, 7, 3.2, 2.8)
    flat(c, face, (240, 236, 230))                                               # 白脸
    flat(c, face & ~np.roll(face, -1, axis=0), (206, 200, 200))                  # 下巴暗一档
    flat(c, c.rect(6, 6, 7, 6), (60, 56, 70))                                    # 挤眼的那只
    flat(c, c.rect(4, 8, 6, 8), (160, 70, 120))                                  # 嘴
    ruff = BARS[2]
    for x in range(2, 9):
        c.put(x, 10 - (x % 2), ruff)                                             # 领圈
    spring = (170, 172, 180)
    for y, xs in ((11, (4, 5, 6)), (12, (4, 5, 6))):
        for x in xs:
            if (x + y) % 2:
                c.put(x, y, spring)
    flat(c, c.rect(5, 11, 5, 12), shade(spring, -2))                             # 弹簧芯
    box = BARS[6]
    flat(c, c.rect(1, 14, 9, 16), box); flat(c, c.rect(1, 16, 9, 16), shade(box, -2))
    flat(c, c.rect(1, 13, 9, 13), hat)                                           # 盒口黄边
    flat(c, c.rect(10, 14, 10, 14), (170, 172, 180)); flat(c, c.rect(10, 15, 10, 15) if f.air else c.rect(10, 13, 10, 13), (170, 172, 180))   # 摇把
    f.led(c, 4, 6)


@mob("test_card", "test_siggen", SHOOT, 16, 12, "信号发生器：小屏幕上跑着正弦波，拖着脚慢慢挪，停下来把输出口对准你射一发测试信号（直线）")
def test_siggen(c, f):
    case = (188, 184, 172)
    flat(c, c.rect(5, 0, 11, 0), shade(case, -3))                                # 提手
    part(c, c.rect(1, 1, 15, 9), case)
    flat(c, c.rect(2, 3, 8, 7), (26, 40, 38))                                    # 示波小屏
    wave = (110, 226, 196)
    for x, y in [(2, 5), (3, 4), (4, 4), (5, 5), (6, 6), (7, 6), (8, 5)] if f.step == 0 else \
            [(2, 4), (3, 4), (4, 5), (5, 6), (6, 6), (7, 5), (8, 4)]:
        c.put(x, y, wave)
    for x, y in ((11, 3), (14, 3), (11, 6), (14, 6)):                            # 旋钮
        flat(c, c.rect(x, y, x + 1, y + 1), shade(case, -4))
    flat(c, c.rect(0, 6, 0, 7), (210, 214, 222))                                 # 输出口
    flat(c, c.rect(2, 10, 4, 11), DARK); flat(c, c.rect(12, 10, 14, 11), DARK)
    f.led(c, 6, 4)                                                               # 屏幕上的光点
    f.muzzle(c, 0, 6)


@mob("test_card", "test_colorbars", ELITE, 36, 44, "站起来的彩条测试卡：彩条一卷扇形打出五发；整块横冲过场子；叫出彩条蜈蚣",
     moves=["spray", "charge", "summon"], elite_name="COLOR BARS", title="PLEASE STAND BY", hp=1000, bullet="rivet")
def test_colorbars(c, f):
    off = 2 if (f.attack or f.pose) else 0                                       # 出招时彩条往旁边滚一格
    for x in range(35):
        col = BARS[((x + off) // 5) % 7]
        flat(c, c.rect(x, 0, x, 0), shade(col, 2))
        flat(c, c.rect(x, 1, x, 25), col)
        flat(c, c.rect(x, 26, x, 26), shade(col, -2))
    for x0, x1, col in [(0, 9, BARS[6]), (10, 14, (30, 30, 36)), (15, 24, (232, 232, 232)), (25, 34, (30, 30, 36))]:
        flat(c, c.rect(x0, 27, x1, 33), col)                                     # 底下一条蓝 / 黑 / 白 / 黑
        flat(c, c.rect(x0, 27, x1, 27), shade(col, 1))
    white = (240, 240, 238)
    flat(c, c.ellipse(17.5, 14, 11.5, 11.5) & ~c.ellipse(17.5, 14, 10.4, 10.4), white)
    flat(c, c.rect(17, 3, 17, 25) | c.rect(6, 14, 28, 14), white)
    flat(c, c.ellipse(17.5, 14.5, 2.6, 2.6), (30, 30, 36))
    leg = (70, 68, 80)
    part(c, c.rect(7, 34, 10, 42), leg, rim=0); part(c, c.rect(24, 34, 27, 42), leg, rim=0)
    flat(c, c.rect(5, 43, 11, 43), shade(leg, -1)); flat(c, c.rect(23, 43, 29, 43), shade(leg, -1))
    f.led(c, 17, 14, 2)


# ================================================================ 雪花屏
SNOW = [(150, 154, 168), (196, 200, 210), (230, 232, 236)]


@mob("static", "static_ghost", FLY, 12, 15, "雪花幽灵：一块比雪花屏暗一截的雪花，下摆参差，只有一只红眼，往亮处飘再俯冲")
def static_ghost(c, f):
    body = (64, 66, 86)
    m = c.ellipse(6, 5.5, 5.6, 5.3) | c.rect(1, 5, 10, 12)
    for x in range(1, 11):                                                       # 参差下摆，两帧交替
        L = 13 + ((x + f.up) % 3 == 0) - ((x + f.up) % 3 == 2) * 2
        m |= c.rect(x, 12, x, min(14, L))
    part(c, m, body, span=1.2)
    rng = random.Random(11)
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):                                                     # 身上的雪花点（固定位置，不闪）
        if rng.random() < 0.08 and not (2 <= x <= 5 and 3 <= y <= 7):
            c.put(x, y, SNOW[rng.randrange(2)])
    flat(c, c.ellipse(4, 5.5, 1.8, 1.6), shade(body, -3))                        # 眼窝
    f.led(c, 3, 5)


@mob("static", "static_ears", HOP, 13, 15, "兔耳天线：两根伸缩天线当耳朵，木底座一蹲，像兔子一样蹦过来")
def static_ears(c, f):
    rod = (150, 156, 172)
    spread = 2 if f.air else 0
    c.line(5, 9, 1 + spread, 1, rod); c.line(7, 9, 11 - spread, 1, rod)
    c.line(5, 9, 3 + spread // 2, 5, shade(rod, -2)); c.line(7, 9, 9 - spread // 2, 5, shade(rod, -2))   # 粗的那一节
    for x in (1 + spread, 11 - spread):
        flat(c, c.rect(x, 0, x, 0), (236, 238, 244))                             # 天线头
    wood = (100, 68, 52)
    part(c, c.ellipse(6.5, 12.5, 6, 3.3) & c.rect(0, 9, 12, 14), wood)
    flat(c, c.rect(8, 11, 9, 12), (220, 200, 160))                               # 旋钮
    flat(c, c.rect(3, 14, 4, 14), DARK); flat(c, c.rect(9, 14, 10, 14), DARK)
    f.led(c, 3, 11)


@mob("static", "static_coax", DASH, 20, 8, "同轴电缆：拖着一条黑线蛇行，接头当脑袋，铜芯当牙，一闪就窜过来咬一口")
def static_coax(c, f):
    cable = (46, 46, 56)
    phase = f.step * 2.5 + (1.2 if f.dash else 0)
    m = np.zeros((c.h, c.w), bool)
    for x in range(4, 20):
        yc = 4 + round(2 * math.sin((x + phase) / 2.2))
        m[yc:yc + 2, x] = True
    part(c, m, cable, span=1.3)
    part(c, c.rect(1, 1, 4, 6), (184, 188, 202))                                 # 接头螺母
    flat(c, c.rect(3, 1, 3, 6), (140, 144, 160))
    flat(c, c.rect(0, 3, 0, 4), (220, 150, 88))                                  # 铜芯
    f.led(c, 2, 2)


@mob("static", "static_tube", SHOOT, 10, 17, "电子管：踩着管脚一步步挪，停下来灯丝烧亮，从顶上打出一道电火花（直线）")
def static_tube(c, f):
    glass = (82, 86, 104)
    part(c, c.rect(2, 3, 7, 12) | c.ellipse(5, 3, 3, 2.6), glass)               # 烟色玻璃泡
    flat(c, c.rect(3, 1, 6, 2) & c.ellipse(5, 3, 3, 2.6), (196, 200, 212))      # 顶上的镀银
    flat(c, c.rect(3, 5, 6, 10), (54, 54, 66))                                   # 阳极
    glow = (250, 176, 80) if (f.aim or f.fire) else (204, 130, 70)
    flat(c, c.rect(5, 6, 5, 9), glow)                                            # 灯丝
    part(c, c.rect(2, 13, 7, 14), (44, 40, 44), rim=0)                           # 胶木底座
    pin = (170, 172, 182)
    flat(c, c.rect(3, 15, 3, 16), pin); flat(c, c.rect(6, 15, 6, 16), pin)
    f.led(c, 3, 6)
    f.muzzle(c, 4, 0)


@mob("static", "static_noise", ELITE, 34, 46, "满屏雪花聚成的兜帽大幽灵：袖子一甩扇形打出雪花；贴地冲过场子；叫出雪花幽灵",
     moves=["spray", "charge", "summon"], elite_name="WHITE NOISE", title="NO SIGNAL", hp=1000, bullet="rivet")
def static_noise(c, f):
    body = (72, 76, 96)
    robe = c.poly([(13, 0), (22, 7), (27, 18), (32, 46), (3, 46), (6, 18), (8, 7)])
    robe = ragged_hem(robe, depth=4, seed=3 + (f.i % 2))
    if f.attack or f.pose:
        arm = c.poly([(8, 18), (0, 12), (1, 16), (10, 24)])
    else:
        arm = c.poly([(8, 20), (1, 27), (2, 30), (10, 26)])
    top_light(c, robe | arm, ramp(body, 7, 1.2), bands=1.0, rim=1, under=1, folds=[14, 20, 26])
    rng = random.Random(7)
    ys, xs = np.nonzero(robe | arm)
    for y, x in zip(ys, xs):                                                     # 身上的雪花点
        if y > 13 and rng.random() < 0.06:
            c.put(x, y, SNOW[rng.randrange(3)])
    flat(c, c.ellipse(12, 10.5, 3.2, 4.4), (26, 26, 36))                        # 兜帽里最暗
    for x, y in [(30, 14), (33, 26), (1, 38), (29, 6), (2, 44)]:                 # 身边飘着几颗雪花
        c.put(x, y, SNOW[2])
    f.led(c, 11, 9, 2)
