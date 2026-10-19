class_name TutorialCrate
extends Node2D
## 一摞纸箱（教学关的台阶、高架）：照第三关搬家纸箱的颜色画，一格一格的箱子，亮的顶边，暗的右侧。

## 放映机会话画的搬家纸箱（art/tutorial/crate.png，30×22，上下摞着能接上）；没有就用代码画
const TEX_PATH := "res://art/tutorial/crate.png"
var tex: Texture2D = load(TEX_PATH) if ResourceLoader.exists(TEX_PATH) else null
var size := Vector2(30, 22)


func _ready() -> void:
	light_mask = TutorialLevel.NO_LIGHT_MASK
	z_index = -6


func _draw() -> void:
	if tex:
		# 从底下往上一个个摞：每个箱子 22 高，最上面那个按剩下的高度截
		var y := size.y
		while y > 0.0:
			var hh := minf(22.0, y)
			draw_texture_rect_region(tex, Rect2(0, y - hh, size.x, hh), Rect2(0, 22.0 - hh, 30, hh))
			y -= 22.0
		return
	var base := Color8(196, 150, 104)
	var dark := Color8(150, 110, 78)
	var top := Color8(226, 186, 136)
	var rows := maxi(1, int(roundf(size.y / 22.0)))
	var rh := size.y / rows
	for i in rows:
		var y := i * rh
		draw_rect(Rect2(0, y, size.x, rh), base)
		draw_rect(Rect2(0, y, size.x, 2), top)
		draw_rect(Rect2(size.x - 4, y, 4, rh), dark)
		draw_rect(Rect2(size.x * 0.5 - 2, y, 4, rh * 0.4), Color8(232, 214, 170))   # 封箱胶带
		draw_rect(Rect2(0, y + rh - 1, size.x, 1), dark)
