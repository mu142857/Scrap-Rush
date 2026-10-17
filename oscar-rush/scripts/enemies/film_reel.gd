class_name FilmReel
extends EnemyBase
## 胶片盘（策划案第九节 17，滚桶的）：一盘盘贴着地面滚过来，血 100。
## 一出生就选主角那边滚过去，撞墙反弹一次，第二次撞墙就碎。碰到伤 10，能跳过去，也能打碎。
## 走到台子边不停，照样滚下去。
## 帧：0、1、2 滚动（孔位每帧转 40°，按滚过的距离换帧），3 没在滚（还在空中没落地）。
## 贴图由 草图/小怪/export_scav_slide_reel.py 导出。

const ROLL_SPEED := 90.0
## 盘子半径 6：周长约 38 像素，三个孔 120° 一循环，一帧 40° ≈ 4.2 像素
const PX_PER_FRAME := 4.2
const BOUNCE_HOP := -70.0
## 掉出关卡这么远就算碎了（不然遭遇战一直等它）
const FALL_LIMIT := 600.0

var _landed := false
var _bounces := 0
var _roll := 0.0


func _setup() -> void:
	texture_path = "res://art/enemies/film_reel.png"
	hframes = 4
	frame_size = Vector2i(28, 13)
	body_rect = Rect2(-6, -12, 12, 12)
	led_pixel = Vector2i(14, 6)
	max_hp = 100.0
	contact_damage = 10.0
	knockback = Vector2(70.0, 30.0)


func _after_ready() -> void:
	var p := nearest_player()
	if p and absf(p.global_position.x - global_position.x) > 1.0:
		dir = 1 if p.global_position.x > global_position.x else -1


func _tick(_delta: float) -> void:
	if not _landed:
		set_frame(3)
		if not is_knocked():
			velocity.x = 0.0
		move_and_slide()
		if is_on_floor():
			_landed = true
			Game.dust(get_parent(), global_position, 3)
		return
	if not is_knocked():
		velocity.x = dir * ROLL_SPEED * speed_mult()
	var x0 := global_position.x
	move_and_slide()
	# 正着往前滚撞上墙才算（被打得往后退撞墙不算）
	if not is_knocked() and is_on_wall() and get_wall_normal().x * dir < 0.0:
		_hit_wall()
	_roll += absf(global_position.x - x0)
	set_frame(int(_roll / PX_PER_FRAME) % 3)
	if global_position.y > _home.y + FALL_LIMIT:
		_die()


func _hit_wall() -> void:
	_bounces += 1
	if _bounces >= 2:
		Game.sparks(get_parent(), aim_point(), Color8(70, 55, 48), 10, 90.0)
		_die()
		return
	dir = -dir
	velocity = Vector2(dir * ROLL_SPEED * 0.6, BOUNCE_HOP)
	_knock = 0.15                                           # 弹回来的那一下先不自己加速
	Game.sfx("clang", -8.0, 1.4, 0.08)
	Game.sparks(get_parent(), global_position + Vector2(-dir * 6.0, -6.0), Color8(200, 190, 175), 4, 50.0)
	Game.add_shake(1.0)


func _on_respawn() -> void:
	_landed = false
	_bounces = 0
	_after_ready()
