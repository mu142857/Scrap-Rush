class_name EnemyBase
extends CharacterBody2D
## 新怪的公共底子（照 crawler.gd 抽出来的；爬虫本身先不改）。
## 管：贴图（横排帧、原图朝左、原点在脚底中间）、受击白闪、红色指示灯（不吃光照 + 一圈小红光）、
## 碰到就伤人、死亡（火花、降情绪）、可选复活、情绪档位倍率。
## 子类在 _setup() 里改下面这些参数，在 _tick(delta) 里写自己的行为，用 set_frame() 换帧。

const LED_COLOR := Color(1.0, 0.28, 0.18)
const LED_HOT := Color(1.0, 0.45, 0.2)
const LED_PANIC := Color(1.0, 0.9, 0.75)
const FLASH_SHADER := """
shader_type canvas_item;
uniform float flash = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
"""
static var _shader: Shader

## 测试关里死了以后过几秒原地复活；正式关卡里是 0（不复活）
@export var respawn_time := 0.0

# ---- 子类在 _setup() 里填 ----
var max_hp := 100.0
var contact_damage := 10.0
## 大怪（汽壶、洗衣机、刷怪机器……）死了情绪 -3，小怪 -1
var big := false
var texture_path := ""
var hframes := 1
## 一帧的大小（像素）
var frame_size := Vector2i(16, 16)
## 身体碰撞框（原点在脚底中间，往上是负）
var body_rect := Rect2(-6, -10, 12, 10)
## 碰到伤人的框，默认和身体一样
var contact_rect := Rect2()
## 指示灯在原图（朝左）里的像素位置，可以按帧给：{帧号: Vector2i}；没写的帧用 led_pixel
var led_pixel := Vector2i(-1, -1)
var led_by_frame := {}
## 飞的怪不受重力
var flying := false
var gravity := 900.0
## 被打中时的击退速度（蓄满 / 没蓄满）
var knockback := Vector2(90.0, 40.0)
## 死的时候的声音和溅出来的碎屑（10-18 加）：机器默认金属"scrap"、灰色碎屑加橙色火星；
## 活物（第二关人形怪、守夜巨人）在 _setup() 里换成倒地的闷响和灰尘、碎布的颜色
var death_sfx := "scrap"
var death_sfx_pitch := 1.0
var death_spark_colors: Array = [Color8(150, 140, 125), Color8(255, 190, 120)]

# ---- 运行时 ----
var hp := 100.0
var dir := -1
var dead := false
var frame := 0

var _home := Vector2.ZERO
var _knock := 0.0
var _flash := 0.0
var _time := 0.0
var _sprite: Sprite2D
var _shape: CollisionShape2D
var _contact: Area2D
var _led: Node2D


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 4.0
	_setup()
	if flying:
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	hp = max_hp
	_home = global_position

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_rect.size
	_shape.shape = rect
	_shape.position = body_rect.get_center()
	add_child(_shape)

	if _shader == null:
		_shader = Shader.new()
		_shader.code = FLASH_SHADER
	_sprite = Sprite2D.new()
	_sprite.texture = load(texture_path)
	_sprite.hframes = hframes
	_sprite.centered = false
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	_sprite.material = mat
	add_child(_sprite)
	Bestiary.watch(self, Bestiary.id_for_texture(texture_path), body_rect)   # 怪物图鉴：第一次出现在画面里就记一笔

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
	var cr := contact_rect if contact_rect.size != Vector2.ZERO else body_rect
	crect.size = cr.size
	cs.shape = crect
	cs.position = cr.get_center()
	_contact.add_child(cs)
	add_child(_contact)
	_after_ready()


## 子类改参数
func _setup() -> void:
	pass


## 子类在节点都建好以后再加东西（粒子、额外的判定框……）
func _after_ready() -> void:
	pass


## 子类的行为，每个物理帧调一次（死了不调）
func _tick(_delta: float) -> void:
	pass


func aim_point() -> Vector2:
	return global_position + body_rect.get_center()


func is_targetable() -> bool:
	return not dead


func hurt(damage: float, from_dir: Vector2, full: bool) -> void:
	if dead:
		return
	hp -= damage
	_flash = 1.0
	_knock = 0.12 if full else 0.06
	velocity.x = signf(from_dir.x) * (knockback.x if full else knockback.y)
	_on_hurt(damage, full)
	if hp <= 0.0:
		_die()


## 子类可以在挨打时打断自己的招式
func _on_hurt(_damage: float, _full: bool) -> void:
	pass


func _die() -> void:
	dead = true
	visible = false
	_shape.set_deferred("disabled", true)
	_contact.set_deferred("monitoring", false)
	Game.sfx(death_sfx, -4.0, (0.85 if big else 1.0) * death_sfx_pitch, 0.12)
	Game.sparks(get_parent(), aim_point(), death_spark_colors[0], 20 if big else 14, 120.0 if big else 110.0)
	Game.sparks(get_parent(), aim_point(), death_spark_colors[1], 6, 80.0)
	Game.add_shake(3.0 if big else 2.0)
	Run.add_emotion(-3.0 if big else -1.0)
	LampOil.maybe_drop(self)
	Mutations.on_kill(self)
	Bestiary.count_kill(Bestiary.id_for_texture(texture_path))   # 怪物图鉴：击杀数
	_on_die()
	if respawn_time > 0.0:
		await get_tree().create_timer(respawn_time, false).timeout
		_respawn()


func _on_die() -> void:
	pass


func _respawn() -> void:
	dead = false
	hp = max_hp
	global_position = _home
	velocity = Vector2.ZERO
	visible = true
	_shape.set_deferred("disabled", false)
	_contact.set_deferred("monitoring", true)
	_on_respawn()


func _on_respawn() -> void:
	pass


func _physics_process(delta: float) -> void:
	if dead:
		return
	_time += delta
	_flash = maxf(_flash - delta * 8.0, 0.0)
	_knock -= delta
	if not flying:
		velocity.y = minf(velocity.y + gravity * delta, 400.0)
	_tick(delta)
	_update_visual()
	_contact_damage()


func set_frame(f: int) -> void:
	frame = clampi(f, 0, hframes - 1)


func is_knocked() -> bool:
	return _knock > 0.0


func _update_visual() -> void:
	_sprite.frame = frame
	# 原图朝左；朝右时水平翻转，原点保持在脚底中间
	_sprite.flip_h = dir > 0
	_sprite.offset = Vector2(-frame_size.x / 2, -frame_size.y)
	_sprite.position = global_position.round() - global_position
	(_sprite.material as ShaderMaterial).set_shader_parameter("flash", _flash)
	var px: Vector2i = led_by_frame.get(frame, led_pixel)
	_led.visible = px.x >= 0
	# 精英自己管红光的亮度（出招前红灯先亮），这里只管小怪
	if not has_method("in_intro"):
		led_glow(_led.get_child(0) as PointLight2D)
	if _led.visible:
		var col := px.x if dir < 0 else frame_size.x - 1 - px.x
		_led.position = _sprite.position + Vector2(col - frame_size.x / 2, px.y - frame_size.y)
		_led.queue_redraw()


func _draw_led() -> void:
	_led.draw_rect(Rect2(0, 0, 1, 1), led_color(_time, _flash))


## 红灯跟着情绪档位变（10-18 加，玩家要看得出"机器被惹毛了"）：
## 平静 一秒闪 3 下、暗红；烦躁 4 下；愤怒 6 下、偏橙更亮；失控 一秒 12 下，在白热和红之间狂闪。
## 爬虫（crawler.gd）也用这一套
static func led_color(time: float, flash := 0.0) -> Color:
	var tier := emotion_tier()
	var col: Color
	match tier:
		0, 1:
			col = LED_COLOR if int(time * (3.0 + tier)) % 4 != 0 else LED_COLOR.darkened(0.5)
		2:
			col = LED_HOT if int(time * 6.0) % 4 != 0 else LED_COLOR.darkened(0.3)
		_:
			col = LED_PANIC if int(time * 12.0) % 2 == 0 else LED_COLOR
	return col.lerp(Color.WHITE, flash)


## 红灯那圈小红光：档位越高越亮、越大
static func led_glow(glow: PointLight2D) -> void:
	var tier := emotion_tier()
	glow.energy = [0.9, 1.0, 1.3, 1.7][tier]
	glow.texture_scale = [0.55, 0.6, 0.7, 0.85][tier]


func _contact_damage() -> void:
	if not _contact.monitoring or contact_damage <= 0.0:
		return
	var dmg := contact_damage * damage_mult()
	for b in _contact.get_overlapping_bodies():
		if b is Player:
			(b as Player).hurt(global_position, dmg)
		elif b is Crystal:
			(b as Crystal).take_hit(global_position, dmg)


## 前方脚下有没有地（走到台子边就掉头用）
func ground_ahead(dist := 8.0) -> bool:
	var from := global_position + Vector2(dir * dist, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## 最近的主角（多人时取最近的），没有就返回 null
func nearest_player(max_dist := INF) -> Player:
	var best: Player = null
	var bd := max_dist
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p == null:
			continue
		var d := global_position.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = p
	return best


# ---- 情绪档位（策划案第八节）。正式的档位（带回差）以后放进 Run，这里先按数值直接分档 ----
static func emotion_tier() -> int:
	return clampi(int(Run.emotion / 25.0), 0, 3)


static func speed_mult() -> float:
	return [1.0, 1.15, 1.3, 1.5][emotion_tier()]


static func damage_mult() -> float:
	return [1.0, 1.25, 1.5, 2.0][emotion_tier()]


## 机关间隔（汽壶喷汽、刷怪机器吐怪）
static func interval_mult() -> float:
	return [1.0, 0.8, 0.6, 0.4][emotion_tier()]
