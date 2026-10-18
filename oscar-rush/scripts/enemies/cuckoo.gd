class_name CuckooClock
extends EliteBase
## 布谷鸟钟（策划案第九节精英怪 1）：慢慢朝主角走，一边走一边倒计时（滴答声）。
## 每到点先冒"!"，然后门打开，弹出一只铁鸟朝主角飞过去（不快、略微追踪，撞到人或墙就碎）。
## 门开着的那 1 秒是弱点窗口：受到的伤害 ×2，钟摆晃个不停。
## 第二招：靠得太近时冒"!"，钟摆往后一拉，伸长了往身前横扫。
## 帧：0、1 走路，2 预警（门里亮起铁鸟的红眼），3、4 门开着、钟摆左右晃，5 横扫前摇，6 横扫。
## 贴图由 草图/精英怪/export_clock_sew_cash.py 导出。

enum { WALK, WARN, OPEN, SWEEP_WARN, SWEEP, RECOVER }

const WALK_SPEED := 14.0
## 走到离主角这么近就站住
const STOP_DIST := 20.0
const SEE_DIST := 240.0
const WALK_FRAME_TIME := 0.22
# —— 布谷 ——
const CUCKOO_INTERVAL := 1.4  # 10-18 作者：招和招之间停太久
const WARN_TIME := 0.5
const OPEN_TIME := 1.0
const WEAK_MULT := 2.0
## 铁鸟从门里出来的位置（朝左时，相对脚底中间）
const DOOR := Vector2(-2, -26)
const BIRD_DAMAGE := 10.0
# —— 钟摆横扫 ——
## 主角离原点这么近（身子前沿在 -9，也就是身前约 20 像素）就扫
const SWEEP_RANGE := 30.0
const SWEEP_HEIGHT := 24.0
const SWEEP_WARN_TIME := 0.45
const SWEEP_TIME := 0.2
const SWEEP_RECOVER := 0.5
const SWEEP_COOLDOWN := 1.6
## 横扫的判定（朝左时）：身前约 20 像素，贴着地面往上 16 像素
const SWEEP_RECT := Rect2(-29, -16, 23, 16)
const SWEEP_DAMAGE := 15.0

var _state := WALK
var _timer := 0.0
var _cuckoo_t := CUCKOO_INTERVAL
var _sweep_cd := 0.0
var _last_tick := -1
var _weak_fx: Node2D
## 门的位置（原图朝左，相对脚底中间）：弱点框画在这一圈
const DOOR_RECT := Rect2(-3, -30, 8, 7)


func _setup() -> void:
	elite_name = "CUCKOO CLOCK"
	intro_title = "TIME'S UP"
	intro_frame = 3
	fill_alpha = 0.35
	death_time = 1.1
	death_frame = 3
	texture_path = "res://art/enemies/cuckoo.png"
	hframes = 7
	frame_size = Vector2i(53, 40)
	body_rect = Rect2(-9, -38, 18, 38)
	led_pixel = Vector2i(26, 21)
	max_hp = 1550.0  # 10-18 作者：第一关太肉（没买科技，要比后两关脆），三把武器站桩 12～18 秒；布谷鸟偏下限
	contact_damage = 10.0


## 门开着时门口一圈金色的角框一闪一闪：告诉玩家"现在打这里伤害翻倍"。不吃压暗
func _after_ready() -> void:
	_weak_fx = Node2D.new()
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_weak_fx.material = unshaded
	_weak_fx.z_index = 9
	_weak_fx.draw.connect(_draw_weak)
	add_child(_weak_fx)


func _draw_weak() -> void:
	if _state != OPEN or dead or dying():
		return
	var r := DOOR_RECT
	if dir > 0:
		r.position.x = -r.position.x - r.size.x
	r.position += global_position.round() - global_position
	# 开门那一刻框大一圈，然后缩到门边；一闪一闪
	var k := clampf((OPEN_TIME - _timer) / 0.15, 0.0, 1.0)
	r = r.grow(roundf(3.0 * (1.0 - k)) + 1.0)
	if int(_timer * 12.0) % 2 == 1 and k >= 1.0:
		return
	var col := Color(1.0, 0.85, 0.35)
	var a := r.position
	var b := r.end - Vector2.ONE
	for c in [a, Vector2(b.x, a.y), Vector2(a.x, b.y), b]:
		var sx := 1.0 if c.x == a.x else -1.0
		var sy := 1.0 if c.y == a.y else -1.0
		_weak_fx.draw_rect(Rect2(c, Vector2.ONE), col)
		_weak_fx.draw_rect(Rect2(c + Vector2(sx, 0), Vector2.ONE), col)
		_weak_fx.draw_rect(Rect2(c + Vector2(0, sy), Vector2.ONE), col)


func _tick(delta: float) -> void:
	_weak_fx.queue_redraw()
	_timer -= delta
	_sweep_cd -= delta
	if _state != WARN and _state != OPEN:
		_cuckoo_t -= delta
		_tick_sound()
	var p := nearest_player(SEE_DIST)
	match _state:
		WALK:
			_walk(p)
			if not is_on_floor():
				pass                     # 从天花板掉下来还没落地，先不放招
			elif _cuckoo_t <= 0.0:
				_state = WARN
				_timer = WARN_TIME
				velocity.x = 0.0
				warn(WARN_TIME)
				pick_focus(p)          # 双人时每只铁鸟轮着追一个人，预警开始就定好
			elif p and _sweep_cd <= 0.0 and _in_sweep_range(p):
				_state = SWEEP_WARN
				_timer = SWEEP_WARN_TIME
				velocity.x = 0.0
				warn(SWEEP_WARN_TIME)
		WARN:
			_brake(delta)
			set_frame(2 if int(_timer / 0.08) % 2 == 0 else 0)
			if _timer <= 0.0:
				_open(focus_player())
		OPEN:
			_brake(delta)
			set_frame(3 + int(_timer / 0.14) % 2)
			if _timer <= 0.0:
				_state = WALK
				_cuckoo_t = CUCKOO_INTERVAL * interval_mult()
				_last_tick = -1
		SWEEP_WARN:
			_brake(delta)
			set_frame(5)
			if _timer <= 0.0:
				_state = SWEEP
				_timer = SWEEP_TIME
				Game.sfx("jet", -10.0, 1.3, 0.05)
				Game.dust(get_parent(), global_position + Vector2(dir * 18, 0), 3, dir)
		SWEEP:
			_brake(delta)
			set_frame(6)
			_hit_rect(SWEEP_RECT, SWEEP_DAMAGE * damage_mult())
			if _timer <= 0.0:
				_state = RECOVER
				_timer = SWEEP_RECOVER
				_sweep_cd = SWEEP_COOLDOWN * interval_mult()
		RECOVER:
			_brake(delta)
			set_frame(0)
			if _timer <= 0.0:
				_state = WALK
	move_and_slide()


func _walk(p: Player) -> void:
	var move := false
	if p:
		var dx := p.global_position.x - global_position.x
		if absf(dx) > 2.0:
			dir = 1 if dx > 0.0 else -1
		move = absf(dx) > STOP_DIST and is_on_floor() and not is_on_wall() and ground_ahead(10.0)
	velocity.x = dir * WALK_SPEED * speed_mult() if move else 0.0
	set_frame(int(_time / WALK_FRAME_TIME) % 2 if move else 0)


func _in_sweep_range(p: Player) -> bool:
	var d := p.global_position - global_position
	return absf(d.x) <= SWEEP_RANGE and absf(d.y) <= SWEEP_HEIGHT


func _open(p: Player) -> void:
	_state = OPEN
	_timer = OPEN_TIME
	var bird := IronBird.new()
	bird.position = global_position + Vector2(DOOR.x * -dir, DOOR.y)
	var aim := Vector2(dir, 0.0)
	if p:
		aim = (p.global_position + Vector2(0, -10) - bird.position).normalized()
		bird.target = p
	bird.velocity = aim * IronBird.SPEED
	bird.damage = BIRD_DAMAGE * damage_mult()
	get_parent().add_child(bird)
	Game.sfx("ready", -6.0, 1.6)
	Game.sfx("jump", -10.0, 1.9)


## 每过一整秒"滴答"一声，最后一秒音调高一点
func _tick_sound() -> void:
	var s := int(ceil(_cuckoo_t))
	if s != _last_tick and s >= 1 and _state == WALK:
		if _last_tick != -1:
			Game.sfx("ui_move", -20.0, 2.4 if s == 1 else 1.7)
		_last_tick = s


## 门开着的时候挨打伤害加倍，冒一点亮火花提示"打对了"
func hurt(damage: float, from_dir: Vector2, full: bool) -> void:
	if _state == OPEN and not dead:
		damage *= WEAK_MULT
		Game.sparks(get_parent(), global_position + Vector2(0, -26), Color8(255, 220, 120), 14, 110.0)
		Game.sfx("ready", -8.0, 2.2, 0.05)
	super.hurt(damage, from_dir, full)


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)


## 朝左时的判定框 r（朝右时镜像），碰到的主角、地上的马灯都挨打
func _hit_rect(r: Rect2, dmg: float) -> void:
	if dir > 0:
		r.position.x = -r.position.x - r.size.x
	var shape := RectangleShape2D.new()
	shape.size = r.size
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, global_position + r.get_center())
	q.collision_mask = 2 | 8
	for hit in get_world_2d().direct_space_state.intersect_shape(q, 8):
		var b: Object = hit["collider"]
		if b is Player:
			(b as Player).hurt(global_position, dmg)
		elif b is Crystal:
			(b as Crystal).take_hit(global_position, dmg)


func _on_respawn() -> void:
	_state = WALK
	_cuckoo_t = CUCKOO_INTERVAL
	_last_tick = -1


## 从门里弹出来的铁鸟：飞得不快，慢慢往主角那边拐，碰到人、马灯或墙就碎，最多飞 2 秒
class IronBird:
	extends Area2D

	const SPEED := 70.0
	## 每秒最多拐这么多弧度（"略微追踪"）
	const TURN := 1.3
	const LIFE := 2.0
	## 朝左的样子，数字是 elites.py 的调色板下标，L 是红眼
	const PIXELS := [
		"..98...",
		"9L6668.",
		".66666.",
	]
	const WING_UP := "..4.4.."
	const WING_DOWN := "..444.."
	const COLORS := {
		"9": Color8(0x9a, 0x92, 0x88), "8": Color8(0x84, 0x7c, 0x74), "6": Color8(0x66, 0x60, 0x5a),
		"4": Color8(0x4b, 0x47, 0x42), "L": Color8(0xff, 0x47, 0x30),
	}

	var velocity := Vector2.ZERO
	var target: Node2D
	var damage := 10.0
	var _t := 0.0
	var _done := false

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1 | 2 | 8
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(6, 4)
		cs.shape = r
		add_child(cs)
		body_entered.connect(_on_body)
		var glow := PointLight2D.new()
		glow.texture = Game.light_texture()
		glow.color = EnemyBase.LED_COLOR
		glow.energy = 0.8
		glow.texture_scale = 0.35
		add_child(glow)
		# 要躲的东西：不吃场景压暗，第一关暗处也看得见（和收银机的硬币、第二关的子弹一样）
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			_break()
			return
		if is_instance_valid(target):
			var want := (target.global_position + Vector2(0, -10) - global_position).angle()
			var diff := wrapf(want - velocity.angle(), -PI, PI)
			velocity = velocity.rotated(clampf(diff, -TURN * delta, TURN * delta))
		global_position += velocity * delta
		queue_redraw()

	func _on_body(b: Node) -> void:
		if _done:
			return
		if b is Player:
			(b as Player).hurt(global_position, damage)
		elif b is Crystal:
			(b as Crystal).take_hit(global_position, damage)
		_break()

	func _break() -> void:
		if _done:
			return
		_done = true
		Game.sparks(get_parent(), global_position, Color8(150, 140, 125), 8, 70.0)
		Game.sfx("crack", -14.0, 1.7, 0.1)
		queue_free()

	func _draw() -> void:
		var rows: Array = PIXELS.duplicate()
		rows.append(WING_UP if int(_t * 12.0) % 2 == 0 else WING_DOWN)
		var flip := velocity.x > 0.0
		var ofs := (global_position.round() - global_position) + Vector2(-3, -2)
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				var c := row[x]
				if COLORS.has(c):
					var px := (row.length() - 1 - x) if flip else x
					draw_rect(Rect2(ofs + Vector2(px, y), Vector2.ONE), COLORS[c])
