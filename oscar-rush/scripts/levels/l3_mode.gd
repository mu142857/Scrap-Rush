class_name L3Mode
extends Node2D
## 第三关遭遇战的"特殊玩法"（2026-10-18 作者：每场都是一堆小怪再精英，太重复）。
## 每块场子屏幕可以挂一种，只在这场遭遇战开打、还没清场的时候起作用，清场就收掉。
##   blackout  停电：屏幕全黑，只有主角和马灯周围一圈看得见；怪只露出红色指示灯（子弹照常看得见）
##   wind      天气频道：一阵一阵的大风，先刮起风线预警，再把人往一边推
##   signal    信号干扰：雪花越来越重，顶上一条"信号"条往下掉，掉光以后马灯每秒掉血，要抢在之前清场
##   shop      购物频道：开打以后每隔一阵"限时特卖"，家具顶上冒出两滴灯油，8 秒不拿就没了
## 由 level3.gd 的 _place_enemies 按场景名挂上（见 level3.gd 的 MODES）。

## 停电：主角、马灯周围看得见的半径
const LIGHT_R := 56.0
const LANTERN_R := 76.0
## 大风：风平 → 预警 → 刮风，循环
const WIND_CALM := 2.6
const WIND_WARN := 0.9
const WIND_GUST := 2.2
const WIND_PUSH := 62.0
## 信号：多久掉光；掉光以后每秒扣马灯多少；每打死一只怪信号回多少（打得快就不会掉光）
## 10-18：精英血 ×2.3 以后一场要 40～65 秒，原来固定 60 秒几乎场场掉光，改成 70 秒 + 杀怪回信号
const SIGNAL_TIME := 70.0
const SIGNAL_DRAIN := 2.0
const SIGNAL_PER_KILL := 0.1
## 购物：第一次特卖在开打后多久，之后每隔多久一次，最多几次，每次几滴
const SHOP_FIRST := 3.0
const SHOP_EVERY := 14.0
const SHOP_ROUNDS := 3
const SHOP_DROPS := 2

const DARK_SHADER := """
shader_type canvas_item;
uniform vec2 size = vec2(400.0, 240.0);
uniform vec4 holes[4];
uniform float alpha = 0.0;
void fragment() {
	vec2 p = floor(UV * size / 2.0) * 2.0;
	float lit = 0.0;
	for (int i = 0; i < 4; i++) {
		if (holes[i].z > 0.0) {
			float d = distance(p, holes[i].xy) / holes[i].z;
			// 分三档硬边，像素感，不要平滑渐变
			lit = max(lit, d < 0.6 ? 1.0 : (d < 0.85 ? 0.6 : (d < 1.0 ? 0.3 : 0.0)));
		}
	}
	COLOR = vec4(0.02, 0.02, 0.04, alpha * (1.0 - lit) * 0.88);
}
"""
const NOISE_SHADER := """
shader_type canvas_item;
uniform vec2 size = vec2(400.0, 240.0);
uniform float amount = 0.0;
uniform float t = 0.0;
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
void fragment() {
	vec2 cell = floor(UV * size / 2.0);
	float n = hash12(cell + floor(t * 24.0) * vec2(17.0, 31.0));
	// 横向滚动的干扰条
	float band = step(0.93, fract(UV.y * 3.0 - t * 0.7));
	float a = step(1.0 - amount * 0.55, n) * 0.75 + band * amount * 0.2;
	COLOR = vec4(vec3(0.75 + 0.25 * n), a * min(1.0, amount * 1.6));
}
"""

var kind := ""
## 屏幕玻璃（世界坐标）
var rect := Rect2()
var floor_y := 0.0
var enc: Encounter
var hud: Hud
## 这块屏幕里的单向平台顶面：[x0, x1, y]（购物频道放灯油用）
var platforms: Array = []

var _on := false
var _t := 0.0
var _fade := 0.0
var _overlay: ColorRect
var _mat: ShaderMaterial
var _eyes: Node2D
# 大风
var _wind_phase := 0
var _wind_dir := 1.0
var _wind_t := 0.0
var _streaks: Array = []
# 信号
var _signal := 1.0
var _drain_t := 0.0
var _alive_ids := {}
var _bar: Node2D
# 购物
var _shop_next := 0.0
var _shop_n := 0


func _ready() -> void:
	# 压在人和怪（0）上面，但在精英的碎块（3）、马灯（5）、灯油和烧地（6）、出招标记（8、10）、子弹（8）下面：
	# 停电时这些预警照样看得见（2026-10-18 和精英会话对过）
	z_index = 2
	if kind == "blackout" or kind == "signal":
		_overlay = ColorRect.new()
		_overlay.position = rect.position
		_overlay.size = rect.size
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = DARK_SHADER if kind == "blackout" else NOISE_SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.set_shader_parameter("size", rect.size)
		_overlay.material = _mat
		_overlay.visible = false
		if kind == "signal":
			# 雪花只盖住屏幕画面（场景、家具），压在人和怪下面：信号再差也看得见自己和怪
			_overlay.z_as_relative = false
			_overlay.z_index = -15
		add_child(_overlay)
	if kind == "blackout":
		# 黑暗里只露出怪的红灯
		_eyes = Node2D.new()
		_eyes.z_index = 1
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_eyes.material = unshaded
		_eyes.draw.connect(_draw_eyes)
		add_child(_eyes)
	if kind == "wind" or kind == "signal":
		_bar = Node2D.new()
		_bar.z_index = 12
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_bar.material = unshaded
		_bar.draw.connect(_draw_bar)
		add_child(_bar)


func _physics_process(delta: float) -> void:
	var active := enc != null and enc.started and not enc.cleared
	if active and not _on:
		_start()
	elif not active and _on:
		_on = false
	_fade = move_toward(_fade, 1.0 if _on else 0.0, delta / (0.6 if _on else 1.0))
	if _fade <= 0.0 and not _on:
		if _overlay:
			_overlay.visible = false
		if _bar:
			_bar.queue_redraw()
		if _eyes:
			_eyes.queue_redraw()
		set_physics_process(not (enc != null and enc.cleared))
		return
	_t += delta
	match kind:
		"blackout":
			_tick_blackout()
		"wind":
			_tick_wind(delta)
		"signal":
			_tick_signal(delta)
		"shop":
			_tick_shop(delta)


func _start() -> void:
	_on = true
	_t = 0.0
	if _overlay:
		_overlay.visible = true
	var line := ""
	match kind:
		"blackout":
			line = "Power cut!"
			Game.sfx("tvoff", -6.0, 0.7)
		"wind":
			line = "Weather channel: gale warning"
			_wind_phase = 0
			_wind_t = WIND_CALM * 0.6
		"signal":
			line = "Signal fading - clear the screen fast"
			_signal = 1.0
			_alive_ids = {}
		"shop":
			line = "Shopping channel: limited-time offers!"
			_shop_next = SHOP_FIRST
			_shop_n = 0
	if hud and line != "":
		hud.show_banner(tr(line), 1.4)


func _players() -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group("player"):
		if rect.grow(8.0).has_point((n as Node2D).global_position):
			out.append(n)
	return out


# ---------------- 停电 ----------------

func _tick_blackout() -> void:
	var holes := PackedVector4Array()
	for p in _players():
		var lp: Vector2 = (p as Node2D).global_position + Vector2(0, -10) - rect.position
		holes.append(Vector4(lp.x, lp.y, LIGHT_R, 0))
	for c in get_tree().get_nodes_in_group("crystal"):
		var cp: Vector2 = (c as Node2D).global_position + Vector2(0, -6) - rect.position
		holes.append(Vector4(cp.x, cp.y, LANTERN_R, 0))
	while holes.size() < 4:
		holes.append(Vector4(0, 0, 0, 0))
	holes.resize(4)
	_mat.set_shader_parameter("holes", holes)
	_mat.set_shader_parameter("alpha", _fade)
	_eyes.queue_redraw()


func _draw_eyes() -> void:
	if _fade <= 0.0:
		return
	var blink := 0.7 + 0.3 * sin(_t * 6.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Node2D
		if en == null or en.get("dead") or not rect.has_point(en.global_position):
			continue
		var at: Vector2 = en.call("aim_point") if en.has_method("aim_point") else en.global_position + Vector2(0, -6)
		at = (at - global_position).round()
		var c := Color(1.0, 0.3, 0.22, _fade * blink)
		var halo := Color(1.0, 0.2, 0.15, 0.3 * _fade * blink)
		for ex in [at.x - 3, at.x + 1]:
			_eyes.draw_rect(Rect2(ex - 1, at.y - 1, 4, 3), halo)
			_eyes.draw_rect(Rect2(ex, at.y, 2, 1), c)


# ---------------- 大风 ----------------

func _tick_wind(delta: float) -> void:
	_wind_t -= delta
	if _wind_t <= 0.0:
		_wind_phase = (_wind_phase + 1) % 3
		match _wind_phase:
			0:
				_wind_t = WIND_CALM
			1:
				_wind_t = WIND_WARN
				_wind_dir = -1.0 if randf() < 0.5 else 1.0
				Game.sfx("vent", -10.0, 0.6)
			2:
				_wind_t = WIND_GUST
				Game.add_shake(1.0)
	if not _on:
		_wind_phase = 0
	# 刮风：把人（和地上的马灯）往一边推；用 move_and_collide，推不进墙
	if _wind_phase == 2 and _on:
		for p in _players():
			(p as CharacterBody2D).move_and_collide(Vector2(_wind_dir * WIND_PUSH * delta, 0))
		for c in get_tree().get_nodes_in_group("crystal"):
			var cr := c as Crystal
			if cr and cr.carrier == null and rect.has_point(cr.global_position) and cr is CharacterBody2D:
				(cr as CharacterBody2D).move_and_collide(Vector2(_wind_dir * WIND_PUSH * 0.6 * delta, 0))
	# 风线：预警时稀稀拉拉，刮风时又密又快
	var want := 0
	if _on and _wind_phase == 1:
		want = 6
	elif _on and _wind_phase == 2:
		want = 16
	while _streaks.size() < want:
		var y := randf_range(rect.position.y + 10.0, floor_y - 4.0)
		var x := rect.position.x if _wind_dir > 0 else rect.end.x
		_streaks.append({"p": Vector2(x - _wind_dir * randf_range(0, rect.size.x), y), "len": randf_range(8, 22)})
	var speed := 260.0 if _wind_phase == 2 else 150.0
	for s in _streaks.duplicate():
		s["p"].x += _wind_dir * speed * delta
		if s["p"].x < rect.position.x - 30.0 or s["p"].x > rect.end.x + 30.0 or _streaks.size() > want:
			_streaks.erase(s)
	_bar.queue_redraw()


# ---------------- 信号干扰 ----------------

func _tick_signal(delta: float) -> void:
	if _on:
		_signal = maxf(_signal - delta / SIGNAL_TIME, 0.0)
		# 屏幕里上一帧还活着、这一帧死了（或没了）的怪：每只回一点信号
		var now := {}
		for e in get_tree().get_nodes_in_group("enemy"):
			var en := e as Node2D
			if en and not en.get("dead") and rect.grow(8.0).has_point(en.global_position):
				now[en.get_instance_id()] = true
		for id in _alive_ids:
			if not now.has(id):
				_signal = minf(_signal + SIGNAL_PER_KILL, 1.0)
		_alive_ids = now
	var amount := (1.0 - _signal) * _fade
	_mat.set_shader_parameter("amount", amount)
	_mat.set_shader_parameter("t", _t)
	if _on and _signal <= 0.0:
		_drain_t -= delta
		if _drain_t <= 0.0:
			_drain_t = 1.0
			Run.damage_crystal(SIGNAL_DRAIN)
			Game.sfx("static", -14.0, 1.2)
	_bar.queue_redraw()


func _draw_bar() -> void:
	if _fade <= 0.0:
		return
	if kind == "wind":
		# 只画在这块屏幕的玻璃里；亮线下面压一道暗线，亮背景（沙漠、海滩）上也看得出
		for s in _streaks:
			var x0: float = maxf(s["p"].x, rect.position.x)
			var x1: float = minf(s["p"].x + s["len"], rect.end.x)
			if x1 <= x0:
				continue
			var p := (Vector2(x0, s["p"].y) - global_position).round()
			var a := 0.45 if _wind_phase == 1 else 0.8
			_bar.draw_rect(Rect2(p.x, p.y + 1, roundf(x1 - x0), 1), Color(0.1, 0.08, 0.12, a * 0.45 * _fade))
			_bar.draw_rect(Rect2(p.x, p.y, roundf(x1 - x0), 1), Color(1, 1, 1, a * _fade))
		return
	# 信号条：屏幕顶上一条，从满往下掉；快没了变红、闪
	var w := minf(120.0, rect.size.x - 40.0)
	var x0 := rect.position.x + (rect.size.x - w) * 0.5 - global_position.x
	var y0 := rect.position.y + 8.0 - global_position.y
	var col := Color(0.55, 1.0, 0.6) if _signal > 0.3 else Color(1.0, 0.35, 0.3)
	if _signal < 0.3 and int(_t * 6.0) % 2 == 0:
		col = col.darkened(0.4)
	_bar.draw_rect(Rect2(x0 - 1, y0 - 1, w + 2, 5), Color(0.05, 0.05, 0.08, 0.85 * _fade))
	_bar.draw_rect(Rect2(x0, y0, roundf(w * _signal), 3), Color(col, _fade))
	# 四格信号塔图标
	for i in 4:
		var h := 2 + i * 2
		var on := _signal > float(i) / 4.0
		_bar.draw_rect(Rect2(x0 - 14 + i * 3, y0 + 3 - h, 2, h), Color(col if on else Color(0.3, 0.3, 0.35), _fade))


# ---------------- 购物频道 ----------------

func _tick_shop(delta: float) -> void:
	if not _on or _shop_n >= SHOP_ROUNDS:
		return
	_shop_next -= delta
	if _shop_next > 0.0:
		return
	_shop_n += 1
	_shop_next = SHOP_EVERY
	Game.sfx("ding", -8.0, 1.3)
	# 挑离人远一点的家具顶（没有家具就放地上），一次放两滴
	var spots: Array = []
	var px := rect.get_center().x
	var ps := _players()
	if not ps.is_empty():
		px = (ps[0] as Node2D).global_position.x
	for pl in platforms:
		var cx: float = (pl[0] + pl[1]) * 0.5
		if absf(cx - px) > 50.0:
			spots.append(Vector2(cx, pl[2] - 4.0))
	spots.shuffle()
	while spots.size() < SHOP_DROPS:
		var x := randf_range(rect.position.x + 30.0, rect.end.x - 30.0)
		if absf(x - px) > 50.0:
			spots.append(Vector2(x, floor_y - 4.0))
	for i in SHOP_DROPS:
		var oil := LampOil.new()
		oil.position = spots[i]
		oil._vel = Vector2(0, -70.0)
		get_parent().add_child(oil)
		Game.sparks(get_parent(), spots[i] + Vector2(0, -6), Color(1.0, 0.85, 0.5), 8, 60.0)
