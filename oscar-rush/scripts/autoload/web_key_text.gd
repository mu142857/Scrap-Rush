class_name WebKeyText
extends Translation
## 网页版的按键提示：把字里的 "Esc" 换成 "P"（暂停、继续）或 "Backspace"（返回、跳过、取消）。
## 10-19 作者在 itch 上发现："在 itch 界面点击 esc 会退出全屏，而不是回到上一个"——浏览器全屏时 Esc 被浏览器拿去退出全屏，
## 游戏收不到。所以网页版加了两个备用键：P 和 Backspace 在 web/shell.html 里直接转成 Esc 发给游戏，哪里认 Esc 哪里就认它们；
## 提示也跟着改，桌面版照旧写 Esc。
## 用法（Lang.apply 里）：网页版不直接加 text.csv 的译文，而是加两个这个：
##   英文 locale "en"，base 为空：原文里有 Esc 就换；
##   中文 locale "zh"，base = text.csv 的中文译文：先翻成中文再换。
## 测试：桌面版设环境变量 SCRAP_WEB_KEYS=1 也走这一套（Lang.web_keys()）。

var base: Translation


static func replace_esc(s: String) -> String:
	if s.find("Esc") < 0:
		return s
	var lower := s.to_lower()
	var key := "P" if (lower.contains("pause") or lower.contains("resume") or s.contains("暂停") or s.contains("继续")) else "Backspace"
	var out := ""
	var i := 0
	while i < s.length():
		# 只换单独的 Esc（后面不是字母），"Escape" 这种词不动
		if s.substr(i, 3) == "Esc" and (i + 3 >= s.length() or not _is_letter(s[i + 3])) and (i == 0 or not _is_letter(s[i - 1])):
			out += key
			i += 3
		else:
			out += s[i]
			i += 1
	return out


static func _is_letter(c: String) -> bool:
	var u := c.unicode_at(0)
	return (u >= 65 and u <= 90) or (u >= 97 and u <= 122)


func _get_message(src_message: StringName, context: StringName) -> StringName:
	var s := String(src_message)
	if base:
		var t := String(base.get_message(src_message, context))
		if t != "":
			s = t
	var r := replace_esc(s)
	# 英文没有要换的：返回空，照原文
	if base == null and r == String(src_message):
		return &""
	return StringName(r)


func _get_plural_message(src_message: StringName, src_plural_message: StringName, n: int, context: StringName) -> StringName:
	if base:
		var t := String(base.get_plural_message(src_message, src_plural_message, n, context))
		if t != "":
			return StringName(replace_esc(t))
	return StringName(replace_esc(String(src_message if n == 1 else src_plural_message)))
