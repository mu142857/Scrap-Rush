class_name Player
extends CharacterBody2D
## 主角。输入从 Controls 的一个前缀读（solo / kb_left / pad0 ……），
## 所以同一份代码给 1~4 个玩家用。数值见 策划案.txt 第六节。
## 原点在脚底中间。

# —— 移动 ——
# 2026-10-17 第二次试玩：嫌慢、嫌笨重，照空洞骑士调——起停几乎是瞬间的。
# 第三次试玩：之前说"慢"指的是提灯的速度，空手 115 正合适，提灯按原比例（约 0.78）是 90。
# 角色 20 像素高，115 像素/秒 ≈ 每秒 6 个身高，横穿一屏约 4 秒。
const RUN_SPEED := 115.0
const CARRY_SPEED := 90.0
const ACCEL_TIME := 0.07
const DECEL_TIME := 0.05
const AIR_CONTROL := 1.0
const CHARGE_MOVE_MULT := 0.7
# —— 跳跃（空洞骑士式）——
# 按住跳跃键时匀速上升（最多 JUMP_HOLD_TIME 秒），松手或到时间才开始受重力，
# 所以弧线是平顶的"半圆"，不是又高又窄的尖抛物线。
# 满按：约 45 像素高、空中约 0.54 秒。实测（tools: -- --arc）：空手跑着跳约 62 像素远，提灯约 49。
# 点一下：最少也匀速升 JUMP_MIN_HOLD 秒，约 23 像素高。
const JUMP_VELOCITY := -190.0
const JUMP_HOLD_TIME := 0.16
const JUMP_MIN_HOLD := 0.05
const GRAVITY := 1300.0
const FALL_GRAVITY_MULT := 1.35
const MAX_FALL_SPEED := 400.0
const APEX_SPEED := 30.0
const APEX_GRAVITY_MULT := 0.5
const APEX_TIME := 0.06
const COYOTE_TIME := 0.10
## 站在单向平台上按"下"（S）就从平台上穿下去；这么久之内不和那块平台碰撞
const DROP_TIME := 0.25
const JUMP_BUFFER_TIME := 0.10
# —— 火箭靴 ——
const JET_MAX_UP := 120.0
const JET_ACCEL := 1500.0
## 一直按着跳跃键时，上升速度慢到这个值（快到顶点）就自动接上喷气
const JET_ARM_SPEED := -40.0
const FUEL_TIME := 1.0
const FUEL_TIME_CARRY := 0.7
const FUEL_UPGRADE := 0.35
const FUEL_REFILL_DELAY := 0.25
const FUEL_REFILL_TIME := 1.2
const JET_VOLUME_DB := -17.0
const JET_SILENT_DB := -50.0
# —— 攻击 ——
const CHARGE_TIME := 0.6
const CHARGE_UPGRADE := 0.08
const CHARGE_TIME_MIN := 0.35
const SHOT_COOLDOWN := 0.12
## 三把武器（开局选，见 weapon_select.gd；商店也能换）。单体每秒伤害都在 100 左右：
##   flash  闪光灯：按住蓄力 0.6 秒，蓄满 100 伤害、更快更大、穿透一排；没蓄满也有 35~80 伤害、只微微下坠
##   rivet  铆钉枪：按住一直连发，每 0.11 秒一颗、每颗 11 伤害，散布 ±8°（打大 Boss 打不满），射程短，有后坐
##   hammer 蒸汽锤：按一下，0.12 秒后以自己为中心炸一圈（半径 48，贴身 200、边缘 80，吹散 Boss 子弹），冷却 1.6 秒
## （2026-10-17 作者试玩后改：闪光灯太弱、蓄力表现太夸张、铆钉枪要更散更痛、蒸汽锤要近高远低）
## 快充升级对三把都有效：蓄力更快 / 射得更快 / 冷却更短
const RIVET_INTERVAL := 0.11
const RIVET_UPGRADE := 0.01
const RIVET_SPREAD := 8.0
const RIVET_MOVE_MULT := 0.8
const RIVET_RECOIL := 10.0
const HAMMER_COOLDOWN := 1.6
const HAMMER_UPGRADE := 0.2
const HAMMER_WINDUP := 0.12
## 蓄力圈：身边一圈 12 个点，蓄到哪亮到哪（作者：别太夸张）
const CHARGE_DOTS := 12
const CHARGE_RING_R := 10.0
## 比屏幕半宽（2 倍放大后 120）略小，不锁屏幕外的怪
const AIM_RANGE := 115.0
## 身后的敌人按距离 ×1.8 算，面朝的方向优先
const BEHIND_PENALTY := 1.8
# —— 挨打 ——
## 2026-10-17 作者试玩嫌短：1.0 → 1.4 秒，期间明显闪烁（藏 / 高亮 / 正常 三拍轮着来）
const INVULN_TIME := 1.4
## 无敌闪烁一拍多长
const BLINK_STEP := 0.06
const STUN_TIME := 0.4
const EMOTION_HIT_CARRY := 5.0
const EMOTION_HIT_EMPTY := 8.0

const STRIP_COLORS := {
	"red": Color8(255, 192, 192),
	"robot": Color8(255, 225, 194),
	"bird": Color8(201, 212, 255),
	"dino": Color8(218, 255, 206),
}
const FRAME_SIZE := Vector2i(16, 20)
## 蓄力开始时整个人往下一缩再弹回来（以脚底为支点）
const SQUASH_TIME := 0.16
const SQUASH_SCALE := Vector2(1.25, 0.72)
const IDLE_FRAME_TIME := 0.2
const WALK_FRAME_TIME := 0.13

@export var input_prefix := "solo"
@export var skin := "red"

var facing := 1
var crystal: Crystal = null
## 剩余油量，0~1
var fuel := 1.0
var charge := 0.0
var charging := false
var charge_full := false
var strip_color := Color.WHITE
## 升级等级（0~3），升级房间做好以后由 Run 写进来
var charge_level := 0
var fuel_level := 0

var _coyote := 0.0
var _drop_t := 0.0
var _drop_bodies: Array[PhysicsBody2D] = []
var _buffer := 0.0
var _jump_hold := 0.0
var _jump_min := 0.0
var _apex := 0.0
var _jetting := false
var _jet_armed := false
var _ground_time := 0.0
var _cooldown := 0.0
var _invuln := 0.0
var _stun := 0.0
var _anim_time := 0.0
var _walk_time := 0.0
var _ring := 0.0
var _squash := 0.0
var _gather := 0.0
var _release_flash := 0.0
var _target: Node2D = null
var _rivet_t := 0.0
var _rivet_n := 0
var _muzzle := 0.0
var _hammer_cd := 0.0
var _hammer_windup := 0.0
## 画面上把精灵对齐到整像素：物理位置保留小数，只有显示取整（照 Phage）
var _snap := Vector2.ZERO
var _push := Vector2.ZERO

var _body: Sprite2D
var _strip: Sprite2D
var _light: PointLight2D
var _smoke: CPUParticles2D
var _jet_light: PointLight2D
var _last_walk_frame := -1
var _jet_sound: AudioStreamPlayer
var _charge_sound: AudioStreamPlayer
var _reticle: Node2D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 3.0
	Upgrades.apply(self)        # 商店买的快充、大油箱
	strip_color = STRIP_COLORS.get(skin, Color.WHITE)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6, 16)
	shape.shape = rect
	shape.position = Vector2(0, -8)
	add_child(shape)

	_body = _make_sprite("res://art/chars/%s_body.png" % skin)
	_strip = _make_sprite("res://art/chars/%s_strip.png" % skin)
	# 荧光条不吃场景压暗，永远是亮的
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_strip.material = unshaded

	_light = PointLight2D.new()
	_light.texture = Game.light_texture()
	_light.color = strip_color
	_light.range_item_cull_mask = 1 | 2
	_light.position = Vector2(0, -10)
	add_child(_light)

	# 喷气的雾：用角色自己荧光条的颜色，不吃场景压暗，黑处也看得见
	_smoke = CPUParticles2D.new()
	_smoke.emitting = false
	_smoke.amount = 70
	_smoke.lifetime = 0.8
	_smoke.local_coords = false
	_smoke.direction = Vector2.DOWN
	_smoke.spread = 40.0
	_smoke.initial_velocity_min = 35.0
	_smoke.initial_velocity_max = 75.0
	_smoke.damping_min = 110.0
	_smoke.damping_max = 170.0
	_smoke.gravity = Vector2(0, -18)
	_smoke.scale_amount_min = 2.0
	_smoke.scale_amount_max = 4.0
	var smoke_scale := Curve.new()
	smoke_scale.add_point(Vector2(0.0, 0.6))
	smoke_scale.add_point(Vector2(0.4, 1.0))
	smoke_scale.add_point(Vector2(1.0, 1.3))
	_smoke.scale_amount_curve = smoke_scale
	# 荧光条本身颜色很浅，雾一变透明就发灰，所以雾用它的高饱和版本
	var mist := Color.from_hsv(strip_color.h, maxf(strip_color.s, 0.6), 1.0)
	var smoke_ramp := Gradient.new()
	smoke_ramp.set_color(0, mist.lerp(Color.WHITE, 0.6))
	smoke_ramp.add_point(0.15, Color(mist.r, mist.g, mist.b, 0.9))
	smoke_ramp.add_point(0.6, Color(mist.r * 0.8, mist.g * 0.8, mist.b * 0.8, 0.45))
	smoke_ramp.set_color(1, Color(mist.r * 0.6, mist.g * 0.6, mist.b * 0.6, 0.0))
	_smoke.color_ramp = smoke_ramp
	var smoke_mat := CanvasItemMaterial.new()
	smoke_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_smoke.material = smoke_mat
	_smoke.position = Vector2(0, -1)
	add_child(_smoke)
	# 喷气时脚下一盏同色的灯，把周围照亮
	_jet_light = PointLight2D.new()
	_jet_light.texture = Game.light_texture()
	_jet_light.color = Color.from_hsv(strip_color.h, maxf(strip_color.s, 0.6), 1.0)
	_jet_light.energy = 0.0
	_jet_light.texture_scale = 1.4
	_jet_light.range_item_cull_mask = 1 | 2
	_jet_light.position = Vector2(0, 4)
	add_child(_jet_light)

	# 喷气声：无缝循环，起停时淡入淡出
	var jet_stream := Game.load_sound("jet").duplicate() as AudioStreamWAV
	jet_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	jet_stream.loop_begin = 0
	jet_stream.loop_end = jet_stream.data.size() / 2
	_jet_sound = AudioStreamPlayer.new()
	_jet_sound.stream = jet_stream
	_jet_sound.volume_db = JET_SILENT_DB
	add_child(_jet_sound)
	_charge_sound = AudioStreamPlayer.new()
	_charge_sound.stream = Game.load_sound("charge")
	_charge_sound.volume_db = -15.0
	add_child(_charge_sound)

	_reticle = Node2D.new()
	_reticle.top_level = true
	_reticle.z_index = 20
	_reticle.draw.connect(_draw_reticle)
	add_child(_reticle)


func _make_sprite(path: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.hframes = 7
	s.centered = false
	s.offset = Vector2(-8, -FRAME_SIZE.y)
	add_child(s)
	return s


func _act(action: String) -> String:
	return input_prefix + "_" + action


func charge_time() -> float:
	return maxf(CHARGE_TIME - CHARGE_UPGRADE * charge_level, CHARGE_TIME_MIN)


func fuel_time() -> float:
	return (FUEL_TIME_CARRY if crystal else FUEL_TIME) + FUEL_UPGRADE * fuel_level


func is_jetting() -> bool:
	return _jetting


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	_coyote -= delta
	_buffer -= delta
	_cooldown -= delta
	_invuln -= delta
	_stun -= delta
	_ring = maxf(_ring - delta * 5.0, 0.0)
	_squash = maxf(_squash - delta / SQUASH_TIME, 0.0)
	_gather = maxf(_gather - delta / 0.18, 0.0)
	_release_flash = maxf(_release_flash - delta / 0.15, 0.0)

	var axis := 0.0
	if _stun <= 0.0:
		axis = Input.get_axis(_act("left"), _act("right"))
	_move_x(axis, delta, on_floor)
	if _drop_through(delta, on_floor):
		on_floor = false
	_jump_and_gravity(delta, on_floor)
	_attack(delta)
	_crystal_input()

	var fall_speed := velocity.y
	move_and_slide()
	# 外力（Boss 吸气之类）按位移直接挪，不进 velocity，免得被走路的加减速抵消
	if _push != Vector2.ZERO:
		move_and_collide(_push * delta)
		_push = Vector2.ZERO
	if not on_floor and is_on_floor() and fall_speed > 140.0:
		Game.sfx("land", -14.0 + clampf((fall_speed - 140.0) / 30.0, 0.0, 8.0), 1.0, 0.1)
		Game.dust(get_parent(), global_position, 3 + int(clampf((fall_speed - 140.0) / 60.0, 0.0, 4.0)))
		if fall_speed > 330.0:
			Game.add_shake(2.0)

	_animate(delta)
	queue_redraw()
	_reticle.queue_redraw()


func _move_x(axis: float, delta: float, on_floor: bool) -> void:
	if axis != 0.0:
		facing = 1 if axis > 0.0 else -1
	var top := CARRY_SPEED if crystal else RUN_SPEED
	if charging:
		top *= RIVET_MOVE_MULT if weapon() == "rivet" else CHARGE_MOVE_MULT
	var accel := RUN_SPEED / ACCEL_TIME
	var decel := RUN_SPEED / DECEL_TIME
	var rate: float
	if _stun > 0.0:
		rate = decel * 0.4
	elif axis == 0.0:
		rate = decel
	elif velocity.x != 0.0 and signf(axis) != signf(velocity.x):
		rate = decel + accel
	elif absf(velocity.x) > top:
		rate = decel
	else:
		rate = accel
	if not on_floor:
		rate *= AIR_CONTROL
	# 地上急转身：脚前蹭出一小团灰
	if on_floor and axis != 0.0 and signf(axis) != signf(velocity.x) and absf(velocity.x) > RUN_SPEED * 0.6:
		Game.dust(get_parent(), global_position + Vector2(signf(velocity.x) * 3, 0), 3, signf(velocity.x))
	velocity.x = move_toward(velocity.x, axis * top, rate * delta)
	# 已经贴着墙还往墙里推：横向速度直接清零。不然每帧都"推进墙里再被弹出来"，
	# 贴墙站着、贴墙跳、贴墙往下掉时都会一顿一顿地抖
	if velocity.x != 0.0 and _against_wall(signf(velocity.x)):
		velocity.x = 0.0


## 这个方向上是不是紧贴着一面竖直的墙（斜坡不算，斜坡要能走上去）
func _against_wall(dir: float) -> bool:
	var hit := move_and_collide(Vector2(dir * 0.5, 0.0), true, safe_margin, true)
	return hit != null and absf(hit.get_normal().x) > 0.9


## 站在单向平台上按"下"：暂时不和脚下那块平台碰撞，掉下去。返回 true 表示这一帧开始往下掉。
## 只对单向平台（one_way_collision）有用，实心地面按了没反应。
func _drop_through(delta: float, on_floor: bool) -> bool:
	if _drop_t > 0.0:
		_drop_t -= delta
		if _drop_t <= 0.0:
			for b in _drop_bodies:
				if is_instance_valid(b):
					remove_collision_exception_with(b)
			_drop_bodies.clear()
	if not on_floor or _stun > 0.0 or not Input.is_action_just_pressed(_act("down")):
		return false
	var found := false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y > -0.7:
			continue
		var shape := c.get_collider_shape()
		var one_way: bool = (shape is CollisionShape2D and shape.one_way_collision) \
			or (shape is CollisionPolygon2D and shape.one_way_collision)
		var body := c.get_collider() as PhysicsBody2D
		if one_way and body:
			found = true
			if not _drop_bodies.has(body):
				add_collision_exception_with(body)
				_drop_bodies.append(body)
	if not found:
		return false
	_drop_t = DROP_TIME
	_coyote = 0.0
	position.y += 1.0
	velocity.y = maxf(velocity.y, 40.0)
	return true


func _jump_and_gravity(delta: float, on_floor: bool) -> void:
	var jump_held := Input.is_action_pressed(_act("jump"))
	if on_floor:
		_coyote = COYOTE_TIME
		_jet_armed = false
	if Input.is_action_just_pressed(_act("jump")):
		_buffer = JUMP_BUFFER_TIME
		if not on_floor and _coyote <= 0.0:
			_jet_armed = true

	if _buffer > 0.0 and _coyote > 0.0 and _stun <= 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		_jump_hold = JUMP_HOLD_TIME
		_jump_min = JUMP_MIN_HOLD
		_apex = APEX_TIME
		Game.sfx("jump", -14.0, 1.0, 0.08)
		Game.dust(get_parent(), global_position, 6)

	var want_jet := not on_floor and jump_held and fuel > 0.0 and _stun <= 0.0 \
		and _jump_hold <= 0.0 and (_jet_armed or velocity.y > JET_ARM_SPEED)
	if is_on_ceiling():
		_jump_hold = 0.0
	if _jump_hold > 0.0 and (jump_held or _jump_min > 0.0) and _stun <= 0.0:
		# 匀速上升段
		_jetting = false
		velocity.y = JUMP_VELOCITY
		_jump_hold -= delta
		_jump_min -= delta
	elif want_jet:
		_jump_hold = 0.0
		_jetting = true
		velocity.y = move_toward(velocity.y, -JET_MAX_UP, JET_ACCEL * delta)
		fuel = maxf(fuel - delta / fuel_time(), 0.0)
	else:
		_jump_hold = 0.0
		_jetting = false
		var g := GRAVITY
		if velocity.y > 0.0:
			g *= FALL_GRAVITY_MULT
		if jump_held and absf(velocity.y) < APEX_SPEED and _apex > 0.0:
			g *= APEX_GRAVITY_MULT
			_apex -= delta
		velocity.y = minf(velocity.y + g * delta, MAX_FALL_SPEED)
	_smoke.emitting = _jetting
	var flicker := 0.85 + 0.15 * sin(_anim_time * 37.0)
	_jet_light.energy = move_toward(_jet_light.energy, 1.6 * flicker if _jetting else 0.0, delta * 8.0)
	_update_jet_sound(delta)

	if on_floor:
		_ground_time += delta
		if _ground_time > FUEL_REFILL_DELAY:
			fuel = minf(fuel + delta / FUEL_REFILL_TIME, 1.0)
	else:
		_ground_time = 0.0


func _update_jet_sound(delta: float) -> void:
	if _jetting and not _jet_sound.playing:
		_jet_sound.volume_db = JET_SILENT_DB
		_jet_sound.play(randf() * 1.5)
	var target := JET_VOLUME_DB if _jetting else JET_SILENT_DB
	var speed := 400.0 if _jetting else 160.0  # 分贝每秒：起得快，收得柔
	_jet_sound.volume_db = move_toward(_jet_sound.volume_db, target, speed * delta)
	if not _jetting and _jet_sound.playing and _jet_sound.volume_db <= JET_SILENT_DB + 0.5:
		_jet_sound.stop()


func weapon() -> String:
	return Upgrades.weapon


func _attack(delta: float) -> void:
	_muzzle = maxf(_muzzle - delta / 0.06, 0.0)
	match weapon():
		"rivet":
			_attack_rivet(delta)
			return
		"hammer":
			_attack_hammer(delta)
			return
	var held := Input.is_action_pressed(_act("attack"))
	if held and not charging and _cooldown <= 0.0 and _stun <= 0.0:
		charging = true
		charge = 0.0
		charge_full = false
		_charge_sound.pitch_scale = CHARGE_TIME / charge_time()
		_charge_sound.play()
		_squash = 0.35
		_gather = 0.5
	if not charging:
		_target = null
		return
	charge = minf(charge + delta / charge_time(), 1.0)
	if charge >= 1.0 and not charge_full:
		charge_full = true
		_ring = 0.5
		Game.sfx("ready", -6.0)
	_target = _find_target()
	if not held:
		_fire()


func _fire() -> void:
	var muzzle := global_position + Vector2(facing * 5, -11)
	var dir := Vector2(facing, 0)
	if _target:
		dir = (_aim_point(_target) - muzzle).normalized()
	var orb := Orb.new()
	orb.setup(self, muzzle, dir, charge, _target if charge_full else null, strip_color)
	get_parent().add_child(orb)
	Mutations.on_attack(self, orb)
	if charge_full:
		Game.sfx("shoot", -4.0, 1.0, 0.05)
		velocity.x -= dir.x * 40.0
	else:
		Game.sfx("shoot", -12.0, 1.35, 0.05)
	_release_flash = 1.0 if charge_full else 0.4
	_cancel_charge()
	_cooldown = SHOT_COOLDOWN


## 铆钉枪：按住就连发，不蓄力。每颗自动瞄最近的怪，带一点散布；人往后顶一下，枪口闪一下
func _attack_rivet(delta: float) -> void:
	_rivet_t -= delta
	var held := Input.is_action_pressed(_act("attack"))
	charging = held and _stun <= 0.0
	if not charging:
		_target = null
		_rivet_n = 0
		return
	_target = _find_target()
	if _rivet_t > 0.0:
		return
	_rivet_t += maxf(RIVET_INTERVAL - RIVET_UPGRADE * charge_level, 0.05)
	if _rivet_t < 0.0:
		_rivet_t = 0.0
	var muzzle := global_position + Vector2(facing * 6, -10)
	var dir := Vector2(facing, 0)
	if _target:
		dir = (_aim_point(_target) - muzzle).normalized()
		if signf(dir.x) != 0.0:
			facing = int(signf(dir.x))
	dir = dir.rotated(deg_to_rad(randf_range(-RIVET_SPREAD, RIVET_SPREAD)))
	var r := Rivet.new()
	r.setup(muzzle, dir, strip_color)
	get_parent().add_child(r)
	Mutations.on_attack(self, r)
	_rivet_n += 1
	_muzzle = 1.0
	_release_flash = maxf(_release_flash, 0.35)
	velocity.x -= dir.x * RIVET_RECOIL
	Game.sfx("rivet_shot", -9.0, 1.0, 0.08)
	if _rivet_n % 3 == 0:
		Game.add_shake(0.6)


func hammer_cooldown() -> float:
	return maxf(HAMMER_COOLDOWN - HAMMER_UPGRADE * charge_level, 1.0)


## 蒸汽锤：按一下，缩一下身子蓄 0.12 秒，以自己为中心炸开一圈蒸汽；之后要冷却
func _attack_hammer(delta: float) -> void:
	var was := _hammer_cd
	_hammer_cd = maxf(_hammer_cd - delta, 0.0)
	if was > 0.0 and _hammer_cd <= 0.0:
		# 冷却好了：汽阀"噗"一声，人身上闪一下
		Game.sfx("blast_ready", -10.0)
		_ring = 0.25
	if _hammer_windup > 0.0:
		_hammer_windup -= delta
		if _hammer_windup <= 0.0:
			_blast()
		return
	if Input.is_action_just_pressed(_act("attack")) and _stun <= 0.0:
		if _hammer_cd > 0.0:
			Game.sfx("ui_back", -18.0, 1.6)
			return
		_hammer_windup = HAMMER_WINDUP
		_squash = 0.45
		Game.sfx("scrape", -12.0, 1.8)


func _blast() -> void:
	var b := SteamBlast.new()
	b.color = strip_color
	b.position = global_position + Vector2(0, -10)
	get_parent().add_child(b)
	Mutations.on_attack(self, b)
	_hammer_cd = hammer_cooldown()
	_release_flash = 0.6
	_ring = 0.35
	if not is_on_floor():
		velocity.y = minf(velocity.y, -90.0)


func _cancel_charge() -> void:
	charging = false
	charge_full = false
	charge = 0.0
	_target = null
	_charge_sound.stop()


func _aim_point(n: Node2D) -> Vector2:
	if n.has_method("aim_point"):
		return n.call("aim_point")
	return n.global_position


func _find_target() -> Node2D:
	var from := global_position + Vector2(0, -11)
	var space := get_world_2d().direct_space_state
	var best: Node2D = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Node2D
		if en == null or (en.has_method("is_targetable") and not en.call("is_targetable")):
			continue
		var p := _aim_point(en)
		var d := from.distance_to(p)
		if d > AIM_RANGE:
			continue
		var score := d
		if (p.x - global_position.x) * facing < 0.0:
			score *= BEHIND_PENALTY
		if score >= best_score:
			continue
		var q := PhysicsRayQueryParameters2D.create(from, p, 1)
		if not space.intersect_ray(q).is_empty():
			continue
		best = en
		best_score = score
	return best


func _crystal_input() -> void:
	if not Input.is_action_just_pressed(_act("crystal")) or _stun > 0.0:
		return
	if crystal:
		crystal.drop()
		return
	var best: Crystal = null
	var best_d := Crystal.PICK_RANGE
	for c in get_tree().get_nodes_in_group("crystal"):
		var cr := c as Crystal
		if cr == null or cr.carrier != null:
			continue
		var d := (cr.global_position + Vector2(0, -5)).distance_to(global_position + Vector2(0, -8))
		if d < best_d:
			best = cr
			best_d = d
	if best:
		best.pick_up(self)


## 外力，像素/秒。每帧都要重新调用（Boss 吸气时一直往炉门拽）
func push(v: Vector2) -> void:
	_push += v


## 被敌人碰到。返回 true 表示这一下算数（不在无敌时间里）
func hurt(from: Vector2, damage: float) -> bool:
	if _invuln > 0.0 or Game.invincible:
		return false
	_invuln = INVULN_TIME
	var away := signf(global_position.x - from.x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 130.0, -120.0)
	if crystal:
		crystal.take_carried_hit(damage)
		Run.add_emotion(EMOTION_HIT_CARRY)
	else:
		_stun = STUN_TIME
		Run.add_emotion(EMOTION_HIT_EMPTY)
	_cancel_charge()
	Game.sfx("hurt", -4.0)
	Game.flash(Color(1, 0.1, 0.1), 0.16, 0.4)
	Game.add_shake(3.0)
	Game.hitstop(0.08, 0.25)
	return true


func _animate(delta: float) -> void:
	_anim_time += delta
	var frame: int
	if not is_on_floor():
		frame = 4 if velocity.y < 0.0 else 6
	elif absf(velocity.x) > 6.0:
		_walk_time += delta * clampf(absf(velocity.x) / RUN_SPEED, 0.5, 1.2)
		frame = 4 + int(_walk_time / WALK_FRAME_TIME) % 3
		if frame == 4 and _last_walk_frame != 4 and absf(velocity.x) > RUN_SPEED * 0.5:
			Game.dust(get_parent(), global_position + Vector2(-facing * 3, 0), 2, -facing)
	else:
		_walk_time = 0.0
		frame = int(_anim_time / IDLE_FRAME_TIME) % 4
	_last_walk_frame = frame
	# 无敌期间三拍轮着来：藏起来 → 高亮 → 正常，比只隐藏显眼，一看就知道自己现在不会挨打
	var blink_phase := int(_invuln / BLINK_STEP) % 3 if _invuln > 0.0 else -1
	var blink_hidden := blink_phase == 0
	_snap = global_position.round() - global_position
	# 缩一下：先猛地压扁，再带一点回弹恢复
	var k := _squash
	var sq := Vector2.ONE.lerp(SQUASH_SCALE, k * k) if k > 0.35 else Vector2.ONE.lerp(Vector2(0.92, 1.1), sin(k / 0.35 * PI))
	for s in [_body, _strip]:
		s.position = _snap
		s.scale = sq
		s.frame = frame
		s.flip_h = facing < 0
		s.visible = not blink_hidden

	var glow := charge if (charging and weapon() == "flash") else 0.0
	var pulse := 0.0
	if charge_full:
		pulse = 0.08 + 0.08 * sin(_anim_time * 10.0)
	_body.modulate = Color.WHITE.lerp(Color(1.7, 1.6, 1.5), clampf(glow * 0.35 + pulse + _ring * 0.4, 0.0, 1.0))
	_strip.modulate = Color.WHITE.lerp(Color(2.2, 2.2, 2.2), clampf(glow * 0.6 + _ring * 0.6, 0.0, 1.0))
	if blink_phase == 1:
		_body.modulate = Color(2.6, 2.6, 2.6)
		_strip.modulate = Color(2.6, 2.6, 2.6)
	_light.energy = 0.8 + glow * 1.4 + pulse + _release_flash * 2.5
	_light.texture_scale = 1.0 + glow * 0.8 + _release_flash * 1.6


func _draw() -> void:
	_draw_fuel()
	_draw_weapon()
	if _gather > 0.0:
		# 蓄力开始：一圈光点从外往里收
		var gr := lerpf(3.0, 14.0, _gather)
		var gcol := Color(strip_color.r, strip_color.g, strip_color.b, 0.9 * _gather)
		for i in 12:
			var a := TAU * i / 12.0 + _gather
			_px(Vector2(0, -10) + Vector2(cos(a), sin(a)) * gr, gcol)
	if _ring > 0.0:
		var r := 5.0 + (1.0 - _ring) * 10.0
		var col := Color(1, 1, 1, _ring)
		for i in 20:
			var a := TAU * i / 20.0
			_px(Vector2(0, -10) + Vector2(cos(a), sin(a)) * r, col)


func _draw_weapon() -> void:
	match weapon():
		"flash":
			if not charging:
				return
			var c := Vector2(0, -10)
			# 几颗光点慢慢往里收（没蓄满时才有）
			if not charge_full:
				var n := 2 + int(charge * 3.0)
				for i in n:
					var ph := fmod(_anim_time * 1.4 + float(i) / n, 1.0)
					var a := float(i) * 2.399 + _anim_time * 0.7
					_px(c + Vector2(cos(a), sin(a)) * lerpf(16.0, 4.0, ph), Color(strip_color, 0.2 + 0.5 * ph))
			# 蓄力圈：一圈 12 个小点，只画亮了的，从正上方顺时针一个个亮；满了整圈变白、轻轻呼吸
			var lit := int(charge * CHARGE_DOTS)
			for i in CHARGE_DOTS:
				if not charge_full and i >= lit:
					continue
				var a := -PI / 2.0 + TAU * i / CHARGE_DOTS
				var p := c + Vector2(cos(a), sin(a)) * CHARGE_RING_R
				var col := Color(strip_color, 0.75)
				if charge_full:
					col = Color(1, 1, 1, 0.65 + 0.3 * sin(_anim_time * 8.0))
				_px(p, col)
		"rivet":
			if _muzzle > 0.0:
				# 枪口火光：一个十字小星
				var m := Vector2(facing * 8, -10)
				var col := Color(1.0, 0.9, 0.6, _muzzle)
				_px(m, Color(1, 1, 1, _muzzle))
				for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
					_px(m + d, col)
				_px(m + Vector2(facing * 2, 0), col)
		"hammer":
			if _hammer_cd > 0.0:
				# 冷却圈：脚下一道弧，冷却完就补满
				var k := 1.0 - _hammer_cd / hammer_cooldown()
				var n := 9
				for i in n:
					if float(i) / n >= k:
						continue
					var a := PI + PI * i / (n - 1)
					var p := Vector2(0, -1) + Vector2(cos(a) * 8.0, sin(a) * 2.0 + 2.0)
					_px(p, Color(strip_color, 0.5))


## 背后的小弧形油量表。满油而且没在飞就不画
func _draw_fuel() -> void:
	if fuel >= 1.0 and not _jetting:
		return
	var center := Vector2(-facing * 4, -10)
	const R := 7.0
	const N := 13
	var low := fuel < 0.25 and int(_anim_time * 8.0) % 2 == 0
	for i in N:
		var k := float(i) / (N - 1)  # 0 = 下端，1 = 上端
		var a := deg_to_rad(lerpf(60.0, -60.0, k))
		var p := center + Vector2(-facing * cos(a), sin(a)) * R
		var filled := k < fuel
		var col := strip_color if filled else Color(0.2, 0.2, 0.22, 0.7)
		if filled and low:
			col = Color(1, 0.3, 0.25)
		_px(p, col)


func _draw_reticle() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var p := _aim_point(_target) + Vector2(0, -12)
	_reticle.global_position = p.round()
	var col := strip_color
	if charge_full and int(_anim_time * 10.0) % 2 == 0:
		col = Color.WHITE
	_reticle.draw_rect(Rect2(-2, 0, 5, 1), col)
	_reticle.draw_rect(Rect2(-1, 1, 3, 1), col)
	_reticle.draw_rect(Rect2(0, 2, 1, 1), col)


func _px(p: Vector2, col: Color) -> void:
	draw_rect(Rect2(p.round() + _snap, Vector2.ONE), col)
