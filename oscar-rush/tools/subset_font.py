"""把像素字体裁成只含用到的字，网页版小一些（原字体 1.3M，裁完一百多 K）。

    python3 tools/subset_font.py

完整的原字体：tools/fonts/PixelFont_full.ttf（天王星像素 11Px，GPLv2 + 字体嵌入例外，tools/ 不进导出包）。
输出：fonts/PixelFont.ttf（游戏实际用的，Hud.font() 读它）。字形原样保留，只是去掉没用到的字。

留下的字：
- 拉丁字母、常用标点、箭头、方块等符号整段保留（英文怎么改都不会缺字）；
- localization/text.csv 里所有译文用到的字；
- scripts/ 里字符串（引号里）出现的非 ASCII 字（比如 —、“”）。
改了 text.csv 或加了中文字符串以后重跑一次；跑完会检查一遍，缺字会报出来。
"""
import csv
import re
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
FULL = ROOT / "tools/fonts/PixelFont_full.ttf"
OUT = ROOT / "fonts/PixelFont.ttf"
CSV = ROOT / "localization/text.csv"

RANGES = [
    (0x0020, 0x024F),  # 拉丁
    (0x2000, 0x206F),  # 通用标点（— … “ ” ‘ ’）
    (0x20A0, 0x20CF),  # 货币
    (0x2100, 0x21FF),  # 字母式符号、箭头
    (0x2460, 0x24FF),  # 带圈数字
    (0x2500, 0x25FF),  # 制表符、方块、三角
    (0x2600, 0x26FF),  # 杂项符号
    (0x3000, 0x303F),  # 中文标点（、。「」）
    (0xFF00, 0xFFEF),  # 全角（，：！？（））
]


def wanted() -> set[int]:
    chars: set[int] = set()
    for a, b in RANGES:
        chars.update(range(a, b + 1))
    with open(CSV, encoding="utf-8", newline="") as f:
        for row in csv.reader(f):
            for cell in row:
                chars.update(ord(c) for c in cell)
    for gd in (ROOT / "scripts").rglob("*.gd"):
        for line in gd.read_text(encoding="utf-8").splitlines():
            code = line.split("#", 1)[0] if '"' not in line else line
            for s in re.findall(r'"((?:[^"\\]|\\.)*)"', code):
                chars.update(ord(c) for c in s if ord(c) > 0x7F)
    return {c for c in chars if c >= 0x20}


def main() -> None:
    full = TTFont(FULL)
    cmap = full.getBestCmap()
    keep = wanted()
    have = sorted(c for c in keep if c in cmap)
    opts = subset.Options()
    opts.name_IDs = ["*"]  # 版权、授权说明原样留着
    opts.name_languages = ["*"]
    opts.layout_features = ["*"]
    opts.notdef_outline = True
    opts.hinting = True
    opts.glyph_names = False
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=have)
    sub.subset(full)
    full.save(OUT)

    # 检查：译文里的字都得在
    out_cmap = TTFont(OUT).getBestCmap()
    missing = set()
    with open(CSV, encoding="utf-8", newline="") as f:
        for row in csv.reader(f):
            for c in row[1] if len(row) > 1 else "":
                if c not in "\n\t" and ord(c) not in out_cmap:
                    missing.add(c)
    print(f"{OUT.relative_to(ROOT)}: {len(out_cmap)} 个字，{OUT.stat().st_size // 1024} KB"
          f"（原字体 {FULL.stat().st_size // 1024} KB）")
    if missing:
        print("原字体里也没有这些字，换个说法：", "".join(sorted(missing)))


if __name__ == "__main__":
    main()
