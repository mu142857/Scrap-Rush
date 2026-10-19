"""教学关的五台电视（房间）：用第三关的画法（草图/第三关/）把五个场景各画成一整台电视（外壳 + 屏幕），
导出到 oscar-rush/art/tutorial/room_<i>.png，屏幕里家具的单向平台导出到 scripts/tutorial/tutorial_data.gd。
    "~/Desktop/程序programs/AI Oscar/.venv/bin/python" 草图/教学关/render_rooms.py
"""
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "第三关"))
import crt_wall_v2 as k  # noqa: E402
from crt_wall_v2 import KHAKI, WOOD, GREY, PLUM, TV  # noqa: E402

GAME = HERE.parent.parent / "oscar-rush"
ART = GAME / "art/tutorial"
ART.mkdir(parents=True, exist_ok=True)

# 外壳 456×265 → 屏幕玻璃 440×240，1 倍镜头正好装下
TW, TH = 456, 265
# 每一步一台电视：(场景, 显示方式, 外壳配色)
ROOMS = [("bedroom", "color", KHAKI), ("living", "color", WOOD), ("attic", "amber", GREY),
         ("kitchen", "color", PLUM), ("kids", "color", KHAKI)]

k.setup(TW + 20, TH + 20, TH + 10)
import l3_registry as reg  # noqa: E402
import l3_scenes as sc  # noqa: E402

out = []
for i, (name, tint, P) in enumerate(ROOMS):
    W, H = TW + 20, TH + 20
    k.setup(W, H, H - 10)
    random.seed(11 + i)
    k.rng = np.random.default_rng(11 + i)
    tv = TV(10, 10, TW, TH, P, "meter", tint, top="vents")
    tv.tint = tint
    tv.flat = name in reg.FLAT
    tv.outdoor = name in reg.OUTDOOR
    tv.name = name
    tv.draw_shell()
    before = k.scr.a.copy()
    k.set_vp(tv)
    n0 = len(sc.PLATFORMS)
    reg.draw(name, tv)
    outside = ~tv.screen_mask()
    k.scr.a[outside] = before[outside]
    img = np.zeros((H, W, 4), np.uint8)
    for layer in (k.mid, k.scr, k.near):
        m = layer.a[..., 3] > 0
        img[m] = layer.a[m]
    crop = Image.fromarray(img).crop((tv.x0, tv.y0, tv.x1 + 1, tv.y1 + 1))
    crop.save(ART / f"room_{i}.png")
    plats = [(a - tv.x0, b - tv.x0, y - tv.y0) for a, b, y in sc.PLATFORMS[n0:]]
    out.append({"scene": name, "glass": (tv.sx0 - tv.x0, tv.sy0 - tv.y0, tv.sx1 - tv.x0, tv.sy1 - tv.y0),
                "floor": tv.fy - tv.y0, "plats": plats})
    print("room", i, name, crop.size, "floor", tv.fy - tv.y0, "plats", len(plats))

lines = ['## 教学关五台电视的数据（草图/教学关/render_rooms.py 生成，别手改）。坐标相对于每台电视的左上角。',
         'const SIZE := Vector2(%d, %d)' % (TW, TH), 'const ROOMS := [']
for r in out:
    g = r["glass"]
    pl = ", ".join("[%d, %d, %d]" % p for p in r["plats"])
    lines.append('\t{"scene": "%s", "glass": Rect2(%d, %d, %d, %d), "floor": %d, "plats": [%s]},' % (
        r["scene"], g[0], g[1], g[2] - g[0] + 1, g[3] - g[1] + 1, r["floor"], pl))
lines.append("]")
(GAME / "scripts/tutorial/tutorial_data.gd").write_text("\n".join(lines) + "\n")
print("wrote tutorial_data.gd")
