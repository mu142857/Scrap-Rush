"""厨房、海滩的怪（样板：别的场景照这个写法）。"""
from mobkit import mob, part, flat, shade, FLY, HOP, DASH, SHOOT, ELITE

CHROME = (176, 180, 190)
BREAD = (222, 176, 112)
CREAM = (226, 220, 196)
DARK = (70, 66, 74)


# ================================================================ 厨房
@mob("kitchen", "toaster", HOP, 14, 11, "吐司机：蹲下时两片吐司弹出来，然后整台跳过来砸")
def toaster(c, f):
    part(c, c.rect(1, 3, 12, 9), CHROME)
    flat(c, c.rect(3, 3, 5, 3), shade(CHROME, -3)); flat(c, c.rect(8, 3, 10, 3), shade(CHROME, -3))   # 两条槽
    up = 2 if f.air else 0
    for x in (3, 8):
        part(c, c.rect(x, 1 - up // 2, x + 2, 3), BREAD, rim=1)
    flat(c, c.rect(13, 5, 13, 7), DARK)                     # 侧面的拨杆
    flat(c, c.rect(2, 10, 3, 10), DARK); flat(c, c.rect(10, 10, 11, 10), DARK)
    f.led(c, 3, 6)


@mob("kitchen", "fan", FLY, 15, 13, "台扇：扇叶当翅膀转，扑向灯光，俯冲时风扇罩先撞过来")
def fan(c, f):
    hub = (7, 6)
    blade = (150, 176, 196)
    if f.up:
        for pts in ([(7, 6), (1, 1), (4, 0)], [(7, 6), (13, 1), (14, 4)]):
            part(c, c.poly(pts), blade)
    else:
        for pts in ([(7, 6), (0, 7), (1, 10)], [(7, 6), (14, 7), (13, 10)]):
            part(c, c.poly(pts), blade)
    ring = c.ellipse(7.5, 6.5, 5, 5)
    inner = c.ellipse(7.5, 6.5, 4, 4)
    flat(c, ring & ~inner, (200, 204, 210))
    part(c, c.ellipse(7.5, 6.5, 2, 2), (110, 116, 130))
    part(c, c.rect(7, 11, 8, 12), (120, 124, 136))          # 底座
    f.led(c, *hub)


@mob("kitchen", "mixer", DASH, 16, 10, "手持打蛋器：两根搅拌头在地上蹭着走，蓄力一下就旋着冲过来")
def mixer(c, f):
    body = (224, 214, 190)
    part(c, c.poly([(2, 1), (13, 1), (15, 4), (12, 5), (3, 5)]), body)
    part(c, c.rect(9, 0, 14, 1), shade(body, -1))           # 把手
    for x in (4, 7):
        flat(c, c.rect(x, 6, x, 9), (180, 184, 194))
        flat(c, c.rect(x - 1, 8 + (f.step if x == 4 else 1 - f.step), x + 1, 8 + (f.step if x == 4 else 1 - f.step)), (200, 204, 212))
    f.led(c, 3, 3)


@mob("kitchen", "percolator", SHOOT, 10, 16, "老式咖啡壶：慢慢挪，壶嘴对准你喷一口滚烫的咖啡（抛物线）", bullet="ember")
def percolator(c, f):
    steel = (166, 170, 182)
    part(c, c.poly([(2, 4), (7, 4), (8, 14), (1, 14)]), steel)
    part(c, c.ellipse(4.5, 2.5, 2.5, 2), shade(steel, 1))
    flat(c, c.rect(4, 0, 4, 0), (120, 90, 70))              # 顶上的玻璃钮
    part(c, c.poly([(1, 6), (0, 6), (0, 8), (1, 9)]), shade(steel, -1))   # 壶嘴（朝左）
    part(c, c.rect(8, 6, 9, 10), (60, 50, 50))              # 把手
    flat(c, c.rect(2, 15, 3, 15), DARK); flat(c, c.rect(6, 15, 7, 15), DARK)
    f.led(c, 4, 9)
    f.muzzle(c, 0, 6)


@mob("kitchen", "fridge", ELITE, 30, 42, "老冰箱：冷气一喷，冰块扇形飞出来；门一开叫出吐司机；整台推着往前撞",
     moves=["spray", "charge", "summon"], elite_name="OLD FRIDGE", title="KEEP COOL", hp=900, bullet="rivet")
def fridge(c, f):
    body = (222, 222, 210)
    part(c, c.rect(2, 2, 27, 39), body, bands=0.6)
    part(c, c.rect(1, 0, 28, 3), shade(body, 1))            # 圆角顶
    flat(c, c.rect(2, 15, 27, 15), shade(body, -3))         # 冷冻室门缝
    flat(c, c.rect(2, 16, 27, 16), shade(body, 1))
    open_ = f.attack or f.pose
    if open_:                                               # 门开着：里面亮着冷光
        flat(c, c.rect(3, 17, 26, 37), (200, 226, 236))
        for y in (24, 31):
            flat(c, c.rect(3, y, 26, y), (150, 180, 196))
        flat(c, c.rect(6, 19, 10, 23), (230, 110, 100)); flat(c, c.rect(16, 26, 21, 30), (240, 214, 120))
    else:
        flat(c, c.rect(4, 19, 5, 30), shade(body, -4))      # 把手
        flat(c, c.rect(12, 22, 18, 27), (226, 214, 180))    # 冰箱上贴着的画
        flat(c, c.rect(13, 25, 17, 25), (96, 136, 214))
    flat(c, c.rect(4, 5, 5, 12), shade(body, -4))
    flat(c, c.rect(14, 6, 20, 8), (232, 200, 120))          # 冰箱贴
    part(c, c.rect(3, 40, 6, 41), DARK); part(c, c.rect(23, 40, 26, 41), DARK)
    f.led(c, 24, 6, 2)


# ================================================================ 海滩
SAND = (226, 196, 150)
CRAB = (206, 96, 78)


@mob("beach", "crab", DASH, 17, 9, "螃蟹：横着走，举钳子一亮就横冲过来夹一下")
def crab(c, f):
    lift = 1 if f.windup else 0
    for x in (0, 14):
        part(c, c.rect(x, 0 - lift, x + 2, 2 - lift), shade(CRAB, 1))
        flat(c, c.rect(x + 1, 3 - lift, x + 1, 4), CRAB)
    flat(c, c.rect(5, 2, 5, 3), (240, 236, 230)); flat(c, c.rect(11, 2, 11, 3), (240, 236, 230))
    part(c, c.ellipse(8.5, 5.5, 7, 2.6), CRAB)
    for i, x in enumerate((3, 5, 7, 10, 12, 14)):
        flat(c, c.rect(x, 8 - (i + f.step) % 2, x, 8), shade(CRAB, -3))
    f.led(c, 8, 4)


@mob("beach", "jelly", FLY, 11, 15, "水母：伞盖一张一合往上浮，触手拖着，俯冲时缩成一团")
def jelly(c, f):
    bell = (196, 160, 214)
    w = 4 if f.up else 5
    part(c, c.ellipse(5.5, 4, w + 0.5, 4) & c.rect(0, 0, 10, 5), bell, span=0.8)
    flat(c, c.rect(5 - w + 1, 5, 5 + w, 5), shade(bell, -2))
    for i, x in enumerate((2, 4, 6, 8)):
        L = 9 if f.up else 7
        for y in range(6, 6 + L):
            c.put(x + ((y + i) // 3) % 2, y, shade(bell, -1 if y % 2 else -2))
    f.led(c, 5, 3)


@mob("beach", "hermit", HOP, 13, 12, "寄居蟹：背着一台小电视当壳，缩进去蹲一下再蹦出来")
def hermit(c, f):
    shell = (176, 168, 150)
    part(c, c.rect(2, 0, 12, 8), shell)
    flat(c, c.rect(4, 2, 10, 6), (60, 62, 80))
    flat(c, c.rect(5, 3, 6, 3), (110, 112, 140))
    for x in (0, 2):                                         # 钳子和腿从左边伸出来
        part(c, c.rect(x, 7, x + 2, 9), CRAB)
    for x in (3, 6, 9):
        flat(c, c.rect(x, 10, x, 11), shade(CRAB, -2))
    flat(c, c.rect(1, 5, 1, 6), (240, 236, 230))
    f.led(c, 10, 4)


@mob("beach", "boombox", SHOOT, 18, 11, "收音机：扛在沙滩上的大喇叭，一放歌就往你那边吹音符（抛物线）", bullet="note")
def boombox(c, f):
    case = (90, 92, 104)
    part(c, c.rect(0, 2, 17, 10), case)
    flat(c, c.rect(4, 0, 13, 0), shade(case, -1)); flat(c, c.rect(4, 0, 4, 2), shade(case, -1)); flat(c, c.rect(13, 0, 13, 2), shade(case, -1))
    for cx in (4, 13):
        part(c, c.ellipse(cx + 0.5, 6.5, 3, 3), (60, 60, 70))
        flat(c, c.ellipse(cx + 0.5, 6.5, 1, 1), (150, 150, 166))
    flat(c, c.rect(7, 4, 10, 5), (230, 200, 120))           # 磁带仓
    f.led(c, 8, 8)
    f.muzzle(c, 1, 6)


@mob("beach", "tvcrab", ELITE, 44, 40, "电视壳大寄居蟹：背着一台老电视当壳，钳子横扫冲过来；跳起来砸出沙浪；叫小螃蟹",
     moves=["charge", "slam", "summon"], elite_name="TV HERMIT", title="HIGH TIDE", hp=950, bullet="rivet")
def tvcrab(c, f):
    c0 = c
    from mobkit import Canvas
    c = Canvas(44, 34)
    tv = (196, 184, 160)
    part(c, c.rect(14, 0, 43, 24), tv, bands=0.7)            # 电视壳
    flat(c, c.rect(17, 3, 37, 19), (50, 54, 72))
    flat(c, c.rect(18, 4, 20, 5), (110, 116, 150))
    flat(c, c.rect(39, 6, 41, 8), shade(tv, -3)); flat(c, c.rect(39, 12, 41, 14), shade(tv, -3))
    flat(c, c.rect(20, 10, 34, 12), (90, 110, 150) if not (f.attack or f.pose) else (230, 220, 200))
    claw_y = 14 if not f.windup else 10
    part(c, c.ellipse(6, claw_y, 6, 4), shade(CRAB, 1))      # 大钳子
    flat(c, c.rect(0, claw_y - 1, 4, claw_y - 1), shade(CRAB, -3))
    part(c, c.ellipse(11, 26, 7, 5), CRAB)
    flat(c, c.rect(7, 20, 7, 23), (240, 236, 230)); flat(c, c.rect(11, 19, 11, 23), (240, 236, 230))
    for i, x in enumerate((10, 15, 20, 26, 32, 38)):
        flat(c, c.rect(x, 30, x + 1, 33 - (i + f.step) % 2), shade(CRAB, -3))
    flat(c, c.rect(14, 24, 43, 29), shade(CRAB, -1))
    f.led(c, 9, 23, 2)
    c0.paste(c, 0, 6)
    for x in (24, 32):                                      # 天线（画在上面空出来的 6 行里）
        c0.line(x, 6, x - 4 + (x - 24), 0, (120, 110, 100))
