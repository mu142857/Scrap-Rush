class_name TutorialSwitch
extends Node2D
## 阁楼雪花对面的开关：人碰到（或者打到）它就拍下去，"咔哒"一声变绿。原点在开关底座底边中间。

## 放映机会话画的开关（art/tutorial/switch.png，24×10，左帧红按钮、右帧拍下去变绿）；没有就用代码画
const TEX_PATH := "res://art/tutorial/switch.png"
var tex: Texture2D = load(TEX_PATH) if ResourceLoader.exists(TEX_PATH) else null
var hit := false


func _ready() -> void:
	light_mask = TutorialLevel.NO_LIGHT_MASK
var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	if hit:
		return
	for p in get_tree().get_nodes_in_group("player"):
		if (p as Node2D).global_position.distance_to(global_position + Vector2(0, -6)) < 16.0:
			_press()
	queue_redraw()


func hurt(_damage: float, _dir: Vector2, _full := false) -> void:
	_press()


func _press() -> void:
	if hit:
		return
	hit = true
	Game.sfx("tvclick", -4.0, 1.2)
	queue_redraw()


func _draw() -> void:
	if tex:
		draw_texture_rect_region(tex, Rect2(-6, -10, 12, 10), Rect2(12 if hit else 0, 0, 12, 10))
		# 没按的时候按钮一闪一闪，提醒"拍这里"
		if not hit and int(_t * 3.0) % 2 == 0:
			draw_rect(Rect2(-3, -9, 6, 2), Color(1, 1, 1, 0.35))
		return
	draw_rect(Rect2(-6, -4, 12, 4), Color(0.3, 0.27, 0.32))
	var col := Color(0.45, 0.95, 0.5) if hit else Color(0.95, 0.3, 0.25)
	if not hit and int(_t * 3.0) % 2 == 0:
		col = col.lightened(0.3)
	draw_rect(Rect2(-4, -10 if not hit else -7, 8, 6 if not hit else 3), col)
