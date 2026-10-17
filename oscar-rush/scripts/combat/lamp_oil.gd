class_name LampOil
extends Area2D
## 灯油：怪死的时候按几率掉一滴，主角碰到就给马灯回一点血（策划案第七节"关卡内回血"，10-17 作者定）。
## 小怪 6%、大怪 15%、精英必掉 2 滴；每滴 +4。8 秒后消失，最后 2 秒一闪一闪。
## 掉出来先往上蹦一下再落地；自己发暖光、不吃场景压暗，暗处也看得见。
## 用法：LampOil.maybe_drop(敌人)，在怪的死亡里调一次。

const HEAL := 4.0
const CHANCE_SMALL := 0.06
const CHANCE_BIG := 0.15
const ELITE_DROPS := 2
const LIFETIME := 8.0
const BLINK_TIME := 2.0
const COLOR := Color8(255, 196, 92)
const CORE := Color8(255, 244, 205)

var _t := 0.0
var _vel := Vector2.ZERO
var _landed := false
var _light: PointLight2D


## 按怪的种类决定掉不掉、掉几滴
static func maybe_drop(enemy: Node2D) -> void:
	if enemy == null or not enemy.is_inside_tree():
		return
	var n := 0
	if enemy is EliteBase:
		n = ELITE_DROPS
	elif enemy.get("big"):
		n = 1 if randf() < CHANCE_BIG else 0
	else:
		n = 1 if randf() < CHANCE_SMALL else 0
	var parent := enemy.get_parent()
	if parent == null:
		return
	var at: Vector2 = enemy.call("aim_point") if enemy.has_method("aim_point") else enemy.global_position
	for i in n:
		var oil := LampOil.new()
		oil.position = at
		oil._vel = Vector2(randf_range(-40.0, 40.0) + (i - (n - 1) * 0.5) * 30.0, -110.0)
		parent.add_child.call_deferred(oil)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 12)
	cs.shape = r
	cs.position = Vector2(0, -3)
	add_child(cs)
	body_entered.connect(_on_body)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	z_index = 6
	_light = PointLight2D.new()
	_light.texture = Game.light_texture()
	_light.color = COLOR
	_light.energy = 0.9
	_light.texture_scale = 0.6
	_light.position = Vector2(0, -3)
	add_child(_light)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	if not _landed:
		_vel.y = minf(_vel.y + 600.0 * delta, 260.0)
		var step := _vel * delta
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step + Vector2(0, 1), 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			global_position += step
		elif _vel.y > 0.0:
			global_position = (hit["position"] as Vector2).round()
			_landed = true
		else:
			_vel = Vector2.ZERO
	var fading := _t > LIFETIME - BLINK_TIME
	visible = not fading or int(_t * 10.0) % 2 == 0
	_light.energy = 0.9 + 0.25 * sin(_t * 6.0)
	queue_redraw()


func _on_body(b: Node) -> void:
	if not b is Player:
		return
	if Run.has_method("heal_crystal"):
		Run.heal_crystal(HEAL)
	Game.sfx("lantern_pick", -6.0, 1.8)
	Game.sparks(get_parent(), global_position + Vector2(0, -3), COLOR, 8, 60.0)
	queue_free()


## 一滴油：上尖下圆，中间一个亮点，悬空时上下浮一点
func _draw() -> void:
	var o := Vector2(0, -roundf(sin(_t * 4.0)) - (1.0 if _landed else 0.0))
	draw_rect(Rect2(o + Vector2(0, -7), Vector2(1, 1)), COLOR)
	draw_rect(Rect2(o + Vector2(-1, -6), Vector2(3, 2)), COLOR)
	draw_rect(Rect2(o + Vector2(-2, -4), Vector2(5, 4)), COLOR)
	draw_rect(Rect2(o + Vector2(-1, 0), Vector2(3, 1)), COLOR.darkened(0.3))
	draw_rect(Rect2(o + Vector2(-1, -3), Vector2(1, 2)), CORE)
