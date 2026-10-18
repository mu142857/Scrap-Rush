extends CanvasLayer
## 第二关开场动画（10-18 作者："第二关可以是电影胶片很快的过去"，要电影感、高级感、流畅）。
## 放在气动管开场（tube_run.gd）最上面一层，播的时候整棵树暂停，管道还没开始跑。
##
##   0.00  倒计时片头 3、2、1：全屏的老胶片片头（圆圈、十字线、扫过的扇形），每个数字 0.3 秒
##   0.90  一条胶片横着从右往左卷过画面，越转越快（指数加速）：格子里是第二关的地方和精英的剪影
##         快了以后带拖影、上下抖、闪得更厉害，声音从一下下咔嗒连成一片嗡
##   3.20  卡住：最后一格（接线员大厅的气动管口）停在正中，片门里打滑抖两下
##   3.50  烧片：从画面中间烧出一个洞，一圈焦黑、一圈橙、里面白，0.45 秒烧满
##   3.95  全白，这一刻放开暂停、气动管开始跑；白慢慢退掉（0.55 秒），露出管道
##
## 素材：草图/第二关/level2_intro_art.py（胶片带、片头、烧穿噪声），声音：草图/第二关/level2_sfx.py intro（和这里同一张时间表）。
## 只在第一次进气动管时播（按 R / 暂停菜单重来不播），任意键跳过（0.25 秒以后）。
## 调试：--intro 强制播；--tubeauto、--tubeat 这些调试参数默认不播。

signal finished

const STRIP := preload("res://art/levels/level2_intro_strip.png")
const LEADER := preload("res://art/levels/level2_intro_leader.png")
const BURN := preload("res://art/levels/level2_intro_burn.png")
const SOUND := preload("res://sfx/level2_intro.wav")

## 时间表（和 level2_sfx.py 的 I_* 一致）
const LEADER_T := 0.9
const ROLL_T := 2.3
const JAM_T := 0.3
const BURN_T := 0.45
const FADE_T := 0.55
## 卷片：一共走多少屏幕像素（13 格 × 每格 200）、加速弯度；正好停在最后一格正中
const DIST := 2600.0
const K := 3.2
const SCALE := 2.0
const PITCH := 100.0
const STRIP_W := 1400.0
const STRIP_H := 88.0
const SKIP_AFTER := 0.25
const BAR_H := 22.0

const SEPIA_DARK := Color8(28, 19, 15)
const WHITE := Color(1.0, 0.97, 0.9)

var _t := 0.0
var _released := false
var _view: Node2D
var _burn: ColorRect
var _burn_mat: ShaderMaterial
var _sound: AudioStreamPlayer
var _flick := 1.0
var _flick_t := 0.0
var _weave := 0.0
var _scratch: Array = []
var _dust: Array = []


## 要不要播：第一次进气动管才播（重来不播），调试参数默认不播
static func wanted() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.has("--intro"):
		return true
	if Run.get("_resuming"):
		return false
	for a in args:
		if a.begins_with("--tube"):
			return false
	return true


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_view = Node2D.new()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.draw.connect(_draw_view)
	add_child(_view)
	# 烧穿：一张全屏的色块，着色器按噪声图一圈圈烧开（噪声图 160×90，放大 3 倍，烧开的边也是方的）
	_burn = ColorRect.new()
	_burn.size = Vector2(480, 270)
	_burn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burn_mat = ShaderMaterial.new()
	_burn_mat.shader = _burn_shader()
	_burn_mat.set_shader_parameter("noise", BURN)
	_burn_mat.set_shader_parameter("progress", 0.0)
	_burn.material = _burn_mat
	_burn.visible = false
	add_child(_burn)
	_sound = AudioStreamPlayer.new()
	_sound.stream = SOUND
	_sound.volume_db = -4.0
	_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sound)
	_sound.play()


static func _burn_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
uniform sampler2D noise : filter_nearest;
uniform float progress = 0.0;
void fragment() {
	float n = texture(noise, UV).r;
	float edge = progress * 1.2 - 0.08;
	vec4 c = vec4(0.0);
	if (n < edge - 0.07) {
		c = vec4(1.0, 0.97, 0.9, 1.0);
	} else if (n < edge - 0.035) {
		c = vec4(1.0, 0.72, 0.32, 1.0);
	} else if (n < edge) {
		c = vec4(0.16, 0.07, 0.03, 1.0);
	}
	COLOR = c;
}
"""
	return s


func _input(event: InputEvent) -> void:
	if _released or _t < SKIP_AFTER:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		_t = LEADER_T + ROLL_T + JAM_T + BURN_T
		var tw := create_tween()
		tw.tween_property(_sound, "volume_db", -60.0, 0.3)


func _process(delta: float) -> void:
	_t += delta
	var t_roll := LEADER_T
	var t_jam := t_roll + ROLL_T
	var t_burn := t_jam + JAM_T
	var t_fade := t_burn + BURN_T
	var t_end := t_fade + FADE_T
	# 老胶片的闪烁、上下抖、划痕、灰点：每 0.05~0.1 秒换一次；越转越快闪得越厉害
	var speed := 0.0
	if _t >= t_roll and _t < t_jam:
		speed = exp(K * (_t - t_roll) / ROLL_T) / exp(K)
	_flick_t -= delta
	if _flick_t <= 0.0:
		_flick_t = randf_range(0.05, 0.1)
		_flick = 1.0 - randf() * (0.1 + 0.15 * speed)
		if randf() < 0.06:
			_flick = 0.75
		_weave = 0.0 if randf() < 0.75 else (1.0 if randf() < 0.5 else -1.0) * (1.0 + roundf(speed * 2.0))
		_scratch.clear()
		for i in randi() % 3:
			_scratch.append(Vector3(randi() % 480, randi() % 120, 60 + randi() % 200))
		_dust.clear()
		for i in randi() % 6:
			_dust.append(Vector2(randi() % 480, randi() % 270))
	if _t >= t_burn and _t < t_fade:
		_burn.visible = true
		_burn_mat.set_shader_parameter("progress", (_t - t_burn) / BURN_T)
	elif _t >= t_fade:
		_burn.visible = false
	# 全白那一刻放开暂停，气动管开始跑；白慢慢退
	if _t >= t_fade and not _released:
		_released = true
		get_tree().paused = false
	if _t >= t_end:
		finished.emit()
		queue_free()
		return
	_view.queue_redraw()


func _draw_view() -> void:
	var t_roll := LEADER_T
	var t_jam := t_roll + ROLL_T
	var t_burn := t_jam + JAM_T
	var t_fade := t_burn + BURN_T
	if _t >= t_fade:
		var a := 1.0 - clampf((_t - t_fade) / FADE_T, 0.0, 1.0)
		_view.draw_rect(Rect2(0, 0, 480, 270), Color(WHITE, a * a))
		return
	_view.draw_rect(Rect2(0, 0, 480, 270), Color(0.03, 0.02, 0.02))
	var k := _flick
	if _t < t_roll:
		# 倒计时片头：3、2、1 各 0.3 秒，每个数字 6 张扇形
		var d := mini(int(_t / 0.3), 2)
		var f := mini(int(fmod(_t, 0.3) / 0.3 * 6.0), 5)
		_view.draw_texture_rect_region(LEADER, Rect2(0, _weave * 3.0, 480, 270), Rect2(f * 160, d * 90, 160, 90), Color(k, k * 0.98, k * 0.94))
	else:
		var off := DIST
		var v := 0.0
		var shake := _weave
		if _t < t_jam:
			var u := (_t - t_roll) / ROLL_T
			off = DIST * (exp(K * u) - 1.0) / (exp(K) - 1.0)
			v = DIST * K * exp(K * u) / (exp(K) - 1.0) / ROLL_T
		else:
			# 卡住：片门里打滑，上下猛抖两下再停
			var j := _t - t_jam
			shake = -6.0 if j < 0.06 else (4.0 if j < 0.12 else (-2.0 if j < 0.18 else 0.0))
			if j < 0.05:
				k = 1.25
		# 片子后面一层暖色的放映光
		_view.draw_rect(Rect2(0, 40, 480, 190), Color(0.12, 0.08, 0.05))
		var y0 := roundf((270.0 - STRIP_H * SCALE) * 0.5 + shake)
		var x := 240.0 - PITCH * 0.5 * SCALE - off
		var col := Color(k, k * 0.98, k * 0.94)
		_strip(roundf(x), y0, col)
		# 快了以后加拖影：往来的方向（右边）错开两份淡的，像快门开着时片子还在走
		var step := v / 60.0
		if step > 10.0:
			_strip(roundf(x + step * 0.35), y0, Color(col, 0.35))
			_strip(roundf(x + step * 0.7), y0, Color(col, 0.18))
	# 满屏的划痕和灰点（片头、卷片、卡住都有）
	for s in _scratch:
		_view.draw_rect(Rect2(s.x, s.y, 1, s.z), Color(1.0, 0.95, 0.85, 0.3))
	for p in _dust:
		_view.draw_rect(Rect2(p, Vector2(2, 2)), Color(0.05, 0.03, 0.02, 0.6))
	# 上下黑边（电影画幅）
	_view.draw_rect(Rect2(0, 0, 480, BAR_H), Color.BLACK)
	_view.draw_rect(Rect2(0, 270 - BAR_H, 480, BAR_H), Color.BLACK)


## 胶片带：贴图首尾相接，横着铺满画面
func _strip(x: float, y: float, col: Color) -> void:
	var w := STRIP_W * SCALE
	var xs := fposmod(x, w) - w
	while xs < 480.0:
		_view.draw_texture_rect(STRIP, Rect2(xs, y, w, STRIP_H * SCALE), false, col)
		xs += w
