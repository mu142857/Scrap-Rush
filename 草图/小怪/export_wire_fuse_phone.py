"""电线蛇、保险丝甲虫、手摇电话的游戏用动画横条（草图在 small.py，这里只补游戏里要的帧）。

    python3 export_wire_fuse_phone.py    # 输出到 oscar-rush/art/enemies/wire_snake.png、fuse_beetle.png、phone.png

横排等宽帧，原图朝左，地面是最后一行。身子放在帧的正中间
（EnemyBase 按帧宽的一半对齐脚底中点，朝右时整帧水平翻转）。
"""
from pathlib import Path

import numpy as np
from PIL import Image

import small
from elites import G, RGB, legs  # small 已经把 精英怪/ 放进 sys.path

OUT = Path(__file__).resolve().parents[2] / "oscar-rush/art/enemies"


def strip(frames):
    h, w = frames[0].shape[:2]
    out = np.zeros((h, w * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        assert f.shape[:2] == (h, w), f.shape
        out[:, i * w:(i + 1) * w] = f
    return out, w


def legs_b(g, roots, ground, spread=1):
    """legs() 的另一步：每条腿往反方向折。"""
    for i, (x, y) in enumerate(roots):
        d = 1 if i % 2 == 0 else -1
        kx, ky = x + d * spread, (y + ground) // 2
        g.line(x, y, kx, ky, 5)
        g.line(kx, ky, kx - d, ground, 4)
        g.put(kx - d - 1, ground, 4)


# ---------------------------------------------------------------- 电线蛇（帧 20×11，只画插头，电线由脚本从天花板画下来）
# 帧：0 挂着（草图待机的插头）、1 前摇（插脚发亮、冒火花）、2 扑下来（插脚带电）、
#     3 被打得晃（草图"扑下来"那一格的歪插头，朝左 = 往左甩）、4/5 落地爬（插头横躺，电线当尾巴甩）
# 草图的插头 x 4..9，这里右移 3 格，落在 20 宽帧的正中
WIRE_W, WIRE_H = 20, 11
WIRE_LED = {0: (9, 6), 1: (9, 6), 2: (9, 6), 3: (9, 3), 4: (8, 8), 5: (8, 8)}
## 电线接进插头的那一格（左边那一列），脚本把电线画到这里
WIRE_ATTACH = {0: (9, 4), 1: (9, 4), 2: (9, 4), 3: (9, 1)}


def wire_plug(p):
    g = G(WIRE_W, WIRE_H)
    g.box(7, 4, 12, 8, base=4, top=7, left=7, right=5, bottom=3)
    g.led(9, 6)
    prong = [(8, 9), (8, 10), (11, 9), (11, 10)]
    if p == 0:
        g.pts(prong, 8)
    elif p == 1:                                                        # 前摇：插脚亮起来，脚尖一点火花
        g.pts(prong, 9)
        g.pts([(9, 10), (7, 10), (12, 9)], "S")
    else:                                                               # 扑下来：插脚带电，两边炸开火花
        g.pts(prong, 9)
        g.pts([(9, 9), (10, 10)], "L")
        g.pts([(7, 9), (6, 10), (12, 10), (13, 9)], "S")
    return g.rgba()


def wire_swing():
    """草图 wire_snake(1) 的插头部分，右移 6、上移 11；电线由脚本画。"""
    g = G(WIRE_W, WIRE_H)
    g.poly([(6, 2), (10, 0), (13, 4), (9, 6)], 4)
    g.path([(6, 2), (10, 0)], 7)
    g.put(9, 3, "L")
    g.pts([(6, 5), (6, 6), (8, 7), (8, 8)], 8)
    g.pts([(7, 8), (9, 10)], "S")
    return g.rgba()


def wire_crawl(p):
    g = G(WIRE_W, WIRE_H)
    tail = ([(13, 9), (14, 9), (15, 8), (16, 8), (17, 9), (18, 10), (19, 10)] if p == 0 else
            [(13, 9), (14, 10), (15, 10), (16, 9), (17, 8), (18, 8), (19, 9)])
    g.pts([(x, y + 1) for x, y in tail], 1)                             # 电线的暗面
    g.pts(tail, 3)
    g.pts(tail[2::3], 5)                                                # 和挂着时一样，隔几格一个亮点
    g.box(7, 6, 12, 10, base=4, top=7, left=7, right=5, bottom=3)       # 插头横躺，插脚朝前
    g.pts([(5, 7), (6, 7), (5, 9), (6, 9)], 8)
    g.led(8, 8)
    return g.rgba()


def wire_frames():
    return [wire_plug(0), wire_plug(1), wire_plug(2), wire_swing(), wire_crawl(0), wire_crawl(1)]


# ---------------------------------------------------------------- 保险丝甲虫（帧 15×9，就是草图的画布）
# 帧：0 走 A（草图待机）、1 走 B（腿反着折）、2 熔丝烧红 A（草图"要炸了"）、3 熔丝烧红 B（火花换位置、熔丝中间发白）
FUSE_LED = (2, 3)


def fuse_walk_b():
    img = small.fuse(0)
    img[6:9] = 0
    g = G(15, 9)
    legs_b(g, [(4, 6), (7, 6), (10, 6)], 8)
    m = g.rgba()
    out = img.copy()
    out[m[..., 3] > 0] = m[m[..., 3] > 0]
    return out


def fuse_burn_b():
    g = G(15, 9)
    g.rect(3, 1, 11, 5, 6)
    g.rect(3, 1, 11, 1, 8)
    g.rect(3, 5, 11, 5, 4)
    g.box(1, 1, 3, 5, base=5, top=9, left=7, right=4, bottom=3)
    g.box(11, 1, 13, 5, base=5, top=9, left=6, right=4, bottom=3)
    g.rect(5, 3, 9, 3, "L")
    g.pts([(7, 3)], "S")                                                # 熔丝中间烧得发白
    g.led(*FUSE_LED)
    legs_b(g, [(4, 6), (7, 6), (10, 6)], 8)
    g.pts([(5, 0), (8, 0), (11, 0), (2, 0), (0, 2), (14, 5), (14, 1)], "S")
    return g.rgba()


def fuse_frames():
    return [small.fuse(0), fuse_walk_b(), small.fuse(1), fuse_burn_b()]


# ---------------------------------------------------------------- 手摇电话（帧 18×22，就是草图的画布）
# 帧：0 装死（草图待机，红灯不亮）、1 走 A（草图待机）、2 走 B（腿反着折）、
#     3 铃响 A（草图"摇铃叫人"）、4 铃响 B（铃回到原位、摇把在半中间、震动线换位置）
PHONE_LED = (8, 7)


def phone_draw(shake, crank_y, vib, walk_b=False):
    """照 small.phone 画：shake 铃往外抖几格，crank_y 摇把头的高度，vib 铃两边的震动线。"""
    g = G(18, 22)
    ox = 4
    g.box(ox, 4, ox + 9, 19, base="r1", top=8, left=7, right=5, bottom=3)
    g.rect(ox + 2, 13, ox + 7, 17, 2)
    g.rect(ox + 2, 13, ox + 7, 13, 4)
    for bx in (ox + 2, ox + 7):
        x = bx + (shake if bx > ox + 4 else -shake)
        g.disk(x, 2.5, 1.8, 7)
        g.put(x, 1, 9)
    g.path([(ox, 9), (ox - 2, 9), (ox - 3, 11)], 6)
    g.rect(ox - 4, 11, ox - 2, 12, 7)
    g.line(ox + 10, 8, ox + 12, crank_y, 6)
    g.put(ox + 12, crank_y, 8)
    g.led(*PHONE_LED)
    (legs_b if walk_b else legs)(g, [(ox + 2, 20), (ox + 7, 20)], 21, spread=1)
    g.pts(vib, 8)
    return g.rgba()


def phone_dead():
    img = small.phone(0)
    x, y = PHONE_LED
    img[y, x, :3] = RGB[2]                                              # 灯是黑的，看着就是一台旧电话
    return img


def phone_frames():
    ox = 4
    return [
        phone_dead(),
        small.phone(0),
        phone_draw(0, 10, [], walk_b=True),
        small.phone(1),
        phone_draw(0, 8, [(ox - 1, 1), (ox - 2, 3), (ox + 11, 1), (ox + 12, 3), (ox + 4, 0), (ox + 5, 0)]),
    ]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = [
        ("wire_snake", wire_frames(), WIRE_LED),
        ("fuse_beetle", fuse_frames(), {i: FUSE_LED for i in range(4)}),
        ("phone", phone_frames(), {i: PHONE_LED for i in range(1, 5)}),
    ]
    for name, frames, leds in jobs:
        img, w = strip(frames)
        Image.fromarray(img).save(OUT / f"{name}.png")
        print(name, img.shape[1], "x", img.shape[0], "帧宽", w, "帧数", len(frames), "红灯", leds)
        for i, (x, y) in leds.items():                                  # 核对红灯位置
            px = tuple(int(v) for v in img[y, i * w + x, :3])
            assert px == RGB["L"], (name, i, px)


if __name__ == "__main__":
    main()
