"""中文模式自查：代码里给玩家看的英文有没有都进 text.csv、译文里的字字体里有没有。

    python3 tools/check_text.py

1. 扫 scripts/（不含 debug/）里所有引号字符串，挑出像"给玩家看的英文"的（有两个以上连续字母、
   不是路径 / 动作名 / 属性路径 / 纯小写标识符），不在 localization/text.csv 第一列的列出来。
   会有少量误报（内部用的大写字符串），确认不是给玩家看的就加进下面的 IGNORE。
2. text.csv 里每句中文的每个字，fonts/PixelFont.ttf 里都得有，不然游戏里是方框。缺字就跑 tools/subset_font.py。
3. 格式串检查：英文和中文的 %d / %s 个数、{jump} 这类占位符要一样，不然游戏里会报错；
   带占位符的句子在代码里要先 tr() 再填数（tr("Hold %s to climb") % key），没包的列出来。
"""
import csv
import re
import sys
from pathlib import Path

from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
CSV = ROOT / "localization/text.csv"
FONT = ROOT / "fonts/PixelFont.ttf"

## 不是给玩家看的（内部用的名字、信号、分组……），或者故意不翻的
IGNORE = {
    "SCRAP RUSH",  # Logo，不翻
    "RED",  # 主角名，不翻
    "CH%d",  # 老电视屏幕上的频道号，3×5 自画字只认 C、H 和数字
    "BRIDGE_TRIGGER", "Master", "Music", "SFX", "UI", "Ambience", "RESTART", "TITLE", "ENGLISH",  # 音频总线、菜单内部选项名
    "LanternAura", "SCRAP_NO_AUTOPAUSE",
    "Encounter",  # find_children 用的类名
    "Aaron Mumu", "Godot Engine\n\n", "Uranus Pixel 11Px / WenQuanYi Bitmap Song\n",  # 制作人员页的人名、引擎名、字体名
    "Mumu", "Oscar", "Little Oscar", "Zpbrqols", "Wutong", "Ben2tu", "Rouri",  # 制作人员的名字
    "WASD", "LB/RB", "LT/RT", "Tab", "Q/E",  # 按键名，两种语言一样
    "LEVEL ",  # 图鉴里拼成 "LEVEL 1/2/3" 再 tr，那几条在表里
    "SPEED",  # 图鉴按常量名找怪的速度（SPEED_NAMES），不是界面字
    "LEVEL %d",  # level_intro 先拼成 "LEVEL 1/2/3" 再 tr，那几条在表里
    "SCRAP-TEK 86   BIOS v1.986", "%dK",  # 第三关开机画面的品牌行和内存数，画面道具，不翻
    "LB", "RB", "LS", "RS", "Share", " / RT",  # 手柄按钮缩写，两种语言一样
    "WINDUP",  # 精英招式常量名（reveal_moves）
}
## 路径、动作名、属性路径、调试输出（"[tube] t=..."）
SKIP = re.compile(r"^(\[\w+\]|res://|user://|ui_|--|#|%s_|modulate|position|global_position|rotation|scale|color:|self_modulate|offset|parameters/)")
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')


def unescape(s: str) -> str:
    return s.replace('\\"', '"').replace("\\n", "\n").replace("\\t", "\t").replace("\\\\", "\\")


def code_strings():
    for gd in sorted((ROOT / "scripts").rglob("*.gd")):
        if "debug" in gd.parts:
            continue
        text = gd.read_text(encoding="utf-8")
        for m in re.finditer(r'"""(.*?)"""', text, re.S):
            body = m.group(1)
            if "shader_type" not in body and "uniform" not in body:
                yield gd, text[: m.start()].count("\n") + 1, body
        text = re.sub(r'"""(.*?)"""', lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
        for i, line in enumerate(text.splitlines(), 1):
            if line.strip().startswith("#"):
                continue
            for m in STRING.finditer(line):
                yield gd, i, unescape(m.group(1))


def main() -> int:
    with open(CSV, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))[1:]
    keys = {r[0] for r in rows}
    problems = 0

    for gd, line, s in code_strings():
        # 带 %d / %s / {jump} 的句子要先翻再填数，代码里得写成 tr("…") % …，不然 Label 对不上原文、一直是英文
        if s in keys and re.search(r"%[ds]|\{\w+\}", s):
            src = (ROOT / gd).read_text(encoding="utf-8").splitlines()[line - 1] if line > 0 else ""
            lit = '"' + s.replace("\n", "\\n").replace('"', '\\"') + '"'
            # 只抓「字面量后面直接 % 或 .format(」的写法；写在数据表里、用的时候再 tr 的不算
            used_raw = re.search(re.escape(lit) + r"\s*(%|\.format\()", src)
            if used_raw and not src[: used_raw.start()].rstrip().endswith("tr("):
                print(f"格式串没包 tr()：{gd.relative_to(ROOT)}:{line}  {s!r}")
                problems += 1
            continue
        if s in keys or s in IGNORE or not re.search(r"[A-Za-z]{2,}", s) or SKIP.match(s):
            continue
        if re.fullmatch(r"[a-z0-9_/.\-%:]+", s) or re.fullmatch(r"[A-Za-z]+_[A-Za-z_0-9]+", s) \
                or re.fullmatch(r"(?:[A-Z][a-z0-9]+){2,}[A-Z0-9]*", s):  # 驼峰式类名（CanvasLayer、ShopStand、PointLight2D）
            continue
        if re.search(r"[一-鿿]", s):  # 中文写的（调试名、注释式字符串），不归这里管
            continue
        if re.fullmatch(r"[.#oOX]+", s):  # 像素图案（"..XX.."、"#oOo#"）
            continue
        src_line = (ROOT / gd).read_text(encoding="utf-8").splitlines()[line - 1] if line > 0 else ""
        if re.search(r"\bprint(_rich|err)?\(", src_line):  # 调试输出
            continue
        lit = re.escape('"' + s + '"')
        if re.search(r"\[\s*" + lit + r"\s*\]|\.get\(\s*" + lit, src_line):  # 字典取值 d["KEY"] / d.get("KEY")，是常量名
            continue
        print(f"没进 text.csv：{gd.relative_to(ROOT)}:{line}  {s!r}")
        problems += 1

    cmap = TTFont(FONT).getBestCmap()
    for key, zh, *_ in rows:
        miss = sorted({c for c in zh if c not in "\n\t" and ord(c) not in cmap})
        if miss:
            print(f"缺字（会是方框）：{''.join(miss)}  ← {zh!r}")
            problems += 1
        for pat in (r"%[ds]", r"\{\w+\}"):
            if sorted(re.findall(pat, key)) != sorted(re.findall(pat, zh)):
                print(f"占位符对不上：{key!r} → {zh!r}")
                problems += 1

    print(f"text.csv {len(rows)} 条；问题 {problems} 个")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
