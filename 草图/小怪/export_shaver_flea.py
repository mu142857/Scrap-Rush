"""电动剃须刀、弹簧跳蚤的游戏用动画横条（草图在 small.py，这里只补游戏里要的帧）。

    python3 export_shaver_flea.py    # 输出到 oscar-rush/art/enemies/shaver.png、flea.png

横排等宽帧，原图朝左，地面是最后一行。每帧左右留白，让身子落在帧的正中间
（EnemyBase 按帧宽的一半对齐脚底中点，朝右时整帧水平翻转）。
"""
from pathlib import Path

import numpy as np
from PIL import Image

import small
from elites import G, RGB  # small 已经把 精英怪/ 放进 sys.path

OUT = Path(__file__).resolve().parents[2] / "oscar-rush/art/enemies"


def over(base, top):
    """把 top 里不透明的像素盖到 base 上。"""
    out = base.copy()
    m = top[..., 3] > 0
    out[m] = top[m]
    return out


def clear(img, x0, y0, x1, y1):
    out = img.copy()
    out[y0:y1 + 1, x0:x1 + 1] = 0
    return out


def strip(frames, pad_left=0, pad_right=0):
    h = frames[0].shape[0]
    w = frames[0].shape[1] + pad_left + pad_right
    out = np.zeros((h, w * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        out[:, i * w + pad_left:i * w + pad_left + f.shape[1]] = f
    return out, w


# ---------------------------------------------------------------- 电动剃须刀（草图 27×10，ox = 2）
# 帧：0 走路 A（草图待机）、1 走路 B（腿反过来、电线换个弯）、2 前摇（刀网全亮）、3 冲刺（草图 shaver(1)）
SHAVER_OX = 2
SHAVER_LED = (SHAVER_OX + 6, 3)


def shaver_walk_b():
    ox = SHAVER_OX
    img = clear(small.shaver(0), 0, 8, 26, 9)                          # 腿只在最后两行
    img = clear(img, ox + 18, 2, 26, 6)                                 # 电线尾巴 + 插头
    g = G(27, 10)
    g.path([(ox + 17, 4), (ox + 19, 5), (ox + 21, 3), (ox + 24, 4)], 3)
    g.pts([(ox + 24, 3), (ox + 24, 5)], 6)
    for root, foot in [((ox + 6, 8), (ox + 7, 9)), ((ox + 10, 8), (ox + 11, 9)), ((ox + 14, 8), (ox + 13, 9))]:
        g.line(*root, *foot, 4)
    return over(img, g.rgba())


def shaver_windup():
    ox = SHAVER_OX
    g = G(27, 10)
    for x, y in [(ox + 1, 6), (ox + 2, 4), (ox + 1, 4), (ox + 3, 3), (ox + 2, 5), (ox + 1, 7)]:
        g.put(x, y, 9)                                                  # 梳齿全亮
    g.pts([(ox + 1, 5), (ox + 2, 6), (ox + 2, 7)], 8)                   # 齿缝也亮起来
    g.pts([(ox, 3), (ox - 1, 5), (ox, 8)], "S")                         # 刀头前面一圈小闪光
    return over(small.shaver(0), g.rgba())


def shaver_frames():
    return [small.shaver(0), shaver_walk_b(), shaver_windup(), small.shaver(1)]


# ---------------------------------------------------------------- 弹簧跳蚤（草图 11×18）
# 帧：0 待机（草图 flea(0)）、1 蹲（弹簧压扁，身子低 3 格）、2 起跳（草图 flea(1)，脚下有尘）、3 空中（去掉尘）
def flea_body(top):
    """照 small.flea 画罐头 + 弹簧，top 是罐头顶边所在的行。"""
    g = G(11, 18)
    g.box(2, top, 8, top + 6, base=4, top=8, left=7, right=5, bottom=3)
    g.rect(3, top + 2, 7, top + 2, 6)
    g.led(3, top + 4)
    for i, y in enumerate(range(top + 7, 17)):
        x = 4 if i % 2 == 0 else 6
        g.put(x, y, 6 if x == 4 else 4)
    g.rect(3, 17, 7, 17, 5)
    return g


def flea_crouch():
    g = flea_body(9)
    g.rect(3, 16, 7, 16, 6)                                             # 压扁的弹簧：两圈并成一横条
    g.pts([(2, 17), (8, 17)], 4)                                        # 底座被压得往两边鼓
    return g.rgba()


def flea_air():
    img = small.flea(1)
    for x, y in [(1, 17), (9, 17), (0, 16), (10, 16)]:
        img[y, x] = 0
    return img


FLEA_LED = {0: (3, 10), 1: (3, 13), 2: (3, 4), 3: (3, 4)}


def flea_frames():
    return [small.flea(0), flea_crouch(), small.flea(1), flea_air()]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # 剃须刀的身子（刀头 x=3 到机身 x=19）中点在 11.5，左边补 4 格让它落在 31 宽帧的正中
    sh, sw = strip(shaver_frames(), pad_left=4)
    Image.fromarray(sh).save(OUT / "shaver.png")
    fl, fw = strip(flea_frames())
    Image.fromarray(fl).save(OUT / "flea.png")
    print("shaver", sh.shape[1], "x", sh.shape[0], "帧宽", sw, "帧数 4", "红灯", (SHAVER_LED[0] + 4, SHAVER_LED[1]))
    print("flea", fl.shape[1], "x", fl.shape[0], "帧宽", fw, "帧数 4", "红灯", FLEA_LED)
    # 核对红灯位置
    for name, img, w, leds in [("shaver", sh, sw, {i: (SHAVER_LED[0] + 4, SHAVER_LED[1]) for i in range(4)}),
                               ("flea", fl, fw, FLEA_LED)]:
        for i, (x, y) in leds.items():
            px = tuple(int(v) for v in img[y, i * w + x, :3])
            assert px == RGB["L"], (name, i, px)


if __name__ == "__main__":
    main()
