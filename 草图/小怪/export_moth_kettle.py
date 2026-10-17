"""把扑灯蛾、汽壶的定稿草图导出成游戏用的动画横条（等宽帧，原图朝左，地面是最后一行）。

    python3 export_moth_kettle.py

扑灯蛾 moth.png（13×11，3 帧）：0 翅膀平展、1 翅膀上收（这两帧来回扇）、2 俯冲（草图的动作帧）。红灯 (5, 4)。
汽壶 kettle.png（16×22，3 帧）：0 平时、1 壶盖顶起一格、2 壶盖顶起并往右歪一格（1、2 来回抖 = 喷汽前摇）。红灯 (6, 15)。
"""
from pathlib import Path

import numpy as np
from PIL import Image

import small

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "oscar-rush" / "art" / "enemies"


def strip(frames):
    h, w = frames[0].shape[:2]
    assert all(f.shape[:2] == (h, w) for f in frames)
    return np.concatenate(frames, axis=1)


def moth_frames():
    flat = small.moth(0)
    dive = small.moth(1)
    up = dive.copy()
    for x, y in [(1, 8), (3, 9)]:                       # 去掉俯冲帧里的速度点，就是普通的"翅膀上收"
        up[y, x] = 0
    return [flat, up, dive]


def kettle_frames():
    base = small.kettle(0)
    lid = (slice(9, 12), slice(5, 11))                   # 壶盖和钮：y 9~11，x 5~10

    def lifted(dx):
        f = base.copy()
        piece = base[lid].copy()
        f[lid] = 0
        f[11, 3:13] = base[12, 3:13]                     # 壶盖底下露出壶口那一行
        f[8:11, 5 + dx:11 + dx] = np.where(piece[..., 3:4] > 0, piece, f[8:11, 5 + dx:11 + dx])
        return f
    return [base, lifted(0), lifted(1)]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, frames in [("moth", moth_frames()), ("kettle", kettle_frames())]:
        Image.fromarray(strip(frames)).save(OUT / f"{name}.png")
        h, w = frames[0].shape[:2]
        print(name, f"{w}x{h}", len(frames), "帧")
        big = Image.fromarray(strip(frames)).resize((w * len(frames) * 8, h * 8), Image.NEAREST)
        bg = Image.new("RGBA", big.size, (104, 102, 110, 255))
        bg.alpha_composite(big)
        bg.save(HERE / f"_preview_{name}.png")


if __name__ == "__main__":
    main()
