"""第二关开场「气动管冲刺」的两张循环背景（左右能无缝接上），画法和褪色跟 level2_map.py 一样。

  level2_tube_far.png  960×270  远景：交换局大厅的砖墙、一只巨大的转盘拨号盘、电线杆和满天的电话线、零星信号灯
  level2_tube_mid.png  960×270  中景：暗的继电器架、吊着的配重球和线圈、远处别的气动管（竖着走，透明底）

游戏里（scripts/levels/tube_run.gd）两张图开 texture_repeat，按不同速度往左卷，三条玻璃管在 Godot 里画。
跑法："/Users/jiamulin/Desktop/程序programs/AI Oscar/.venv/bin/python" level2_tube_art.py
"""
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import level2_map as M  # noqa: E402
from oscarkit.canvas import Canvas  # noqa: E402

TW, TH = 960, 270


def tile_far():
    c = Canvas(TW, TH)
    M.fill(c, 0, 0, TW - 1, TH - 1, M.VOID)
    M.vgrad(c, 0, 0, TW - 1, TH - 1, M.DARK, 0.2, 0.75)
    for y in range(0, TH, 8):                                  # 砖缝（周期 32，960 能整除）
        for x in range(TW):
            M.nudge(c, x, y, -1)
            if (x + (16 if (y // 8) % 2 else 0)) % 32 == 0:
                for t in range(1, 8):
                    M.nudge(c, x, y + t, -1)
    M.rotary_dial(c, 300, 150, 96)
    poles = [(120, 20), (600, 34)]
    for x, top in poles:
        for dx in (0, -TW, TW):
            M.telephone_pole(c, x + dx, top, TH)
    pairs = [((120, 20), (600, 34)), ((600, 34), (120 + TW, 20))]
    for (ax, at), (bx, bt) in pairs:
        for k, dy in enumerate((6, 14, 22)):
            for side in (-18, 0, 18):
                for off in (0, -TW):                            # 跨过右边界的那段在左边再画一遍
                    M.wire(c, ax + side + off, at + dy, bx + side + off, bt + dy, 16 + k * 6, ramp=M.FAR_WIRE)
    rng = np.random.default_rng(5)
    for _ in range(26):
        c.put(int(rng.integers(0, TW)), int(rng.integers(10, TH - 10)), M.LAMP_OFF if rng.random() < 0.7 else M.LAMP)
    return c


def tile_mid():
    c = Canvas(TW, TH)
    for i, x in enumerate((40, 330, 700)):
        M.relay_rack(c, x, 20 + (i % 2) * 40, x + 44, TH - 1, lit=0.12, seed=i, dim=True)
    for x, by in ((200, 60), (520, 230), (860, 90)):
        M.hang_rod(c, x, 0, by, knobs=(by - 26,))
        M.ball(c, x, by + 12, 11)
    for x, cy in ((450, 40), (80, 250)):
        M.hang_rod(c, x, 0, cy - 9)
        M.coil(c, x, cy)
    # 远处别的气动管一律竖着走（10-18 新玩家报告：原来两根横管和能走的三条道同方向、同颜色，像第 4、5 条道）
    for x in (270, 610, 930):
        M.pipe(c, [(x, 0), (x, TH - 1)], dim=True)
    return c


def main():
    far, mid = tile_far(), tile_mid()
    M.fade(far)
    M.fade(mid)
    far.save(M.ART / "level2_tube_far.png")
    mid.save(M.ART / "level2_tube_mid.png")
    prev = Canvas(TW, TH, arr=far.a)
    m = mid.a[..., 3] > 0
    prev.a[m] = mid.a[m]
    prev.save(M.MAPDIR / "level2_tube_bg_preview.png", scale=2)
    print("ok")


if __name__ == "__main__":
    main()
