"""教学关（隐藏关缩成的那一关）的几件小道具贴图（放映机会话，10-19）。原来是代码画的色块，换成像样的像素图。

    "/Users/jiamulin/Desktop/程序programs/AI Oscar/.venv/bin/python" tutorial_props.py

输出到 oscar-rush/art/tutorial/（文件名、格式照剧情会话 10-19 的约定）：
  door.png         32×40：两帧横排。左 = 关着的卷帘门（铁皮一条条横棱、底下一根把手横杆）；
                   右 = 卷起一半（顶上卷起来的门筒、卷帘只剩上半截挂在下面，下面露出黑门洞）
  crate.png        30×22：一个搬家纸箱（封箱胶带、正面亮、右侧面暗、写着字的标签），可以竖着摞
  switch.png       24×10：两帧横排。左 = 没拍的红按钮（凸起），右 = 拍下去的绿按钮（压扁）
  static_band.png  48×8：雪花三帧横排，每帧 16×8，左右能接上，可以平铺；顶上一道亮边告诉你别踩
  （阁楼的木板桥剧情会话改用 art/hidden/plank_memory.png 平铺，这里不画）
光从左上来、不描边、硬边；颜色跟阁楼和纸箱那几间房的木头、纸板一样暖。
"""
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "oscar-rush/art/tutorial"

CARD = [(112, 78, 54), (150, 110, 78), (178, 134, 94), (196, 150, 104), (214, 170, 120), (232, 196, 146)]
TAPE = [(200, 184, 140), (232, 214, 170)]
IRON = [(30, 27, 34), (46, 42, 52), (62, 56, 70), (82, 74, 92), (104, 96, 114), (132, 124, 140)]
WOOD = [(96, 62, 44), (138, 94, 62), (176, 126, 82), (206, 158, 104), (230, 190, 134)]
RED = [(110, 34, 30), (190, 64, 52), (240, 104, 80), (255, 168, 140)]
GREEN = [(30, 84, 44), (60, 150, 80), (110, 220, 120), (190, 250, 190)]


def blank(w, h):
    return np.zeros((h, w, 4), np.uint8)


def put(a, x, y, c):
    if 0 <= x < a.shape[1] and 0 <= y < a.shape[0]:
        a[y, x] = (*c, 255)


def rect(a, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(a, x, y, c)


# ---------------------------------------------------------------- 卷帘门
def door():
    a = blank(32, 40)
    # 关着：一条条横棱（每 4 行一条：亮棱 + 两行面 + 暗缝），左亮右暗，底下一根把手横杆
    for y in range(40):
        k = y % 4
        for x in range(16):
            side = 1 if x < 2 else (-1 if x > 13 else 0)
            base = [4, 3, 3, 1][k] + side
            put(a, x, y, IRON[max(0, min(5, base))])
    rect(a, 0, 36, 15, 39, IRON[2])
    rect(a, 0, 36, 15, 36, IRON[5])
    rect(a, 6, 37, 9, 37, IRON[0])                          # 把手的抠槽
    for y in (8, 24):                                       # 两颗铆钉
        put(a, 2, y + 1, IRON[5])
        put(a, 13, y + 1, IRON[1])
    # 开着：门框两边各 2 列、顶上卷起来的门筒（6 行，圆柱：上亮下暗），里面黑
    o = 16
    rect(a, o, 0, o + 15, 39, (14, 12, 18))
    for y in range(40):
        put(a, o, y, IRON[3])
        put(a, o + 1, y, IRON[2])
        put(a, o + 14, y, IRON[1])
        put(a, o + 15, y, IRON[0])
    for y, c in enumerate([IRON[5], IRON[4], IRON[3], IRON[3], IRON[2], IRON[1]]):
        rect(a, o, y, o + 15, y, c)
    for x in range(o + 2, o + 14, 3):                       # 门筒上卷起来的缝
        put(a, x, 2, IRON[2])
        put(a, x, 3, IRON[2])
    rect(a, o + 2, 6, o + 13, 7, IRON[1])                   # 卷筒下沿的影子
    return a


# ---------------------------------------------------------------- 纸箱
def crate_box(a, x0, y0, w, h, seed=0):
    """一个纸箱：正面亮、右侧面窄一条暗、顶边亮，中间一条封箱胶带，正面一张小标签（几道"字"）。"""
    side = 4
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            c = CARD[3]
            if x >= x0 + w - side:
                c = CARD[1] if y > y0 + 1 else CARD[2]
            elif y == y0:
                c = CARD[5]
            elif y == y0 + 1:
                c = CARD[4]
            elif y >= y0 + h - 1:
                c = CARD[1]
            put(a, x, y, c)
    # 纸板的折痕：顶上盖子那条横缝
    for x in range(x0 + 1, x0 + w - side):
        put(a, x, y0 + 3, CARD[2])
    # 封箱胶带：从顶上垂到盖子缝下面一点
    mx = x0 + (w - side) // 2
    for y in range(y0, y0 + 7):
        put(a, mx - 1, y, TAPE[1])
        put(a, mx, y, TAPE[1] if y < y0 + 2 else TAPE[0])
        put(a, mx + 1, y, TAPE[0])
    # 标签：左下一张浅色纸，上面三道"字"
    lx, ly = x0 + 3 + (seed % 3), y0 + h - 9
    rect(a, lx, ly, lx + 8, ly + 5, TAPE[1])
    for k, n in enumerate((6, 4, 5)):
        if k < 3 and ly + 1 + k * 2 <= ly + 5:
            for x in range(lx + 1, lx + 1 + n):
                put(a, x, ly + 1 + k * 2, CARD[1])
    # 左下角磨损的一角
    put(a, x0, y0 + h - 1, CARD[2])


def crate30():
    a = blank(30, 22)
    crate_box(a, 0, 0, 30, 22, seed=1)
    return a


def crate34():
    a = blank(34, 64)
    crate_box(a, 0, 43, 34, 21, seed=0)                     # 最下面一个最大
    crate_box(a, 1, 22, 32, 21, seed=2)                     # 中间一个稍微往右缩
    crate_box(a, 0, 0, 31, 22, seed=1)                      # 最上面一个往左偏一点
    return a


# ---------------------------------------------------------------- 雪花带、木板桥
def static_frames():
    out = blank(190, 24)
    snow = [(70, 72, 84), (130, 132, 146), (190, 192, 204), (236, 236, 244)]
    for f in range(3):
        rng = np.random.default_rng(31 + f)
        y0 = f * 8
        for y in range(1, 8):
            for x in range(0, 190, 1):
                r = rng.random()
                if r < 0.62:
                    put(out, x, y0 + y, snow[min(3, int(rng.random() * 4))])
        # 顶上一道亮边：一段亮一段灰（三帧错开，像在闪）
        for x in range(190):
            put(out, x, y0, snow[3] if ((x + f * 5) // 6) % 2 == 0 else snow[1])
    return out


def bridge():
    a = blank(190, 6)
    n = 190 // 14
    for i in range(n + 1):
        x0 = i * 14
        for x in range(x0, min(190, x0 + 13)):
            put(a, x, 0, WOOD[4] if x < x0 + 9 else WOOD[3])
            put(a, x, 1, WOOD[3])
            put(a, x, 2, WOOD[2])
            put(a, x, 3, WOOD[2] if (x - x0) % 6 else WOOD[1])     # 木纹
            put(a, x, 4, WOOD[1])
            put(a, x, 5, WOOD[0])
        put(a, x0 + 2, 2, WOOD[0])                                 # 两颗钉子
        put(a, x0 + 10, 2, WOOD[0])
    return a


# ---------------------------------------------------------------- 开关
def switch():
    a = blank(24, 10)
    for o, pressed in ((0, False), (12, True)):
        # 底座：一块铁皮台子 12×4，上面亮下面暗
        rect(a, o, 6, o + 11, 9, IRON[2])
        rect(a, o, 6, o + 11, 6, IRON[4])
        rect(a, o, 9, o + 11, 9, IRON[0])
        put(a, o + 1, 8, IRON[5])
        put(a, o + 10, 8, IRON[1])
        if not pressed:                                    # 凸起的红按钮，顶上一点高光
            rect(a, o + 2, 1, o + 9, 5, RED[1])
            rect(a, o + 2, 1, o + 9, 1, RED[2])
            rect(a, o + 9, 2, o + 9, 5, RED[0])
            put(a, o + 3, 2, RED[3])
            put(a, o + 4, 2, RED[2])
            rect(a, o + 3, 0, o + 8, 0, RED[1])
        else:                                              # 拍下去：压扁、变绿
            rect(a, o + 2, 4, o + 9, 5, GREEN[1])
            rect(a, o + 2, 4, o + 9, 4, GREEN[2])
            put(a, o + 3, 4, GREEN[3])
            put(a, o + 9, 5, GREEN[0])
    return a


def door_frames():
    """door.png 32×40：左 = 关着；右 = 卷起一半（顶上门筒 6 行，卷帘只剩上半截、底边把手跟着上去，下面露出黑门洞）。"""
    full = door()
    a = blank(32, 40)
    a[:, 0:16] = full[:, 0:16]
    a[:, 16:32] = full[:, 16:32]                            # 先画开着的门洞 + 门筒
    shut = full[:, 0:16]
    h = 20                                                   # 卷帘还露在外面的高度（门筒下面）
    a[6:6 + h, 16:32] = shut[40 - h:40]                      # 卷帘的下半截（带把手横杆）挂在门筒下面
    return a


def static_tile():
    """static_band.png 48×8：三帧 16×8 横排，每帧左右能接上，可以平铺；顶边一道一闪一闪的亮边。"""
    snow = [(70, 72, 84), (130, 132, 146), (190, 192, 204), (236, 236, 244)]
    out = blank(48, 8)
    for f in range(3):
        rng = np.random.default_rng(31 + f)
        for y in range(1, 8):
            for x in range(16):
                if rng.random() < 0.62:
                    put(out, f * 16 + x, y, snow[min(3, int(rng.random() * 4))])
        for x in range(16):
            put(out, f * 16 + x, 0, snow[3] if ((x + f * 5) // 4) % 2 == 0 else snow[1])
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    files = {
        "door.png": door_frames(),
        "crate.png": crate30(),
        "switch.png": switch(),
        "static_band.png": static_tile(),
    }
    for n, img in files.items():
        Image.fromarray(img).save(OUT / n)
        print(n, img.shape[1], "x", img.shape[0])


if __name__ == "__main__":
    main()
