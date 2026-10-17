class_name Crystal
extends CharacterBody2D
## 水晶（马灯），里面封着那段录像。全队只有一盏。
## 提着走：慢、亮、主角挨打时水晶跟着掉血。
## 放在地上：主角轻快，但四周变黑，敌人会来打它。
## 血量记在 Run 里（跨关卡保留）。原点在灯座底部中间。

const GRAVITY := 900.0
const PICK_RANGE := 18.0
## 2026-10-17 画面放大 2 倍后从 90 改成 64，不然整屏都被照亮，没有黑暗了
const LIGHT_RADIUS := 64.0
## 提灯的手，相对主角脚底；x 乘主角朝向
const HAND := Vector2(6, -11)
const HOOK_HEIGHT := 9.0
const HIT_INVULN := 0.6
const LIGHT_COLOR := Color(1.0, 0.78, 0.5)

const IRON_DARK := Color8(46, 38, 34)
const IRON := Color8(84, 68, 54)
const GLASS := Color8(255, 211, 138)
const GLASS_CORE := Color8(255, 240, 200)

var carrier: Player = null

var _swing := 0.0
var _swing_v := 0.0
var _last_carrier_vx := 0.0
var _invuln := 0.0
var _hurt_flash := 0.0
var _time := 0.0
var _light: PointLight2D
var _prompt: Label


func _ready() -> void:
	add_to_group("crystal")
	collision_layer = 8
	collision_mask = 1
	z_index = 5
	# 马灯本身是光源，不吃场景光照，颜色画多少就是多少
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(5, 8)
	shape.shape = rect
	shape.position = Vector2(0, -4)
	add_child(shape)

	_light = PointLight2D.new()
	_light.texture = Game.light_texture()
	_light.color = LIGHT_COLOR
	_light.position = Vector2(0, -5)
	_light.texture_scale = LIGHT_RADIUS / 32.0
	add_child(_light)

	_prompt = Label.new()
	_prompt.label_settings = Hud.small_text()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(80, 12)
	_prompt.position = Vector2(-40, -26)
	_prompt.visible = false
	add_child(_prompt)


func pick_up(p: Player, quiet := false) -> void:
	carrier = p
	p.crystal = self
	collision_layer = 0
	velocity = Vector2.ZERO
	_last_carrier_vx = p.velocity.x
	if not quiet:
		Game.sfx("lantern_pick", -8.0, 1.0, 0.05)


func drop() -> void:
	if carrier == null:
		return
	var p := carrier
	carrier = null
	p.crystal = null
	collision_layer = 8
	global_position = p.global_position + Vector2(HAND.x * p.facing, -2)
	# 贴着墙放下时，手的位置在墙里面，改放在脚下
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position + Vector2(0, -4)
	q.collision_mask = 1
	if not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty():
		global_position = p.global_position + Vector2(0, -2)
	velocity = Vector2(p.velocity.x * 0.3, -40.0)
	Game.sfx("lantern_drop", -8.0, 1.0, 0.05)


## 提灯的人挨打，伤害直接转给水晶
func take_carried_hit(damage: float) -> void:
	_on_damaged(damage)


## 放在地上时被敌人碰到
func take_hit(from: Vector2, damage: float) -> void:
	if _invuln > 0.0 or carrier != null:
		return
	_invuln = HIT_INVULN
	velocity = Vector2(signf(global_position.x - from.x) * 60.0, -60.0)
	_on_damaged(damage)


func _on_damaged(damage: float) -> void:
	Run.damage_crystal(damage)
	_hurt_flash = 1.0
	_swing_v += 6.0
	Game.sfx("crack", -4.0, 1.0, 0.1)
	Game.sparks(get_parent(), global_position + Vector2(0, -5), GLASS, 7, 60.0)


func _physics_process(delta: float) -> void:
	_time += delta
	_invuln -= delta
	_hurt_flash = maxf(_hurt_flash - delta * 3.0, 0.0)

	if carrier:
		if not is_instance_valid(carrier):
			carrier = null
			collision_layer = 8
		else:
			var hand := carrier.global_position + Vector2(HAND.x * carrier.facing, HAND.y)
			global_position = hand + Vector2(0, HOOK_HEIGHT)
			# 灯是挂在手上的：主角一加速，灯就往反方向荡
			var accel := (carrier.velocity.x - _last_carrier_vx) / maxf(delta, 0.0001)
			_last_carrier_vx = carrier.velocity.x
			_swing_v += (-_swing * 60.0 - _swing_v * 5.0 - clampf(accel, -2000.0, 2000.0) * 0.004) * delta
	if carrier == null:
		velocity.y = minf(velocity.y + GRAVITY * delta, 400.0)
		velocity.x = move_toward(velocity.x, 0.0, (300.0 if is_on_floor() else 60.0) * delta)
		move_and_slide()
		_swing_v += (-_swing * 60.0 - _swing_v * 6.0) * delta
	_swing = clampf(_swing + _swing_v * delta, -0.8, 0.8)

	var hp_ratio := Run.crystal_hp / Run.crystal_max
	var flicker := 0.05 * sin(_time * 13.0) + 0.04 * sin(_time * 31.0 + 1.3)
	if hp_ratio < 0.3:
		flicker += 0.25 * maxf(sin(_time * 7.0) * sin(_time * 23.0), 0.0) * -1.0
	_light.energy = (0.6 + 0.7 * hp_ratio) * (1.0 + flicker) + _hurt_flash * 1.5
	_update_prompt()
	queue_redraw()


func _update_prompt() -> void:
	_prompt.visible = false
	if carrier != null:
		return
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p and p.crystal == null and p.global_position.distance_to(global_position) < PICK_RANGE + 14.0:
			_prompt.text = "%s Pick up" % Controls.key_name(p.input_prefix, "crystal")
			_prompt.visible = true
			return


## 像素马灯，7×9。摆动时越往下的部分偏得越多
func _draw() -> void:
	draw_set_transform(global_position.round() - global_position)
	var glass := GLASS.lerp(Color.WHITE, _hurt_flash)
	var hp_ratio := Run.crystal_hp / Run.crystal_max
	glass = glass.lerp(Color8(120, 90, 70), (1.0 - hp_ratio) * 0.5)
	var core := GLASS_CORE.lerp(glass, 1.0 - hp_ratio)
	var rows := [
		# [y, x0, 宽, 颜色]
		[-9, 0, 1, IRON_DARK],
		[-8, -1, 3, IRON_DARK],
		[-7, -2, 5, IRON],
		[-6, -2, 5, IRON], [-6, -1, 3, glass],
		[-5, -2, 5, IRON], [-5, -1, 3, glass], [-5, 0, 1, core],
		[-4, -2, 5, IRON], [-4, -1, 3, glass], [-4, 0, 1, core],
		[-3, -2, 5, IRON], [-3, -1, 3, glass],
		[-2, -2, 5, IRON],
		[-1, -3, 7, IRON_DARK],
	]
	for r in rows:
		var y: int = r[0]
		var shift := roundf(sin(_swing) * (y + 10) * 0.45) if carrier else roundf(sin(_swing) * (y + 1) * -0.3)
		draw_rect(Rect2(r[1] + shift, y, r[2], 1), r[3])
	# 裂纹：血越少越多
	if hp_ratio < 0.66:
		draw_rect(Rect2(-1 + roundf(sin(_swing) * 2.0), -5, 1, 1), IRON_DARK)
	if hp_ratio < 0.33:
		draw_rect(Rect2(1 + roundf(sin(_swing) * 2.5), -4, 1, 1), IRON_DARK)
