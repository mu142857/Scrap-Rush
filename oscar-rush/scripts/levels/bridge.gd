class_name Bridge
extends Node2D
## 第一关底层那座桥（Oscar 原稿的 QIAO 图层，27 帧）和右上角的吊车臂（图层 3，27 帧）。
## 第 0 帧桥完整伸出（449~808，桥面 y=343，厚到 379），往后每帧左端往右缩 15 像素，第 24 帧起整座桥收进右边柱子。
## extend()：桥从柱子里一截截伸出来（26 → 0）；retract()：收回去（0 → 26）。吊车臂每次都跟着摆一遍。
## 碰撞跟着桥面走；桥下面到地面（414）留 35 像素，人能从桥下走过。
## 加进关卡时要放在视差背景后面，和原图一样夹在 near_a/near_b/near_c 中间（见 test_level.gd）。

signal moved

const BRIDGE_TEX := preload("res://art/levels/scene1_bridge.png")
const CRANE_TEX := preload("res://art/levels/scene1_crane.png")
const FRAMES := 27
## 每帧多大。27 帧原来横排一行，桥那张有 9720 宽，超过 WebGL2 保证的 2048，手机、集显上可能画不出来；
## 现在导出时排成多行（每行不超过 2048 宽，tools/export_art.py），这里按贴图大小算几列几行，帧号照旧按行数
const BRIDGE_FRAME := Vector2i(360, 37)
const CRANE_FRAME := Vector2i(91, 161)
const FRAME_TIME := 0.1
const BRIDGE_POS := Vector2(449, 343)
const CRANE_POS := Vector2(912, 0)
const RIGHT_X := 808.0
const TOP_Y := 343.0
const THICK := 36.0
## 第 i 帧桥面左端：450 + 15i，第 24 帧起没有桥
const GONE_FRAME := 24

## 现在是第几帧（可以是小数，动画中间）
var frame := 26.0
var busy := false

var _bridge: Sprite2D
var _crane: Sprite2D
var _shape: CollisionShape2D
var _rumble: AudioStreamPlayer


func _ready() -> void:
	_crane = _sheet(CRANE_TEX, CRANE_POS, -16, CRANE_FRAME)
	_bridge = _sheet(BRIDGE_TEX, BRIDGE_POS, -15, BRIDGE_FRAME)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	body.add_child(_shape)
	add_child(body)
	_rumble = AudioStreamPlayer.new()
	var st := Game.load_sound("suction").duplicate() as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = st.data.size() / 2
	_rumble.stream = st
	_rumble.volume_db = -12.0
	_rumble.pitch_scale = 0.7
	add_child(_rumble)
	_apply()


func _sheet(tex: Texture2D, pos: Vector2, z: int, cell: Vector2i) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = tex.get_width() / cell.x
	s.vframes = tex.get_height() / cell.y
	s.centered = false
	s.position = pos
	s.z_index = z
	add_child(s)
	return s


## 立刻摆到某一帧（0 = 伸出，26 = 收起），不播动画
func set_state(f: float) -> void:
	frame = f
	_crane.frame = 0
	_apply()


func extend() -> void:
	await _play(float(FRAMES - 1), 0.0)


func retract() -> void:
	await _play(0.0, float(FRAMES - 1))


## 桥面现在的左端 x（没有桥时返回右边柱子的 x）
func left_x() -> float:
	var f := int(roundf(frame))
	return RIGHT_X if f >= GONE_FRAME else 450.0 + 15.0 * f


func _play(from: float, to: float) -> void:
	busy = true
	Game.sfx("alarm", -10.0, 0.8)
	Game.sfx("clang", -8.0, 0.6)
	_rumble.play()
	var dur := FRAMES * FRAME_TIME
	var t := 0.0
	while t < dur:
		# 桥伸到一半关卡被重来（马灯碎了、按 R）：节点已经不在树上了，别再等
		if not is_inside_tree():
			return
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		t += get_physics_process_delta_time()
		var k := clampf(t / dur, 0.0, 1.0)
		var last := int(roundf(frame))
		frame = lerpf(from, to, k)
		# 吊车臂每次都从头摆一遍
		_crane.frame = mini(int(k * FRAMES), FRAMES - 1)
		_apply()
		if int(roundf(frame)) != last:
			Game.add_shake(1.0)
			moved.emit()
	_rumble.stop()
	Game.sfx("clang", -4.0, 0.8)
	Game.add_shake(4.0)
	Game.dust(get_parent(), Vector2(left_x(), TOP_Y), 6)
	busy = false


func _apply() -> void:
	var f := clampi(int(roundf(frame)), 0, FRAMES - 1)
	_bridge.frame = f
	var lx := left_x()
	var gone := f >= GONE_FRAME
	_shape.disabled = gone
	if not gone:
		var r := _shape.shape as RectangleShape2D
		r.size = Vector2(RIGHT_X - lx, THICK)
		_shape.position = Vector2((lx + RIGHT_X) / 2.0, TOP_Y + THICK / 2.0)
