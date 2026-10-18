class_name SteamRoller
extends EliteBase
## 蒸汽压路机：第一关最强的精英怪，单独出现在最底层的桥上（桥上那场遭遇战的最后一波）。
## 招式：
## 1. 冲撞：主角和它差不多高时，原地蓄力（红"!"、烟囱冒汽、轰鸣）→ 朝锁定的方向直冲，
##    一路冲到撞墙（桥两头的闸门）为止 → 撞墙大震，晕 2 秒，晕的时候挨打 ×1.5。跳过去躲。
## 2. 喷汽：主角在它头顶（跳过去、飞在上面）时，先冒"!"，然后烟囱往上喷一柱蒸汽，顶人也伤人。
##    免得玩家一直飘在它头上打。
## 3. 碎石炮（2026-10-17 加，原名煤渣炮）：主角离得远时，鸣笛（"!"），烟囱朝主角的位置连轰两发路面碎石，
##    落地以后接着往前滚。站远了慢慢磨也不安全。和冲撞轮流用。
## 平时慢慢朝主角开。从天花板掉下来时落地一震。
## 冲撞的前摇（2026-10-17 试玩嫌不明显）：先往后倒一小段，车身闪红、越抖越厉害，烟囱一股股喷汽，
## 后轮原地空转扬灰，地上从车头往冲的方向画一条闪烁的红色虚线，标出要冲的那条道。
## 贴图 roller.png（54×38）：0、1 开动，2 蓄力，3 冲撞，4 晕。由 草图/精英怪/export_roller.py 导出。

enum State { DRIVE, WINDUP, CHARGE, STUN, BLAST_WARN, BLAST, MORTAR_WARN, MORTAR }

const DRIVE_SPEED := 20.0
## 2026-10-17 第二次试玩嫌太难，整体降了一档：冲得慢、前摇长、冷却长、晕得久、碎石炮少一发、伤害低了
## 第三次试玩：好躲可以，但太脆、招放不全。血翻倍；冷却更长且不跟着情绪值变短；冲撞和碎石炮严格轮流
const CHARGE_SPEED := 145.0
const WINDUP_TIME := 1.2
const BACKUP_SPEED := 14.0
const MORTAR_WARN_TIME := 0.9
const MORTAR_SHOTS := 2
const MORTAR_GAP := 0.45
const MORTAR_MIN_DIST := 90.0
const STUN_TIME := 3.0
const STUN_DAMAGE_MULT := 2.0
const CHARGE_COOLDOWN := 1.1  # 10-18 作者：招和招之间停太久
const SEE_HEIGHT := 28.0
const BLAST_WARN_TIME := 0.5
const BLAST_TIME := 0.8
const BLAST_HEIGHT := 70.0
const BLAST_DAMAGE := 8.0
const BLAST_PUSH := 200.0
const CHIMNEY_PIXEL := Vector2i(11, 3)

var state := State.DRIVE
var _state_t := 0.0
var _cooldown := 1.0
var _charge_dir := -1
var _landed := false
var _blast_area: Area2D
var _blast: CPUParticles2D
var _smoke: CPUParticles2D
var _lane: Node2D
var _mortar_left := 0
var _next_is_mortar := false


func _setup() -> void:
	elite_name = "STEAM ROLLER"
	intro_title = "FULL STEAM"
	intro_frame = 2
	fill_alpha = 0.35
	death_time = 1.1
	death_frame = 4
	warn_tint = false
	texture_path = "res://art/enemies/roller.png"
	hframes = 5
	frame_size = Vector2i(54, 38)
	body_rect = Rect2(-24, -30, 48, 30)
	led_pixel = Vector2i(7, 15)
	max_hp = 1220.0  # 10-18 作者：第一关太肉（没买科技，要比后两关脆），三把武器站桩 12～18 秒
	contact_damage = 8.0


func _after_ready() -> void:
	var p := nearest_player()
	if p:
		dir = 1 if p.global_position.x > global_position.x else -1
	_blast_area = Area2D.new()
	_blast_area.collision_layer = 0
	_blast_area.collision_mask = 2
	_blast_area.monitoring = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, BLAST_HEIGHT)
	cs.shape = r
	_blast_area.add_child(cs)
	add_child(_blast_area)
	_blast = _particles(60, 0.5, 160.0, 10.0, Vector2(2, 4), 0.6)
	_smoke = _particles(10, 0.6, 30.0, 25.0, Vector2(1, 3), 0.4)
	_smoke.emitting = true
	# 冲撞道的红色虚线
	_lane = Node2D.new()
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_lane.material = unshaded
	_lane.z_index = 9
	_lane.draw.connect(_draw_lane)
	add_child(_lane)


func _tick(delta: float) -> void:
	_state_t += delta
	_cooldown -= delta
	var chimney := _chimney_local()
	_blast_area.position = chimney + Vector2(0, -BLAST_HEIGHT / 2.0)
	_blast.position = chimney
	_smoke.position = chimney
	if not _landed:
		# 落地的那一震由 EliteBase 的出场动画负责，出场完了才走到这里
		if is_on_floor():
			_landed = true
		velocity.x = 0.0
		move_and_slide()
		set_frame(0)
		return

	var p := nearest_player()
	match state:
		State.DRIVE:
			if p:
				var dx := p.global_position.x - global_position.x
				var dy := p.global_position.y - global_position.y
				if absf(dx) > 6.0:
					dir = 1 if dx > 0.0 else -1
				if _cooldown <= 0.0 and absf(dx) < 40.0 and dy < -24.0:
					_enter(State.BLAST_WARN)
				# 轮到碎石炮就放（贴脸也放，炮弹是抛过来的）；不轮到时，主角离得远或者不同高也用它
				elif _cooldown <= 0.0 and (_next_is_mortar or (absf(dx) > MORTAR_MIN_DIST and absf(dy) >= SEE_HEIGHT)):
					_next_is_mortar = false
					pick_focus(p)      # 双人时轮着轰一个人，预警开始就定好
					_enter(State.MORTAR_WARN)
				elif _cooldown <= 0.0 and absf(dy) < SEE_HEIGHT and absf(dx) < 300.0:
					_next_is_mortar = true
					# 双人时轮着冲一个人：同一层的那个才冲，不然冲最近的
					var t := pick_focus(p)
					if absf(t.global_position.y - global_position.y) >= SEE_HEIGHT:
						t = p
						focus = p
					if absf(t.global_position.x - global_position.x) > 6.0:
						dir = 1 if t.global_position.x > global_position.x else -1
					_enter(State.WINDUP)
			velocity.x = dir * DRIVE_SPEED * speed_mult()
			set_frame(int(_time / 0.15) % 2)
		State.WINDUP:
			var k := _state_t / WINDUP_TIME
			# 前一半往后倒车蓄势，后一半原地空转
			velocity.x = -dir * BACKUP_SPEED if k < 0.5 else 0.0
			set_frame(2 if int(_state_t / 0.06) % 2 == 0 else 0)
			if int(_state_t / 0.12) != int((_state_t - delta) / 0.12):
				Game.dust(get_parent(), global_position + Vector2(-dir * 18, 0), 2, -dir)
			if int(_state_t / 0.25) != int((_state_t - delta) / 0.25):
				Game.sfx("vent", -14.0, 1.6, 0.1)
				_smoke.amount = 30
			_lane.queue_redraw()
			if _state_t >= WINDUP_TIME:
				_charge_dir = dir
				_enter(State.CHARGE)
		State.CHARGE:
			velocity.x = _charge_dir * CHARGE_SPEED * speed_mult()
			set_frame(3)
			if int(_state_t / 0.08) != int((_state_t - delta) / 0.08):
				Game.dust(get_parent(), global_position + Vector2(-_charge_dir * 20, 0), 2, -_charge_dir)
			if _state_t > 0.1 and is_on_wall():
				_crash()
			elif _state_t > 0.2 and not ground_ahead(28.0):
				# 前面没路了：刹住，不掉下去
				velocity.x = 0.0
				_enter(State.DRIVE)
			elif _state_t > 4.0:
				_enter(State.DRIVE)
		State.STUN:
			velocity.x = 0.0
			set_frame(4)
			if _state_t >= STUN_TIME:
				_enter(State.DRIVE)
		State.MORTAR_WARN:
			velocity.x = 0.0
			set_frame(2)
			if _state_t >= MORTAR_WARN_TIME:
				_mortar_left = MORTAR_SHOTS
				_enter(State.MORTAR)
		State.MORTAR:
			velocity.x = 0.0
			set_frame(3 if fmod(_state_t, MORTAR_GAP) < 0.1 else 2)
			if _mortar_left > 0 and _state_t >= (MORTAR_SHOTS - _mortar_left) * MORTAR_GAP:
				_mortar_left -= 1
				_fire_mortar(focus_player())
			if _mortar_left == 0 and _state_t >= MORTAR_SHOTS * MORTAR_GAP + 0.3:
				_enter(State.DRIVE)
		State.BLAST_WARN:
			velocity.x = 0.0
			set_frame(2)
			if _state_t >= BLAST_WARN_TIME:
				_enter(State.BLAST)
		State.BLAST:
			velocity.x = 0.0
			set_frame(2)
			for b in _blast_area.get_overlapping_bodies():
				var pl := b as Player
				if pl:
					pl.velocity.y = minf(pl.velocity.y, -BLAST_PUSH)
					pl.hurt(global_position + chimney, BLAST_DAMAGE * damage_mult())
			if _state_t >= BLAST_TIME:
				_enter(State.DRIVE)
	contact_damage = 12.0 if state == State.CHARGE else 8.0
	move_and_slide()


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	_blast.emitting = s == State.BLAST
	_blast_area.set_deferred("monitoring", s == State.BLAST)
	_smoke.amount = 10
	match s:
		State.WINDUP:
			warn(WINDUP_TIME)
			Game.sfx("jet", -8.0, 0.6)
		State.CHARGE:
			Game.sfx("jet", -4.0, 0.9)
			Game.sfx("whistle", -8.0, 1.5)
			Game.add_shake(3.0)
			_lane.queue_redraw()
		State.BLAST_WARN:
			warn(BLAST_WARN_TIME)
		State.MORTAR_WARN:
			warn(MORTAR_WARN_TIME)
			Game.sfx("whistle", -10.0, 1.3)
		State.BLAST:
			Game.sfx("jet", -6.0, 1.5)
		State.DRIVE:
			_cooldown = CHARGE_COOLDOWN


func _crash() -> void:
	velocity.x = 0.0
	Game.add_shake(7.0)
	Game.hitstop(0.06)
	Game.sfx("crack", 0.0, 0.5)
	Game.sparks(get_parent(), global_position + Vector2(_charge_dir * 26, -16), Color8(255, 190, 120), 18, 140.0)
	Game.dust(get_parent(), global_position, 8)
	_enter(State.STUN)


func hurt(damage: float, from_dir: Vector2, full: bool) -> void:
	super.hurt(damage * (STUN_DAMAGE_MULT if state == State.STUN else 1.0), from_dir, full)


func _on_die() -> void:
	_blast.emitting = false
	_smoke.emitting = false


func _update_visual() -> void:
	super._update_visual()
	# 蓄力时原地发抖，越到后面抖得越厉害，车身一闪一闪发红
	if state == State.WINDUP:
		var k := _state_t / WINDUP_TIME
		var amp := 1.0 if k < 0.6 else 2.0
		_sprite.position.x += amp if int(_state_t * 30.0) % 2 == 0 else -amp
		var pulse := 0.5 + 0.5 * sin(_state_t * (12.0 + 20.0 * k))
		_sprite.modulate = Color.WHITE.lerp(Color(1.8, 0.7, 0.6), pulse * (0.4 + 0.6 * k))
	elif state == State.MORTAR_WARN:
		_sprite.modulate = Color.WHITE.lerp(Color(1.6, 0.9, 0.6), 0.5 + 0.5 * sin(_state_t * 30.0))
	else:
		_sprite.modulate = Color.WHITE


## 冲撞道：从车头往要冲的方向，贴地一条红色虚线，往前流动、越来越亮
func _draw_lane() -> void:
	if state != State.WINDUP or dead:
		return
	var k := _state_t / WINDUP_TIME
	if int(_state_t * 10.0) % 2 == 1 and k < 0.7:
		return
	var col := Color(1.0, 0.25, 0.18, 0.35 + 0.6 * k)
	var front := dir * (frame_size.x / 2 + 2)
	var flow := int(_state_t * 40.0) % 8
	for i in range(0, 260, 8):
		var x := front + dir * (i + flow)
		_lane.draw_rect(Rect2(x - (4 if dir < 0 else 0), -2, 4, 1), col)


## 碎石炮：从烟囱朝主角现在的位置抛一发路面碎石（落地接着滚）。
## 用的是 COAL 的飞法，但画成碎石（gravel），和锅炉工的煤块区分开
func _fire_mortar(p: Player) -> void:
	var from := global_position + _chimney_local() + Vector2(0, -2)
	var target := p.global_position if p else from + Vector2(dir * 120, 0)
	target.x += randf_range(-14, 14)
	var t := randf_range(0.95, 1.2)
	# 落到人脚下那一列的地面（和压路机同一层），贴地才伤人
	target.y = global_position.y
	var v := Vector2((target.x - from.x) / t, (target.y - 4.0 - from.y) / t - 0.5 * BossBullet.COAL_GRAVITY * t)
	var b := BossBullet.spawn(get_parent(), BossBullet.Kind.COAL, from, v, true)
	b.gravel = true
	b.floor_y = global_position.y
	b.arena = Rect2(global_position.x - 300, global_position.y - 230, 600, 260)
	Game.sfx("boom", -10.0, 1.5, 0.1)
	Game.sfx("embers", -8.0, 1.2)
	Game.add_shake(2.0)
	# 烟囱口喷一股白汽和几粒石屑，不是火星
	Game.sparks(get_parent(), from, Color(0.9, 0.9, 0.92), 6, 70.0, Vector2.UP)
	Game.sparks(get_parent(), from, Color8(150, 140, 125), 3, 50.0, Vector2.UP)


## 烟囱口相对原点（脚底中间）的位置，跟着朝向镜像
func _chimney_local() -> Vector2:
	var col := CHIMNEY_PIXEL.x if dir < 0 else frame_size.x - 1 - CHIMNEY_PIXEL.x
	return Vector2(col - frame_size.x / 2, CHIMNEY_PIXEL.y - frame_size.y)


func _particles(amount: int, life: float, speed: float, spread: float, size: Vector2, alpha: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.direction = Vector2.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.7
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, -20)
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.83, 0.8, alpha))
	ramp.set_color(1, Color(0.6, 0.58, 0.58, 0.0))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	add_child(p)
	return p
