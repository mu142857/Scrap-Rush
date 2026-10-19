class_name Lang
extends RefCounted
## 中文模式：English / 中文 两种语言，设置里的 LANGUAGE 一项切换，当场生效。
##
## 译文全在 res://localization/text.csv：第一列 keys 是代码里的英文原文，zh 列是中文。
## 代码里给玩家看的字照旧写英文：
## - 固定的英文直接塞进 Label.text 就行，不用改：Label 会按当前语言自动翻，切语言时自己换；
## - 要拼接、格式化（%s、%d、format）、按字数打字、量宽度，或者用 draw_string 画的，
##   先 tr("英文原文") 再用（静态函数里用 TranslationServer.translate）；
## - 改了英文原文，text.csv 里那一行的 key 也要跟着改，不然中文版那句就变回英文。
## 加了新字：往 text.csv 加一行，再跑 python3 tools/subset_font.py 重新生成字体子集
## （fonts/PixelFont.ttf 留 GB2312 一级常用字 + 用到的字，完整的原字体在 tools/fonts/）。
##
## Settings.language：""= 没选过，用英文（10-19 起不再跟随系统），"en"、"zh" = 玩家选过。
## 字体：天王星像素 11Px（文泉驿点阵宋体 11px 的矢量版，GPLv2 + 字体嵌入例外），英文和中文同一套，
## 11 号字一个汉字正好 11×11 像素；22、33 号是整 2、3 倍。

const TRANSLATION := "res://localization/text.zh.translation"
const LANGS: Array[String] = ["en", "zh"]
## 语言名用它自己的语言写，切到看不懂的语言也能切回来
const NAMES := {"en": "ENGLISH", "zh": "中文"}

static var _loaded := false


static func apply(language: String) -> void:
	if not _loaded:
		_loaded = true
		if ResourceLoader.exists(TRANSLATION):
			TranslationServer.add_translation(load(TRANSLATION))
		else:
			push_warning("没找到 %s：text.csv 还没导入（编辑器里切一下窗口就会导入）" % TRANSLATION)
	TranslationServer.set_locale(resolve(language))


## "" = 玩家没选过：一律英文（10-19 作者："导出一个版本，默认英文的"；以前是跟随系统 / 浏览器语言）。
## 设置里切成中文会存成 "zh"，以后照存的来
static func resolve(language: String) -> String:
	if language in LANGS:
		return language
	return "en"


static func current() -> String:
	return "zh" if TranslationServer.get_locale().begins_with("zh") else "en"


static func is_zh() -> bool:
	return current() == "zh"


## 22 号大字菜单的行距：英文大写字只有十几像素高，中文一个字满 22 像素，
## 英文原来的行距（19、20）会让上下两行的字贴在一起，中文时拉到 25
static func menu_step(en_step: float) -> float:
	return maxf(en_step, 25.0) if is_zh() else en_step


## 多行小字收紧行距用：英文大写只有十几像素高，收紧 2 像素刚好；中文字满 11 像素，再收就上下贴住，不收
static func tight_line() -> float:
	return 0.0 if is_zh() else -2.0
