extends Node
## 对话框测试：第一关垫在后面，打开对话框说几句占位台词；说完停一秒再从头来。
## 用法：在编辑器里打开 scenes/dialog_check.tscn 按 F6，或
##   Godot --path . res://scenes/dialog_check.tscn
## 跳 / 攻击 / 回车 / 点屏幕翻页。

const LINES := [
	"（占位台词）这里就是废品星……比想象中还要吵。",
	{"text": "（占位）马灯亮度可以，出发了。", "skin": "robot"},
	{"text": "（占位）我去前面看看，你们跟上。", "skin": "dino"},
	"Placeholder line. Long enough to wrap onto a second line, so we can check how English text breaks inside the box.",
	{"text": "（占位）名字也可以每句单独换。", "name": "???"},
	"最后一句。翻过去对话框就会关掉，游戏继续。",
]

var box: DialogBox


func _ready() -> void:
	add_child(load("res://scenes/test_level.tscn").instantiate())
	box = DialogBox.new()
	add_child(box)
	_loop()


func _loop() -> void:
	while true:
		await get_tree().create_timer(0.6).timeout
		box.play(LINES)
		await box.finished
		print("[dialog] 说完了")
