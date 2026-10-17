"""场景样张：每种场景画三块屏幕（大 444×245、中 270×190、小 130×100 的玻璃），几秒钟出图，改场景时用。

    python scene_gallery.py                 全部场景，出 预览场景/<名字>.png 和 预览场景/_总览.png
    python scene_gallery.py living kitchen  只出这几个
    python scene_gallery.py --tint=amber    全用某种显示方式（默认每块屏幕用这种场景的第一种）
用 "~/Desktop/程序programs/AI Oscar/.venv/bin/python" 跑。
"""
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import crt_wall_v2 as k
from crt_wall_v2 import KHAKI, WOOD, GREY, PLUM, TV

HERE = Path(__file__).parent
OUT = HERE / "预览场景"
OUT.mkdir(exist_ok=True)
SIZES = [(460, 270), (286, 215), (146, 125)]          # 外壳大小；玻璃 = 外壳 - (16, 25)
args = [a for a in sys.argv[1:] if not a.startswith("--")]
tint_arg = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--tint=")), None)

k.setup(1000, 300, 290)
import l3_registry as reg  # noqa: E402
import l3_scenes as sc  # noqa: E402

names = args or (list(reg.SCENES) + ["entry", "hometown"])
FONT = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 16)
shots = []
for name in names:
    W = sum(w for w, h in SIZES) + 10 * (len(SIZES) + 1)
    H = max(h for w, h in SIZES) + 20
    k.setup(W, H, H - 10)
    random.seed(7)
    k.rng = np.random.default_rng(7)
    x = 10
    for i, (w, h) in enumerate(SIZES):
        tv = TV(x, H - 10 - h, w, h, [KHAKI, WOOD, GREY][i], "meter", "color", top="vents" if w > 180 else None)
        tints = reg.SCENES[name][2] if name in reg.SCENES else ["color"]
        tv.tint = tint_arg or tints[0]
        tv.flat = name in reg.FLAT
        tv.outdoor = name in reg.OUTDOOR
        tv.name = name
        tv.draw_shell()
        before = k.scr.a.copy()
        k.set_vp(tv)
        try:
            reg.draw(name, tv)
        except Exception as e:                      # 小屏放不下的场景照样出图，标出来
            print(f"  {name} {w}x{h}: {e!r}")
        outside = ~tv.screen_mask()
        k.scr.a[outside] = before[outside]
        x += w + 10
    img = np.zeros((H, W, 4), np.uint8)
    img[..., :3] = (24, 22, 30)
    img[..., 3] = 255
    for layer in (k.mid, k.scr, k.near):
        m = layer.a[..., 3] > 0
        img[m] = layer.a[m]
    pic = Image.fromarray(img).convert("RGB")
    tag = f"{name}（{reg.OVERRIDDEN.get(name, '旧画法')}）"
    big = pic.resize((pic.width * 2, pic.height * 2), Image.NEAREST)
    ImageDraw.Draw(big).text((20, 6), tag, fill=(240, 230, 200), font=FONT)
    big.save(OUT / f"{name}.png")
    shots.append((tag, pic))
    print("ok", name)

if len(shots) > 1:
    cols = 2
    cw, ch = shots[0][1].width, shots[0][1].height + 22
    rows = (len(shots) + cols - 1) // cols
    sheet = Image.new("RGB", (cw * cols, ch * rows), (14, 14, 18))
    d = ImageDraw.Draw(sheet)
    for i, (tag, pic) in enumerate(shots):
        x, y = (i % cols) * cw, (i // cols) * ch
        sheet.paste(pic, (x, y + 20))
        d.text((x + 8, y + 2), tag, fill=(240, 230, 200), font=FONT)
    sheet.save(OUT / "_总览.png")
