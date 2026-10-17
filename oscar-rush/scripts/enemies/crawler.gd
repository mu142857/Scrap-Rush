class_name Crawler
extends CharacterBody2D
## 爬虫（Oscar 画的，策划案里的"齿轮虫"位置）。沿地面来回爬，碰到就伤人。
## 1 发蓄满的光球打死。测试关里死了 4 秒后在原地复活。原点在脚底中间。

const SPEED := 18.0
const MAX_HP := 100.0
const CONTACT_DAMAGE := 10.0
const GRAVITY := 900.0
const FRAME_W := 36
const FRAME_TIME := 0.1
const LED_COLOR := Color(1.0, 0.28, 0.18)

const FLASH_SHADER := """
shader_type canvas_item;
uniform float flash = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
"""
static var _shader: Shader

@export var respawn_time := 4.0

var hp := MAX_HP
var dir := -1
var dead := false

var _home := Vector2.ZERO
var _knock := 0.0
var _flash := 0.0
var _anim := 0.0
var _sprite: Sprite2D
var _contact: Area2D
var _shape: CollisionShape2D
var _led: Node2D


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 4.0
	_home = global_position

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 10)
	_shape.shape = rect
	_shape.position = Vector2(0, -5)
	add_child(_shape)

	if _shader == null:
		_shader = Shader.new()
		_shader.code = FLASH_SHADER
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://art/enemies/crawler.png")
	_sprite.hframes = 4
	_sprite.centered = false
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	_sprite.material = mat
	add_child(_sprite)

	# 老机器的指示灯：一颗不吃光照的红点加一圈小红光，黑暗里也看得到怪在哪
	_led = Node2D.new()
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_led.material = unshaded
	_led.draw.connect(_draw_led)
	add_child(_led)
	var glow := PointLight2D.new()
	glow.texture = Game.light_texture()
	glow.color = LED_COLOR
	glow.energy = 0.9
	glow.texture_scale = 0.55
	_led.add_child(glow)

	_contact = Area2D.new()
	_contact.collision_layer = 0
	_contact.collision_mask = 2 | 8
	var cs := CollisionShape2D.new()
	var crect := RectangleShape2D.new()
	crect.size = Vector2(14, 10)
	cs.shape = crect
	cs.position = Vector2(0, -5)
	_contact.add_child(cs)
	add_child(_contact)


func aim_point() -> Vector2:
	return global_position + Vector2(0, -6)


func is_targetable() -> bool:
	return not dead


func hurt(damage: float, from_dir: Vector2, full: bool) -> void:
	if dead:
		return
	hp -= damage
	_flash = 1.0
	_knock = 0.12 if full else 0.06
	velocity.x = signf(from_dir.x) * (90.0 if full else 40.0)
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	visible = false
	_shape.set_deferred("disabled", true)
	_contact.set_deferred("monitoring", false)
	Game.sfx("scrap", -4.0, 1.0, 0.12)
	Game.sparks(get_parent(), aim_point(), Color8(150, 140, 125), 14, 110.0)
	Game.sparks(get_parent(), aim_point(), Color8(255, 190, 120), 6, 80.0)
	Game.add_shake(2.0)
	Run.add_emotion(-1.0)
	LampOil.maybe_drop(self)
	if respawn_time > 0.0:
		await get_tree().create_timer(respawn_time, false).timeout
		_respawn()


func _respawn() -> void:
	dead = false
	hp = MAX_HP
	global_position = _home
	velocity = Vector2.ZERO
	visible = true
	_shape.set_deferred("disabled", false)
	_contact.set_deferred("monitoring", true)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_anim += delta
	_flash = maxf(_flash - delta * 8.0, 0.0)
	_knock -= delta
	velocity.y = minf(velocity.y + GRAVITY * delta, 400.0)
	if _knock <= 0.0:
		velocity.x = dir * SPEED
	move_and_slide()
	if is_on_floor() and _knock <= 0.0 and (is_on_wall() or not _ground_ahead()):
		dir = -dir

	_sprite.frame = int(_anim / FRAME_TIME) % 4
	# 原图朝左（铁盒在左、电线拖在右边）
	_sprite.flip_h = dir > 0
	_sprite.offset = Vector2(-24 if dir > 0 else -12, -16)
	_sprite.position = global_position.round() - global_position
	(_sprite.material as ShaderMaterial).set_shader_parameter("flash", _flash)
	# 指示灯在铁盒朝前的上角
	_led.position = Vector2(-6 if dir < 0 else 5, -11)
	_led.queue_redraw()

	for b in _contact.get_overlapping_bodies():
		if b is Player:
			(b as Player).hurt(global_position, CONTACT_DAMAGE)
		elif b is Crystal:
			(b as Crystal).take_hit(global_position, CONTACT_DAMAGE)


func _draw_led() -> void:
	var col := LED_COLOR if int(_anim * 3.0) % 4 != 0 else LED_COLOR.darkened(0.5)
	_led.draw_rect(Rect2(0, 0, 1, 1), col.lerp(Color.WHITE, _flash))


func _ground_ahead() -> bool:
	var from := global_position + Vector2(dir * 8, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()
