"""隐藏关的概念图：核心机制示意、三个小机制、Boss 场地和分阶段、敌人概念草图。
    python3 草图/隐藏关/draw_concepts.py
只是设计图，不进游戏。敌人草图照游戏里的怪物画法（深灰方盒子身子 + 一只红色指示灯眼睛 + 手里的旧科技道具），
1 倍像素画完放大 5 倍，不是成品美术。
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE.parent.parent / "截图" / "隐藏关设计"
FONT_PATH = "/System/Library/Fonts/Hiragino Sans GB.ttc"


def font(size):
    return ImageFont.truetype(FONT_PATH, size)


BG = (18, 16, 24)
PANEL = (26, 24, 34)
INK = (232, 226, 214)
DIM = (140, 134, 150)
NEUTRAL = (84, 76, 98)
MEM = (238, 178, 108)
MEM_TOP = (255, 222, 160)
JUNK = (96, 124, 162)
JUNK_TOP = (150, 182, 220)
GOLD = (255, 206, 110)
RED = (232, 72, 64)
LED = (226, 72, 64)


def wrap(d, text, width, f):
    lines, cur = [], ""
    for ch in text:
        if ch == "\n":
            lines.append(cur)
            cur = ""
            continue
        cur += ch
        if d.textbbox((0, 0), cur, font=f)[2] > width:
            lines.append(cur[:-1])
            cur = ch
    lines.append(cur)
    return lines


def text_block(d, x, y, text, width, f, fill=INK, gap=6):
    for ln in wrap(d, text, width, f):
        d.text((x, y), ln, fill=fill, font=f)
        y += f.size + gap
    return y


# ---------------------------------------------------------------- 小零件

def player(d, x, y, s=4, col=(210, 50, 50)):
    """红衣人：脚底在 (x, y)。"""
    d.rectangle([x - 2 * s, y - 7 * s, x + 2 * s, y], fill=col)
    d.rectangle([x - 2 * s, y - 9 * s, x + 2 * s, y - 7 * s], fill=(70, 20, 24))
    d.rectangle([x + s, y - 6 * s, x + 2 * s, y - 2 * s], fill=(255, 220, 200))


def lantern(d, x, y, s=4, glow=True, r=110):
    if glow:
        for k, a in ((1.0, 34), (0.8, 46), (0.6, 60)):
            rr = r * k
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(a + 20, a, int(a * 0.6)))
    d.rectangle([x - 2 * s, y - 3 * s, x + 2 * s, y + 2 * s], fill=GOLD)
    d.rectangle([x - s, y - 5 * s, x + s, y - 3 * s], fill=(120, 90, 50))


def plat(d, x0, x1, y, kind, solid=True, h=14):
    if kind == "m":
        if solid:
            d.rectangle([x0, y, x1, y + h], fill=MEM)
            d.rectangle([x0, y, x1, y + 4], fill=MEM_TOP)
        else:
            for xx in range(int(x0), int(x1), 12):
                d.rectangle([xx, y, xx + 6, y + 3], fill=(120, 90, 60))
    elif kind == "j":
        if solid:
            d.rectangle([x0, y, x1, y + h], fill=JUNK)
            for xx in range(int(x0), int(x1), 8):
                d.line([xx, y + h, xx + 8, y], fill=JUNK_TOP, width=2)
        else:
            for xx in range(int(x0), int(x1), 12):
                d.rectangle([xx, y + h - 3, xx + 6, y + h], fill=(50, 62, 84))
    else:
        d.rectangle([x0, y, x1, y + h], fill=NEUTRAL)


## 说明文字最后统一画，免得被插图的灯光盖住
_LATER = []


def panel(d, x, y, w, h, title, body):
    d.rectangle([x, y, x + w, y + h], fill=PANEL, outline=(60, 56, 72), width=2)
    d.text((x + 16, y + 12), title, fill=GOLD, font=font(22))
    _LATER.append((x + 16, y + h - 118, body, w - 32))


def flush_text(d):
    for x, y, body, w in _LATER:
        d.rectangle([x - 6, y - 6, x + w + 6, y + 100], fill=PANEL)
        text_block(d, x, y, body, w, font(16))
    _LATER.clear()


# ---------------------------------------------------------------- 3 核心机制

def core():
    W, H = 2000, 1240
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.text((40, 24), "核心机制 · 灯照回忆（贯穿全关）", fill=INK, font=font(34))
    d.text((40, 76), "录像带上有两层：灯照得到的地方放的是「回忆」（家的样子，暖色），照不到的地方被废品星「覆盖录制」了（冷色废铁）。"
                     "暖色平台只在光里是实的，冷色平台只在暗处是实的。", fill=DIM, font=font(18))
    pw, ph = 930, 520
    ps = [(40, 130), (1030, 130), (40, 680), (1030, 680)]
    # A 提着灯
    x, y = ps[0]
    panel(d, x, y, pw, ph, "① 提着灯走：脚下的暖色木板接住你",
          "灯在手上，光圈跟着人走：光圈里的回忆木板是实的，光圈外的还是虚线。坑上只有回忆里的木板，所以要提着灯过坑。"
          "代价和前三关一样：提灯又慢、又飞不久。")
    gy = y + 340
    plat(d, x + 30, x + 260, gy, "n")
    plat(d, x + 640, x + 900, gy, "n")
    for k, a in ((1.0, 34), (0.8, 46), (0.6, 60)):
        rr = 150 * k
        d.ellipse([x + 450 - rr, gy - 40 - rr, x + 450 + rr, gy - 40 + rr], fill=(a + 20, a, int(a * 0.6)))
    plat(d, x + 300, x + 600, gy, "m", solid=True)
    plat(d, x + 600, x + 640, gy, "m", solid=False)
    plat(d, x + 260, x + 300, gy, "m", solid=False)
    player(d, x + 440, gy)
    lantern(d, x + 462, gy - 34, glow=False)
    d.text((x + 320, gy + 26), "光圈外的回忆木板：虚的（踩不住）", fill=DIM, font=font(15))
    # B 放下灯
    x, y = ps[1]
    panel(d, x, y, pw, ph, "② 把灯放下：暗处的冷色废铁才浮出来",
          "灯放在地上，那一圈回忆一直亮着（像一个家的泡泡）。人走出光圈，暗处的覆盖层废铁变成实的，可以踩着往上爬；"
          "但人在黑里，覆盖层的怪更凶。爬上去以后再回头把灯捡起来——或者用「扔灯」。")
    gy = y + 360
    plat(d, x + 30, x + 900, gy, "n")
    lantern(d, x + 200, gy - 14, glow=True, r=130)
    plat(d, x + 120, x + 300, gy - 110, "m", solid=True)
    plat(d, x + 420, x + 540, gy - 70, "j", solid=True)
    plat(d, x + 600, x + 720, gy - 140, "j", solid=True)
    plat(d, x + 760, x + 900, gy - 210, "j", solid=True)
    player(d, x + 650, gy - 140)
    d.text((x + 420, gy - 260), "暗处：废铁台阶是实的", fill=JUNK_TOP, font=font(16))
    d.text((x + 110, gy - 160), "光里：回忆木板", fill=MEM_TOP, font=font(16))
    # C 扔灯
    x, y = ps[2]
    panel(d, x, y, pw, ph, "③ 新动作：按住水晶键＝扔灯（只在这关）",
          "按住 0.3 秒松手，把灯往面朝的方向抛出去（约 5 格高、7 格远）。灯在半空也照亮：抛过一道坑，坑上的回忆木板就在灯落下的那一路上亮起来。"
          "灯落地后照常可以捡。不加新按键，还是 5 个键。")
    gy = y + 360
    plat(d, x + 30, x + 260, gy, "n")
    plat(d, x + 700, x + 900, gy, "n")
    pts = [(x + 230 + i * 40, gy - 40 - 140 * math.sin(i / 12 * math.pi)) for i in range(13)]
    for i in range(len(pts) - 1):
        if i % 2 == 0:
            d.line([pts[i], pts[i + 1]], fill=GOLD, width=3)
    lantern(d, int(pts[7][0]), int(pts[7][1]), glow=True, r=110)
    plat(d, x + 380, x + 560, gy - 60, "m", solid=True)
    plat(d, x + 260, x + 380, gy - 60, "m", solid=False)
    plat(d, x + 560, x + 700, gy - 60, "m", solid=False)
    player(d, x + 220, gy)
    # D 其他光源
    x, y = ps[3]
    panel(d, x, y, pw, ph, "④ 武器的光也算光：七把武器各有用法",
          "闪光灯的光球飞过的一路、显像管激光的光束、特斯拉电钳放电那一下，都会短暂照出回忆木板（0.6～1.5 秒）。"
          "不发光的武器（铆钉枪、霰弹枪、蒸汽锤、唱片）靠别的本事：霰弹枪的后坐力能在暗处多弹两下，唱片回程能穿墙把东西捞回来。")
    gy = y + 330
    plat(d, x + 30, x + 200, gy, "n")
    player(d, x + 140, gy)
    d.line([x + 160, gy - 30, x + 880, gy - 180], fill=(255, 120, 120), width=5)
    d.line([x + 160, gy - 32, x + 880, gy - 182], fill=(120, 255, 255), width=2)
    for i in range(5):
        px = x + 260 + i * 130
        py = gy - 30 - (i * 130 + 100) * 150 / 720 + 26
        plat(d, px, px + 90, py, "m", solid=True, h=10)
    d.text((x + 470, gy - 250), "激光扫过：一路照出一座光桥", fill=MEM_TOP, font=font(16))
    flush_text(d)
    img.save(OUT / "3_核心机制_灯照回忆.png")
    print("3 core", img.size)


# ---------------------------------------------------------------- 4 三个小机制

def mini():
    W, H = 2000, 660
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.text((40, 24), "只在某些房间出现的小机制：录像机上的三个键", fill=INK, font=font(34))
    pw = 620
    specs = [
        ("暂停 ‖  （生日：R5～R7、R16）",
         "墙上的大暂停键，打一下（或跳上去踩）：4 秒里除了玩家，所有东西定格——怪、子弹、彩带炮、旋转的光束。画面有暂停时的横向抖线。"
         "定格时你打出去的子弹也会停在半空，恢复播放的一瞬间一起飞出去：可以先「排」一排子弹。冷却 8 秒，键上的灯从红变绿。"),
        ("跳帧 >>|  （雪天：R8～R10、R16）",
         "画面每 2.4 秒在 A、B 两帧之间跳：A 帧有的平台，B 帧没有，反过来也一样；怪也跳到另一帧里的位置。"
         "跳之前 0.5 秒有撕裂预警（画面横着错开几条），声音「咔」。站在两帧都有的中性台子上最稳。"),
        ("倒带 <<  （夏天：R11～R12、R16）",
         "每 6 秒，房间倒回 2 秒：怪和子弹沿着刚才的路倒着走，只有玩家不倒。"
         "所以子弹会原路飞回去打它的主人。站在怪和它刚打出的子弹中间，倒带时子弹就从你身边飞回去。磁带的嗡嗡声提前 0.5 秒变调。"),
    ]
    for i, (title, body) in enumerate(specs):
        x = 40 + i * (pw + 30)
        y = 100
        d.rectangle([x, y, x + pw, y + 540], fill=PANEL, outline=(60, 56, 72), width=2)
        d.text((x + 16, y + 14), title, fill=GOLD, font=font(22))
        # 时间轴示意
        ty = y + 90
        d.text((x + 16, ty - 4), "时间 →", fill=DIM, font=font(14))
        for k in range(10):
            bx = x + 80 + k * 50
            if i == 0:
                col = (250, 210, 80) if 3 <= k < 7 else (70, 66, 84)
                lab = "‖" if 3 <= k < 7 else ">"
            elif i == 1:
                col = (230, 130, 160) if (k // 2) % 2 == 0 else (110, 210, 200)
                lab = "A" if (k // 2) % 2 == 0 else "B"
            else:
                col = (240, 200, 100) if k % 3 != 2 else (190, 150, 230)
                lab = "<<" if k % 3 == 2 else ">"
            d.rectangle([bx, ty, bx + 44, ty + 28], fill=col)
            d.text((bx + 12, ty + 4), lab, fill=(20, 18, 24), font=font(16))
        # 小场景
        sy = y + 150
        d.rectangle([x + 20, sy, x + pw - 20, sy + 220], fill=(20, 18, 28))
        plat(d, x + 30, x + pw - 30, sy + 200, "n", h=14)
        player(d, x + 100, sy + 200)
        if i == 0:
            for k in range(4):
                bx = x + 200 + k * 50
                d.ellipse([bx, sy + 150, bx + 12, sy + 162], fill=(255, 240, 200))
            d.text((x + 190, sy + 110), "定格中排好的一排子弹", fill=DIM, font=font(14))
            d.rectangle([x + 470, sy + 120, x + 540, sy + 200], fill=(70, 70, 80))
            d.ellipse([x + 495, sy + 135, x + 505, sy + 145], fill=LED)
            for yy in range(sy + 10, sy + 200, 18):
                d.line([x + 20, yy, x + pw - 20, yy + 2], fill=(40, 38, 50))
        elif i == 1:
            d.rectangle([x + 160, sy + 130, x + 280, sy + 144], fill=(230, 130, 160))
            d.rectangle([x + 320, sy + 90, x + 440, sy + 104], outline=(110, 210, 200), width=3)
            d.rectangle([x + 460, sy + 60, x + 580, sy + 74], fill=(230, 130, 160))
            for k in range(3):
                yy = sy + 30 + k * 50
                d.rectangle([x + 20, yy, x + pw - 20, yy + 6], fill=(60, 56, 80))
            d.text((x + 160, sy + 150), "A 帧", fill=(230, 130, 160), font=font(14))
            d.text((x + 320, sy + 110), "B 帧", fill=(110, 210, 200), font=font(14))
        else:
            d.rectangle([x + 470, sy + 140, x + 540, sy + 200], fill=(70, 70, 80))
            d.ellipse([x + 495, sy + 150, x + 505, sy + 160], fill=LED)
            for k in range(5):
                bx = x + 200 + k * 50
                d.ellipse([bx, sy + 160, bx + 10, sy + 170], fill=(255, 150, 150))
            d.line([x + 200, sy + 185, x + 460, sy + 185], fill=(190, 150, 230), width=3)
            d.polygon([(x + 460, sy + 178), (x + 474, sy + 185), (x + 460, sy + 192)], fill=(190, 150, 230))
            d.text((x + 200, sy + 120), "倒带：子弹原路飞回去", fill=DIM, font=font(14))
        text_block(d, x + 16, sy + 240, body, pw - 32, font(16))
    img.save(OUT / "4_三个小机制.png")
    print("4 mini", img.size)


# ---------------------------------------------------------------- 5 Boss

def boss():
    W, H = 2000, 1050
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.text((40, 24), "Boss · 覆盖录制机 REC ●（场地：录像机内部，侧视，两屏宽）", fill=INK, font=font(34))
    ax, ay, aw, ah = 40, 90, 1920, 600
    d.rectangle([ax, ay, ax + aw, ay + ah], fill=(20, 18, 28), outline=(190, 150, 230), width=3)
    # 磁带走带路径
    floor = ay + ah - 70
    d.rectangle([ax, floor, ax + aw, floor + 20], fill=(70, 50, 40))
    for xx in range(ax, ax + aw, 30):
        d.line([xx, floor + 10, xx + 14, floor + 10], fill=(110, 80, 60), width=2)
    d.text((ax + 20, floor + 26), "磁带 = 地面，一直往右走（传送带 20 像素/秒；二阶段忽快忽倒）", fill=DIM, font=font(16))
    # 供带盘、收带盘
    for cx, lab in ((ax + 120, "供带盘"), (ax + aw - 120, "收带盘")):
        d.ellipse([cx - 90, floor - 200, cx + 90, floor - 20], outline=(130, 120, 140), width=6)
        d.ellipse([cx - 20, floor - 130, cx + 20, floor - 90], fill=(130, 120, 140))
        d.text((cx - 30, floor - 230), lab, fill=DIM, font=font(16))
    # 磁鼓（Boss 本体）
    cx, cy = ax + aw // 2, ay + 250
    d.ellipse([cx - 150, cy - 150, cx + 150, cy + 150], fill=(150, 150, 165), outline=(220, 220, 235), width=4)
    d.ellipse([cx - 120, cy - 30, cx + 120, cy + 30], fill=(110, 110, 125))
    d.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], fill=LED)
    d.text((cx - 60, cy + 160), "磁鼓（本体）", fill=INK, font=font(18))
    d.text((cx + 120, cy - 170), "REC ●", fill=LED, font=font(30))
    # 压带轮、主导轴：可站的小平台
    for px in (ax + 520, ax + aw - 520):
        d.ellipse([px - 40, floor - 120, px + 40, floor - 40], fill=(60, 56, 70), outline=(150, 140, 160), width=3)
        d.rectangle([px - 70, floor - 130, px + 70, floor - 118], fill=NEUTRAL)
        d.text((px - 40, floor - 160), "压带轮", fill=DIM, font=font(15))
    # 回忆 / 废铁平台
    for (x0, y0, k) in [(ax + 330, ay + 230, "m"), (ax + 1450, ay + 230, "m"), (ax + 330, ay + 120, "j"), (ax + 1450, ay + 120, "j")]:
        plat(d, x0, x0 + 150, y0, k)
    # 消磁头
    d.rectangle([ax + aw - 330, floor - 70, ax + aw - 250, floor], fill=(120, 40, 50), outline=(255, 120, 120), width=3)
    d.text((ax + aw - 360, floor - 100), "消磁头（三阶段）", fill=(255, 150, 150), font=font(16))
    player(d, ax + 700, floor)
    lantern(d, ax + 722, floor - 34, glow=False)
    # 三阶段
    by = ay + ah + 30
    cw = 620
    phases = [
        ("一阶段 · ● REC 覆盖录制（血 100%～66%）",
         "磁鼓转着，红色录制线从左往右扫过场地（1 秒预警：一道细红线一闪一闪）：被扫过的回忆木板变成废铁，被扫到的人掉灯 + 情绪 +8。"
         "灯照着的地方扫不掉——站在光里就是安全区。间隔里从磁鼓吐出「购物频道」价签弹（三颗一组，抛物线）。"
         "打法：本体只有转到正面时（红灯朝外）吃全伤害；激光、闪光灯这时最好用。"),
        ("二阶段 << >> 倒带 / 快进（66%～33%）",
         "磁带地面忽快忽倒：先 「>>」 往右冲 3 秒（要往左跑才站得住），再 「<<」 往左冲。"
         "它把一阶段你打过去的子弹倒带吐回来（数量 = 你最近 4 秒打中它的次数的一半）。"
         "压带轮是唯一不动的台子。打法：跳上压带轮输出；倒带时往右边站，让倒回来的子弹从磁鼓和你之间穿过去打到它自己。"),
        ("三阶段 EJECT 消磁（33%～0）",
         "右边的消磁头通电，像磁铁一样把地上的马灯往右吸（提在手上也会往右拖，走路慢一半）。"
         "灯被吸进消磁头，马灯每秒 -6。磁鼓同时放慢、低头，红灯一直朝外：这是它最脆弱的时候。"
         "打法：一个人提灯顶住吸力，或者把灯放在左边压带轮后面（挡得住吸力）。双人时一个抱灯、一个打。"),
    ]
    for i, (t, body) in enumerate(phases):
        x = 40 + i * (cw + 30)
        d.rectangle([x, by, x + cw, by + 300], fill=PANEL, outline=(60, 56, 72), width=2)
        d.text((x + 16, by + 14), t, fill=GOLD, font=font(20))
        text_block(d, x + 16, by + 60, body, cw - 32, font(16))
    img.save(OUT / "5_Boss_覆盖录制机.png")
    print("5 boss", img.size)


# ---------------------------------------------------------------- 6 敌人概念草图

def sprite(w, h):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def mob_moth():
    im, d = sprite(22, 14)
    d.rectangle([9, 5, 13, 10], fill=(70, 66, 76))
    d.point((12, 7), fill=LED)
    for i, (x0, y0) in enumerate([(1, 2), (2, 5), (3, 8)]):
        d.line([x0, y0, 9, 6 + i], fill=(92, 64, 44))
        d.line([21 - x0, y0, 13, 6 + i], fill=(92, 64, 44))
    d.line([10, 11, 9, 13], fill=(70, 66, 76)); d.line([12, 11, 13, 13], fill=(70, 66, 76))
    for p in [(4, 12), (17, 11), (7, 0)]:
        d.point(p, fill=(120, 100, 90))
    return im


def mob_spool():
    im, d = sprite(34, 14)
    for cx in (6, 17):
        d.ellipse([cx - 5, 2, cx + 5, 12], fill=(64, 60, 70))
        d.ellipse([cx - 2, 5, cx + 2, 9], fill=(120, 110, 120))
    d.rectangle([6, 2, 17, 4], fill=(64, 60, 70))
    d.point((17, 7), fill=LED)
    d.line([22, 7, 33, 5], fill=(92, 64, 44), width=1)
    d.line([22, 8, 33, 9], fill=(70, 48, 34))
    for x in (3, 9, 14, 20):
        d.line([x, 12, x, 13], fill=(64, 60, 70))
    return im


def mob_remote():
    im, d = sprite(12, 22)
    d.rectangle([2, 2, 9, 17], fill=(58, 56, 64))
    d.point((5, 0), fill=LED); d.point((6, 0), fill=LED); d.point((5, 1), fill=LED); d.point((6, 1), fill=LED)
    for yy in range(5, 15, 3):
        d.point((4, yy), fill=(140, 136, 150)); d.point((7, yy), fill=(140, 136, 150))
    d.rectangle([4, 15, 7, 16], fill=(200, 80, 70))
    d.line([1, 19, 4, 18], fill=(110, 106, 120)); d.line([10, 19, 7, 18], fill=(110, 106, 120))
    d.point((5, 21), fill=(90, 140, 170)); d.point((6, 21), fill=(90, 140, 170))
    return im


def mob_rewinder():
    im, d = sprite(26, 18)
    for k, a in ((0, 60), (6, 110), (12, 255)):
        col = (90, 200, 210, a)
        d.rectangle([k + 2, 5, k + 6, 15], fill=col)
        d.rectangle([k + 2, 3, k + 6, 5], fill=(30, 90, 100, a))
    d.point((17, 8), fill=LED)
    d.polygon([(20, 6), (23, 4), (23, 8)], fill=(190, 150, 230))
    d.polygon([(23, 6), (25, 4), (25, 8)], fill=(190, 150, 230))
    return im


def mob_tracking():
    im, d = sprite(36, 8)
    import random
    rr = random.Random(4)
    for x in range(36):
        for y in range(2, 7):
            if rr.random() < 0.6:
                v = rr.randint(120, 230)
                d.point((x, y), fill=(v, v, v + 10))
    d.rectangle([16, 3, 19, 5], fill=(30, 30, 36))
    d.point((17, 4), fill=LED); d.point((18, 4), fill=LED)
    return im


def elite_musicbox():
    im, d = sprite(40, 40)
    d.rectangle([4, 22, 35, 37], fill=(96, 70, 60))
    d.rectangle([4, 22, 35, 24], fill=(130, 96, 80))
    d.polygon([(4, 22), (35, 22), (31, 12), (8, 12)], fill=(78, 56, 50))
    for x in range(9, 31, 3):
        d.line([x, 27, x, 33], fill=(200, 190, 170))
    d.point((19, 30), fill=LED); d.point((20, 30), fill=LED)
    d.rectangle([19, 6, 20, 21], fill=(220, 210, 220))
    d.ellipse([17, 2, 22, 7], fill=(230, 220, 230))
    d.polygon([(14, 15), (25, 15), (19, 11)], fill=(236, 170, 190))
    d.rectangle([36, 26, 38, 33], fill=(200, 170, 90)); d.rectangle([38, 24, 39, 35], fill=(200, 170, 90))
    return im


def elite_globe():
    im, d = sprite(40, 42)
    d.rectangle([6, 32, 33, 40], fill=(90, 66, 58))
    d.point((19, 36), fill=LED); d.point((20, 36), fill=LED)
    d.ellipse([3, 2, 36, 35], fill=(60, 80, 110), outline=(200, 220, 240))
    d.rectangle([14, 20, 25, 30], fill=(230, 200, 170))
    d.polygon([(12, 20), (27, 20), (19, 13)], fill=(200, 80, 70))
    d.rectangle([18, 25, 20, 30], fill=(250, 220, 120))
    for p in [(9, 10), (27, 8), (14, 6), (30, 18), (8, 22), (22, 12)]:
        d.point(p, fill=(255, 255, 255))
    d.line([8, 8, 12, 5], fill=(255, 255, 255))
    return im


def elite_camcorder():
    im, d = sprite(46, 40)
    d.rectangle([8, 8, 34, 22], fill=(56, 54, 62))
    d.rectangle([34, 10, 44, 20], fill=(40, 40, 46))
    d.ellipse([38, 11, 45, 19], fill=(90, 120, 150))
    d.rectangle([10, 3, 20, 8], fill=(46, 44, 52))
    d.point((26, 10), fill=LED); d.point((27, 10), fill=LED)
    d.rectangle([2, 12, 8, 16], fill=(46, 44, 52))
    for x0, x1 in ((20, 10), (22, 22), (24, 34)):
        d.line([x0, 22, x1, 39], fill=(120, 116, 130))
    return im


def boss_vcr():
    im, d = sprite(80, 50)
    d.rectangle([2, 10, 77, 44], fill=(58, 56, 64))
    d.rectangle([2, 10, 77, 12], fill=(84, 80, 92))
    d.rectangle([12, 22, 52, 30], fill=(20, 20, 24))
    d.rectangle([14, 24, 50, 28], fill=(70, 50, 40))
    d.rectangle([58, 18, 74, 26], fill=(20, 30, 24))
    for i, x in enumerate((60, 64, 68)):
        d.rectangle([x, 20, x + 2, 24], fill=(220, 70, 60))
    d.ellipse([60, 32, 66, 38], fill=LED)
    d.ellipse([28, 0, 52, 14], fill=(170, 170, 185), outline=(220, 220, 230))
    d.ellipse([37, 4, 43, 10], fill=LED)
    d.line([14, 30, 4, 46], fill=(92, 64, 44), width=2)
    d.line([50, 30, 64, 48], fill=(92, 64, 44), width=2)
    for x in (8, 20, 60, 72):
        d.rectangle([x, 44, x + 3, 48], fill=(46, 44, 52))
    return im


def enemies():
    items = [
        ("磁粉蛾", mob_moth(), "小怪 · 飞",
         "磁带掉下来的锈粉聚成的飞蛾，翅膀是两截磁带。只扑光：贴到灯的光圈上会把光圈啃小一圈（每只 -10%，最小剩一半），打死就还回来。"
         "预警：俯冲前翅膀合拢，抖一下。打法：一发就死，成群来；闪光灯、电钳会招它们。"),
        ("卷带虫", mob_spool(), "小怪 · 地面",
         "两个卷盘做身子的虫，一路吐磁带。招式：甩带鞭——卷盘越转越快（0.5 秒，嗡声变尖），朝前抽出 6 格长的磁带。"
         "抽出的磁带在暗处留下 3 秒，是一段冷色废铁平台——敌人的招式也能借来走路。"),
        ("遥控器", mob_remote(), "小怪 · 飞",
         "悬在空中的遥控器，头上的红外灯对准你：一条虚线红外光（0.8 秒预警）连上就按「慢放」，人 1.5 秒里慢一半。"
         "光照着的时候红外线看得见（照不到时只有一个红点），所以带着灯更好躲。血薄，霰弹枪一下一只。"),
        ("倒带鬼", mob_rewinder(), "小怪 · 地面",
         "你自己的负片影子：出生后一直重走你 3 秒前走过的路，碰到就伤人。它会在你 3 秒前站过的地方打一下（地上先亮一个青色圈）。"
         "打法：别原路折返；它走在你身后，蒸汽锤回身一锤正好。在光里它显形，伤害 ×1.5。"),
        ("跟踪条", mob_tracking(), "小怪 · 贴墙",
         "老录像机「跟踪」没调好时的那条雪花横条，活了。顺着墙和地面爬，碰到的人掉灯。"
         "在暗处打不动（子弹穿过去），只有在光圈里才是实的：把灯靠过去照住它再打。"),
        ("八音盒", elite_musicbox(), "精英 · 生日",
         "上面站着一个转圈的芭蕾小人，转一圈射出一道旋转光束；盒子的音梳一排排弹出音符弹，按旋律的节奏排成弧线。"
         "一半血以后上满弦，转得飞快。弱点：背后的发条钥匙，打中算 ×2，连打 6 下「上过头」晕 2.5 秒。拍暂停键能把光束停在想要的角度。"),
        ("雪花球", elite_globe(), "精英 · 雪天",
         "玻璃罩里是那间家里的小房子。先要敲碎玻璃罩（只有近身重击算：蒸汽锤、霰弹枪贴脸、唱片回程）。"
         "它会把自己晃起来：画面下暴雪、灯光圈缩小一半；整个球滚过场子（1 秒预警：球往后一缩）。玻璃碎了以后里面的小房子冒烟，才吃普通伤害。"),
        ("摄像机", elite_camcorder(), "精英 · 夏天",
         "当年录下这盘带子的那台摄像机，架在三脚架上。它在场子里投一个取景框（白框），框慢慢收拢，1 秒后「咔」一声录下来："
         "被框住的玩家会多出一个倒带鬼（录下来的你），被框住的怪会多复制一只。打法：别被框住，或者把怪引进框里、自己出来。录完镜头盖打开，正面挨打 ×2。"),
        ("覆盖录制机 REC", boss_vcr(), "Boss · 第一盘",
         "把整颗星球的垃圾节目往这盘带子上录的录像机。三阶段：覆盖录制 → 倒带快进 → 消磁（见 Boss 图）。"
         "打败以后它吐出磁带，磁带落进马灯，录像回来了。"),
    ]
    S = 6
    cw, chh = 640, 360
    cols = 3
    rows = math.ceil(len(items) / cols)
    W, H = cols * cw + 80, rows * chh + 140
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.text((40, 24), "敌人概念草图（1 倍像素画、放大 6 倍；照游戏里的怪物画法：深灰身子 + 一只红灯眼睛 + 旧科技道具）", fill=INK, font=font(26))
    d.text((40, 66), "不是成品美术，给 Oscar 和作者看造型方向。", fill=DIM, font=font(18))
    for i, (name, im, kind, body) in enumerate(items):
        x = 40 + (i % cols) * cw
        y = 110 + (i // cols) * chh
        d.rectangle([x, y, x + cw - 20, y + chh - 20], fill=PANEL, outline=(60, 56, 72), width=2)
        big = im.resize((im.width * S, im.height * S), Image.NEAREST)
        bx = x + 20
        by = y + 70 + max(0, (150 - big.height) // 2)
        if big.height > 170:
            big = im.resize((im.width * 4, im.height * 4), Image.NEAREST)
            by = y + 60
        img.paste(big, (bx, by), big)
        d.text((x + 20, y + 14), name, fill=GOLD, font=font(24))
        d.text((x + 20 + d.textbbox((0, 0), name, font=font(24))[2] + 16, y + 20), kind, fill=DIM, font=font(16))
        text_block(d, x + 300, y + 66, body, cw - 340, font(15), gap=5)
    img.save(OUT / "6_敌人概念草图.png")
    print("6 enemies", img.size)


if __name__ == "__main__":
    core()
    mini()
    boss()
    enemies()
