"""怪物图鉴卡片后面垫的背景：从关卡美术里裁一块，拼成一张图集 art/ui/bestiary_bg.png。
每格 CELL_W×CELL_H，按 PLACES 的顺序从左到右、从上到下排（scripts/ui/bestiary.gd 的 PLACES 要和这里同一个顺序）。
压暗、打码都在游戏里做（点亮的压暗，没点亮的更暗再打码），这里存原色。

跑：python3 tools/make_bestiary_bg.py（关卡美术改了以后重跑一次）
"""
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art"
CELL_W, CELL_H = 190, 110
COLS = 6

# 第三关各场景：在 level3_data.gd 的 SCREENS 里找这个场景最大的那块屏幕
L3_SCENES = ["workshop", "classroom", "subway", "rain_street", "rooftop", "living", "bedroom", "kids", "study",
             "bathroom", "attic", "kitchen", "beach", "aquarium", "snow_yard", "harbor", "desert", "forest", "space",
             "ferris", "weather", "test_card", "static"]
# 其他地方：[名字, 图, 裁剪框左上角 (x0, y0)，提亮倍数（原图太暗的提一点，不然压暗以后全黑）]
PLACES_FIXED = [
    ("factory", "l1", (300, 190), 1),       # 第一关锅炉房：齿轮和桁架
    ("exchange", "l2", (585, 325), 1),      # 第二关交换局：一排接线台
    ("bridge", "l2", (1700, 205), 1),       # 第二关胶片天桥：胶片和大片盘
    ("cinema", "l2", (3445, 230), 1),       # 第二关放映厅：倒数的银幕
    ("boss1", "art/boss/room_bg.png", (89, 70), 1),
    ("boss2", "art/boss/room2_bg.png", (150, 110), 1.8),
    ("boss3", "art/boss/room3_bg.png", (89, 70), 1),
]
PLACES = [p[0] for p in PLACES_FIXED] + ["l3_" + s for s in L3_SCENES]


def level2() -> Image.Image:
    img = Image.new("RGBA", (3700, 600), (0, 0, 0, 255))
    for layer in ("far", "mid", "main"):
        img.alpha_composite(Image.open(ART / f"levels/level2_{layer}_0.png").convert("RGBA"), (0, 0))
        img.alpha_composite(Image.open(ART / f"levels/level2_{layer}_1.png").convert("RGBA"), (2048, 0))
    data = (ROOT / "scripts/levels/level2_data.gd").read_text()
    a_x1 = int(re.search(r"const A_X1 := (\d+)", data).group(1))
    film_top = int(re.search(r"const FILM_TOP := (\d+)", data).group(1))
    img.alpha_composite(Image.open(ART / "levels/level2_film.png").convert("RGBA"), (a_x1, film_top))
    return img


def level1() -> Image.Image:
    img = Image.new("RGBA", (1006, 426), (0, 0, 0, 255))
    for name in ("scene1_far", "scene1_truss", "scene1_machines", "scene1_beams", "scene1"):
        p = ART / f"levels/{name}.png"
        if p.exists():
            img.alpha_composite(Image.open(p).convert("RGBA"))
    return img


def l3_screens() -> dict:
    data = (ROOT / "scripts/levels/level3_data.gd").read_text()
    best = {}
    for m in re.finditer(r'\{"name": "(\w+)".*?"rect": \[(\d+), (\d+), (\d+), (\d+)\]', data):
        name = m.group(1)
        r = tuple(int(m.group(i)) for i in range(2, 6))
        area = (r[2] - r[0]) * (r[3] - r[1])
        if name not in best or area > best[name][0]:
            best[name] = (area, r)
    return {k: v[1] for k, v in best.items()}


def cover(img: Image.Image, box) -> Image.Image:
    """把 box 那块按整数倍放大到能盖满一格，再从中间裁出一格（最近邻，像素不糊）"""
    piece = img.crop(box)
    k = 1
    while piece.width * k < CELL_W or piece.height * k < CELL_H:
        k += 1
    piece = piece.resize((piece.width * k, piece.height * k), Image.NEAREST)
    x0 = (piece.width - CELL_W) // 2
    y0 = (piece.height - CELL_H) // 2
    return piece.crop((x0, y0, x0 + CELL_W, y0 + CELL_H))


def main() -> None:
    l1, l2 = level1(), level2()
    screens_img = Image.new("RGBA", (4639, 1200), (0, 0, 0, 255))
    for layer in ("l3_far", "l3_screens"):
        screens_img.alpha_composite(Image.open(ART / f"levels/{layer}.png").convert("RGBA"))
    screens = l3_screens()
    cells = []
    for name, src, (x, y), gain in PLACES_FIXED:
        img = l1 if src == "l1" else l2 if src == "l2" else Image.open(ROOT / src).convert("RGBA")
        cell = img.crop((x, y, x + CELL_W, y + CELL_H)).convert("RGB")
        if gain != 1:
            cell = cell.point(lambda v: min(255, int(v * gain)))
        cells.append(cell)
    for s in L3_SCENES:
        r = screens[s]
        # 屏幕边框往里缩 4 格，只要画面
        cells.append(cover(screens_img, (r[0] + 4, r[1] + 4, r[2] - 4, r[3] - 4)))
    rows = (len(cells) + COLS - 1) // COLS
    atlas = Image.new("RGBA", (COLS * CELL_W, rows * CELL_H), (0, 0, 0, 255))
    for i, c in enumerate(cells):
        atlas.paste(c.convert("RGBA"), ((i % COLS) * CELL_W, (i // COLS) * CELL_H))
    out = ART / "ui/bestiary_bg.png"
    atlas.convert("RGB").save(out)
    print(out, atlas.size, len(cells), "cells")
    print("PLACES =", PLACES)


if __name__ == "__main__":
    main()
