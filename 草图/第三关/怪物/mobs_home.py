"""家里的几个场景：客厅、卧室、儿童房、书房、浴室、阁楼。写法照 mobs_kitchen_beach.py。

每个场景 4 只小怪（飞 / 跳 / 冲 / 射各一只）+ 1 只精英怪。怪都是那个屋里会有的老物件，红色指示灯当眼睛。
"""
from mobkit import mob, part, flat, shade, FLY, HOP, DASH, SHOOT, ELITE

CHROME = (176, 180, 190)
DARK = (70, 66, 74)
WOOD = (150, 100, 64)
BRASS = (206, 170, 92)
CREAM = (226, 218, 194)
GLASS = (54, 58, 74)


# ================================================================ 客厅（彩色）：蓝绿沙发、小电视、落地灯、紫灰墙
@mob("living", "rabbitears", FLY, 15, 12, "兔耳天线：两根拉杆天线当翅膀扑腾，扑向灯光，俯冲时底座先撞过来")
def rabbitears(c, f):
    base = (78, 64, 60)
    rod = (214, 214, 220)
    tips = [(2, 0), (12, 0)] if f.up else [(0, 4), (14, 4)]
    for tx, ty in tips:
        c.line(7, 7, tx, ty, rod)
        c.line(7 + (1 if tx > 7 else -1), 7, tx + (1 if tx > 7 else -1), ty + 1, shade(rod, -2))
        flat(c, c.rect(tx - (1 if tx > 7 else 0), ty, tx + (0 if tx > 7 else 1), ty), shade(rod, 2))
    part(c, c.ellipse(7.5, 9.5, 5, 3.2) & c.rect(0, 6, 14, 11), base)
    flat(c, c.rect(3, 11, 12, 11), shade(base, -2))
    flat(c, c.rect(9, 9, 11, 9), BRASS)                      # 调台旋钮
    f.led(c, 5, 9)


@mob("living", "dialphone", HOP, 14, 11, "转盘电话：铃一响听筒先跳起来，整台电话蹲一下，蹦过来砸你")
def dialphone(c, f):
    body = (214, 200, 160)
    lift = 2 if f.air else 0
    part(c, c.poly([(2, 5), (12, 5), (14, 11), (0, 11)]), body)
    flat(c, c.rect(4, 3, 4, 3), shade(body, -3)); flat(c, c.rect(9, 3, 9, 3), shade(body, -3))   # 叉簧
    part(c, c.rect(3, 0 - lift + 1, 10, 1 - lift + 1), shade(body, -2))        # 听筒：两头粗中间细
    part(c, c.rect(0, 1 - lift + 1, 3, 3 - lift + 1), shade(body, -2))
    part(c, c.rect(10, 1 - lift + 1, 13, 3 - lift + 1), shade(body, -2))
    part(c, c.ellipse(7, 7.5, 3.5, 2.6), (232, 230, 222))   # 转盘
    for x, y in ((5, 6), (7, 6), (9, 7), (5, 8), (9, 8)):
        c.put(x, y, shade(body, -3))
    flat(c, c.rect(1, 10, 13, 10), shade(body, -3))
    f.led(c, 7, 7)


@mob("living", "upright_vac", DASH, 14, 18, "老吸尘器：布袋鼓鼓的立式吸尘器，来回吸地，车头灯一闪就整台冲过来")
def vacuum(c, f):
    bag = (118, 134, 182)
    metal = (170, 172, 182)
    flat(c, c.rect(9, 0, 13, 1), DARK)                       # 把手
    c.line(11, 1, 9, 14, shade(metal, -2))                   # 杆子
    part(c, c.poly([(8, 2), (12, 2), (13, 11), (11, 13), (7, 13), (6, 5)]), bag)   # 布袋
    flat(c, c.rect(7, 7, 12, 7), shade(bag, -3))
    flat(c, c.rect(8, 2, 11, 2), shade(bag, 2))
    part(c, c.poly([(0, 18), (0, 15), (2, 14), (13, 14), (13, 18)]), metal)    # 吸头
    flat(c, c.rect(0, 17, 13, 17), shade(metal, -3))
    flat(c, c.rect(9 + f.step, 16, 11 + f.step, 17), DARK)           # 轮子
    f.led(c, 1, 15)


@mob("living", "gramophone", SHOOT, 14, 16, "留声机：慢慢挪，喇叭口转过来对准你，吹出一串音符（抛物线）")
def gramophone(c, f):
    horn = BRASS
    part(c, c.poly([(1, 0), (9, 6), (9, 8), (1, 10)]), horn, span=0.9)   # 喇叭
    part(c, c.ellipse(1.8, 5, 1.8, 5), shade(horn, 1))
    flat(c, c.ellipse(1.6, 5, 0.9, 3.2), shade(horn, -4))
    flat(c, c.rect(9, 7, 10, 9), shade(horn, -2))
    part(c, c.rect(3, 10, 13, 14), WOOD)                     # 木箱
    flat(c, c.rect(4, 9, 12, 9), (60, 54, 58))               # 唱片
    flat(c, c.rect(13, 11, 13, 13), shade(WOOD, -3))         # 摇把
    flat(c, c.rect(4, 15, 5, 15), shade(WOOD, -3)); flat(c, c.rect(11, 15, 12, 15), shade(WOOD, -3))
    f.led(c, 5, 12)
    f.muzzle(c, 0, 5)


@mob("living", "radiogram", ELITE, 44, 32, "落地收音电唱机：大木柜一掀盖，唱片转起来朝你抛音符；整台推过来撞；叫出转盘电话",
     moves=["volley", "charge", "summon"], elite_name="RADIOGRAM", title="NOW PLAYING", hp=950, bullet="note")
def radiogram(c, f):
    wood = (156, 104, 66)
    part(c, c.rect(1, 8, 42, 27), wood, bands=0.6)
    open_ = f.attack or f.pose
    if open_:                                                # 盖子掀开：唱片在转
        part(c, c.poly([(0, 6), (43, 6), (40, 0), (3, 0)]), shade(wood, 1))
        flat(c, c.rect(3, 6, 40, 7), (60, 52, 56))
        flat(c, c.rect(6, 5, 22, 6), (44, 40, 46)); flat(c, c.rect(12, 5, 15, 5), (230, 200, 120))
    else:
        part(c, c.rect(0, 5, 43, 8), shade(wood, 1))
    grille = (198, 172, 128)                                 # 喇叭布
    part(c, c.rect(4, 11, 20, 24), grille, bands=0.5)
    for x in range(6, 20, 3):
        flat(c, c.rect(x, 11, x, 24), shade(wood, -1))
    flat(c, c.rect(24, 11, 39, 16), (236, 206, 130))         # 调台刻度窗，亮着
    for x in range(25, 39, 2):
        flat(c, c.rect(x, 16, x, 16), (170, 120, 60))
    flat(c, c.rect(31, 11, 31, 16), DARK)                    # 指针
    for x in (27, 32, 37):
        part(c, c.ellipse(x + 0.5, 21.5, 1.6, 1.6), BRASS)
    flat(c, c.rect(1, 26, 42, 27), shade(wood, -3))
    for x0 in (4, 36):
        part(c, c.poly([(x0, 28), (x0 + 4, 28), (x0 + 3, 32), (x0 + 1, 32)]), shade(wood, -2))
    f.led(c, 35, 12, 2)


# ================================================================ 卧室（黑白）：床、黑衣柜、窗；墙是浅灰，怪要压得住
@mob("bedroom", "alarmclock", HOP, 13, 13, "双铃闹钟：铃锤一敲就蹦起来，朝你一跳一跳地吵过来")
def alarmclock(c, f):
    steel = (96, 102, 120)
    up = 1 if f.air else 0
    for cx in (2.5, 10.5):
        part(c, c.ellipse(cx, 2.5 - up, 2.5, 2.2) & c.rect(0, 0, 12, 3 - up), shade(steel, 1))
    flat(c, c.rect(6, 0, 6, 2), shade(steel, -2))             # 铃锤
    part(c, c.ellipse(6.5, 7.5, 6, 5.3), steel)
    flat(c, c.ellipse(6.5, 7.5, 4.3, 3.8), (236, 230, 212))  # 表盘
    for x, y in ((6, 4), (10, 7), (6, 10), (3, 7)):
        c.put(x, y, (150, 150, 160))
    c.line(6, 7, 6, 5, DARK); c.line(6, 7, 8, 8, DARK)
    flat(c, c.rect(1, 12, 3, 12), shade(steel, -3)); flat(c, c.rect(9, 12, 11, 12), shade(steel, -3))
    f.led(c, 6, 7)


@mob("bedroom", "tapemoth", FLY, 17, 11, "磁带蛾：抽出来的磁带当翅膀扑腾，扑向灯光，俯冲时收起带子撞过来")
def tapemoth(c, f):
    tape = (98, 66, 54)
    shell = (210, 206, 196)
    if f.up:
        wings = ([(6, 5), (0, 0), (5, 0), (8, 3)], [(10, 5), (17, 0), (12, 0), (9, 3)])
    else:
        wings = ([(5, 4), (0, 6), (1, 10), (5, 8)], [(12, 4), (17, 6), (16, 10), (12, 8)])
    for pts in wings:
        part(c, c.poly(pts), tape)
    for x, y in ((2, 1), (14, 1)) if f.up else ((2, 7), (14, 7)):
        c.put(x, y, shade(tape, 3))                          # 带子反光
    part(c, c.rect(4, 3, 12, 8), shell)
    flat(c, c.rect(5, 4, 11, 4), (226, 190, 110))            # 标签
    flat(c, c.rect(5, 5, 11, 7), (70, 66, 74))               # 窗
    flat(c, c.rect(6, 6, 6, 6), shell); flat(c, c.rect(10, 6, 10, 6), shell)
    f.led(c, 7, 6)


@mob("bedroom", "iron", DASH, 16, 10, "电熨斗：贴着地来回熨，指示灯一闪就冒着热气直直推过来")
def iron(c, f):
    shell = (128, 156, 186)
    part(c, c.poly([(1, 7), (5, 3), (14, 3), (14, 7)]), shell)
    part(c, c.rect(6, 0, 13, 1), shade(shell, -1))           # 把手
    flat(c, c.rect(7, 2, 7, 2), shade(shell, -2)); flat(c, c.rect(12, 2, 13, 2), shade(shell, -2))
    part(c, c.poly([(0, 9), (2, 7), (14, 7), (14, 9)]), CHROME)     # 底板
    flat(c, c.rect(1, 9, 14, 9), shade(CHROME, -3))
    flat(c, c.rect(15, 5 + f.step, 15, 6 + f.step), DARK)    # 电线
    f.led(c, 5, 5)


@mob("bedroom", "flashcam", SHOOT, 13, 14, "闪光灯相机：架在三脚架上慢慢挪，停下对焦，闪光一亮就是一枪（直线）")
def flashcam(c, f):
    body = (64, 62, 70)
    part(c, c.ellipse(9.5, 2.5, 3, 2.5) & c.rect(0, 0, 12, 2), CHROME)   # 闪光碗
    flat(c, c.rect(9, 1, 10, 1), (250, 246, 220))
    flat(c, c.rect(9, 3, 9, 4), shade(CHROME, -2))
    part(c, c.rect(2, 5, 12, 10), body)
    flat(c, c.rect(2, 5, 12, 5), CHROME)
    part(c, c.rect(0, 6, 2, 9), CHROME)                      # 镜头
    flat(c, c.rect(0, 7, 0, 8), GLASS)
    for x1 in (4, 7, 10):
        c.line(7, 11, x1, 13, shade(CHROME, -2))
    f.led(c, 10, 7)
    f.muzzle(c, 0, 7)


@mob("bedroom", "wardrobe", ELITE, 30, 44, "老衣柜：门缝里有只眼睛；跳起来砸地；门一开衣架扇形飞出来；叫出闹钟",
     moves=["slam", "spray", "summon"], elite_name="OLD WARDROBE", title="LIGHTS OUT", hp=1000, bullet="rivet")
def wardrobe(c, f):
    wood = (150, 116, 86)
    part(c, c.rect(2, 4, 27, 39), wood, bands=0.7)
    part(c, c.rect(0, 0, 29, 4), shade(wood, 1))            # 顶檐
    flat(c, c.rect(1, 4, 28, 4), shade(wood, -3))
    open_ = f.attack or f.pose
    if open_:                                                # 门开了：里面黑，挂着衣服
        flat(c, c.rect(5, 6, 24, 34), (40, 38, 46))
        flat(c, c.rect(5, 8, 24, 8), (120, 120, 130))
        for x, col in ((7, (150, 160, 190)), (13, (200, 196, 180)), (19, (120, 140, 120))):
            c.line(x + 2, 8, x + 2, 10, (150, 150, 160))
            part(c, c.poly([(x, 11), (x + 4, 11), (x + 5, 24), (x - 1, 24)]), col)
        part(c, c.rect(0, 6, 4, 34), shade(wood, -1)); part(c, c.rect(25, 6, 29, 34), shade(wood, -1))
    else:
        for x0 in (5, 16):                                   # 两扇门的嵌板
            flat(c, c.rect(x0, 7, x0 + 8, 20), shade(wood, -1))
            flat(c, c.rect(x0, 23, x0 + 8, 33), shade(wood, -1))
            flat(c, c.rect(x0, 7, x0 + 8, 7), shade(wood, 1))
            flat(c, c.rect(x0, 23, x0 + 8, 23), shade(wood, 1))
        flat(c, c.rect(14, 6, 15, 34), (36, 34, 42))         # 门缝
        flat(c, c.rect(12, 19, 12, 22), BRASS); flat(c, c.rect(17, 19, 17, 22), BRASS)
    part(c, c.rect(2, 35, 27, 39), shade(wood, -1))         # 抽屉
    flat(c, c.rect(13, 37, 16, 37), BRASS)
    part(c, c.rect(3, 40, 5, 43), shade(wood, -3)); part(c, c.rect(24, 40, 26, 43), shade(wood, -3))
    f.led(c, 14, 14, 2)


# ================================================================ 儿童房（绿荧光）：上下铺、玩具火箭、盆栽
@mob("kids", "tinchopper", FLY, 16, 11, "铁皮直升机：螺旋桨一转一转飞起来，扑向灯光，俯冲时机头先撞过来")
def tinchopper(c, f):
    tin = (226, 186, 72)
    if f.up:
        flat(c, c.rect(0, 0, 14, 0), (200, 204, 212))
    else:
        flat(c, c.rect(4, 1, 10, 1), (200, 204, 212)); flat(c, c.rect(3, 0, 3, 0), (200, 204, 212)); flat(c, c.rect(11, 2, 11, 2), (200, 204, 212))
    flat(c, c.rect(7, 1, 7, 3), DARK)
    part(c, c.rect(10, 5, 14, 6), shade(tin, -1))           # 尾杆
    part(c, c.rect(14, 3, 15, 6), shade(tin, -1))
    part(c, c.ellipse(6.5, 6.5, 5, 3.5), tin)
    flat(c, c.ellipse(4.5, 5.5, 2.2, 1.6), (120, 170, 200))  # 舷窗
    flat(c, c.rect(2, 10, 10, 10), DARK)                     # 起落架
    flat(c, c.rect(4, 9, 4, 9), DARK); flat(c, c.rect(8, 9, 8, 9), DARK)
    f.led(c, 4, 5)


@mob("kids", "jackbox", HOP, 12, 17, "八音盒小丑：弹簧小丑缩回盒子里蹲一下，然后整盒连人一起弹过来")
def jackbox(c, f):
    box = (88, 120, 196)
    for i, y in enumerate(range(6, 10)):                     # 弹簧
        flat(c, c.rect(4 + (i % 2) * 2, y, 5 + (i % 2) * 2, y), (190, 194, 204))
    part(c, c.ellipse(5.5, 4.5, 3.2, 2.8), CREAM)            # 小丑头
    part(c, c.poly([(2, 3), (9, 3), (6, -1), (5, -1)]), shade(box, 2))   # 尖帽
    flat(c, c.rect(5, 0, 6, 0), (240, 236, 220))
    flat(c, c.rect(3, 6, 8, 6), shade(CREAM, -2))
    part(c, c.rect(1, 10, 10, 16), box)
    part(c, c.rect(0, 9 if not f.air else 8, 11, 10 if not f.air else 9), shade(box, 1))   # 盒盖边
    flat(c, c.rect(4, 12, 5, 13), (230, 210, 120)); flat(c, c.rect(8, 14, 8, 14), (230, 210, 120))   # 星星
    flat(c, c.rect(11, 12, 11, 13), (190, 194, 204))         # 摇把
    f.led(c, 4, 4)


@mob("kids", "tincar", DASH, 16, 10, "发条小汽车：背上的钥匙一圈圈转，来回开，车灯一闪就全速撞过来")
def tincar(c, f):
    tin = (220, 146, 70)
    if f.step:                                               # 发条钥匙转着
        flat(c, c.rect(12, 0, 14, 0), CHROME)
    else:
        flat(c, c.rect(13, 0, 13, 0), CHROME); flat(c, c.rect(12, 1, 14, 1), CHROME)
    flat(c, c.rect(13, 1, 13, 2), shade(CHROME, -2))
    part(c, c.poly([(0, 8), (1, 5), (5, 5), (7, 3), (11, 3), (13, 5), (16, 5), (16, 8)]), tin)
    flat(c, c.rect(8, 4, 10, 5), (150, 196, 210))            # 车窗
    flat(c, c.rect(1, 7, 15, 7), shade(tin, -2))
    for x in (3.5, 12.5):
        part(c, c.ellipse(x, 8, 1.9, 1.9), DARK)
        c.put(int(x), 8, CHROME)
    f.led(c, 0, 6)


@mob("kids", "tinbot", SHOOT, 12, 16, "铁皮机器人：一步一顿地走，举起光线枪瞄准，砰一枪（直线）")
def tinbot(c, f):
    tin = (176, 182, 194)
    flat(c, c.rect(7, 0, 7, 1), shade(tin, -2)); c.put(7, 0, (240, 220, 120))   # 天线
    part(c, c.rect(4, 2, 10, 6), tin)
    flat(c, c.rect(4, 3, 8, 4), GLASS)                       # 面罩
    part(c, c.rect(3, 7, 11, 12), shade(tin, -1))
    flat(c, c.rect(6, 8, 9, 10), (230, 210, 120))            # 胸口的表盘
    c.put(7, 9, DARK)
    part(c, c.rect(1, 8, 4, 9), tin)                         # 举枪的手
    part(c, c.rect(0, 7, 2, 8), (120, 170, 200))             # 光线枪
    leg = 1 if f.step else 0
    flat(c, c.rect(4, 13, 5, 15 - leg), shade(tin, -3)); flat(c, c.rect(9, 13, 10, 15 - (1 - leg)), shade(tin, -3))
    flat(c, c.rect(3, 15, 5, 15), shade(tin, -3)); flat(c, c.rect(8, 15, 10, 15), shade(tin, -3))
    f.led(c, 5, 3)
    f.muzzle(c, 0, 7)


@mob("kids", "rockhorse", ELITE, 44, 34, "摇摇木马：前后一摇就冲过来；高高跳起砸地；叫出发条小汽车",
     moves=["charge", "slam", "summon"], elite_name="ROCKING HORSE", title="GIDDY UP", hp=900, bullet="rivet")
def rockhorse(c, f):
    paint = (226, 206, 168)
    mane = (120, 80, 56)
    rock = (156, 84, 62)
    yy = 0 if not f.pose else -2
    bot = [(x, 33 - 0.013 * (x - 22) ** 2) for x in range(0, 45, 2)]
    part(c, c.poly([(x, y - 3) for x, y in bot] + [(x, y + 0.6) for x, y in bot[::-1]]), rock)   # 弧形摇杆
    for x0, x1 in ((15, 10), (19, 17), (29, 29), (33, 36)):  # 四条腿
        part(c, c.poly([(x0, 18), (x0 + 3, 18), (x1 + 3, 30), (x1, 30)]), shade(paint, -1))
    part(c, c.ellipse(25, 15, 12, 6), paint)                 # 身子
    part(c, c.poly([(12, 16), (8, 6 + yy), (13, 3 + yy), (20, 11)]), paint)     # 脖子
    part(c, c.poly([(2, 9 + yy), (5, 4 + yy), (11, 2 + yy), (15, 5 + yy), (11, 10 + yy), (4, 12 + yy), (1, 11 + yy)]), paint)   # 头
    flat(c, c.rect(2, 11 + yy, 4, 11 + yy), shade(paint, -3))
    part(c, c.poly([(11, 0 + yy), (13, 0 + yy), (13, 3 + yy), (11, 3 + yy)]), mane)   # 耳朵
    part(c, c.poly([(13, 2 + yy), (16, 3 + yy), (21, 11), (18, 12)]), mane)        # 鬃毛
    part(c, c.poly([(36, 12), (39, 12), (43, 22), (40, 23)]), mane)                  # 尾巴
    for x, y in ((20, 14), (28, 18), (32, 13), (24, 18), (17, 17)):
        flat(c, c.rect(x, y, x + 1, y), shade(paint, -2))   # 木马身上的斑点
    saddle = (96, 136, 196)
    part(c, c.ellipse(26, 10.5, 5, 2) | c.rect(22, 10, 30, 15), saddle)
    flat(c, c.rect(25, 16, 26, 20), shade(saddle, -2))
    f.led(c, 7, 5 + yy, 2)


# ================================================================ 书房（琥珀）：书架、挂钟、落地灯、旧扶手椅
@mob("study", "ledger", FLY, 15, 10, "账本：硬皮旧书一开一合当翅膀，扑向灯光，俯冲时合上书砸下来")
def ledger(c, f):
    cover = (92, 56, 44)
    page = (232, 222, 196)
    if f.up:
        part(c, c.poly([(7, 8), (0, 1), (2, 0), (7, 6)]), cover); part(c, c.poly([(8, 8), (15, 1), (13, 0), (8, 6)]), cover)
        part(c, c.poly([(7, 6), (2, 1), (4, 1), (7, 4)]), page); part(c, c.poly([(8, 6), (13, 1), (11, 1), (8, 4)]), page)
    else:
        part(c, c.poly([(7, 7), (0, 6), (0, 9), (7, 9)]), cover); part(c, c.poly([(8, 7), (15, 6), (15, 9), (8, 9)]), cover)
        part(c, c.poly([(7, 7), (1, 6), (1, 5), (7, 5)]), page); part(c, c.poly([(8, 7), (14, 6), (14, 5), (8, 5)]), page)
    part(c, c.rect(6, 4, 8, 9), shade(cover, -1))            # 书脊
    flat(c, c.rect(6, 6, 8, 6), BRASS)
    f.led(c, 7, 8)


@mob("study", "globe", HOP, 12, 15, "地球仪：在支架上转着蹲一下，整个蹦过来砸你")
def globe(c, f):
    sea = (60, 96, 130)
    part(c, c.ellipse(6, 6, 5, 5), sea)
    for pts in ([(2, 3), (5, 2), (6, 5), (3, 7)], [(7, 6), (9, 5), (10, 8), (8, 10)]):
        flat(c, c.poly(pts), (206, 194, 132))
    ring = c.ellipse(6, 6, 6.2, 6.2) & ~c.ellipse(6, 6, 5.2, 5.2) & c.rect(6, 0, 12, 12)
    flat(c, ring, BRASS)
    flat(c, c.rect(5, 11, 6, 12), shade(BRASS, -2))
    part(c, c.rect(2, 13, 9, 14), WOOD)
    f.led(c, 3, 5)


@mob("study", "desklamp", DASH, 14, 16, "台灯：摇臂台灯拖着底座来回走，灯罩一亮就整个扑过来照你一下")
def desklamp(c, f):
    metal = (50, 82, 66)
    part(c, c.rect(6, 14, 13, 15), metal)                   # 底座
    for d in (0, 1):
        c.line(10 + d, 13, 11 + d, 7, shade(metal, 1))       # 下臂
        c.line(11, 7 + d, 5, 3 + d, shade(metal, 1))         # 上臂
    flat(c, c.rect(11, 6, 12, 7), BRASS)                     # 关节
    part(c, c.poly([(5, 1), (8, 4), (4, 9), (0, 9), (0, 6)]), metal)   # 灯罩
    flat(c, c.rect(1, 9, 3, 9), (250, 232, 170))             # 灯泡
    f.led(c, 4, 4)


@mob("study", "keyclacker", SHOOT, 16, 12, "老打字机：嗒嗒嗒往前挪，回车杆一拉，朝你射出铅字（直线）")
def keyclacker(c, f):
    body = (66, 64, 70)
    part(c, c.rect(5, 0, 11, 3), (236, 228, 204))           # 纸
    flat(c, c.rect(6, 1, 9, 1), (170, 160, 140))
    part(c, c.rect(2, 3, 14, 4), (90, 88, 96))               # 滚筒
    flat(c, c.rect(0, 3, 1, 4), CHROME); flat(c, c.rect(15, 3, 15, 4), CHROME)
    part(c, c.poly([(2, 5), (14, 5), (16, 11), (0, 11)]), body)
    for x in range(3, 14, 2):
        c.put(x, 7, (214, 210, 200))
    for x in range(2, 15, 2):
        c.put(x, 9, (214, 210, 200))
    flat(c, c.rect(1, 11, 15, 11), shade(body, -2))
    f.led(c, 4, 6)
    f.muzzle(c, 0, 4)


@mob("study", "grandclock", ELITE, 22, 46, "落地大座钟：钟摆一甩；跳起来砸地震出冲击波；掉下一把齿轮；叫出地球仪",
     moves=["slam", "volley", "summon"], elite_name="GRANDFATHER", title="TIME IS UP", hp=1000, bullet="ember")
def grandclock(c, f):
    wood = (96, 62, 46)
    part(c, c.poly([(1, 4), (5, 1), (11, 0), (17, 1), (21, 4)]), shade(wood, 1))   # 顶冠
    part(c, c.rect(0, 4, 21, 5), shade(wood, 1))
    part(c, c.rect(2, 6, 19, 18), wood)
    part(c, c.ellipse(11, 12, 6, 5.5), (236, 226, 196))      # 钟面
    for x, y in ((10, 7), (15, 11), (10, 16), (6, 11)):
        c.put(x, y, (120, 100, 80))
    c.line(10, 11, 10, 8, DARK); c.line(10, 11, 13, 13, DARK)
    part(c, c.rect(4, 19, 17, 36), wood, bands=0.7)
    flat(c, c.rect(6, 20, 15, 35), (170, 130, 70))           # 玻璃门的铜边
    flat(c, c.rect(7, 21, 14, 34), (36, 30, 34))             # 玻璃里的钟摆
    sw = [-2, 2, 0, 3, -3, 0][f.i]
    c.line(10, 21, 10 + sw, 29, BRASS); c.line(11, 21, 11 + sw, 29, BRASS)
    part(c, c.ellipse(10.5 + sw, 31, 2.5, 2.2), BRASS)
    part(c, c.rect(2, 37, 19, 43), shade(wood, -1))
    part(c, c.rect(1, 44, 20, 45), shade(wood, -2))
    f.led(c, 10, 11, 2)


# ================================================================ 浴室（黑白 / 彩色）：浴缸、洗手池、镜子、粉色浴帘
@mob("bathroom", "tproll", FLY, 15, 10, "卷纸：抽出来的纸当翅膀扑腾，扑向灯光，俯冲时卷成一团撞过来")
def tproll(c, f):
    paper = (236, 234, 228)
    if f.up:
        wings = ([(6, 4), (0, 0), (4, 0), (7, 2)], [(9, 4), (15, 0), (11, 0), (8, 2)])
        perf = ((2, 1), (13, 1))
    else:
        wings = ([(6, 5), (0, 5), (0, 9), (3, 9)], [(9, 5), (15, 5), (15, 9), (12, 9)])
        perf = ((1, 7), (2, 7), (13, 7), (14, 7))
    for pts in wings:
        part(c, c.poly(pts), shade(paper, -4))
    for x, y in perf:
        c.put(x, y, shade(paper, -8))                       # 撕纸的虚线
    part(c, c.rect(5, 2, 10, 8), paper)
    flat(c, c.rect(5, 8, 10, 8), shade(paper, -5))           # 卷筒底下的影子
    part(c, c.ellipse(5, 5, 2, 3), shade(paper, -3))         # 卷筒的端面
    flat(c, c.ellipse(5, 5, 1.2, 1.6), (150, 112, 78))      # 纸芯
    f.led(c, 4, 4)


@mob("bathroom", "plunger", HOP, 10, 16, "马桶搋子：橡胶碗一压蹲下去，啵一声弹过来扣你")
def plunger(c, f):
    rubber = (122, 92, 88)
    stick = (206, 160, 104)
    part(c, c.rect(4, 0, 5, 10), stick)
    flat(c, c.rect(3, 0, 6, 0), shade(stick, 1))
    part(c, c.poly([(1, 15), (2, 11), (4, 9), (6, 9), (8, 11), (9, 15)]), rubber)
    part(c, c.rect(0, 14, 9, 15), shade(rubber, -1))
    f.led(c, 3, 12)


@mob("bathroom", "razor", DASH, 16, 8, "电动剃须刀：嗡嗡地来回爬，刀头一亮就冲过来剃你一下")
def shaver(c, f):
    body = (140, 100, 88)
    part(c, c.ellipse(9.5, 3.5, 6, 3.5) | c.rect(4, 0, 12, 6), body)
    flat(c, c.rect(8, 1, 10, 1), CHROME)                     # 开关
    part(c, c.rect(0, 0, 3, 6), CHROME)                      # 刀头网罩
    for y in range(1, 6, 2):
        flat(c, c.rect(0, y, 2, y), shade(CHROME, -3))
    flat(c, c.rect(15, 5 + f.step, 15, 7), DARK)             # 电线尾巴
    flat(c, c.rect(5, 7, 6, 7), DARK); flat(c, c.rect(11, 7, 12, 7), DARK)
    f.led(c, 5, 2)


@mob("bathroom", "hairdryer", SHOOT, 15, 13, "电吹风：用手柄一顿一顿地走，喷口对准你吹出一发热风（直线）")
def hairdryer(c, f):
    body = (220, 168, 176)
    part(c, c.rect(2, 1, 11, 6) | c.ellipse(11, 3.5, 3.6, 3.5), body)
    part(c, c.rect(0, 2, 2, 5), shade(body, -2))             # 喷口
    flat(c, c.rect(0, 2, 0, 5), shade(body, -4))
    for x in (12, 14):
        flat(c, c.rect(x, 2, x, 5), shade(body, -3))         # 后面的进风格栅
    part(c, c.poly([(6, 6), (10, 6), (10, 12), (7, 12)]), shade(body, -1))   # 手柄
    flat(c, c.rect(6, 12, 10, 12), shade(body, -3))
    flat(c, c.rect(7, 8, 7, 9), CHROME)
    f.led(c, 5, 3)
    f.muzzle(c, 0, 3)


@mob("bathroom", "clawtub", ELITE, 46, 30, "爪脚浴缸：溢水口是眼睛；四只铜爪蹬着冲过来；跳起来砸出水浪；水龙头喷出一扇水珠",
     moves=["charge", "slam", "spray"], elite_name="CLAWFOOT TUB", title="BATH TIME", hp=1000, bullet="rivet")
def clawtub(c, f):
    enamel = (214, 220, 226)
    paint = (110, 140, 170)
    foam = (244, 244, 240)
    if f.attack or f.pose:                                   # 水溅出来
        for cx, cy, r in ((12, 7, 3), (20, 5, 4), (29, 6, 3.5), (37, 7, 3)):
            part(c, c.ellipse(cx, cy, r, r), foam)
    else:
        for cx, cy, r in ((14, 9, 2.5), (21, 8.5, 3), (28, 9, 2.5), (35, 9, 2)):
            part(c, c.ellipse(cx, cy, r, r), foam)
    part(c, c.poly([(3, 11), (44, 11), (42, 21), (37, 25), (9, 25), (5, 21)]), paint, bands=0.7)
    part(c, c.rect(2, 9, 45, 11), enamel)                    # 卷边
    part(c, c.rect(3, 2, 4, 8), CHROME)                      # 水龙头
    part(c, c.rect(3, 2, 9, 3), CHROME)
    flat(c, c.rect(9, 4, 9, 4), (180, 210, 230))
    flat(c, c.rect(1, 4, 6, 4), shade(CHROME, 1))
    part(c, c.ellipse(8, 15, 2.6, 2.6), CHROME)             # 溢水口
    for x0 in (8, 35):                                       # 铜爪脚
        part(c, c.poly([(x0, 24), (x0 + 4, 24), (x0 + 5, 29), (x0 - 1, 29)]), BRASS)
        flat(c, c.rect(x0 - 1, 29, x0 + 5, 29), shade(BRASS, -2))
        c.put(x0 + 1, 29, shade(BRASS, -4)); c.put(x0 + 3, 29, shade(BRASS, -4))
    f.led(c, 7, 14, 2)


# ================================================================ 阁楼（琥珀）：很暗，一道天窗光，纸箱，小木椅
@mob("attic", "filmreel", FLY, 17, 11, "胶片盘：甩出两条胶片当翅膀，扑向那道光，俯冲时把胶片收回去撞过来")
def filmreel(c, f):
    film = (110, 74, 50)
    if f.up:
        wings = ([(6, 5), (0, 0), (2, -1), (8, 3)], [(11, 5), (17, 0), (15, -1), (9, 3)])
    else:
        wings = ([(6, 5), (0, 7), (0, 10), (6, 8)], [(11, 5), (17, 7), (17, 10), (11, 8)])
    for pts in wings:
        part(c, c.poly(pts), film)
    for x, y in ((1, 1), (3, 2), (15, 1), (13, 2)) if f.up else ((1, 8), (3, 8), (15, 8), (13, 8)):
        c.put(x, y, (230, 210, 160))                        # 齿孔
    part(c, c.ellipse(8.5, 5.5, 4.6, 4.6), (190, 192, 200))
    for x, y in ((7, 2), (10, 4), (6, 6)):
        flat(c, c.rect(x, y, x + 1, y + 1), (60, 60, 72))    # 片盘上的三个大孔
    f.led(c, 8, 5)


@mob("attic", "cardbox", HOP, 14, 12, "旧纸箱：盖子缝里有只眼睛，往下一蹲，盖子一掀蹦过来")
def cardbox(c, f):
    card = (200, 154, 98)
    part(c, c.rect(1, 4, 12, 11), card)
    flat(c, c.rect(2, 4, 11, 5), (44, 34, 34))               # 盖子下的黑缝
    if f.air:
        part(c, c.poly([(1, 4), (6, 4), (2, 0), (0, 1)]), shade(card, 1))
        part(c, c.poly([(7, 4), (12, 4), (13, 1), (11, 0)]), shade(card, 1))
    else:
        part(c, c.poly([(0, 3), (6, 3), (6, 4), (0, 5)]), shade(card, 1))
        part(c, c.poly([(7, 2), (13, 3), (13, 4), (7, 4)]), shade(card, 1))
    flat(c, c.rect(6, 6, 7, 9), (226, 206, 150))              # 胶带
    flat(c, c.rect(1, 11, 12, 11), shade(card, -3))
    f.led(c, 4, 5)


@mob("attic", "oldchair", DASH, 12, 16, "小木椅：四条腿嗒嗒地来回走，椅面一亮就整把撞过来")
def oldchair(c, f):
    wood = (196, 150, 100)
    part(c, c.rect(9, 0, 10, 15), shade(wood, -1))          # 后腿连靠背
    part(c, c.rect(7, 0, 11, 1), wood)                       # 靠背横档
    flat(c, c.rect(9, 4, 10, 4), shade(wood, -3))
    part(c, c.rect(1, 8, 10, 9), wood)                       # 椅面
    s = f.step
    flat(c, c.rect(1 + s, 10, 2 + s, 15), shade(wood, -1))   # 前腿
    flat(c, c.rect(2, 12, 9, 12), shade(wood, -2))
    f.led(c, 2, 8)


@mob("attic", "projector", SHOOT, 16, 14, "电影放映机：两只片盘转着慢慢挪，镜头对准你，射出一束光（直线）")
def projector(c, f):
    metal = (160, 160, 170)
    for cx in (4.5, 11.5):
        part(c, c.ellipse(cx, 3.5, 3.5, 3.5), shade(metal, 1))
        x0 = int(cx)
        for dx, dy in ((-1, -2), (1, 0), (-2, 1)) if not f.step else ((0, -2), (0, 1), (-2, -1)):
            flat(c, c.rect(x0 + dx, 3 + dy, x0 + dx + 1, 3 + dy + 1), (60, 60, 72))   # 片盘上的孔，走路时转一格
    flat(c, c.rect(4, 7, 4, 7), DARK); flat(c, c.rect(11, 7, 11, 7), DARK)
    part(c, c.rect(2, 7, 14, 11), metal)
    part(c, c.rect(0, 8, 2, 10), (90, 90, 100))              # 镜头
    flat(c, c.rect(0, 9, 0, 9), (250, 240, 200))
    flat(c, c.rect(3, 12, 4, 13), DARK); flat(c, c.rect(12, 12, 13, 13), DARK)
    f.led(c, 6, 9)
    f.muzzle(c, 0, 9)


@mob("attic", "dustsheet", ELITE, 36, 44, "盖布的老电视：蒙着防尘布像个鬼，破洞里一只红眼；整个冲过来；抖出一把灰；叫出旧纸箱",
     moves=["charge", "volley", "summon"], elite_name="DUST SHEET", title="FORGET ME NOT", hp=950, bullet="ember")
def dustsheet(c, f):
    sheet = (196, 180, 150)
    c.line(14, 7, 9, 0, (150, 140, 120)); c.line(22, 7, 27, 0, (150, 140, 120))   # 戳出来的天线
    flare = 3 if (f.attack or f.pose) else 0
    hem = [(35 + flare, 43)]
    for x in range(35 + flare, -1 - flare, -4):              # 参差的下摆
        hem += [(x, 43), (x - 2, 40)]
    part(c, c.poly([(9, 6), (27, 6), (30, 10), (30, 24), (35 + flare, 42)] + hem[1:] + [(0 - flare, 42), (6, 24), (6, 10)]), sheet, bands=0.8)
    for pts in ([(11, 24), (13, 24), (10, 41), (7, 41)], [(23, 24), (25, 24), (28, 41), (25, 41)], [(17, 27), (19, 27), (19, 41), (17, 41)]):
        flat(c, c.poly(pts), shade(sheet, -3))               # 布的褶子：暗楔
    flat(c, c.rect(6, 24, 30, 25), shade(sheet, -2))         # 电视底边撑出来的棱
    flat(c, c.ellipse(15, 15, 4.5 + (1 if f.pose else 0), 3.5), (52, 56, 66))   # 破洞里的屏幕
    flat(c, c.rect(12, 13, 13, 13), (110, 116, 140))
    f.led(c, 15, 15, 2)
