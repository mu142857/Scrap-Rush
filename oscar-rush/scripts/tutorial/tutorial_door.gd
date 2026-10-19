class_name TutorialDoor
extends Node2D
## 两台电视之间的卷帘门：关着是一道实墙（碰撞层 1），开门时卷上去（0.4 秒），门上一盏小灯红变绿。

## 放映机会话画的卷帘门（art/tutorial/door.png，32×40，左帧关着、右帧卷起一半）；没有就用代码画
const TEX_PATH := "res://art/tutorial/door.png"
var tex: Texture2D = load(TEX_PATH) if ResourceLoader.exists(TEX_PATH) else null
var size := Vector2(16, 40)
var open := false
var _k := 0.0
var _body: StaticBody2D
var _shape: CollisionShape2D


func _ready() -> void:
	light_mask = TutorialLevel.NO_LIGHT_MASK
	z_index = -5
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	_shape.shape = r
	_shape.position = size * 0.5
	_body.add_child(_shape)
	add_child(_body)


func set_open(v: bool) -> void:
	open = v
	_shape.set_deferred("disabled", v)


func _process(delta: float) -> void:
	var want := 1.0 if open else 0.0
	if not is_equal_approx(_k, want):
		_k = move_toward(_k, want, delta / 0.4)
		queue_redraw()


func _draw() -> void:
	if tex:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.04, 0.035, 0.05))
		if _k < 0.15:
			draw_texture_rect_region(tex, Rect2(0, 0, 16, 40), Rect2(0, 0, 16, 40))
		elif _k < 0.85:
			draw_texture_rect_region(tex, Rect2(0, 0, 16, 40), Rect2(16, 0, 16, 40))
		else:
			# 全开：只剩顶上卷起来的门筒（右帧最上面 6 行）
			draw_texture_rect_region(tex, Rect2(0, 0, 16, 6), Rect2(16, 0, 16, 6))
		var led2 := Color(0.45, 0.95, 0.5) if open else Color(0.95, 0.3, 0.25)
		draw_rect(Rect2(size.x * 0.5 - 1, -5, 3, 3), led2)
		return
	var h := roundf(size.y * (1.0 - _k))
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.08, 0.07, 0.1))
	if h > 0.0:
		draw_rect(Rect2(0, 0, size.x, h), Color(0.32, 0.29, 0.36))
		for y in range(2, int(h), 4):
			draw_rect(Rect2(1, y, size.x - 2, 1), Color(0.22, 0.2, 0.26))
		draw_rect(Rect2(0, h - 2, size.x, 2), Color(0.45, 0.4, 0.48))
	var led := Color(0.45, 0.95, 0.5) if open else Color(0.95, 0.3, 0.25)
	draw_rect(Rect2(size.x * 0.5 - 1, -5, 3, 3), led)
