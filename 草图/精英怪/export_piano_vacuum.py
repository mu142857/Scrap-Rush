"""自动钢琴、吸尘器的游戏用动画横条（草图在 elites.py，这里只补游戏里要的帧，不改 elites.py）。

    python3 export_piano_vacuum.py    # 输出到 oscar-rush/art/enemies/piano.png、vacuum.png

横排等宽帧，原图朝左，地面是最后一行。所有帧用同一个外框裁掉四周的空白，
身子落在帧的正中间（EnemyBase 按帧宽的一半对齐脚底中点，朝右时整帧水平翻转）。
地面上顶起来的琴键柱由 piano.gd 用代码画，这里不画。

piano.png  7 帧：0~3 待机（穿孔纸卷往上走），4 预警（琴键抬起一半），5、6 放招（琴键一根根轮流翘起来）
vacuum.png 7 帧：0、1 走（软管波纹和小轮子转），2 预警（吸头抬到一半），3、4 吸（灰一串串往嘴里飞），
           5 噗（嘴张大往外喷），6 喷完往后一缩
"""
from pathlib import Path

import numpy as np

import elites
from elites import G, RGB

OUT = Path(__file__).resolve().parents[2] / "oscar-rush/art/enemies"


def over(base, g):
    """把画布 g 里画了的像素盖到 base 上。"""
    out = base.copy()
    top = g.rgba()
    m = top[..., 3] > 0
    out[m] = top[m]
    return out


def clear(img, x0, y0, x1, y1):
    out = img.copy()
    out[y0:y1 + 1, x0:x1 + 1] = 0
    return out


def trim_all(frames):
    """所有帧用同一个外框；返回裁好的帧和裁掉的左上角（算像素位置用）。"""
    al = np.zeros(frames[0].shape[:2], bool)
    for f in frames:
        al |= f[..., 3] > 0
    ys, xs = np.nonzero(al)
    x0, y0 = xs.min(), ys.min()
    assert ys.max() == frames[0].shape[0] - 1, "地面要是最后一行"
    return [f[y0:, x0:xs.max() + 1] for f in frames], (x0, y0)


def save_strip(name, frames):
    h, w = frames[0].shape[:2]
    out = np.zeros((h, w * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        out[:, i * w:(i + 1) * w] = f
    from PIL import Image
    Image.fromarray(out).save(OUT / f"{name}.png")
    return w, h


# ---------------------------------------------------------------- 自动钢琴
P_OX = 8                      # elites.piano 里的 ox
P_W, P_H = 52, 32


def piano_roll(base, phase):
    """窗口里的穿孔纸卷往上走一格。孔的图案 4 行一循环，4 帧刚好接上。"""
    g = G(P_W, P_H)
    ox = P_OX
    rng = np.random.default_rng(11)
    holes = rng.random((4, 23)) < 0.28
    g.rect(ox + 10, 8, ox + 33, 11, 5)
    for i, x in enumerate(range(ox + 11, ox + 33)):
        for r, y in enumerate((8, 9, 10, 11)):
            if holes[(r + phase) % 4, i]:
                g.put(x, y, 2)
    g.led(ox + 21, 9, 2)
    return over(base, g)


def piano_keys(base, offset, rows):
    """键盘上的琴键翘起来：从 offset 开始每隔 6 格一组，rows 是翘起的行（14、15 全翘，只有 15 是一半）。"""
    g = G(P_W, P_H)
    ox = P_OX
    for x in range(ox + 1 + offset, ox + 43, 6):
        x1 = min(x + 2, ox + 42)
        g.rect(x, rows[0], x1, rows[-1], 8)
        g.rect(x, rows[0], x1, rows[0], 9)
    return over(base, g)


def piano_frames():
    idle = elites.piano(0)
    # elites 的放招图在钢琴左边画了三根地上的琴键，游戏里由代码画，这里清掉
    cast = clear(elites.piano(1), 0, 0, P_OX - 1, P_H - 1)
    frames = [piano_roll(idle, i) for i in range(4)]
    frames.append(piano_keys(piano_roll(idle, 0), 0, [15]))
    frames.append(piano_roll(cast, 1))
    # 另一半琴键翘起来：先把放招图里翘起的键擦回待机的样子，再从第 3 格开始翘
    alt = piano_roll(idle, 2)
    frames.append(piano_keys(alt, 3, [14, 15]))
    return frames


# ---------------------------------------------------------------- 吸尘器
V_OX = 6                      # elites.vacuum 里的 ox
V_W, V_H = 48, 24


def vacuum_walk2(base):
    """走路第二帧：软管上的亮节往前挪一格，两个小轮子的高光转到另一边。"""
    out = base.copy()
    ox = V_OX
    g = G(V_W, V_H)
    for x, y in [(ox + 10, 10), (ox + 8, 12), (ox + 6, 15)]:     # 原来的亮节抹回软管色
        g.put(x, y, 4)
    for x, y in [(ox + 11, 10), (ox + 9, 11), (ox + 7, 13), (ox + 5, 17)]:
        g.put(x, y, 6)
    for x in (ox + 17, ox + 33):
        g.put(x - 2, 19, 3)
        g.put(x, 21, 6)
    return over(out, g)


def vacuum_body_only():
    """去掉软管和吸头的罐身（预警帧在这上面画半抬的吸头）。"""
    return clear(elites.vacuum(0), 0, 5, V_OX + 11, V_H - 1)


def vacuum_lift():
    """预警：吸头离地抬到一半，斜着对准前方。"""
    g = G(V_W, V_H)
    ox = V_OX
    g.path([(ox + 12, 10), (ox + 7, 11), (ox + 4, 13)], 4)
    g.path([(ox + 12, 11), (ox + 7, 12), (ox + 4, 14)], 4)
    g.pts([(ox + 9, 11), (ox + 6, 12)], 6)
    g.poly([(0, 12), (4, 9), (8, 14), (4, 18), (0, 17)], 5)
    g.path([(0, 12), (4, 9)], 8)
    g.path([(4, 9), (8, 14)], 7)
    g.path([(0, 17), (4, 18)], 3)
    g.line(0, 13, 0, 16, 0)                                         # 嘴
    return over(vacuum_body_only(), g)


def vacuum_suck(phase):
    """吸：嘴前面的灰一串串往里飞，phase 让灰往嘴的方向挪一格。"""
    base = clear(elites.vacuum(1), 0, 0, V_OX - 2, V_H - 1)
    g = G(V_W, V_H)
    for y, x0 in [(7, 0), (10, 1), (13, 0)]:
        for x in range(x0 + phase, V_OX - 2, 2):
            g.put(x, y + (1 if x < 2 else 0), "S" if x > 2 else 6)
    return over(base, g)


def vacuum_spit(recoil):
    """噗：嘴张大（上下唇往外翻），往外喷一小团灰；recoil=1 时整个吸头往回缩一格。"""
    base = clear(elites.vacuum(1), 0, 0, V_OX + 3, 16)
    g = G(V_W, V_H)
    ox = V_OX
    hx = ox - 1 + recoil                                            # 吸头左边那一列
    g.path([(ox + 12, 10), (ox + 6, 9), (hx + 4, 10)], 4)
    g.path([(ox + 12, 11), (ox + 6, 10), (hx + 4, 11)], 4)
    g.box(hx, 5, hx + 4, 15, base=5, top=8, left=7, right=5, bottom=3)
    g.rect(hx, 7, hx, 13, 0)
    if not recoil:
        g.pts([(hx - 1, 5), (hx - 1, 4), (hx - 1, 15), (hx - 1, 16)], 7)  # 翻开的唇
        g.rect(hx - 1, 6, hx - 1, 14, 1)
        for x, y in [(hx - 3, 8), (hx - 4, 11), (hx - 3, 13), (hx - 5, 9), (hx - 5, 12)]:
            g.put(x, y, "S")
    return over(base, g)


def vacuum_frames():
    idle = elites.vacuum(0)
    return [idle, vacuum_walk2(idle), vacuum_lift(), vacuum_suck(0), vacuum_suck(1),
            vacuum_spit(0), vacuum_spit(1)]


def report(name, frames, origin, pixels):
    (x0, y0) = origin
    w, h = save_strip(name, frames)
    print(f"{name}.png: {len(frames)} 帧，每帧 {w}x{h}")
    for label, (px, py) in pixels.items():
        print(f"  {label}: 帧内像素 ({px - x0}, {py - y0})，相对脚底中点 ({px - x0 - w // 2}, {py - y0 - h})")


def main():
    pf, po = trim_all(piano_frames())
    report("piano", pf, po, {"红灯": (P_OX + 21, 9), "前脚": (P_OX + 3, P_H - 1)})
    vf, vo = trim_all(vacuum_frames())
    report("vacuum", vf, vo, {"红灯": (V_OX + 14, 8), "吸嘴（抬起）": (V_OX - 1, 10), "罐身左": (V_OX + 12, 5),
                              "罐身右": (V_OX + 39, 15), "吸头（平放）右": (V_OX + 8, 18)})


if __name__ == "__main__":
    main()
