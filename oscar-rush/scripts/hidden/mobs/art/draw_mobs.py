"""隐藏关「第四盘·倒带」五种小怪的占位贴图（总机台/留声机会话 10-18）。
照游戏里怪的画法：深灰身子 + 一只红色指示灯眼睛（红灯在游戏里由代码画，这里只留暗红底）+ 旧科技道具。
原图朝左，横排帧，原点在每帧脚底中间。正式贴图由放映机会话画好以后直接替换同名 png。
用法：python3 scripts/hidden/mobs/art/draw_mobs.py
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).parent
D0 = (30, 28, 30, 255)      # 最暗的边
D1 = (59, 56, 53, 255)      # 身子
D2 = (92, 87, 82, 255)      # 亮面
D3 = (138, 132, 124, 255)   # 高光
RUST = (120, 72, 48, 255)   # 磁粉的锈色
TAPE = (52, 40, 34, 255)    # 磁带
TAPE_HI = (96, 74, 60, 255)
LEDD = (110, 30, 24, 255)   # 红灯的底
IR = (150, 40, 40, 255)
CY0 = (40, 120, 130, 200)   # 倒带鬼：青色负片
CY1 = (90, 200, 210, 220)
CY2 = (180, 245, 250, 230)
SNOW = [(200, 205, 210, 255), (120, 125, 130, 255), (235, 238, 240, 255), (80, 84, 88, 255)]


def strip(w, h, n):
    return Image.new("RGBA", (w * n, h), (0, 0, 0, 0))


def px(img, f, w, x, y, c):
    if 0 <= x < w and 0 <= y < img.height:
        img.putpixel((f * w + x, y), c)


def rect(img, f, w, x, y, rw, rh, c):
    for i in range(rw):
        for j in range(rh):
            px(img, f, w, x + i, y + j, c)


def moth():
    # 14×12：0 翅膀上、1 翅膀下、2 合拢抖（预警）、3 俯冲。两片翅膀是两截磁带，身子是锈粉团
    w, h, n = 14, 12, 4
    img = strip(w, h, n)
    for f in range(n):
        # 身子（锈粉团）
        rect(img, f, w, 5, 5, 4, 4, RUST)
        rect(img, f, w, 6, 4, 2, 6, D1)
        px(img, f, w, 5, 6, LEDD)         # 红灯眼睛（朝左）
        px(img, f, w, 8, 8, D2)
        if f == 0:      # 翅膀往上张
            rect(img, f, w, 1, 1, 5, 2, TAPE); rect(img, f, w, 8, 1, 5, 2, TAPE)
            px(img, f, w, 2, 1, TAPE_HI); px(img, f, w, 11, 1, TAPE_HI)
        elif f == 1:    # 翅膀往下扇
            rect(img, f, w, 0, 7, 5, 2, TAPE); rect(img, f, w, 9, 7, 5, 2, TAPE)
            px(img, f, w, 1, 8, TAPE_HI); px(img, f, w, 12, 8, TAPE_HI)
        elif f == 2:    # 合拢（贴在背上）
            rect(img, f, w, 6, 1, 2, 4, TAPE); rect(img, f, w, 8, 2, 2, 3, TAPE)
            px(img, f, w, 6, 1, TAPE_HI)
        else:           # 俯冲：翅膀往后拖
            rect(img, f, w, 8, 3, 6, 2, TAPE); rect(img, f, w, 9, 6, 5, 1, TAPE)
            px(img, f, w, 13, 3, TAPE_HI)
        # 掉下来的锈粉
        if f in (0, 1):
            px(img, f, w, 7, 11, RUST)
    img.save(OUT / "tape_moth.png")


def reel_worm():
    # 18×10：0、1 爬（卷盘辐条转）、2 甩带预警（卷盘糊成一圈）、3 甩出去。两个卷盘做身子，嘴在左边吐磁带
    w, h, n = 18, 10, 4
    img = strip(w, h, n)
    for f in range(n):
        for cx in (5, 12):
            rect(img, f, w, cx - 3, 2, 7, 7, D1)
            rect(img, f, w, cx - 2, 1, 5, 9, D1)
            rect(img, f, w, cx - 1, 4, 3, 3, D0)
            if f == 2:
                rect(img, f, w, cx - 2, 3, 5, 5, D2)
                px(img, f, w, cx, 5, D3)
            else:
                spokes = [(0, -2), (2, 0), (0, 2), (-2, 0)] if f == 0 else [(1, -1), (1, 1), (-1, 1), (-1, -1)]
                for dx, dy in spokes:
                    px(img, f, w, cx + dx, 5 + dy, D3)
        rect(img, f, w, 8, 6, 2, 2, D2)          # 两个卷盘中间的连杆
        px(img, f, w, 2, 4, LEDD)                # 红灯眼睛
        rect(img, f, w, 0, 7, 2, 1, TAPE)        # 嘴里吐出一截磁带
        if f == 3:
            rect(img, f, w, 0, 6, 3, 2, TAPE_HI)
        # 脚：一排小钩
        for x in (3, 7, 10, 14):
            px(img, f, w, x + (f % 2), 9, D0)
    img.save(OUT / "reel_worm.png")


def remote():
    # 10×16：0、1 悬着上下晃、2 瞄准（头上的红外灯亮）
    w, h, n = 10, 16, 3
    img = strip(w, h, n)
    for f in range(n):
        y0 = 1 if f == 1 else 0
        rect(img, f, w, 2, 2 + y0, 6, 12, D1)
        rect(img, f, w, 3, 1 + y0, 4, 1, D1)
        rect(img, f, w, 2, 2 + y0, 1, 12, D2)
        # 一排排小按钮
        for r in range(4):
            for c in range(2):
                px(img, f, w, 4 + c * 2, 5 + y0 + r * 2, D3 if (r + c) % 2 == 0 else D0)
        px(img, f, w, 3, 3 + y0, LEDD)          # 红灯眼睛
        rect(img, f, w, 4, 0 + y0, 2, 1, IR if f == 2 else D0)   # 头上的红外灯
        if f == 2:
            px(img, f, w, 5, 0, (255, 90, 80, 255))
        # 底下一缕热气（悬着）
        px(img, f, w, 4, 15, D0 if f != 1 else (0, 0, 0, 0))
    img.save(OUT / "remote.png")


def rewind_ghost():
    # 12×16：主角的负片影子（青色、半透明），0 走、1 打下去
    w, h, n = 12, 16, 2
    img = strip(w, h, n)
    for f in range(n):
        rect(img, f, w, 4, 3, 4, 10, CY0)        # 身子（披风）
        rect(img, f, w, 4, 1, 4, 3, CY1)         # 头
        px(img, f, w, 5, 2, CY2)                 # 眼睛（负片的白）
        rect(img, f, w, 3, 13, 2, 3, CY0)
        rect(img, f, w, 7, 13, 2, 3, CY0)
        rect(img, f, w, 4, 4, 1, 8, CY1)         # 亮边
        if f == 1:                                # 一拳往下砸
            rect(img, f, w, 0, 8, 4, 2, CY1)
            rect(img, f, w, 0, 10, 2, 3, CY2)
        else:
            rect(img, f, w, 2, 6, 2, 4, CY0)
    img.save(OUT / "rewind_ghost.png")


def track_bar():
    # 26×6：一条活的"跟踪"雪花横条。0、1 两帧雪花（交替），2 加速前闪白
    w, h, n = 26, 6, 3
    img = strip(w, h, n)
    import random
    rnd = random.Random(2401)
    for f in range(n):
        for x in range(w):
            for y in range(1, 5):
                if f == 2:
                    c = SNOW[2]
                else:
                    c = SNOW[rnd.randrange(4)]
                # 两头参差（像撕开的信号）
                if (x < 2 and y in (1, 4)) or (x > w - 3 and y in (1, 4)):
                    continue
                px(img, f, w, x, y, c)
        rect(img, f, w, 1, 2, 2, 2, D0)          # 左头一小块暗的
        px(img, f, w, 1, 2, LEDD)                # 红灯眼睛
    img.save(OUT / "track_bar.png")


if __name__ == "__main__":
    moth(); reel_worm(); remote(); rewind_ghost(); track_bar()
    print("ok")
