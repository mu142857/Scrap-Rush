"""第三关的场景清单：名字 → (画法, 最小屏宽, 能用的显示方式)。地图脚本 crt_level3.py 和样张工具 scene_gallery.py 共用。

改场景（2026-10-17 起）：不要直接改 l3_scenes.py / crt_wall_v2.py 里的旧画法，
新建 scenes_v3_<组名>.py，写 SCENES_V3 = {"living": 新函数, ...}，这里会自动换成新的。
新函数 fn(tv)：在 tv.sx0..sx1 × tv.sy0..sy1 的屏幕里画完整个场景（最后调 k.finish_room(tv, 灯的位置)），
能站的东西用 l3_scenes.plat(x0, x1, y) 登记成单向平台。
"""
import importlib
from pathlib import Path

import crt_wall_v2 as k
import l3_scenes as sc

ROOMS = {"kitchen": k.room_kitchen, "living": k.room_living, "bedroom": k.room_bedroom,
         "kids": k.room_kids, "study": k.room_study, "entry": k.room_entry}
SCENES = {
    "kitchen": (k.room_kitchen, 130, ["color", "bw"]), "living": (k.room_living, 140, ["color", "amber"]),
    "bedroom": (k.room_bedroom, 130, ["bw", "color"]), "kids": (k.room_kids, 130, ["green", "color"]),
    "study": (k.room_study, 140, ["amber"]), "bathroom": (sc.sc_bathroom, 130, ["color", "bw"]),
    "workshop": (sc.sc_workshop, 140, ["amber", "color"]), "subway": (sc.sc_subway, 150, ["amber", "bw"]),
    "classroom": (sc.sc_classroom, 150, ["color", "green"]), "ferris": (sc.sc_ferris, 150, ["color"]),
    "rooftop": (sc.sc_rooftop, 130, ["color", "amber"]), "beach": (sc.sc_beach, 140, ["color"]),
    "harbor": (sc.sc_harbor, 130, ["color", "bw"]), "rain_street": (sc.sc_rain_street, 130, ["bw"]),
    "snow_yard": (sc.sc_snow_yard, 120, ["color"]), "forest": (sc.sc_forest, 110, ["green", "color"]),
    "aquarium": (sc.sc_aquarium, 80, ["color", "green"]), "space": (sc.sc_space, 100, ["color"]),
    "weather": (sc.sc_weather, 80, ["color"]), "test_card": (sc.sc_test_card, 70, ["color"]),
    "static": (sc.sc_static, 70, ["color"]), "attic": (sc.sc_attic, 100, ["amber"]),
    "desert": (sc.sc_desert, 100, ["color", "amber"]),
}
SPECIAL = {"entry": k.room_entry, "hometown": sc.sc_hometown}
FLAT = {"test_card", "weather", "static"}
OUTDOOR = {"beach", "harbor", "rain_street", "snow_yard", "forest", "aquarium", "space", "desert", "rooftop", "ferris", "hometown"}

OVERRIDDEN = {}
for f in sorted(Path(__file__).parent.glob("scenes_v3_*.py")):
    mod = importlib.import_module(f.stem)
    for name, fn in getattr(mod, "SCENES_V3", {}).items():
        OVERRIDDEN[name] = f.stem
        if name in SCENES:
            SCENES[name] = (fn,) + SCENES[name][1:]
        if name in SPECIAL:
            SPECIAL[name] = fn
        ROOMS.pop(name, None)


def draw(name, tv):
    """画一个场景。旧的房间函数由 l3_scenes.room 包一层（登记家具平台）；返回值只有家乡用（门口的位置）。"""
    fn = SCENES[name][0] if name in SCENES else SPECIAL[name]
    if name in ROOMS:
        return sc.room(ROOMS[name], tv)
    return fn(tv)
