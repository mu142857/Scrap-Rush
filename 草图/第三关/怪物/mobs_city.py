"""工作间、教室、地铁车厢、雨夜街道、黄昏屋顶的怪（写法照 mobs_kitchen_beach.py）。

屏幕的显示方式：workshop 琥珀、classroom 绿荧光、subway 黑白、rain_street 黑白、rooftop 琥珀。
单色屏只认亮度，所以每只怪先想好"在这块屏幕的背景前该偏亮还是偏暗"，红灯尽量放在深色的灯座里。
"""
from mobkit import mob, part, flat, shade, FLY, HOP, DASH, SHOOT, ELITE

DARK = (52, 50, 58)          # 红灯的灯座、缝、洞


def eye(c, f, x, y, size=1, sock=DARK):
    """红灯 + 一圈深色灯座：在琥珀、黑白屏上也能一眼看到。"""
    flat(c, c.rect(x - 1, y - 1, x + size, y + size), sock)
    f.led(c, x, y, size)


# ================================================================ 工作间（琥珀屏：上面洞洞板很亮，地面一带很暗 → 地上的怪偏亮）
STEEL = (176, 180, 192)
WOOD = (150, 108, 76)
TOOLRED = (196, 74, 64)


@mob("workshop", "bulb_moth", FLY, 15, 14, "灯泡蛾：吊灯上掉下来的灯泡，两片铁皮当翅膀，红灯丝一亮就扑向别的灯")
def bulb_moth(c, f):
    tin = (92, 94, 108)
    if f.up:
        wings = ([(6, 5), (0, 0), (2, 6)], [(9, 5), (15, 0), (13, 6)])
    else:
        wings = ([(6, 4), (0, 8), (3, 10)], [(9, 4), (15, 8), (12, 10)])
    for pts in wings:
        part(c, c.poly(pts), tin)
    part(c, c.ellipse(7.5, 4.5, 4, 4.5), (240, 224, 168), span=0.7)       # 玻璃泡
    flat(c, c.rect(6, 5, 6, 7), (150, 126, 96)); flat(c, c.rect(9, 5, 9, 7), (150, 126, 96))   # 灯丝支架
    f.led(c, 7, 4, 2)                                                        # 红灯丝
    for y in range(9, 12):                                                   # 螺口
        flat(c, c.rect(5, y, 10, y), (120, 116, 110) if y % 2 else (82, 80, 82))
    flat(c, c.rect(7, 12, 8, 13), DARK)


@mob("workshop", "bench_vise", HOP, 16, 12, "台钳：蹲下时钳口张开，整台跳过来一口夹住")
def bench_vise(c, f):
    open_ = 2 if f.i in (1, 2, 3) else 0
    part(c, c.rect(2, 10, 15, 11), shade(STEEL, -2))                        # 底座
    part(c, c.rect(4, 5, 13, 9), STEEL)
    part(c, c.rect(10, 1, 14, 6), STEEL)                                    # 后钳口（固定）
    part(c, c.rect(4 - open_, 1, 7 - open_, 6), STEEL)                      # 前钳口（会张开）
    for x0 in (4 - open_, 10):                                              # 钳口上的齿
        flat(c, c.rect(x0, 1, x0 + 3, 1), shade(STEEL, -4))
    if open_:
        flat(c, c.rect(8 - open_, 3, 9, 4), DARK)                           # 张开的嘴
    flat(c, c.rect(0, 6, 3, 6), shade(STEEL, -3))                           # 丝杠
    flat(c, c.rect(0, 3 + open_ // 2, 0, 9 - open_ // 2), WOOD)             # T 形把手
    eye(c, f, 11, 8)


@mob("workshop", "hand_saw", DASH, 19, 10, "手锯：锯齿当脚在地上蹭着走，看见人就来回拉两下，一亮就锯过去")
def hand_saw(c, f):
    blade = (184, 186, 196)
    part(c, c.poly([(0, 5), (13, 1), (13, 9), (0, 9)]), blade, span=0.8)
    flat(c, c.rect(1, 9, 13, 9), shade(blade, -4))
    for x in range(1 + f.step, 14, 2):                                      # 锯齿（走路时错一格）
        c.put(x, 9, shade(blade, -1))
    part(c, c.poly([(12, 0), (18, 0), (18, 9), (12, 9), (13, 5)]), WOOD)  # 木把手
    flat(c, c.rect(14, 3, 16, 6), DARK)                                     # 握手的洞
    f.led(c, 15, 4)
    flat(c, c.rect(12, 2, 12, 2), (200, 200, 206)); flat(c, c.rect(12, 7, 12, 7), (200, 200, 206))  # 铆钉


@mob("workshop", "nail_gun", SHOOT, 15, 14, "钉枪：拖着气管慢慢挪，停下来对准你，咔一声打出一颗钉子（直线）",
     bullet="rivet")
def nail_gun(c, f):
    body = (226, 190, 92)                                                   # 黄色机身
    part(c, c.poly([(3, 1), (13, 1), (14, 4), (13, 7), (3, 7)]), body)      # 机身
    part(c, c.rect(0, 3, 3, 6), STEEL)                                      # 枪嘴
    flat(c, c.rect(0, 4, 0, 5), DARK)
    part(c, c.rect(4, 8, 8, 9), STEEL)                                      # 钉匣
    for x in (5, 7):
        c.put(x, 9, shade(STEEL, -4))
    part(c, c.rect(10, 8, 12, 11), body)                                    # 握把
    c.line(13, 10, 14, 13, shade(body, -5))                                 # 气管
    flat(c, c.rect(4, 10, 5, 13), shade(STEEL, -3)); flat(c, c.rect(9, 12, 10, 13), shade(STEEL, -3))
    eye(c, f, 6, 4)
    f.muzzle(c, 0, 4)


@mob("workshop", "tool_chest", ELITE, 34, 42, "红工具柜：抽屉一拉，螺丝钉扇形喷出来；整台蹦起来砸地；拉开下层抽屉放出台钳",
     moves=["spray", "slam", "summon"], elite_name="TOOL CHEST", title="SOME ASSEMBLY REQUIRED", hp=950, bullet="rivet")
def tool_chest(c, f):
    part(c, c.rect(2, 8, 31, 37), TOOLRED, bands=0.6)
    part(c, c.poly([(1, 8), (4, 2), (29, 2), (32, 8)]), shade(TOOLRED, 1))   # 顶盖
    part(c, c.rect(11, 0, 22, 1), (70, 70, 80))                             # 提手
    flat(c, c.rect(1, 8, 32, 8), shade(TOOLRED, -3))
    rows = [(10, 15), (17, 22), (24, 29), (31, 36)]
    for i, (y0, y1) in enumerate(rows):
        flat(c, c.rect(3, y1 + 1, 30, y1 + 1), shade(TOOLRED, -4))         # 抽屉缝
        flat(c, c.rect(8, y0 + 1, 25, y0 + 1), (200, 200, 208))           # 抽屉拉手
    if f.attack or f.pose:                                                  # 第一层抽屉拉出来：一把螺丝刀和扳手探出头
        part(c, c.rect(0, 10, 12, 15), shade(TOOLRED, -1))
        flat(c, c.rect(1, 10, 11, 11), DARK)
        flat(c, c.rect(2, 7, 3, 10), (200, 200, 208)); flat(c, c.rect(6, 6, 9, 9), (176, 178, 186))
        flat(c, c.rect(7, 7, 8, 8), DARK)
    if f.pose:
        part(c, c.rect(0, 31, 14, 36), shade(TOOLRED, -1))                  # 最下层也拉开
        flat(c, c.rect(1, 31, 13, 32), DARK)
    flat(c, c.rect(25, 3, 28, 6), (230, 200, 120))                          # 贴纸
    for x in (3, 27):                                                       # 轮子
        part(c, c.rect(x, 38, x + 3, 41), (60, 60, 68))
    eye(c, f, 26, 12, 2)                                                    # 锁眼里的红灯


# ================================================================ 教室（绿荧光屏，墙很亮 → 怪偏暗）
CHALK = (226, 232, 220)
BOARD = (30, 52, 42)
DESKWOOD = (216, 172, 130)    # 浅色木头：绿屏上墙裙是中间亮度，课桌要更亮才跳出来


@mob("classroom", "alarm_clock", FLY, 15, 15, "双铃闹钟：两个铃铛当翅膀扑腾，叮铃铃冲向亮的地方，俯冲时整个砸下来")
def alarm_clock(c, f):
    case = (78, 90, 100)
    if f.up:
        bells = [(2.5, 2.5), (12.5, 2.5)]
    else:
        bells = [(3.5, 4.5), (11.5, 4.5)]
    c.line(7, 0, 7, 3, (120, 126, 134))                                      # 敲锤
    for bx, by in bells:
        part(c, c.ellipse(bx, by, 2.6, 2.4), shade(case, 2))
    part(c, c.ellipse(7.5, 8.5, 6, 6), case)
    part(c, c.ellipse(7.5, 8.5, 4.2, 4.2), (226, 226, 210), span=0.6)       # 表盘
    flat(c, c.rect(7, 5, 7, 8), (40, 44, 52))                               # 分针
    flat(c, c.rect(8, 8, 9, 8), (40, 44, 52))                               # 时针
    f.led(c, 7, 8)                                                          # 指针中间的红灯
    flat(c, c.rect(3, 14, 4, 14), (60, 66, 74)); flat(c, c.rect(10, 14, 11, 14), (60, 66, 74))


@mob("classroom", "flip_desk", HOP, 16, 14, "翻盖课桌：蹲下时桌盖一掀露出一排白牙（作业本），跳过来咬")
def flip_desk(c, f):
    open_ = f.i in (1, 2, 3)
    part(c, c.rect(1, 6, 14, 9), shade(DESKWOOD, -1))                      # 桌肚
    part(c, c.rect(0, 4, 4, 5), DESKWOOD)                                   # 前面固定的一条（放墨水瓶）
    part(c, c.rect(1, 1, 3, 3), (60, 66, 80))                               # 墨水瓶
    f.led(c, 2, 2)
    if open_:
        flat(c, c.rect(5, 4, 14, 5), DARK)                                  # 张开的嘴
        for x in range(6, 14, 2):
            c.put(x, 4, (236, 236, 226))                                    # 本子当牙
        lid = c.line(5, 3, 14, -1) | c.line(5, 2, 14, -2) | c.line(6, 3, 15, -1)
        part(c, lid, DESKWOOD)                                              # 掀起来的盖子
    else:
        part(c, c.rect(5, 3, 15, 5), DESKWOOD)                              # 桌盖（略微斜）
        flat(c, c.rect(5, 5, 15, 5), shade(DESKWOOD, -3))
    iron = (66, 70, 80)
    flat(c, c.rect(2, 10, 3, 13), iron); flat(c, c.rect(12, 10, 13, 13), iron)   # 铸铁桌腿
    flat(c, c.rect(3, 11, 12, 11), iron)


@mob("classroom", "board_eraser", DASH, 16, 9, "黑板擦：贴着地来回蹭，留下一串粉笔灰；一亮就滑过来拍你一下")
def board_eraser(c, f):
    part(c, c.poly([(1, 2), (3, 0), (13, 0), (15, 2), (15, 4), (1, 4)]), (110, 76, 60))   # 木背
    flat(c, c.rect(4, 1, 12, 1), (150, 108, 84))
    part(c, c.rect(0, 5, 15, 7), (64, 70, 74))                              # 毛毡
    for x in range(1 + f.step, 16, 3):                                      # 底下的粉笔灰
        c.put(x, 8, CHALK)
    c.put(0, 8, CHALK)
    eye(c, f, 4, 3)


@mob("classroom", "film_projector", SHOOT, 16, 15, "电影放映机：头上两盘胶片转着，停下来对准你，镜头射出一道光（直线）",
     bullet="rivet")
def film_projector(c, f):
    body = (72, 78, 90)
    for cx in (5, 11):                                                      # 两盘胶片：中间轴 + 三个孔
        part(c, c.ellipse(cx + 0.5, 3, 3, 3), (170, 176, 184))
        c.put(cx, 3, (226, 228, 232))
        for dx, dy in ((-1, 2), (1, 4)):                                    # 两个斜对角的孔，看着像在转
            c.put(cx + dx, dy, DARK)
    flat(c, c.rect(5, 5, 11, 5), (150, 156, 164))
    part(c, c.rect(3, 6, 15, 11), body)
    part(c, c.rect(0, 7, 3, 10), shade(body, 1))                            # 镜头筒
    flat(c, c.rect(0, 8, 0, 9), (230, 232, 220))                            # 镜片
    flat(c, c.rect(5, 8, 7, 8), shade(body, -3))                            # 散热缝
    eye(c, f, 12, 8)
    for x in (4, 13):
        flat(c, c.rect(x, 12, x + 1, 14), (56, 60, 70))
    f.muzzle(c, 0, 8)


@mob("classroom", "chalkboard", ELITE, 44, 38, "活动黑板：板上画的粉笔脸会说话；抛粉笔头、跳起来砸地、叫出黑板擦",
     moves=["volley", "slam", "summon"], elite_name="CHALKBOARD", title="PAY ATTENTION", hp=900, bullet="ember")
def chalkboard(c, f):
    frame = (112, 82, 66)                                                   # 深色框：整块黑板压在亮墙上
    part(c, c.rect(0, 0, 43, 27), frame, bands=0.5)
    flat(c, c.rect(2, 2, 41, 25), BOARD)
    flat(c, c.rect(2, 2, 41, 2), shade(BOARD, 2))
    # 粉笔画的脸：一只圈眼睛 + 一只红灯眼睛
    for (x0, y0) in ((9, 7), (23, 7)):
        c.polyline([(x0, y0), (x0 + 5, y0), (x0 + 5, y0 + 5), (x0, y0 + 5), (x0, y0)], CHALK)
    f.led(c, 25, 9, 2)
    if f.attack or f.pose:                                                  # 张大嘴
        c.polyline([(12, 16), (28, 16), (26, 22), (14, 22), (12, 16)], CHALK)
        flat(c, c.rect(14, 17, 26, 21), shade(BOARD, -2))
    else:
        c.line(13, 18, 27, 18, CHALK)
        c.line(27, 18, 29, 16, CHALK)
    c.polyline([(33, 6), (33, 11), (35, 8), (37, 11), (37, 6)], CHALK)     # 角落里的字
    flat(c, c.rect(1, 27, 42, 28), shade(frame, -1))                        # 粉笔槽
    flat(c, c.rect(6, 26, 9, 26), CHALK); flat(c, c.rect(30, 25, 35, 26), (110, 76, 60))
    for x0, x1 in ((6, 3), (37, 40)):                                       # A 字架
        c.line(x0, 29, x1, 35, shade(frame, -3)); c.line(x0 + 1, 29, x1 + 1, 35, shade(frame, -3))
    flat(c, c.rect(4, 32, 39, 32), shade(frame, -3))
    for x in (2, 38):
        part(c, c.rect(x, 36, x + 3, 37), (56, 56, 64))                     # 轮子


# ================================================================ 地铁车厢（黑白屏，背后是深色长椅 → 怪偏亮）
PLASTIC = (214, 210, 200)
SILVER = (196, 198, 206)


@mob("subway", "strap_bat", FLY, 15, 15, "吊环蝙蝠：车顶的拉手挣脱了，皮带当翅膀扑腾，绕着亮处转两圈再撞过来")
def strap_bat(c, f):
    strap = (176, 172, 166)
    if f.up:
        wings = ([(6, 3), (0, 0), (1, 5), (3, 4)], [(8, 3), (14, 0), (13, 5), (11, 4)])
    else:
        wings = ([(6, 3), (0, 5), (1, 9), (3, 6)], [(8, 3), (14, 5), (13, 9), (11, 6)])
    for pts in wings:
        part(c, c.poly(pts), shade(strap, -1))
    part(c, c.rect(6, 0, 8, 7), strap)                                      # 皮带
    eye(c, f, 7, 4)                                                         # 扣子上的红灯
    ring = c.ellipse(7.5, 11, 4.5, 4) & ~c.ellipse(7.5, 11.5, 2.5, 2)
    part(c, ring, PLASTIC)                                                  # 塑料拉环


@mob("subway", "walkman", HOP, 12, 15, "随身听：戴着耳机一蹲一蹦地追过来，肚子里的磁带一直在转")
def walkman(c, f):
    lift = 1 if f.air else 0
    band = (90, 90, 100)
    c.line(1, 1 - lift, 10, 1 - lift, band)                                 # 头戴耳机
    c.put(1, 2 - lift, band); c.put(10, 2 - lift, band)
    for x in (0, 10):
        part(c, c.rect(x, 3 - lift, x + 1, 6 - lift), (120, 120, 132))      # 耳罩
    part(c, c.rect(2, 3, 9, 13), SILVER)                                    # 机身
    flat(c, c.rect(3, 5, 8, 8), DARK)                                       # 磁带窗
    flat(c, c.rect(4, 6, 4, 7), (220, 220, 226)); flat(c, c.rect(7, 6, 7, 7), (220, 220, 226))
    for x in (3, 5, 7):
        flat(c, c.rect(x, 10, x, 10), shade(SILVER, -3))                    # 按键
    f.led(c, 8, 11)                                                         # 播放灯
    flat(c, c.rect(3, 14, 4, 14), band); flat(c, c.rect(7, 14, 8, 14), band)


@mob("subway", "subway_rat", DASH, 17, 10, "地铁老鼠：尾巴是一根插头线；在长椅底下窜来窜去，眼一亮就冲过来咬一口")
def subway_rat(c, f):
    fur = (176, 172, 172)
    part(c, c.ellipse(8.5, 6, 6.5, 3.6), fur)
    part(c, c.poly([(0, 6), (4, 3), (6, 7)]), fur)                          # 尖鼻子
    part(c, c.ellipse(5, 2.5, 1.6, 1.6), shade(fur, 1))                     # 耳朵
    c.put(0, 6, (60, 56, 60))
    eye(c, f, 3, 5)
    cord = (60, 60, 70)
    c.line(15, 6, 16, 4, cord); c.line(16, 4, 15, 2, cord)                  # 电线尾巴 + 插头
    flat(c, c.rect(13, 0, 15, 1), (210, 210, 214))
    for i, x in enumerate((4, 7, 10, 13)):
        flat(c, c.rect(x, 9 - (i + f.step) % 2, x, 9), shade(fur, -3))


@mob("subway", "farebox", SHOOT, 12, 18, "投币箱：玻璃罩里堆满地铁代币，停下来瞄准，从投币口把代币弹出来（直线）",
     bullet="rivet")
def farebox(c, f):
    part(c, c.ellipse(6, 3.5, 4.5, 3.5) & c.rect(0, 0, 11, 5), (226, 228, 232), span=0.6)   # 玻璃罩
    for x, y in ((4, 4), (6, 3), (8, 4), (5, 5), (7, 5)):
        c.put(x, y, (150, 150, 160))                                        # 罩里的代币
    part(c, c.rect(1, 6, 10, 15), SILVER)
    flat(c, c.rect(0, 8, 1, 9), DARK)                                       # 投币口（朝前）
    flat(c, c.rect(4, 12, 7, 12), shade(SILVER, -3))
    eye(c, f, 8, 9)
    part(c, c.rect(0, 16, 11, 17), (100, 100, 110))
    f.muzzle(c, 0, 8)


@mob("subway", "last_train", ELITE, 48, 34, "末班车：车头大灯一开就整列冲过来；车顶火花扇形溅开；车门一开跑出老鼠",
     moves=["charge", "spray", "summon"], elite_name="LAST TRAIN", title="MIND THE GAP", hp=1000, bullet="rivet")
def last_train(c, f):
    body = (210, 208, 202)
    part(c, c.poly([(6, 2), (47, 2), (47, 28), (0, 28), (0, 10)]), body, bands=0.6)   # 车身，车头朝左斜
    flat(c, c.rect(6, 1, 47, 1), shade(body, 1))
    flat(c, c.rect(8, 4, 20, 6), DARK)                                      # 线路牌
    for x in range(9, 20, 3):
        flat(c, c.rect(x, 5, x + 1, 5), (236, 236, 230))
    flat(c, c.poly([(4, 10), (8, 8), (12, 8), (12, 16), (2, 16)]), (40, 44, 54))   # 司机窗
    for wx in (17, 32):                                                     # 车窗
        flat(c, c.rect(wx, 9, wx + 10, 16), (40, 44, 54))
        flat(c, c.rect(wx + 1, 10, wx + 3, 10), (120, 124, 136))
    door_open = f.pose
    flat(c, c.rect(28, 9, 30, 26), DARK if door_open else shade(body, -3))  # 车门缝 / 开着的门
    flat(c, c.rect(0, 19, 47, 20), (130, 132, 140))                         # 腰线
    lamp = (255, 246, 210) if (f.attack or f.windup) else (232, 228, 200)
    flat(c, c.rect(0, 22, 3, 24), lamp)                                     # 大灯
    eye(c, f, 5, 23, 2)                                                     # 红色标志灯
    for x in (8, 36):                                                       # 转向架和轮子
        part(c, c.rect(x - 2, 29, x + 9, 30), (70, 70, 80))
        for wx in (x, x + 6):
            part(c, c.ellipse(wx + 1, 32, 2, 2), (54, 54, 62))


# ================================================================ 雨夜街道（黑白屏：地面一带背后是中灰的楼和亮窗 → 怪大多做成黑的）
IRON = (64, 66, 80)
WET = (190, 192, 204)


@mob("rain_street", "rain_umbrella", FLY, 15, 14, "破雨伞：伞面一开一合往路灯扑，伞面破洞里亮着红灯；俯冲时收拢像根矛")
def rain_umbrella(c, f):
    cloth = (66, 66, 80)                                                    # 黑伞
    if f.up:                                                                # 合起来一半
        part(c, c.poly([(7, 0), (12, 7), (3, 7)]), cloth)
        rib = [3, 7, 11]
    else:
        part(c, c.ellipse(7.5, 6, 7.5, 6) & c.rect(0, 0, 14, 6), cloth)
        rib = [0, 4, 7, 11, 14]
        for x in (2, 12):
            c.put(x, 6, shade(cloth, -3))                                   # 伞边一垂一垂
    for x in rib:
        c.put(x, 7, (176, 178, 190))                                        # 伞骨尖
    c.put(7, 0, (176, 178, 190))
    eye(c, f, 6, 4, sock=(30, 30, 40))                                      # 破洞里的红灯
    c.line(7, 8, 7, 12, (176, 178, 190))                                    # 伞柄（亮的弯钩）
    c.put(8, 13, (176, 178, 190)); c.put(9, 12, (176, 178, 190))


@mob("rain_street", "parking_meter", HOP, 11, 19, "停车咪表：玻璃窗里的过期红旗就是它的眼睛，一蹲一蹦追着你收钱")
def parking_meter(c, f):
    head = (200, 202, 210)
    part(c, c.poly([(0, 2), (2, 0), (8, 0), (10, 2), (10, 9), (0, 9)]), head)
    flat(c, c.rect(2, 2, 8, 5), (40, 42, 52))                               # 玻璃窗
    c.line(3, 5, 6, 3, (170, 170, 180))                                     # 指针
    f.led(c, 6, 3, 2)                                                       # 过期红旗
    flat(c, c.rect(4, 7, 6, 7), shade(head, -3))                            # 投币口
    part(c, c.rect(4, 10, 6, 17), IRON)                                     # 铸铁杆子
    part(c, c.rect(2, 18, 8, 18), IRON)


@mob("rain_street", "wind_cat", DASH, 17, 12, "发条野猫：背上插着发条钥匙，独眼红灯；在路灯下来回踱步，一亮就扑过来挠一下")
def wind_cat(c, f):
    fur = (58, 58, 70)                                                      # 黑猫
    part(c, c.ellipse(9.5, 7.5, 6, 3), fur)                                 # 身子
    part(c, c.ellipse(3.5, 5, 3.4, 3), fur)                                 # 头
    flat(c, c.poly([(1, 3), (1, 0), (3, 2)]), shade(fur, 1))                # 耳朵
    flat(c, c.poly([(4, 2), (6, 0), (6, 3)]), shade(fur, 1))
    f.led(c, 2, 5)
    c.put(4, 5, shade(fur, 3))                                              # 另一只眼闭着
    c.line(15, 6, 16, 3, fur); c.put(16, 2, fur)                            # 尾巴
    key = (210, 200, 170)                                                   # 发条钥匙（亮的）
    flat(c, c.rect(9, 3, 9, 4), key); flat(c, c.rect(7 + f.step, 1, 11 - f.step, 2), key)
    for i, x in enumerate((5, 7, 12, 14)):
        flat(c, c.rect(x, 11 - (i + f.step) % 2, x, 11), shade(fur, -1))


@mob("rain_street", "payphone", SHOOT, 13, 18, "投币电话：挪到你面前停下，铃一响，音符从听筒里抛过来（抛物线）",
     bullet="note")
def payphone(c, f):
    box = (196, 198, 206)
    part(c, c.rect(0, 0, 12, 2) | c.rect(2, 3, 11, 13), box)                # 小雨棚 + 机身
    flat(c, c.rect(1, 2, 11, 2), shade(box, -3))
    flat(c, c.rect(0, 4, 1, 10), (70, 72, 84))                              # 挂在侧面的听筒
    for y in (6, 8, 10):                                                    # 拨号键
        for x in (6, 8, 10):
            c.put(x, y, shade(box, -4))
    flat(c, c.rect(3, 12, 5, 12), DARK)                                     # 退币口
    eye(c, f, 4, 5)
    c.line(2, 11, 3, 14, (70, 72, 84))                                      # 电话线
    flat(c, c.rect(5, 14, 8, 16), (70, 72, 84))
    flat(c, c.rect(3, 17, 10, 17), (70, 72, 84))
    f.muzzle(c, 0, 5)


@mob("rain_street", "street_lamp", ELITE, 28, 46, "老路灯：灯罩下的红灯盯着你；甩出一扇雨点、跳起来砸出水花、照出一窝发条猫",
     moves=["spray", "slam", "summon"], elite_name="STREETLIGHT", title="NO LOITERING", hp=950, bullet="rivet")
def street_lamp(c, f):
    pole = (74, 76, 92)                                                     # 铸铁，比背后的楼暗
    part(c, c.rect(18, 8, 21, 40), pole, bands=0.5)                         # 灯杆
    part(c, c.rect(8, 4, 21, 7), pole)                                      # 弯过来的横臂
    part(c, c.poly([(0, 10), (4, 4), (14, 4), (18, 10)]), shade(pole, 1))   # 灯罩
    bright = f.attack or f.windup or f.pose
    flat(c, c.rect(3, 10, 15, 11), (255, 250, 220) if bright else (236, 232, 200))   # 灯泡
    if bright:
        for x in range(2, 17, 3):                                           # 光一束束往下
            c.line(x, 13, x - 1, 17, (236, 232, 200))
    eye(c, f, 8, 7, 2, sock=(30, 30, 40))
    for y in (16, 28):
        flat(c, c.rect(17, y, 22, y), shade(pole, 2))                       # 杆上的箍
    part(c, c.rect(15, 41, 24, 43), shade(pole, -1))                        # 底座
    part(c, c.rect(13, 44, 16, 45), shade(pole, -2)); part(c, c.rect(23, 44, 26, 45), shade(pole, -2))


# ================================================================ 黄昏屋顶（琥珀屏，背后是楼和屋顶 → 怪偏亮）
@mob("rooftop", "laundry_shirt", FLY, 16, 14, "飞走的衬衫：晾衣夹还夹在领口，袖子当翅膀扇，第一颗扣子是红灯")
def laundry_shirt(c, f):
    cloth = (236, 232, 220)
    stripe = (180, 150, 130)
    if f.up:
        sleeves = ([(4, 3), (0, 0), (0, 3), (4, 6)], [(11, 3), (15, 0), (15, 3), (11, 6)])
    else:
        sleeves = ([(4, 3), (0, 7), (2, 9), (4, 7)], [(11, 3), (15, 7), (13, 9), (11, 7)])
    for pts in sleeves:
        part(c, c.poly(pts), shade(cloth, -1))
    part(c, c.poly([(4, 2), (6, 2), (8, 4), (10, 2), (12, 2), (12, 13), (3, 13)]), cloth)
    for x in (5, 10):
        flat(c, c.rect(x, 5, x, 12), stripe)                                # 竖条纹
    flat(c, c.rect(3, 13, 12, 13), shade(cloth, -2))
    part(c, c.rect(7, 0, 8, 3), (150, 108, 76))                             # 晾衣夹
    eye(c, f, 8, 5, sock=(110, 90, 80))
    c.put(8, 8, stripe); c.put(8, 11, stripe)                               # 其他扣子


@mob("rooftop", "homing_pigeon", HOP, 14, 12, "信鸽：腿上绑着铜信筒，蹲一下扑腾两步跳过来啄你")
def homing_pigeon(c, f):
    gray = (190, 186, 198)
    part(c, c.ellipse(8, 6.5, 5.5, 4), gray)                                # 身子
    part(c, c.poly([(9, 4), (14, 5), (13, 8), (8, 8)]), shade(gray, -2))    # 翅膀和尾巴
    part(c, c.ellipse(3.5, 3.5, 2.6, 2.6), shade(gray, 1))                  # 头
    flat(c, c.rect(0, 3, 0, 3), (130, 110, 90))                             # 嘴
    eye(c, f, 2, 2, sock=(110, 108, 120))
    flat(c, c.rect(4, 6, 6, 7), (150, 160, 170))                            # 脖子的亮羽
    flat(c, c.rect(9, 9, 11, 10), (200, 150, 90))                           # 铜信筒
    flat(c, c.rect(6, 10, 6, 11), (150, 100, 90)); flat(c, c.rect(8, 10, 8, 11), (150, 100, 90))
    flat(c, c.rect(5, 11, 6, 11), (150, 100, 90))


@mob("rooftop", "yagi_bug", DASH, 19, 12, "天线虫：屋顶的八木天线成了精，横杆当腿来回爬；一闪就冲过来刮一下")
def yagi_bug(c, f):
    alu = (196, 196, 206)
    part(c, c.rect(2, 4, 18, 5), alu)                                       # 主杆
    for i, (x, half) in enumerate(((5, 4), (9, 4), (13, 3), (17, 2))):      # 横杆：上半是天线，下半是腿
        flat(c, c.rect(x, 4 - half, x, 4), shade(alu, 1))
        dx = (-1 if (i + f.step) % 2 else 0)
        c.line(x, 6, x + dx, 11, shade(alu, -2))
    part(c, c.rect(0, 2, 3, 6), (110, 104, 112))                            # 接线盒（头）
    f.led(c, 1, 3)
    c.line(3, 7, 5, 9, (90, 84, 92))                                        # 垂下来的馈线


@mob("rooftop", "roof_dish", SHOOT, 15, 16, "锅盖天线：慢慢挪，锅盖对准你，从馈源射出一道信号（直线）",
     bullet="rivet")
def roof_dish(c, f):
    dish = (226, 222, 214)
    back = c.ellipse(10.5, 7, 3.5, 7)
    part(c, back, shade(dish, -3))                                          # 锅背
    part(c, c.ellipse(9.5, 7, 2.6, 6.4), dish, span=0.7)                     # 锅面（朝左）
    c.line(2, 7, 8, 2, shade(dish, -2)); c.line(2, 7, 8, 12, shade(dish, -2))   # 馈源支架
    part(c, c.rect(0, 6, 2, 8), shade(dish, -4))                            # 馈源
    eye(c, f, 9, 7, sock=(100, 96, 104))
    part(c, c.rect(11, 11, 12, 13), (140, 136, 140))
    c.line(11, 13, 9, 15, (120, 116, 122)); c.line(12, 13, 14, 15, (120, 116, 122))
    f.muzzle(c, 0, 7)


@mob("rooftop", "water_tower", ELITE, 30, 44, "水塔：四条腿走路；水管一甩抛出三团水、跳起来砸得整个屋顶一震、水龙头一开冲出天线虫",
     moves=["volley", "slam", "summon"], elite_name="WATER TOWER", title="HIGH PRESSURE", hp=1050, bullet="ember")
def water_tower(c, f):
    tank = (196, 150, 120)
    part(c, c.poly([(15, 0), (29, 9), (1, 9)]), (110, 84, 76))              # 尖顶
    part(c, c.rect(2, 9, 27, 28), tank, bands=0.6)
    for y in (13, 20, 26):
        flat(c, c.rect(2, y, 27, y), shade(tank, -4))                       # 铁箍
    flat(c, c.rect(8, 15, 13, 18), DARK)                                    # 水位窗
    f.led(c, 10, 16, 2)
    flat(c, c.rect(20, 21, 22, 25), shade(tank, 2))                         # 板缝的亮条
    leg = (150, 120, 108)
    for x0, x1 in ((4, 2), (11, 10), (19, 20), (26, 28)):                   # 四条腿
        c.line(x0, 29, x1, 43, leg); c.line(x0 + 1, 29, x1 + 1, 43, leg)
    c.line(4, 35, 26, 35, leg)
    spout = (140, 140, 150)
    if f.attack or f.pose:                                                  # 水管甩起来
        part(c, c.rect(0, 22, 3, 24), spout); flat(c, c.rect(0, 19, 1, 21), (230, 236, 240))
    else:
        part(c, c.rect(0, 24, 2, 26), spout)
