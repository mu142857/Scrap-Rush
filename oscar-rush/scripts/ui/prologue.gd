class_name Prologue
extends Control
## 胶片序章（2026-10-19 作者："我觉得可以加，我觉得你做这样的挺有氛围的"）。新开一局时放，约 27 秒。
## 10-19 晚作者看完第一版："场景没有美感，立绘最好不要单独出现；为什么制作名单比这个更有电影感？"
## 于是照制作人员页（credits_menu.gd）的做法重做：整屏一格胶片、上下齿孔带，每格是原大像素的游戏场景（不缩放），
## 慢慢平移、有视差、有会动的东西，换格时放映机把胶片横着往前拉一格。四格：
##   1 锅炉房：五层视差慢慢平移，中层大梁上几只小怪在走      "旧机器都被扔到这颗废品星上。它们死不透。"
##   2 第二关放胶片盘的机房：四人提着马灯走过墙上那幅家的画    "我们把家的最后一盘录像带，封进了一盏马灯。"
##     （第一版是代码画的夜景城市加屋顶剪影，作者："生成的不好，有问题且没质感"，换成关卡里现成的房间）
##   3 第三关 Boss 房：四人站在那台老电视前，屏幕里闪出家      "最深处，还有一台老电视能放它。"
##   4 家（结局里老电视放的那张）：四人从坠毁的飞船走向房子    "山坡上那栋房子。去看看门廊的灯还亮不亮。"
## 开头是第二关那套 3、2、1 片头；放完画面慢慢暗到黑（放映机停了），再切到下一个场景，下一个场景从黑里淡入
## （作者：以前烧成白一下跳到教学关太突兀）。
## 翻页：任意键、鼠标、手柄键、触屏 = 下一格（倒计时里按就直接开片；最后一格按就暗场、走）。
## Esc / 手柄 Start 整段跳过（10-19 作者：任意键跳过整段不行，要一次翻一页）。
## 全用现成的贴图加画矩形，不加新图。

const LEADER := preload("res://art/levels/level2_intro_leader.png")
const WHITE := Color(1.0, 0.97, 0.9)

## 走完去哪。开始界面在切过来之前设好（新开一局的流程）；默认去选武器
static var next_scene := "res://scenes/weapon_select.tscn"

const SCREEN := Vector2(480, 270)
## 胶片：和制作人员页一样的尺寸
const BAND := 14.0
const PIC := Vector2(480, 242)
const GAP := 24.0
const PITCH := 480.0 + GAP
const HOLE := Vector2(8, 5)
const HOLE_STEP := 24.0
const FILM_BASE := Color(0.085, 0.062, 0.046)
const FILM_BAND := Color(0.12, 0.088, 0.064)
const FILM_HOLE := Color(0.42, 0.35, 0.26)

## 时间轴（秒）
const T_LEADER := 0.4
const LEADER_NUM := 0.6
const ROLL := 0.7          # 拉一格用多久
const HOLD := 4.8          # 每格停多久（最后一格 LAST_HOLD）
const LAST_HOLD := 5.6
const CAP_IN := 0.5        # 停稳后多久出字幕
const END_FADE := 1.6      # 放完暗到黑
const END_BLACK := 0.3

const SHOTS := [
	{"kind": "junk", "gain": 2.3, "caption": "Old machines get dumped here. They don't stay dead."},
	{"kind": "reels", "gain": 1.5, "caption": "We sealed the last tape of home inside a lantern."},
	{"kind": "tv", "gain": 1.25, "caption": "Deep inside, one old TV can still play it."},
	{"kind": "home", "gain": 1.0, "caption": "The house on the hill. Let's go see if the porch light is on."},
]

## 主角四人（贴图 16×20 一格、7 格：0~3 待机，4~6 走），走在最前面的红色提马灯
const CREW := ["red", "robot", "dino", "bird"]
const CREW_GAP := 15.0
const WALK_FRAME := 0.13
const IDLE_FRAME := 0.2
## 马灯的形状照 crystal.gd 的 _draw：[y, x0, 宽, 0 铁暗 / 1 铁 / 2 玻璃 / 3 灯芯]
const LANTERN_ROWS := [
	[-9, 0, 1, 0], [-8, -1, 3, 0], [-7, -2, 5, 1],
	[-6, -2, 5, 1], [-6, -1, 3, 2],
	[-5, -2, 5, 1], [-5, -1, 3, 2], [-5, 0, 1, 3],
	[-4, -2, 5, 1], [-4, -1, 3, 2], [-4, 0, 1, 3],
	[-3, -2, 5, 1], [-3, -1, 3, 2],
	[-2, -2, 5, 1], [-1, -3, 7, 0],
]

## 老胶片色：和制作人员页一样压成棕褐色，亮度高一些（这里字幕在下面的暗条上，不用整格压暗）
const SEPIA := """
shader_type canvas_item;
uniform float bright = 0.9;
void fragment() {
	// COLOR 进来时已经是贴图 × 画的颜色 × modulate：代码画的矩形没有贴图，只能从这里拿颜色
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(vec3(l * 1.08, l * 0.86, l * 0.6) * bright, c.a);
}
"""

## 这一段放哪几格、拉一格多久（幕间 Interlude 继承这个类、换掉这两样）
var shots: Array = SHOTS
var roll_time := ROLL

var _t := 0.0
var _phase := "leader"     # leader → roll → hold → roll → … → end
var _shot := -1            # 现在停在第几格（-1 = 片头）
var _roll := 0.0           # 胶片一共往前拉了多少像素
var _hold_t := 0.0
var _end_t := 0.0
var _done := false
var _tex := {}             # 贴图都在 _ready 里载好拿着
var _film: Control         # 底色、片头
var _pics: Control         # 每格的画面（Shot）
var _top: Control          # 划痕、灰点、齿孔带、字幕底下的暗条
var _black: ColorRect      # 暗场
var _caption: Label
var _hint: Label
var _loop: AudioStreamPlayer
var _flick := 1.0
var _flick_t := 0.0
var _weave := 0.0
var _scratch: Array = []
var _dust: Array = []
var _last_num := -1
var _material: ShaderMaterial


func _ready() -> void:
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for n in ["scene1_far", "scene1_beams", "scene1_machines", "scene1_truss", "scene1_near", "level2_far_0", "level2_mid_0", "level2_main_0"]:
		_tex[n] = load("res://art/levels/%s.png" % n)
	for n in ["room3_bg", "room3_fg", "tv_body", "hometown"]:
		_tex[n] = load("res://art/boss/%s.png" % n)
	for n in ["crawler", "kettle", "flea"]:
		_tex[n] = load("res://art/enemies/%s.png" % n)
	for n in CREW:
		_tex[n + "_body"] = load("res://art/chars/%s_body.png" % n)
		_tex[n + "_strip"] = load("res://art/chars/%s_strip.png" % n)
	_material = ShaderMaterial.new()
	_material.shader = Shader.new()
	_material.shader.code = SEPIA
	_film = Control.new()
	_film.size = SCREEN
	_film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_film.draw.connect(_draw_film)
	add_child(_film)
	_pics = Control.new()
	_pics.size = SCREEN
	_pics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pics)
	for i in shots.size():
		var s := Shot.new()
		s.owner_prologue = self
		s.index = i
		s.kind = shots[i]["kind"]
		s.gain = shots[i]["gain"]
		s.size = PIC
		s.material = _material
		s.visible = false
		_pics.add_child(s)
	_top = Control.new()
	_top.size = SCREEN
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.draw.connect(_draw_top)
	add_child(_top)
	_caption = Label.new()
	_caption.label_settings = Hud.small_text(Color(0.95, 0.9, 0.8))
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.position = Vector2(0, SCREEN.y - BAND - 24.0)
	_caption.size = Vector2(480, 18)
	_caption.modulate.a = 0.0
	add_child(_caption)
	_hint = Label.new()
	_hint.label_settings = Hud.small_text(Color(0.6, 0.56, 0.5))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.position = Vector2(0, BAND + 4.0)
	_hint.size = Vector2(472, 14)
	_hint.text = tr("Any key: next    Esc: skip")
	_hint.modulate.a = 0.0
	add_child(_hint)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.size = SCREEN
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	add_child(_black)
	_loop = AudioStreamPlayer.new()
	_loop.stream = load("res://sfx/amb_projector.wav")
	_loop.volume_db = -12.0
	add_child(_loop)
	_loop.play()
	# 自测：-- --pshot=<格> 直接停在第几格，--pat=<秒> 再往后放这么久（拍单帧看画面用）；
	# --proll=<格> 从上一格停满、正要往这一格拉的那一刻开始放（分段录像用，一段接一段拼起来是连着的）
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--proll="):
			var i := arg.trim_prefix("--proll=").to_int()
			if i > 0:
				_jump_to(i - 1)
				_hold_t = HOLD
				var prev: Shot = _pics.get_child(i - 1)
				prev.t = HOLD + ROLL
		elif arg.begins_with("--pshot="):
			_jump_to(arg.trim_prefix("--pshot=").to_int())
		elif arg.begins_with("--pat="):
			var at := arg.trim_prefix("--pat=").to_float()
			_hold_t = at
			for s: Shot in _pics.get_children():
				s.t = at


func _jump_to(i: int) -> void:
	_shot = i
	_roll = (i + 1) * PITCH
	_phase = "hold"
	_hold_t = 0.0
	_t = T_LEADER + LEADER_NUM * 3.0 + 1.0
	_pics.get_child(i).visible = true


# ---------------------------------------------------------------- 时间轴

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	match _phase:
		"leader":
			if _t >= T_LEADER:
				var n := int((_t - T_LEADER) / LEADER_NUM)
				if n != _last_num and n < 3:
					_last_num = n
					Game.sfx("tvclick", -8.0, 0.7 - n * 0.05)   # 和开游戏片头一样：音高 0.7 往下降
			if _t >= T_LEADER + LEADER_NUM * 3.0:
				_next()
		"hold":
			_hold_t += delta
			if _hold_t >= _hold_len():
				_next()
		"end":
			_end_t += delta
			_black.modulate.a = clampf(_end_t / END_FADE, 0.0, 1.0)
			_loop.volume_db = lerpf(-12.0, -50.0, clampf(_end_t / END_FADE, 0.0, 1.0))
			if _end_t >= END_FADE + END_BLACK:
				_finish()
				return
	if OS.get_cmdline_user_args().has("--pdebug") and int(_t * 2.0) != int((_t - delta) * 2.0):
		print("prologue t=%.1f phase=%s shot=%d hold=%.1f caption=%s" % [_t, _phase, _shot, _hold_t, _caption.text])
	_hint.modulate.a = clampf((_t - 0.6) * 2.0, 0.0, 0.7) if _phase != "end" else 0.0
	_update_caption()
	# 老胶片的闪烁、上下抖、划痕、灰点：每 0.05~0.1 秒换一次（参数照制作人员页，淡一些）
	_flick_t -= delta
	if _flick_t <= 0.0:
		_flick_t = randf_range(0.05, 0.1)
		_flick = 1.0 - randf() * 0.12
		if randf() < 0.05:
			_flick = 0.82
		_weave = 0.0 if randf() < 0.8 else (1.0 if randf() < 0.5 else -1.0)
		_scratch.clear()
		for i in randi() % 3:
			_scratch.append(Vector3(randi() % 480, BAND + randi() % 100, 40 + randi() % 140))
		_dust.clear()
		for i in randi() % 5:
			_dust.append(Vector2(randi() % 480, BAND + randi() % int(PIC.y - 2.0)))
	for s: Shot in _pics.get_children():
		s.position = Vector2(roundf((s.index + 1) * PITCH - _roll), BAND + _weave)
		var k := _flick * s.gain
		s.modulate = Color(k, k, k)
	_film.queue_redraw()
	_top.queue_redraw()


func _hold_len() -> float:
	return LAST_HOLD if _shot == shots.size() - 1 else HOLD


## 往下一格：片头 / 停着的格 → 拉到下一格；最后一格 → 暗场
func _next() -> void:
	if _phase == "roll" or _phase == "end":
		return
	if _shot >= shots.size() - 1:
		_start_end()
		return
	_phase = "roll"
	_shot += 1
	_hold_t = 0.0
	var s: Shot = _pics.get_child(_shot)
	s.visible = true
	s.t = 0.0
	Game.sfx("tvon" if _shot == 0 else "tvclick", -8.0 if _shot == 0 else -6.0, 0.9 if _shot == 0 else 0.6)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _roll = v, _roll, (_shot + 1) * PITCH, roll_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(func() -> void:
		if _phase == "roll":
			_phase = "hold"
			for c: Shot in _pics.get_children():
				c.visible = c.index == _shot)


func _start_end() -> void:
	if _phase == "end":
		return
	_phase = "end"
	_end_t = 0.0


func _update_caption() -> void:
	var a := 0.0
	if _phase == "hold" and _shot >= 0:
		_caption.text = tr(shots[_shot]["caption"])
		a = clampf((_hold_t - CAP_IN) * 2.5, 0.0, 1.0)
		if _shot < shots.size() - 1:
			a = minf(a, clampf((_hold_len() - _hold_t) * 3.0, 0.0, 1.0))
	_caption.modulate.a = a if a > 0.0 else move_toward(_caption.modulate.a, 0.0, 0.12)


# ---------------------------------------------------------------- 画：胶片

func _draw_film() -> void:
	var k := _flick
	_film.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color.BLACK)
	var first := floori(_roll / PITCH)
	for n in range(first, first + 2):
		var x := roundf(n * PITCH - _roll)
		if x >= SCREEN.x or x + PITCH <= 0.0:
			continue
		_film.draw_rect(Rect2(x, BAND + _weave, PIC.x, PIC.y), Color(FILM_BASE.r * k, FILM_BASE.g * k, FILM_BASE.b * k))
		# 第 0 格是片头：3、2、1，每个数字 6 张扇形（第二关开场的片头图），铺满整屏
		if n == 0 and _t >= T_LEADER:
			var d := mini(int((_t - T_LEADER) / LEADER_NUM), 2)
			var f := mini(int(fmod(minf(_t - T_LEADER, LEADER_NUM * 3.0 - 0.001), LEADER_NUM) / LEADER_NUM * 6.0), 5)
			_film.draw_texture_rect_region(LEADER, Rect2(x, _weave * 3.0, SCREEN.x, SCREEN.y), Rect2(f * 160, d * 90, 160, 90),
					Color(k, k * 0.98, k * 0.94))


func _draw_top() -> void:
	var k := _flick
	for sc in _scratch:
		_top.draw_rect(Rect2(sc.x, sc.y + _weave, 1, sc.z), Color(1.0, 0.95, 0.85, 0.14))
	for p in _dust:
		_top.draw_rect(Rect2(p + Vector2(0, _weave), Vector2(2, 2)), Color(0.02, 0.012, 0.008, 0.55))
	# 字幕底下一条往下变暗的暗条（2 像素一阶），字在亮画面上也清楚
	var ca := _caption.modulate.a
	if ca > 0.0:
		var y0 := SCREEN.y - BAND - 40.0
		var y := y0
		while y < SCREEN.y - BAND:
			var u := (y - y0) / 40.0
			_top.draw_rect(Rect2(0, y, SCREEN.x, 2), Color(0, 0, 0, 0.62 * u * ca))
			y += 2.0
	# 上下齿孔带：齿孔跟着胶片走
	var band := Color(FILM_BAND.r * k, FILM_BAND.g * k, FILM_BAND.b * k)
	var hole := Color(FILM_HOLE.r * k, FILM_HOLE.g * k, FILM_HOLE.b * k)
	for by: float in [0.0, SCREEN.y - BAND]:
		_top.draw_rect(Rect2(0, by, SCREEN.x, BAND), band)
		var hx := -fposmod(_roll, HOLE_STEP) + 8.0
		while hx < SCREEN.x:
			_top.draw_rect(Rect2(roundf(hx), by + roundf((BAND - HOLE.y) * 0.5), HOLE.x, HOLE.y), hole)
			hx += HOLE_STEP
	# 倒数完放映机灯"啪"一下亮：0.25 秒退掉
	var t_film := T_LEADER + LEADER_NUM * 3.0
	if _t >= t_film and _t < t_film + 0.25 and _shot <= 0:
		var a := 1.0 - (_t - t_film) / 0.25
		_top.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(WHITE, a * a * 0.8))


# ---------------------------------------------------------------- 跳过、结束

func _input(event: InputEvent) -> void:
	if _done:
		return
	var is_btn := event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton \
			or event is InputEventScreenTouch
	if not is_btn:
		return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo() or _t < 0.2:
		return
	var skip_all: bool = (event is InputEventKey and event.keycode == KEY_ESCAPE) \
			or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START)
	if skip_all:
		# Esc / Start = 跳过整段序章，照常往下走（进教学或选难度）；其余的键一次翻一页（10-19 作者在宣传视频会话里定的）。
		# 作者报的"退出回到选难度、不回主菜单"是暂停菜单的事，那边"回标题"会清标记，不在这里
		_start_end()
	else:
		_next()


func _finish() -> void:
	_done = true
	print("prologue: done at %.1fs -> %s" % [_t, next_scene])
	var tree := get_tree()
	# 下一个场景从黑里淡入：切场景时先盖着全黑（60 秒才退，等于不动），新场景进来了再用 1 秒淡开。
	# 不在这里直接开始淡：载入教学关那一帧很长，淡入会被它吃掉一大截，看起来还是"突然就到了"
	Game.flash(Color.BLACK, 1.0, 60.0)
	tree.scene_changed.connect(func() -> void: Game.flash(Color.BLACK, 1.0, 1.0), CONNECT_ONE_SHOT)
	tree.change_scene_to_file.call_deferred(next_scene)


# ---------------------------------------------------------------- 画：每一格

## 主角四人一排：feet = 最前面那个（红色）的脚底，往右走；走路 / 站着播自己的帧；红色手里提马灯
func draw_crew(c: CanvasItem, feet: Vector2, t: float, walking: bool, lantern_lit: float) -> void:
	for k in range(CREW.size() - 1, -1, -1):
		var n: String = CREW[k]
		var p := (feet - Vector2(k * CREW_GAP, 0)).round()
		var fr := 4 + int(t / WALK_FRAME + k) % 3 if walking else int(t / IDLE_FRAME + k * 1.3) % 4
		var src := Rect2(fr * 16, 0, 16, 20)
		var dst := Rect2(p.x - 8, p.y - 20, 16, 20)
		c.draw_texture_rect_region(_tex[n + "_body"], dst, src)
		c.draw_texture_rect_region(_tex[n + "_strip"], dst, src)
	var hand := feet.round() + Vector2(6, -2)
	draw_lantern(c, hand, t, lantern_lit)


## 1 倍大的马灯（原点在灯座底部中间）加一圈暖光
func draw_lantern(c: CanvasItem, base: Vector2, t: float, lit: float) -> void:
	var glass_c := base + Vector2(0, -5)
	var pulse := 1.0 + sin(t * 4.0) * 0.06
	for k in 4:
		disc(c, Rect2(Vector2.ZERO, PIC), glass_c, (14.0 + k * 13.0) * pulse, Color(1.0, 0.85, 0.55, 0.075 * lit * (1.0 - k * 0.2)))
	var cols := [Crystal.IRON_DARK, Crystal.IRON, Crystal.GLASS, Crystal.GLASS_CORE]
	var swing := roundf(sin(t * 2.6) * 0.6)
	for r in LANTERN_ROWS:
		c.draw_rect(Rect2(base.x + r[1] + (swing if r[0] < -6 else 0.0), base.y + r[0], r[2], 1), cols[r[3]])


## 像素圆（一行一条，切在 clip 里）
func disc(c: CanvasItem, clip: Rect2, center: Vector2, r: float, col: Color) -> void:
	var ri := int(r)
	for dy in range(-ri, ri + 1):
		var yy := roundf(center.y) + dy
		if yy < clip.position.y or yy >= clip.end.y:
			continue
		var hw := floorf(sqrt(r * r - dy * dy))
		var x0 := maxf(roundf(center.x) - hw, clip.position.x)
		var x1 := minf(roundf(center.x) + hw + 1.0, clip.end.x)
		if x1 > x0:
			c.draw_rect(Rect2(x0, yy, x1 - x0, 1), col)


## 一格胶片里的画面（照制作人员页的 Picture）：t 从这一格开始往里拉的时候算起
class Shot extends Control:
	var owner_prologue: Prologue
	var index := 0
	var kind := ""
	var gain := 1.0
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		if visible:
			t += delta
			queue_redraw()

	func _draw() -> void:
		match kind:
			"junk":
				_draw_junk()
			"reels":
				_draw_reels()
			"tv":
				_draw_tv()
			"home":
				_draw_home()
			"wall":
				_draw_wall()

	func _tex(n: String) -> Texture2D:
		return owner_prologue._tex[n]

	## 1 锅炉房：五层视差（远的走得慢），镜头每秒往右 9 像素；中层大梁（y=208）上小怪慢慢往左爬
	func _draw_junk() -> void:
		var x0 := 380.0
		var y0 := 112.0
		var pan := 9.0 * t
		var layers := [["scene1_far", 0.55], ["scene1_beams", 0.7], ["scene1_machines", 0.8], ["scene1_truss", 0.9], ["scene1_near", 1.0]]
		for l in layers:
			var rx := roundf(x0 + pan * float(l[1]))
			draw_texture_rect_region(_tex(l[0]), Rect2(Vector2.ZERO, size), Rect2(rx, y0, size.x, size.y))
		# 小怪：世界坐标（第一关场景）里的位置，减去最近一层的镜头
		var cam := roundf(x0 + pan)
		var mobs := [["crawler", 4, 640.0, -11.0], ["kettle", 3, 700.0, -7.0], ["crawler", 4, 790.0, -9.0], ["flea", 4, 560.0, -13.0]]
		for m in mobs:
			var tex := _tex(m[0])
			var hf: int = m[1]
			var fw := tex.get_width() / hf
			var fr := int(t * 6.0 + float(m[2])) % hf
			var wx: float = float(m[2]) + float(m[3]) * t
			var p := Vector2(roundf(wx - cam), 208.0 - y0 - tex.get_height())
			# 指示灯的一圈光（游戏里怪在黑暗里也靠这盏灯认），不然压成棕褐色以后和大梁混在一起
			var eye := p + Vector2(fw * 0.4, tex.get_height() * 0.35)
			for k in 2:
				owner_prologue.disc(self, Rect2(Vector2.ZERO, size), eye, 6.0 + k * 5.0, Color(1.0, 0.75, 0.5, 0.09 - k * 0.04))
			# 往左走：横着翻过来画
			draw_texture_rect_region(tex, Rect2(p.x + fw, p.y, -fw, tex.get_height()), Rect2(fr * fw, 0, fw, tex.get_height()))
			draw_rect(Rect2(eye.round(), Vector2(2, 1)), Color(1.0, 0.95, 0.8))

	## 2 第二关放胶片盘的机房（地图 x 540 起、地面 y=300，墙上挂着家的画）：三层一起慢慢往右移（远的慢），
	## 四人提着马灯往右走，走到画跟前
	func _draw_reels() -> void:
		var x0 := 540.0
		var y0 := 120.0
		var pan := 5.0 * t
		for l in [["level2_far_0", 0.6], ["level2_mid_0", 0.8], ["level2_main_0", 1.0]]:
			var rx := roundf(x0 + pan * float(l[1]))
			draw_texture_rect_region(_tex(l[0]), Rect2(Vector2.ZERO, size), Rect2(rx, y0, size.x, size.y))
		var feet := Vector2(roundf(150.0 + 13.0 * t - pan), 300.0 - y0)
		owner_prologue.draw_crew(self, feet, t, true, 1.0)


	## 3 第三关 Boss 房：屋子居中，两边黑；老电视在地上，屏幕先雪花再闪出家；四人站在左边看着它
	func _draw_tv() -> void:
		var room := Vector2(56, 7)
		draw_texture(_tex("room3_bg"), room, Color(0.75, 0.75, 0.75))
		draw_texture(_tex("room3_fg"), room, Color(0.75, 0.75, 0.75))
		var floor_y := room.y + 188.0
		var tv := _tex("tv_body")
		var to := Vector2(room.x + 150.0, floor_y - 70.0)
		var scr := Rect2(to + Vector2(12, 30), Vector2(47, 31))
		var show := clampf((t - 1.4) / 1.0, 0.0, 1.0)
		# 屏幕的光
		var sc := scr.get_center()
		for k in 3:
			owner_prologue.disc(self, Rect2(Vector2.ZERO, size), sc + Vector2(0, 6), 30.0 + k * 22.0,
					Color(0.85, 0.9, 1.0, (0.04 + show * 0.05) * (1.0 - k * 0.25)))
		draw_texture(tv, to)
		var home := _tex("hometown")
		var src_w := home.get_height() * scr.size.x / scr.size.y
		var src := Rect2((home.get_width() - src_w) * 0.5, 0, src_w, home.get_height())
		draw_texture_rect_region(home, scr, src, Color(1, 1, 1, show * (0.8 + randf() * 0.2)))
		for k in 40:
			draw_rect(Rect2(scr.position + Vector2(randi() % int(scr.size.x), randi() % int(scr.size.y)), Vector2.ONE),
					Color(0.95, 0.95, 0.9, 0.7 * (1.0 - show * 0.75)))
		var y := scr.position.y
		while y < scr.end.y:
			draw_rect(Rect2(scr.position.x, y, scr.size.x, 1), Color(0, 0, 0, 0.2))
			y += 2.0
		owner_prologue.draw_crew(self, Vector2(room.x + 122.0, floor_y), t, false, 0.8)
		# 两边：屋子外面是黑的
		draw_rect(Rect2(0, 0, room.x, size.y), Color(0.02, 0.015, 0.012))
		draw_rect(Rect2(room.x + 368.0, 0, size.x - room.x - 368.0, size.y), Color(0.02, 0.015, 0.012))

	## 4 家：整张往上提（小路在图的最底下，底下空出来的黑边放字幕），再慢慢往下落一点；
	## 四人从坠毁的飞船那儿沿小路走向房子
	func _draw_home() -> void:
		var home := _tex("hometown")
		var o := Vector2(18, roundf(-32.0 + minf(t, 6.0) * 0.5))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.012))
		draw_texture(home, o)
		# 小路：飞船旁边（x≈110, y≈232）到门口（x≈292, y≈216），图上的坐标
		var u := clampf(t * 13.0 / 182.0, 0.0, 1.0)
		var feet := o + Vector2(110, 232).lerp(Vector2(292, 216), u)
		owner_prologue.draw_crew(self, feet, t, u < 1.0, 1.0)

	## 第三关的电视墙（幕间用）：外壳和屏幕两层，镜头每秒往右 8 像素慢慢扫过一排排老电视
	func _draw_wall() -> void:
		var r := Rect2(roundf(120.0 + 8.0 * t), 650.0, size.x, size.y)
		draw_texture_rect_region(_tex("l3_mid_0"), Rect2(Vector2.ZERO, size), r)
		draw_texture_rect_region(_tex("l3_screens_0"), Rect2(Vector2.ZERO, size), r)
