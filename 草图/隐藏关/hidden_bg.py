"""隐藏关的房间背景（放映机会话，10-18）：从第三关的场景脚本出"自家版"回忆场景，铺满一个房间。

    "/Users/jiamulin/Desktop/程序programs/AI Oscar/.venv/bin/python" hidden_bg.py <房间id>=<场景名>[:宽x高] ...
    例：hidden_bg.py R1=hometown R2=living:720x270

做法：照 草图/第三关/scene_gallery.py，造一台"玻璃正好等于房间大小"的电视，让第三关的场景画进去，只取玻璃里面的画面
（扫描线、暗角、反光都留着：这一关本来就在录像带里）。然后整张压暗、褪色一点，免得抢了暖色回忆木板和冷色废铁平台。
输出 oscar-rush/art/hidden/bg_<id>.png。
"""
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
L3 = HERE.parent / "第三关"
sys.path.insert(0, str(L3))
sys.path.insert(0, "/Users/jiamulin/Desktop/程序programs/AI Oscar")
import crt_wall_v2 as k  # noqa: E402
from crt_wall_v2 import GREY, TV  # noqa: E402

k.setup(1000, 300, 290)
import l3_registry as reg  # noqa: E402
from oscarkit.measure import srgb_to_oklab  # noqa: E402
from oscarkit.palette import oklab_to_srgb  # noqa: E402

OUT = HERE.parents[1] / "oscar-rush/art/hidden"


def render(name, w, h, tint=None, seed=7):
    """第三关的场景 name 画进一块 w×h 的玻璃，返回 h×w×4。"""
    W, H = w + 17 + 20, h + 26 + 20
    k.setup(W, H, H - 10)
    random.seed(seed)
    k.rng = np.random.default_rng(seed)
    tv = TV(10, 10, w + 17, h + 26, GREY, "meter", "color", top=None)
    tints = reg.SCENES[name][2] if name in reg.SCENES else ["color"]
    tv.tint = tint or tints[0]
    tv.flat = name in reg.FLAT
    tv.outdoor = name in reg.OUTDOOR
    tv.name = name
    tv.draw_shell()
    k.set_vp(tv)
    reg.draw(name, tv)
    img = np.zeros((H, W, 4), np.uint8)
    img[..., :3] = (24, 22, 30)
    img[..., 3] = 255
    for layer in (k.mid, k.scr, k.near):
        m = layer.a[..., 3] > 0
        img[m] = layer.a[m]
    return img[tv.sy0:tv.sy0 + h, tv.sx0:tv.sx0 + w].copy(), (tv.sx1 - tv.sx0, tv.sy1 - tv.sy0)


def fade(img, gain=0.72, chroma=0.7, lift=0.03, mean_cap=0.36):
    """压暗、褪色：按颜色一一映射（不多出颜色）。亮的场景（米色客厅）多压一点：
    整张平均明度压到 mean_cap 以下，暖色回忆木板（OKLab 明度约 0.8）才跳得出来。"""
    a = img.copy()
    m = a[..., 3] > 0
    cols, inv = np.unique(a[m][:, :3], axis=0, return_inverse=True)
    lab = srgb_to_oklab(cols.astype(np.uint8))
    mean_l = float(srgb_to_oklab(a[m][:, :3].astype(np.uint8))[:, 0].mean())
    gain = min(gain, (mean_cap - lift) / max(1e-3, mean_l))
    lab[:, 0] = lift + gain * lab[:, 0]
    lab[:, 1:] *= chroma
    out = oklab_to_srgb(lab)
    px = a[m]
    px[:, :3] = out[inv.reshape(-1)]
    a[m] = px
    return a


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for arg in sys.argv[1:]:
        rid, spec = arg.split("=", 1)
        name, _, size = spec.partition(":")
        w, h = (int(v) for v in size.split("x")) if size else (480, 270)
        img, glass = render(name, w, h)
        img = fade(img)
        Image.fromarray(img).save(OUT / f"bg_{rid}.png")
        kb = (OUT / f"bg_{rid}.png").stat().st_size // 1024
        print(f"bg_{rid}.png  {name}  {w}x{h}  玻璃 {glass}  {kb} KB")


if __name__ == "__main__":
    main()
