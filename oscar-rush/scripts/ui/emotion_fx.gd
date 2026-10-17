class_name EmotionFx
extends CanvasLayer
## 情绪值（压力）和马灯"看得见"（作者试玩反馈 10-17："压力值和灯笼的作用不明显，要有恢复特效"）。
## Hud 自己建一个，所以每个有 HUD 的场景都有。不改任何平衡数值，只补策划案第八节里定了、还没做的部分：
##
## 情绪（策划案第八节）
## - 随时间上涨：每 4 秒 +1；马灯放在地上时 ×1.5（一片黑的时候人更慌）；乘商店"阻尼"升级的系数。商店里不涨。
## - 档位带回差：涨到 25 / 50 / 75 升档，降到 20 / 45 / 70 才降档。怪的快慢狠在 EnemyBase 里按情绪算。
## - 到 100 过载：水晶每秒 -1。
## - 看得见：右上角指针表（四个色区 + 指针，越高抖得越厉害 + 档位名字）；挨打、杀怪时表旁边跳 "+5" / "-1"；
##   全屏老电视滤镜随情绪连续加重（扫描线、色散、噪点、暗角），愤怒以后泛红；
##   升档：0.35 秒换台雪花 + "咔"一声 + 屏幕上方一行说这一档怪会怎样；降档：一下冷色 + 轻"叮"；
##   失控：心跳（画面一缩一放 + 低沉的咚）、偶尔跑台；过载：表下面闪 OVERLOAD + 警报。
## 马灯
## - 怪走进光圈：白闪一下、冒一点暖色火花（被照到了）。
## - 马灯掉血：灯上方飘红字 "-10"。
## - 回血（商店修灯、重来时补到三成、以后的回血变异……任何让马灯血量变多的事）：
##   灯上冒一串往上飘的暖金色光点，飘 "+25"，左上角血条上扫过一道亮光，轻轻"叮"一声；持续回血就一直冒。
## 关掉"震屏"（设置）时，画面上会晃的效果（撕裂、跑台、心跳缩放）一起关掉，只留颜色。

const RISE_PER_SEC := 0.25
const DARK_MULT := 1.5
const OVERLOAD_DRAIN := 1.0
const UP: Array[float] = [25.0, 50.0, 75.0]
const DOWN: Array[float] = [20.0, 45.0, 70.0]
const NAMES: Array[String] = ["CALM", "UNEASY", "ANGRY", "PANIC"]
## 升到这一档时屏幕上方那行字：这一档的怪会怎样
const TIER_LINES: Array[String] = ["machines calm down", "machines speed up", "machines hit harder", "machines go haywire"]
const ZONE_COLORS: Array[Color] = [Color8(120, 140, 160), Color8(222, 186, 84), Color8(232, 112, 58), Color8(196, 34, 34)]
const GAUGE_POS := Vector2(420, 4)
const GAUGE_SIZE := Vector2(56, 34)
## Hud 画的马灯血条在屏幕上的位置（hud.gd：_bar 在 (8,8)，条在其中 (8,4,60,4)）
const HUD_BAR := Rect2(16, 12, 60, 4)
const WARM := Color8(255, 211, 138)
const HEAL_COLOR := Color8(255, 226, 150)

## 带回差的档位（EnemyBase 现在自己按每 25 分一档算；这里给画面和声音用）
static var tier := 0

const SCREEN_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float strength = 0.0;
uniform float red = 0.0;
uniform float burst = 0.0;
uniform float calm = 0.0;
uniform float vroll = 0.0;
uniform float pulse = 0.0;
uniform float wobble = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	uv = (uv - 0.5) * (1.0 - pulse * 0.014 * wobble) + 0.5;
	uv.y = fract(uv.y + vroll * wobble);
	float t = TIME;
	float tick = floor(t * 14.0);
	float jolt = step(0.985 - strength * 0.06, hash(vec2(tick, 3.1))) * strength;
	float band = floor(uv.y * 40.0 + floor(t * 30.0) * 7.0);
	float tear = (hash(vec2(band, floor(t * 30.0))) - 0.5) * (0.03 * burst + 0.012 * jolt) * wobble;
	uv.x += tear + sin(uv.y * 90.0 + t * 7.0) * 0.0006 * strength * wobble;
	float ch = 0.0022 * strength + 0.008 * burst;
	vec3 c = vec3(texture(screen_tex, uv + vec2(ch, 0.0)).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, uv - vec2(ch, 0.0)).b);
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(l * 1.55, l * 0.38, l * 0.32), red * 0.5);
	c = mix(c, c * vec3(0.78, 0.95, 1.2), calm * 0.55);
	float line = step(0.5, fract(SCREEN_UV.y * 135.0));
	c *= 1.0 - line * 0.2 * strength;
	float n = hash(SCREEN_UV * vec2(613.0, 977.0) + fract(t * 7.3));
	c += (n - 0.5) * (0.05 * strength + 0.45 * burst);
	c = mix(c, vec3(n) * 0.75, burst * 0.4);
	vec2 d = SCREEN_UV - 0.5;
	float v = dot(d, d);
	c *= 1.0 - v * (0.3 + 1.5 * strength);
	c = mix(c, vec3(0.55, 0.0, 0.0), clamp(v * 2.6, 0.0, 1.0) * red * (0.3 + 0.25 * pulse));
	COLOR = vec4(c, 1.0);
}
"""

var _screen: ColorRect
var _top: CanvasLayer
var _gauge: Control
var _tier_label: Label
var _state_label: Label
var _banner: Label
var _banner_t := 0.0
var _bar_fx: Control

var _shown := 0.0
var _kick := 0.0
var _last_emotion := 0.0
var _own := 0.0
var _acc := 0.0
var _acc_t := 0.0
var _burst := 0.0
var _calm := 0.0
var _vroll := 0.0
var _heart_t := 0.0
var _pulse := 0.0
var _alarm_t := 0.0
var _last_hp := -1.0
var _heal_t := 0.0
var _heal_sweep := 0.0
var _time := 0.0
var _dark := false
## 重生后这段时间里马灯血量的变化不放特效
var _quiet_until := 0.0
var _rage_t := 0.0
## 等着出的横幅：[字, 颜色]；精英名字卡在屏幕上时先不出
var _banner_pending: Array = []


func _ready() -> void:
	layer = 9
	_screen = ColorRect.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SCREEN_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_screen.material = mat
	add_child(_screen)

	# 表、跳字、横幅、血条上的亮光放在 HUD 上面一层
	_top = CanvasLayer.new()
	_top.layer = 12
	add_child(_top)
	_gauge = Control.new()
	_gauge.position = GAUGE_POS
	_gauge.size = GAUGE_SIZE
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	_top.add_child(_gauge)
	_tier_label = _label(Vector2(0, 22), GAUGE_SIZE.x, Color.WHITE)
	_gauge.add_child(_tier_label)
	# 右对齐、往左留够宽度：字长的时候往左长，不会出屏幕右边
	_state_label = _label(Vector2(GAUGE_POS.x + GAUGE_SIZE.x - 200, GAUGE_POS.y + GAUGE_SIZE.y + 1), 200, Color.WHITE)
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_top.add_child(_state_label)
	_banner = _label(Vector2(0, 40), 480, Color.WHITE)
	_banner.visible = false
	_top.add_child(_banner)
	_bar_fx = Control.new()
	_bar_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fx.position = Vector2.ZERO
	_bar_fx.size = Vector2(120, 30)
	_bar_fx.draw.connect(_draw_bar_fx)
	_top.add_child(_bar_fx)

	_last_emotion = Run.emotion
	_shown = Run.emotion
	tier = _tier_for(Run.emotion, 0)
	_last_hp = Run.crystal_hp
	Run.crystal_changed.connect(_on_crystal_changed)
	if Run.has_signal("resumed"):
		Run.resumed.connect(func(): _quiet_until = _time + 0.6; _last_hp = Run.crystal_hp)


func _label(pos: Vector2, w: float, color: Color) -> Label:
	var l := Label.new()
	l.label_settings = Hud.small_text(color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = Vector2(w, 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 不看回差时的档位（开局用）
static func _tier_for(e: float, _cur: int) -> int:
	var t := 0
	for i in UP.size():
		if e >= UP[i]:
			t = i + 1
	return t


func _in_level() -> bool:
	var root := get_tree().current_scene
	return root != null and not root is ShopRoom and not get_tree().get_nodes_in_group("player").is_empty()


func _process(delta: float) -> void:
	_time += delta
	var level := _in_level()

	# ---- 情绪随时间上涨（策划案第八节）----
	_dark = false
	for c in get_tree().get_nodes_in_group("crystal"):
		if c.get("carrier") == null:
			_dark = true
	if level and not get_tree().paused:
		var before := Run.emotion
		Run.add_emotion(RISE_PER_SEC * (DARK_MULT if _dark else 1.0) * Upgrades.emotion_rate_mult() * delta)
		_own += Run.emotion - before
		if Run.emotion >= 100.0:
			Run.damage_crystal(OVERLOAD_DRAIN * delta)

	# ---- 别处加减的情绪：攒 0.25 秒跳一次字 ----
	var ext := Run.emotion - _last_emotion - _own
	_own = 0.0
	_last_emotion = Run.emotion
	if absf(ext) > 0.01:
		_acc += ext
		if ext > 0.0:
			_kick = 1.0
	_acc_t += delta
	if _acc_t >= 0.25:
		_acc_t = 0.0
		if absf(_acc) >= 0.5:
			_pop_number(_acc)
		_acc = 0.0

	# ---- 档位（带回差）----
	var t := tier
	while t < 3 and Run.emotion >= UP[t]:
		t += 1
	while t > 0 and Run.emotion < DOWN[t - 1]:
		t -= 1
	if t != tier:
		_on_tier(tier, t)
		tier = t

	# ---- 表 ----
	_shown = lerpf(_shown, Run.emotion, 1.0 - exp(-8.0 * delta))
	_kick = maxf(_kick - delta * 3.0, 0.0)
	var col := ZONE_COLORS[tier]
	_tier_label.text = NAMES[tier]
	_tier_label.label_settings.font_color = col
	var state := ""
	var state_col := Color(0.75, 0.75, 0.78)
	if Run.emotion >= 100.0:
		# 常亮，颜色一明一暗（闪烁的字在低帧率下容易整句看不见）
		state = "OVERLOAD! LANTERN BURNS"
		state_col = ZONE_COLORS[3].lightened(0.25 + 0.25 * (0.5 + 0.5 * sin(_time * 10.0)))
		_alarm_t -= delta
		if _alarm_t <= 0.0 and level:
			_alarm_t = 1.0
			Game.sfx("alarm", -14.0)
	elif not level:
		state = "PAUSED" if get_tree().current_scene is ShopRoom else ""
	elif _dark:
		state = "IN THE DARK x1.5"
		state_col = Color(0.62, 0.66, 0.8)
	_state_label.text = state
	_state_label.label_settings.font_color = state_col
	_gauge.queue_redraw()

	# ---- 横幅 ----
	if not _banner_pending.is_empty() and not _elite_intro_on():
		_banner.text = _banner_pending[0]
		_banner.label_settings.font_color = _banner_pending[1]
		_banner.visible = true
		_banner_t = 2.2
		_banner_pending = []
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t / 0.4, 0.0, 1.0)
		_banner.visible = _banner_t > 0.0

	# ---- 全屏滤镜 ----
	var wobble: float = Settings.SHAKE_LEVELS[Settings.shake_index] if "shake_index" in Settings else 1.0
	var e := Run.emotion
	_burst = maxf(_burst - delta / 0.35, 0.0)
	_calm = maxf(_calm - delta * 2.0, 0.0)
	_vroll = maxf(_vroll - delta * 1.5, 0.0)
	if tier == 3 and level:
		_heart_t -= delta
		if _heart_t <= 0.0:
			_heart_t = 0.75 if e < 100.0 else 0.55
			_pulse = 1.0
			Game.sfx("land", -8.0, 0.45)
			# 失控时偶尔跑台：整屏往上滚一截再弹回来
			if randf() < 0.18:
				_vroll = 0.12
	_pulse = maxf(_pulse - delta * 4.0, 0.0)
	var m := _screen.material as ShaderMaterial
	m.set_shader_parameter("strength", smoothstep(18.0, 100.0, e))
	m.set_shader_parameter("red", smoothstep(45.0, 95.0, e))
	m.set_shader_parameter("burst", _burst)
	m.set_shader_parameter("calm", _calm)
	m.set_shader_parameter("vroll", _vroll * _vroll)
	m.set_shader_parameter("pulse", _pulse)
	m.set_shader_parameter("wobble", wobble)

	# ---- 马灯：光圈、怪进光、回血 ----
	for c in get_tree().get_nodes_in_group("crystal"):
		if not (c as Node).has_node("LanternAura"):
			var aura := LanternAura.new()
			aura.name = "LanternAura"
			(c as Node).add_child(aura)
	_heal_t = maxf(_heal_t - delta, 0.0)
	_heal_sweep = maxf(_heal_sweep - delta * 1.2, 0.0)
	for c in get_tree().get_nodes_in_group("crystal"):
		var aura := (c as Node).get_node_or_null("LanternAura") as LanternAura
		if aura:
			aura.healing = _heal_t > 0.0
	_bar_fx.queue_redraw()
	# 怒火：越生气，人身上冒的红火星越多
	if Upgrades.mutation == "rage" and level and not get_tree().paused:
		_rage_t -= delta
		var rage := Mutations.rage_mult()
		if _rage_t <= 0.0 and rage >= 1.2:
			_rage_t = lerpf(0.5, 0.15, (rage - 1.2) / 0.8)
			for pl in get_tree().get_nodes_in_group("player"):
				var n := pl as Node2D
				Game.sparks(n.get_parent(), n.global_position + Vector2(randf_range(-4, 4), -10), Mutations.RAGE_COLOR, 2, 35.0, Vector2.UP)


func _on_tier(old: int, new: int) -> void:
	var col := ZONE_COLORS[new]
	if new > old:
		_burst = 1.0
		Game.sfx("tvclick", -4.0, 1.0)
		Game.sfx("static", -14.0, 1.2)
		Game.add_shake(2.0)
		_show_banner(tr("%s: %s") % [tr(NAMES[new]), tr(TIER_LINES[new])], col)
	else:
		_calm = 1.0
		Game.sfx("ding", -12.0, 0.8)
		_show_banner(tr("%s: %s") % [tr(NAMES[new]), tr(TIER_LINES[0] if new == 0 else "a little calmer")], col)


## 精英怪登场的名字卡（elite_base.gd 的 IntroCard）也在屏幕上方正中，两段字会叠在一起：
## 有精英正在播出场动画时，横幅先排着，等名字卡收起再出（换台雪花和音效照常立刻出）
func _show_banner(text: String, col: Color) -> void:
	_banner_pending = [text, col]
	_banner_t = 0.0
	_banner.visible = false


func _elite_intro_on() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.has_method("in_intro") and e.call("in_intro"):
			return true
	return false


## 表旁边跳字：涨是红色往下掉一点，降是冷色往上飘
func _pop_number(v: float) -> void:
	var l := _label(Vector2(GAUGE_POS.x - 26, GAUGE_POS.y + 8), 28, ZONE_COLORS[3].lightened(0.25) if v > 0.0 else Color8(140, 200, 230))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.text = ("+%d" if v > 0.0 else "%d") % roundi(v)
	_top.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	var y0 := l.position.y
	var dy := 8.0 if v > 0.0 else -8.0
	tw.tween_method(func(k: float): l.position.y = roundf(y0 + dy * k), 0.0, 1.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _on_crystal_changed(hp: float, _max: float) -> void:
	var d := hp - _last_hp
	_last_hp = hp
	# 从存档点重来那一下补到三成，是重生动画管的（"三个主要bug修复"会话做），这里不放回血特效
	if Run.get("_resuming") or _time < _quiet_until:
		return
	if d > 0.05:
		_heal_t = maxf(_heal_t, 1.2)
		_heal_sweep = 1.0
		Game.sfx("ding", -8.0, 1.5)
		for c in get_tree().get_nodes_in_group("crystal"):
			var aura := (c as Node).get_node_or_null("LanternAura") as LanternAura
			if aura:
				aura.float_text("+%d" % roundi(d), HEAL_COLOR)
	elif d < -0.9:
		for c in get_tree().get_nodes_in_group("crystal"):
			var aura := (c as Node).get_node_or_null("LanternAura") as LanternAura
			if aura:
				aura.float_text("%d" % roundi(d), Color8(255, 90, 70))


func _draw_gauge() -> void:
	var g := _gauge
	g.draw_rect(Rect2(Vector2.ZERO, GAUGE_SIZE), Color(0.03, 0.025, 0.035, 0.78))
	g.draw_rect(Rect2(Vector2.ZERO, GAUGE_SIZE), Color(0.45, 0.4, 0.36, 0.9), false, 1.0)
	var c := Vector2(GAUGE_SIZE.x * 0.5, 21)
	var r := 16.0
	# 四个色区：从左（平静）到右（失控）
	for i in 4:
		var a0 := PI + PI * i / 4.0
		var a1 := PI + PI * (i + 1) / 4.0
		UiStyle.pixel_arc_band(g, c, r - 1.5, r + 1.5, a0 + 0.06, a1 - 0.06, ZONE_COLORS[i].darkened(0.0 if i == tier else 0.45))
	# 刻度
	for k in 5:
		var a := PI + PI * k / 4.0
		UiStyle.pixel_line(g, c + Vector2.from_angle(a) * (r - 4), c + Vector2.from_angle(a) * (r - 3), Color(0.6, 0.56, 0.5))
	# 指针：越高抖得越厉害；挨打时猛跳一下
	var shake_amp: float = ([0.01, 0.03, 0.06, 0.11] as Array[float])[tier] + _kick * 0.12
	var jitter: float = sin(_time * 37.0) * shake_amp + sin(_time * 53.0 + 1.7) * shake_amp * 0.6
	var ang: float = PI + PI * clampf(_shown / 100.0, 0.0, 1.0) + jitter
	var tip := c + Vector2.from_angle(ang) * (r - 2)
	UiStyle.pixel_line(g, c, tip, Color(0.96, 0.92, 0.86))
	g.draw_rect(Rect2(c - Vector2(1, 1), Vector2(3, 3)), Color(0.7, 0.62, 0.5))


## 回血时左上角马灯血条上扫过一道亮光
func _draw_bar_fx() -> void:
	# 发电机：马灯血条下面 10 小格，杀一只亮一格，满 10 只回血
	if Upgrades.mutation == "dynamo" and _in_level():
		UiStyle.bars(_bar_fx, Vector2(HUD_BAR.position.x, HUD_BAR.end.y + 3), Mutations.dynamo_kills, Mutations.DYNAMO_KILLS,
				4.0, 2.0, 2.0, Mutations.DYNAMO_COLOR)
	if _heal_sweep <= 0.0:
		return
	var x := HUD_BAR.position.x + HUD_BAR.size.x * (1.0 - _heal_sweep)
	_bar_fx.draw_rect(Rect2(x - 3, HUD_BAR.position.y - 1, 6, HUD_BAR.size.y + 2), Color(HEAL_COLOR, 0.85 * _heal_sweep))
	_bar_fx.draw_rect(HUD_BAR.grow(1.0), Color(HEAL_COLOR, 0.5 * _heal_sweep), false, 1.0)


## 挂在马灯上：怪走进灯光时的反应、回血时往外扩的像素光环和往上飘的光点、头顶飘字
## （原来还画一圈照亮范围的虚线，作者 10-17 说"不像素画又不明确"，去掉了）
class LanternAura:
	extends Node2D

	var healing := false
	var _ring_t := 0.0
	var _inside := {}
	var _t := 0.0
	var _heal: CPUParticles2D

	func _ready() -> void:
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		z_index = 3
		_heal = CPUParticles2D.new()
		_heal.position = Vector2(0, -5)
		_heal.emitting = false
		_heal.amount = 22
		_heal.lifetime = 1.0
		_heal.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_heal.emission_rect_extents = Vector2(5, 3)
		_heal.direction = Vector2.UP
		_heal.spread = 12.0
		_heal.initial_velocity_min = 18.0
		_heal.initial_velocity_max = 34.0
		_heal.gravity = Vector2(0, -10)
		_heal.scale_amount_min = 2.0
		_heal.scale_amount_max = 2.0
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
		ramp.set_color(1, Color(1.0, 0.8, 0.4, 0.0))
		_heal.color_ramp = ramp
		_heal.use_parent_material = true
		add_child(_heal)

	func _physics_process(delta: float) -> void:
		_t += delta
		_heal.emitting = healing
		_ring_t = _ring_t + delta if healing else 0.0
		var crystal := get_parent() as Crystal
		if crystal == null:
			return
		# 怪走进光圈：白闪一下、冒一点暖色火花
		var center := crystal.global_position + Vector2(0, -5)
		var now := {}
		for e in get_tree().get_nodes_in_group("enemy"):
			var n := e as Node2D
			if n == null or n.get("dead"):
				continue
			var id := n.get_instance_id()
			if n.global_position.distance_to(center) <= Crystal.LIGHT_RADIUS:
				now[id] = true
				if not _inside.has(id):
					n.set("_flash", 0.7)
					var at: Vector2 = n.call("aim_point") if n.has_method("aim_point") else n.global_position
					Game.sparks(crystal.get_parent(), at, Color(1.0, 0.85, 0.55), 4, 40.0)
		_inside = now
		queue_redraw()

	func float_text(text: String, col: Color) -> void:
		var l := Label.new()
		l.label_settings = Hud.small_text(col)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(40, 12)
		l.position = Vector2(-20, -24)
		l.use_parent_material = true
		l.z_index = 30
		add_child(l)
		var tw := l.create_tween().set_parallel(true)
		tw.tween_method(func(k: float): l.position.y = roundf(lerpf(-24.0, -36.0, k)), 0.0, 1.0, 0.9)
		tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
		tw.chain().tween_callback(l.queue_free)

	func _draw() -> void:
		var crystal := get_parent() as Crystal
		if crystal == null:
			return
		draw_set_transform(crystal.global_position.round() - crystal.global_position)
		if Upgrades.mutation == "slave" and crystal.carrier == null and int(_t * 3.0) % 2 == 0:
			draw_rect(Rect2(-1, -13, 3, 1), Mutations.SLAVE_COLOR)
			draw_rect(Rect2(0, -14, 1, 1), Color.WHITE)
		# 回血中：灯外面一圈圈往外扩的暖金色光环（两圈错开），配合往上飘的光点
		if healing:
			for k in 2:
				var ph := fmod(_ring_t * 1.6 + k * 0.5, 1.0)
				# 像素圆环，透明度分三档（不做平滑渐变）
				var alpha := 0.85 if ph < 0.4 else (0.55 if ph < 0.75 else 0.3)
				UiStyle.pixel_ring(self, Vector2(0, -5), int(4.0 + ph * 16.0), Color(EmotionFx.HEAL_COLOR, alpha))
