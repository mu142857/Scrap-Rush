class_name PlayerPiano
extends EliteBase
## 自动钢琴（策划案第九节，第一关精英怪 3）：读着穿孔纸卷，让地面的琴键一根根顶起来，要跟着节奏跳。
## 基本站着不动，偶尔朝主角挪一小步。一个阶段，两招轮着放，都先冒红色"!"：
## - 琴键浪：从钢琴脚下开始，地面上 8 根琴键柱依次顶起来，像浪一样朝主角推过去，要跳过去。
## - 和弦：在主角脚下和左右各 30 像素先出落点标记，0.5 秒后同时顶起 3 根更高的柱子，要走开。
## - 琶音（2026-10-17 加）：朝主角连弹 5 个音，每个音飞出一颗发光的音符，抛物线落下，音一个比一个高。
##   空中的威胁，和地上的两招配合，不能只靠跳。三招轮着放。
## 前摇（2026-10-17 试玩嫌不明显）：预警时琴身抖、一闪一闪发红；琴键浪在预警时就把整排琴键的位置
## 在地上淡淡标出来，提前知道浪会推到哪。
## 琴键柱是地上的东西，用代码画（内部类 KeyColumn），每根顶起之前地面先闪一下。
## 贴图 piano.png（草图/精英怪/export_piano_vacuum.py 导出）：
## 0~3 待机（穿孔纸卷往上走），4 预警（琴键抬起一半），5、6 放招（琴键轮流翘起来）。

enum State { IDLE, SHUFFLE, WAVE_WARN, WAVE, CHORD_WARN, CHORD, ARP_WARN, ARP, RECOVER }

## 2026-10-17 第二次试玩嫌太难，整体降了一档：歇得更久、预警更长、琴键更少更慢、伤害更低
## 第三次试玩：好躲可以，但死太快、三招放不全。血翻倍；招与招之间歇得更久，而且不跟着情绪值变快
const IDLE_TIME := Vector2(0.4, 0.7)  # 10-18 作者：招和招之间停太久
const ROLL_FRAME_TIME := 0.16
## 偶尔挪一下：每隔几轮招式挪 0.5 秒
const SHUFFLE_EVERY := 3
const SHUFFLE_TIME := 0.5
const SHUFFLE_SPEED := 28.0
## 琴键浪
const WAVE_WARN := 0.8
const WAVE_KEYS := 6
const WAVE_GAP := 0.16
const WAVE_HEIGHT := 12.0
const WAVE_UP := 0.4
const WAVE_WIDTH := 8.0
## 每根之间的间距在这个范围里，按主角离得多远来定，让第 8 根刚好越过主角
const WAVE_SPACING := Vector2(12.0, 20.0)
const WAVE_DAMAGE := 8.0
## 和弦
const CHORD_WARN := 0.6
const CHORD_MARK := 0.8
const CHORD_SPREAD := 36.0
const CHORD_HEIGHT := 26.0
const CHORD_UP := 0.5
const CHORD_WIDTH := 10.0
const CHORD_DAMAGE := 9.0
const RECOVER_TIME := 0.6
## 琶音
const ARP_WARN := 0.9
const ARP_NOTES := 5
const ARP_GAP := 0.18
## 琴键浪的音：五声音阶往上走（"叮"换音高）
const NOTES := [1.0, 1.122, 1.26, 1.498, 1.682, 2.0, 2.245, 2.52]
## 前脚离脚底中点多远（第一根柱子从这里外面开始）
const FOOT_X := 21.0

var state := State.IDLE
var _state_t := 0.0
var _idle_time := 1.5
var _rounds := 0
## 下一招：0 琴键浪，1 和弦，2 琶音
var _next_attack := 0
var _arp_left := 0
var _attack_dir := -1


func _setup() -> void:
	elite_name = "PLAYER PIANO"
	intro_title = "ENCORE"
	intro_frame = 5
	fill_alpha = 0.35
	death_time = 1.1
	death_frame = 5
	warn_tint = false
	texture_path = "res://art/enemies/piano.png"
	hframes = 7
	frame_size = Vector2i(42, 30)
	body_rect = Rect2(-19, -28, 38, 28)
	led_pixel = Vector2i(20, 7)
	max_hp = 1230.0  # 10-18 作者：第一关太肉（没买科技，要比后两关脆），三把武器站桩 12～18 秒
	contact_damage = 8.0
	_idle_time = 0.6


func _tick(delta: float) -> void:
	_state_t += delta
	if not is_knocked():
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	match state:
		State.IDLE:
			_face_player()
			_roll_frames()
			# 精英怪的出招间隔不乘 interval_mult()：情绪高时间隔太短，招看不清
			if _state_t >= _idle_time and is_on_floor():
				_rounds += 1
				if _rounds % SHUFFLE_EVERY == 0:
					_enter(State.SHUFFLE)
				else:
					_start_attack()
		State.SHUFFLE:
			_roll_frames()
			_shuffle()
			if _state_t >= SHUFFLE_TIME:
				velocity.x = 0.0
				_start_attack()
		State.WAVE_WARN:
			set_frame(4)
			if _state_t >= WAVE_WARN:
				_enter(State.WAVE)
		State.WAVE:
			_play_frames()
			if _state_t >= WAVE_KEYS * WAVE_GAP + WAVE_UP:
				_enter(State.RECOVER)
		State.CHORD_WARN:
			set_frame(4)
			if _state_t >= CHORD_WARN:
				_chord()
				_enter(State.CHORD)
		State.CHORD:
			_play_frames()
			if _state_t >= CHORD_MARK + CHORD_UP:
				_enter(State.RECOVER)
		State.ARP_WARN:
			set_frame(4)
			if _state_t >= ARP_WARN:
				_arp_left = ARP_NOTES
				_enter(State.ARP)
		State.ARP:
			_play_frames()
			if _arp_left > 0 and _state_t >= (ARP_NOTES - _arp_left) * ARP_GAP:
				_play_note(ARP_NOTES - _arp_left)
				_arp_left -= 1
			if _arp_left == 0 and _state_t >= ARP_NOTES * ARP_GAP + 0.2:
				_enter(State.RECOVER)
		State.RECOVER:
			_roll_frames()
			if _state_t >= RECOVER_TIME:
				_enter(State.IDLE)
	move_and_slide()


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	if s == State.IDLE:
		_idle_time = randf_range(IDLE_TIME.x, IDLE_TIME.y)
	elif s == State.SHUFFLE:
		var p := nearest_player()
		var dx := p.global_position.x - global_position.x if p else 0.0
		# 离得远就往主角那边挪，太近就往后挪，中间随便挪
		var side := signf(dx) if absf(dx) > 90.0 else (-signf(dx) if absf(dx) < 45.0 else (1.0 if randf() < 0.5 else -1.0))
		velocity.x = side * SHUFFLE_SPEED * speed_mult()
		Game.sfx("land", -10.0, 0.6, 0.05)
		Game.dust(get_parent(), global_position, 3)


func _start_attack() -> void:
	pick_focus()
	_face_player()
	_attack_dir = dir
	match _next_attack:
		1:
			warn(CHORD_WARN)
			_enter(State.CHORD_WARN)
		2:
			warn(ARP_WARN)
			_enter(State.ARP_WARN)
			Game.sfx("charge", -12.0, 1.4)
		_:
			warn(WAVE_WARN)
			_enter(State.WAVE_WARN)
			# 琴键马上排出来：预警这段时间先在地上淡淡标出整排位置，到点再一根根顶起
			_wave(WAVE_WARN)
	Game.sfx("ready", -12.0, 0.7)
	_next_attack = (_next_attack + 1) % 3


func _shuffle() -> void:
	# 前面没地或者顶着墙就停
	var side := signf(velocity.x)
	if side != 0.0 and (not _ground_at(side, FOOT_X) or is_on_wall()):
		velocity.x = 0.0
	if int(_state_t / 0.16) != int((_state_t - get_physics_process_delta_time()) / 0.16):
		Game.dust(get_parent(), global_position + Vector2(-side * 16.0, 0), 2, -side)


## 琴键浪：一根根往主角那边排过去。地面断了、撞墙就停。
## head_start：在顶起之前多等多久（这段时间琴键的位置在地上淡淡标出来）
func _wave(head_start := 0.0) -> void:
	var p := focus_player()
	var reach := 120.0
	if p:
		reach = absf(p.global_position.x - global_position.x) - FOOT_X + 24.0
	var spacing := clampf(reach / WAVE_KEYS, WAVE_SPACING.x, WAVE_SPACING.y)
	var x := global_position.x + _attack_dir * (FOOT_X + WAVE_WIDTH / 2.0)
	var y := global_position.y
	var space := get_world_2d().direct_space_state
	for i in WAVE_KEYS:
		if i > 0:
			var nx := x + _attack_dir * spacing
			# 12 像素以内的台阶跟着走上去，再高就算墙
			var wall := PhysicsRayQueryParameters2D.create(Vector2(x, y - 13.0), Vector2(nx, y - 13.0), 1)
			if not space.intersect_ray(wall).is_empty():
				break
			x = nx
		# 往上 12、往下 16 像素以内的台阶都跟着走，再往下就是坑，浪停在这里
		var fy := _floor_y(x, y - 13.0, 29.0)
		if is_nan(fy):
			break
		y = fy
		var k := KeyColumn.new()
		k.width = WAVE_WIDTH
		k.height = WAVE_HEIGHT
		k.lead = 0.2
		k.delay = head_start + i * WAVE_GAP * interval_mult()
		k.preview = head_start > 0.0
		k.up_time = WAVE_UP
		k.damage = WAVE_DAMAGE * damage_mult()
		k.pitch = NOTES[i % NOTES.size()]
		k.position = Vector2(roundf(x), y)
		get_parent().add_child(k)


## 和弦：主角脚下和左右各 30 像素，落点先标出来
func _chord() -> void:
	var p := focus_player()
	if p == null:
		return
	var i := 0
	for off in [-CHORD_SPREAD, 0.0, CHORD_SPREAD]:
		var x: float = p.global_position.x + off
		# 从主角头顶的高度往下找地面（旁边高一截的台阶也算）
		var fy := _floor_y(x, p.global_position.y - 16.0, 140.0)
		if is_nan(fy) or _in_wall(Vector2(x, fy - 4.0)):
			continue
		var k := KeyColumn.new()
		k.width = CHORD_WIDTH
		k.height = CHORD_HEIGHT
		k.lead = CHORD_MARK
		k.marker = true
		k.up_time = CHORD_UP
		k.damage = CHORD_DAMAGE * damage_mult()
		k.pitch = [1.0, 1.26, 1.498][i]
		k.position = Vector2(roundf(x), fy)
		get_parent().add_child(k)
		i += 1


## x 处从 from_y 往下 depth 以内的地面 y，没有就返回 NAN
func _floor_y(x: float, from_y: float, depth: float) -> float:
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, from_y), Vector2(x, from_y + depth), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector2).y > -0.5:
		return NAN
	return (hit.position as Vector2).y


func _in_wall(pos: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pos
	q.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


func _ground_at(side: float, dist: float) -> bool:
	var from := global_position + Vector2(side * dist, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## 琶音的第 i 个音：朝主角抛一颗音符，落点散开一点，音一个比一个高
func _play_note(i: int) -> void:
	var p := focus_player()
	var from := global_position + Vector2(_attack_dir * 10.0, -frame_size.y + 4.0)
	var target := p.global_position + Vector2(0, -6) if p else from + Vector2(_attack_dir * 100.0, 20.0)
	target.x += (i - ARP_NOTES / 2) * 9.0 + randf_range(-5, 5)
	var g := BossBullet.EMBER_GRAVITY * 0.85
	var t := 0.95 + i * 0.04
	var v := Vector2((target.x - from.x) / t, (target.y - from.y) / t - 0.5 * g * t)
	var b := BossBullet.spawn(get_parent(), BossBullet.Kind.NOTE, from, v, i % 2 == 0)
	b.arena = Rect2(global_position.x - 320, global_position.y - 240, 640, 280)
	Game.sfx("ready", -8.0, NOTES[i % NOTES.size()])
	Game.sparks(get_parent(), from, Color(1.0, 0.9, 0.6), 3, 40.0, Vector2.UP)


## 预警时琴身抖、一闪一闪发红，越接近放招越快
func _update_visual() -> void:
	super._update_visual()
	var warn_t := -1.0
	match state:
		State.WAVE_WARN:
			warn_t = _state_t / WAVE_WARN
		State.CHORD_WARN:
			warn_t = _state_t / CHORD_WARN
		State.ARP_WARN:
			warn_t = _state_t / ARP_WARN
	if warn_t >= 0.0:
		var amp := 1.0 if warn_t < 0.6 else 2.0
		_sprite.position.x += amp if int(_state_t * 30.0) % 2 == 0 else -amp
		var pulse := 0.5 + 0.5 * sin(_state_t * (14.0 + 20.0 * warn_t))
		_sprite.modulate = Color.WHITE.lerp(Color(1.8, 0.75, 0.6), pulse * (0.4 + 0.6 * warn_t))
	else:
		_sprite.modulate = Color.WHITE


func _face_player() -> void:
	var p := focus_player()
	if p and absf(p.global_position.x - global_position.x) > 2.0:
		dir = 1 if p.global_position.x > global_position.x else -1


func _roll_frames() -> void:
	set_frame(int(_time / ROLL_FRAME_TIME) % 4)


func _play_frames() -> void:
	set_frame(5 + int(_state_t / WAVE_GAP) % 2)


func _on_respawn() -> void:
	_enter(State.IDLE)


## 地面上顶起来的一根琴键柱。原点在地面上、柱子底边中间。
## 先 lead 秒地面闪（marker 为真时再加一个往下指的红箭头当落点标记），然后顶起 up_time 秒，碰到就伤人。
## 放在关卡节点下面，钢琴死了也会把这一根放完。
class KeyColumn:
	extends Node2D

	const RISE := 0.05
	const SINK := 0.08
	const FLASH := Color(1.0, 0.45, 0.3)
	const KEY_TOP := Color8(0x8a, 0x84, 0x7c)
	const KEY := Color8(0x5c, 0x57, 0x52)
	const KEY_LEFT := Color8(0x6e, 0x68, 0x62)
	const KEY_SHADE := Color8(0x3b, 0x38, 0x35)
	const KEY_GAP := Color8(0x12, 0x11, 0x10)

	var width := 8.0
	var height := 14.0
	## 等多久才开始（琴键浪一根根错开）
	var delay := 0.0
	## 顶起之前地面闪多久
	var lead := 0.2
	var up_time := 0.4
	var damage := 10.0
	var marker := false
	var pitch := 1.0
	## 等待（delay）的这段时间也在地上淡淡画出位置（琴键浪的预警）
	var preview := false

	var _t := 0.0
	var _rose := false

	func _ready() -> void:
		z_index = 3
		# 地面闪光和落点标记黑暗里也要看得见；柱子本身也不吃压暗，不然在黑处看不见要跳的东西
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _physics_process(delta: float) -> void:
		_t += delta
		var t := _t - delay
		if t >= lead and not _rose:
			_rose = true
			Game.sfx("ready", -10.0, pitch)
			Game.sfx("land", -14.0, 1.4, 0.1)
			Game.dust(get_parent(), global_position, 2)
		if t >= lead + up_time:
			queue_free()
			return
		var h := current_height()
		if h >= 3.0:
			_hit(h)
		queue_redraw()

	## 现在顶起来多高
	func current_height() -> float:
		var t := _t - delay - lead
		if t < 0.0:
			return 0.0
		var up := clampf(t / RISE, 0.0, 1.0)
		var down := clampf((up_time - t) / SINK, 0.0, 1.0)
		return roundf(height * minf(up, down))

	func _hit(h: float) -> void:
		var r := Rect2(global_position.x - width / 2.0, global_position.y - h, width, h)
		for n in get_tree().get_nodes_in_group("player"):
			var p := n as Player
			# 主角的身子：6×16，原点在脚底中间
			if p and r.intersects(Rect2(p.global_position + Vector2(-3, -16), Vector2(6, 16))):
				p.hurt(global_position + Vector2(0, 4), damage)
		for n in get_tree().get_nodes_in_group("crystal"):
			var c := n as Crystal
			if c and c.carrier == null and r.intersects(Rect2(c.global_position + Vector2(-2.5, -8), Vector2(5, 8))):
				c.take_hit(global_position + Vector2(0, 4), damage)

	func _draw() -> void:
		var t := _t - delay
		var hw := floorf(width / 2.0)
		if t < 0.0:
			if preview and int(_t / 0.12) % 2 == 0:
				draw_rect(Rect2(-hw, -1, width, 1), Color(FLASH, 0.45))
			return
		if t < lead:
			# 地面闪：一亮一暗，越到后面越快
			var blink := int(t / (0.05 if t > lead * 0.5 else 0.08)) % 2 == 0
			if blink:
				draw_rect(Rect2(-hw - 1, -1, width + 2, 2), Color(FLASH, 0.9))
				draw_rect(Rect2(-hw, -2, width, 1), Color(FLASH, 0.4))
			if marker:
				# 往下指的箭头，在柱子顶的高度上
				var y := -height - 6.0
				var c := Color(FLASH, 0.95 if blink else 0.5)
				draw_rect(Rect2(-3, y, 7, 1), c)
				draw_rect(Rect2(-2, y + 1, 5, 1), c)
				draw_rect(Rect2(-1, y + 2, 3, 1), c)
				draw_rect(Rect2(0, y + 3, 1, 1), c)
			return
		var h := current_height()
		if h <= 0.0:
			return
		# 一根白键：顶上最亮，左边亮一档，右边暗，中间一道黑缝像琴键之间的缝
		draw_rect(Rect2(-hw, -h, width, h), KEY)
		draw_rect(Rect2(-hw, -h, 1, h), KEY_LEFT)
		draw_rect(Rect2(hw - 1, -h, 1, h), KEY_SHADE)
		draw_rect(Rect2(-hw, -h, width, 1), KEY_TOP)
		draw_rect(Rect2(-1, -h + 3, 2, minf(5.0, h - 3.0)), KEY_GAP)
		# 底下压着的地面亮一条，像被顶起的接缝
		draw_rect(Rect2(-hw - 1, -1, width + 2, 1), Color(FLASH, 0.35))
