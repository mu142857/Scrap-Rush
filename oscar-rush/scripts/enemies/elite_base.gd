class_name EliteBase
extends EnemyBase
## 精英怪的公共底子（策划案第九节：每场遭遇战最后一波出一个，带一招独门技能）。在 EnemyBase 上多了：
## - 登场：屏幕下方出名字和血条（打死消失）；遭遇战里登场时情绪 +10 由 Encounter 负责。
## - 出场动画（约 2 秒，落地开始算，见 _tick_intro）：从天花板砸下来（拖着速度线）→ 落地"哐"一声、
##   压扁一下、地面冲击波、上下黑边滑进来 → 老机器开机：红灯跟着灯管通电声闪三下才亮稳，亮起时一圈红光
##   扩出去 → 摆出招牌姿势（子类填 intro_frame），屏幕上方像老终端一样打出名字（intro_title + elite_name），
##   底下的血条从空涨满 → 黑边收回，开打。
##   出场时不放招、不伤人、打不动（打上去只冒火星），子类的 _tick 落地两秒后才开始调。
##   出场时镜头往这边拉一半（camera_focus 组），不然场子另一头落下来的精英怪在画面外。
## - 很重：挨打不后退（knockback 为 0），不会被打断招式，除非子类自己在 _on_hurt 里处理。
## - warn(offset, time)：头顶冒一个红色"!"，大招之前用（照 story_jam 的预警）。
## - 死亡：更大的火花、顿帧、震屏。
## 子类和 EnemyBase 一样：在 _setup() 里填参数（记得填 elite_name），在 _tick() 里写招式。

const WARN_COLOR := Color(1.0, 0.25, 0.2)
# —— 出场动画的时间点（秒，从落地算）——
const INTRO_TIME := 2.0
## 灯管通电声（sfx/title_on）的三下"嗒"在 0、0.09、0.16 秒，红灯跟着它闪
const INTRO_BOOT := 0.35
const INTRO_FLICKERS := [[0.0, 0.03], [0.09, 0.115], [0.16, 99.0]]
## 摆招牌姿势、开始打名字
const INTRO_POSE := 0.7
const INTRO_POSE_END := 1.4
## 名字像显像管关机一样闪灭、黑边收回去
const INTRO_OUT := 1.75
## 落地前最多等这么久（掉进坑里也照样开演）
const INTRO_MAX_FALL := 3.0
## 出场时打不动：身上一圈闪动的白边（上下左右各错一格的白色剪影，叠在贴图后面），打上去冒"叮"的护盾火花。
## 夜间打磨 10-18（新玩家体验报告：原来打不动却没有任何提示，像没打中）
const SHIELD_COLOR := Color(0.9, 0.96, 1.0)
const SHIELD_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}
"""
static var _shield_shader: Shader

## 屏幕下方显示的名字（英文大写，评委看得懂）
var elite_name := "ELITE"
## 名字上面那行小字（英文大写），空的就写 ELITE
var intro_title := ""
## 摆招牌姿势时显示的帧，-1 就一直用第 0 帧
var intro_frame := -1

## 暗处可读性（照总机台、留声机）：> 0 时叠一层不吃光照的同一张图，透明度就是这个值，暗处也看得出形状；
## 亮处基本看不出差别。顺带预警（warn）期间整只一闪一闪发红。0 = 不叠（总机台、留声机自己叠了一层）
var fill_alpha := 0.0
## 预警时贴图一闪一闪发红（只在叠了亮层时生效）；自己在 _update_visual 里管颜色的子类（钢琴、压路机）关掉
var warn_tint := true
## 挨打时贴图往被打的方向顿一格（只在叠了亮层时生效；放映机、留声机自己有一套）
const HIT_JOLT := 0.07
## 死亡演出（照留声机）：> 0 时先"坏掉"这么多秒——停手、越抖越厉害、红灯接触不良一样闪着灭掉、噼啪冒火星、
## 呜地一声降调停转——然后才炸开。0 = 原来的一下子炸开（自己做了一套的子类不填）
var death_time := 0.0
## 坏掉时摆的姿势（帧号），-1 = 保持当前帧
var death_frame := -1
## 炸开时撒废铁碎块（机器）；活物填 false，改成往前扑倒、扬起一大片灰
var death_scrap := true
## 碎块的颜色，空 = EliteFx 默认的暖灰 + 铜色（第三关按屏幕色调填）
var death_colors: Array = []
## 炸开那一下的声音和溅出来的两把火星（10-18 加）：机器默认"crack"、暖橙火星 + 灰碎屑；
## 活物（第二关人形精英、守夜巨人）换成倒地的闷响和灰尘、碎布的颜色。EnemyBase 那一声见 death_sfx
var death_boom_sfx := "crack"
var death_boom_pitch := 0.5
var death_spark_colors_big: Array = [Color8(255, 200, 130), Color8(160, 150, 135)]
## 挨打时贴图往被打的方向顿一格。叠了亮层的自动打开；没叠亮层的子类（第三关）自己设 true
var hit_jolt := false

## 这一招盯的主角（双人以上用，夜间打磨 10-18，照总机）：每招预警开始时调一次 pick_focus() 选人，整招不换；
## 出手时用 focus_player()。单人永远是那个人（和原来一样）；两人以上按玩家顺序轮着盯，
## 不然精英永远只打"最近的"那个，另一个人整场没压力；离得太远（FOCUS_RANGE 外）的跳过，退回最近的
const FOCUS_RANGE := 320.0
var focus: Player = null
var _focus_i := -1

## 出场动画：< 0 还在往下掉，0 起是落地以后的秒数，到 INTRO_TIME 结束
var intro_t := -1.0

var _bar: EliteBar
var _warn_t := 0.0
var _warn_offset := Vector2.ZERO
var _warn_node: Node2D
var _fall_t := 0.0
var _fx: Node2D
var _card: IntroCard
var _land_pos := Vector2.ZERO
var _lift_layer: Sprite2D
var _hit_jolt := 0.0
var _jolt_dir := 0.0
## 死亡演出：< 0 没在死，0 起是"坏掉"了多久
var _death_t := -1.0
var _death_pop := 0.0
var _shield: Array[Sprite2D] = []
var _shield_ping := 0.0

## 露底（10-19 作者："当玩家看过所有技能了，受到的伤害加百分之二十，然后之后会越来越多"）：
## 子类在 _setup() 里填 reveal_moves = 这只精英的几招（填状态名，比如 "WAVE_WARN"；第三关精英填 _pattern 的招名）。
## 每招第一次出现记一下；全部亮过一次就"露底"：受到的伤害 ×1.2，之后每 8 秒再 +0.1，最多 ×2.0。
## 只看离多远都会放的招（贴身才出的近身招不算，不然远程打的人永远等不到露底）。
## 看得出来：露底那一下冒一股蒸汽、白闪一下、"嗤——咔"一声；头顶一排小红格（每 +0.1 一格）一闪一闪，
## 倍率越高闪得越快，身上裂纹越多、越红。每再涨一档冒一小股汽。Boss 不用这套。
const EXPOSE_BASE := 1.2
const EXPOSE_STEP := 0.1
const EXPOSE_EVERY := 8.0
const EXPOSE_MAX := 2.0
var reveal_moves: Array = []
var _revealed := {}
var _reveal_map := {}
var _expose_mult := 1.0
var _expose_t := 0.0
var _expose_fx: Node2D


func _ready() -> void:
	big = true
	knockback = Vector2.ZERO
	super._ready()
	_warn_node = Node2D.new()
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_warn_node.material = unshaded
	_warn_node.z_index = 10
	_warn_node.draw.connect(_draw_warn)
	add_child(_warn_node)
	# 出场特效：速度线、地面冲击波、开机红光圈。挂在世界坐标上，不吃场景压暗
	_fx = Node2D.new()
	_fx.top_level = true
	_fx.material = unshaded
	_fx.z_index = 9
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_bar = EliteBar.new()
	_bar.elite = self
	add_child(_bar)
	_card = IntroCard.new()
	_card.elite = self
	add_child(_card)
	# 出场时镜头往这边拉（GameCamera 看 camera_focus 组），出场完了放开
	add_to_group("camera_focus")
	# 出场时打不动的白边：四个方向各错一格的白色剪影，放在贴图后面
	if _shield_shader == null:
		_shield_shader = Shader.new()
		_shield_shader.code = SHIELD_SHADER
	for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		var sh := Sprite2D.new()
		sh.texture = _sprite.texture
		sh.hframes = hframes
		sh.centered = false
		var sm := ShaderMaterial.new()
		sm.shader = _shield_shader
		sh.material = sm
		sh.set_meta("off", off)
		add_child(sh)
		move_child(sh, _sprite.get_index())
		_shield.append(sh)
	if fill_alpha > 0.0:
		_lift_layer = Sprite2D.new()
		_lift_layer.texture = _sprite.texture
		_lift_layer.hframes = hframes
		_lift_layer.centered = false
		_lift_layer.material = unshaded
		add_child(_lift_layer)
		move_child(_lift_layer, _sprite.get_index() + 1)


## 头顶的红色"!"：offset 是相对脚底中间的位置，默认在贴图上面 6 像素
func warn(time := 0.5, offset := Vector2.INF) -> void:
	_warn_t = time
	_warn_offset = offset if offset != Vector2.INF else Vector2(0, -frame_size.y - 6)
	Game.sfx("charge", -16.0, 2.2)


## 选这一招盯谁（预警开始时调）。fallback 是调用的地方已经找好的最近的人
func pick_focus(fallback: Player = null) -> Player:
	var near := fallback if fallback else nearest_player()
	var ps := get_tree().get_nodes_in_group("player")
	if ps.size() <= 1:
		focus = near
		return focus
	_focus_i = (_focus_i + 1) % ps.size()
	var c := ps[_focus_i] as Player
	if c == null or not is_instance_valid(c) or global_position.distance_to(c.global_position) > FOCUS_RANGE:
		c = near
	focus = c
	return focus


## 这一招盯的人；盯的人没了（退出、离开场景）就退回最近的
func focus_player() -> Player:
	if is_instance_valid(focus) and focus.is_inside_tree():
		return focus
	return nearest_player()


func in_intro() -> bool:
	return intro_t < INTRO_TIME and not dead


func dying() -> bool:
	return _death_t >= 0.0 and not dead


func is_targetable() -> bool:
	return super.is_targetable() and _death_t < 0.0


func _physics_process(delta: float) -> void:
	if dying():
		_tick_death(delta)
	elif in_intro():
		_tick_intro(delta)
	else:
		super._physics_process(delta)
		_tick_reveal(delta)
		if _hit_jolt > 0.0 and (_lift_layer or hit_jolt):
			_hit_jolt -= delta
			_sprite.position.x += _jolt_dir
	if _warn_t > 0.0:
		# 最后一帧减到 0 以下时也重画一次，把"!"擦掉
		_warn_t -= delta
		_warn_node.position = _warn_offset
		_warn_node.queue_redraw()
	if _lift_layer:
		_sync_lift()
	_sync_shield(delta)
	if _expose_fx:
		_expose_fx.queue_redraw()


## 露底：记下这一帧在放的招；全亮过就开始加伤
func _tick_reveal(delta: float) -> void:
	if reveal_moves.is_empty() or dead:
		return
	if _expose_mult <= 1.0:
		var mv := _current_move_name()
		if mv != "" and reveal_moves.has(mv) and not _revealed.has(mv):
			_revealed[mv] = true
			if _revealed.size() >= reveal_moves.size():
				_expose()
		return
	_expose_t += delta
	if _expose_t >= EXPOSE_EVERY and _expose_mult < EXPOSE_MAX - 0.001:
		_expose_t -= EXPOSE_EVERY
		_expose_mult = minf(_expose_mult + EXPOSE_STEP, EXPOSE_MAX)
		Game.sparks(get_parent(), aim_point() + Vector2(0, -body_rect.size.y * 0.3), Color(0.85, 0.85, 0.88), 6, 50.0, Vector2.UP)
		Game.sfx("vent", -14.0, 1.2 + (_expose_mult - 1.0) * 0.4, 0.05)


## 这一帧在放哪一招：第三关精英看 _pattern（招名），别的看 state / _state 的名字
func _current_move_name() -> String:
	var pat = get("_pattern")
	if pat is String and pat != "":
		return pat
	var st = get("state")
	if st == null:
		st = get("_state")
	if st == null or not (st is int):
		return ""
	if _reveal_map.is_empty():
		var m: Dictionary = (get_script() as GDScript).get_script_constant_map()
		if m.get("State") is Dictionary:
			for n in m["State"]:
				_reveal_map[m["State"][n]] = n
		for n in reveal_moves:
			if m.get(n) is int:
				_reveal_map[m[n]] = n
	return str(_reveal_map.get(st, ""))


func _expose() -> void:
	_expose_mult = EXPOSE_BASE
	_expose_t = 0.0
	_flash = 1.0
	Game.add_shake(2.0)
	Game.sfx("vent", -6.0, 0.9)
	Game.sfx("crack", -10.0, 1.3)
	Game.sparks(get_parent(), aim_point() + Vector2(0, -body_rect.size.y * 0.3), Color(0.9, 0.9, 0.92), 16, 70.0, Vector2.UP)
	if _expose_fx == null:
		_expose_fx = Node2D.new()
		_expose_fx.z_index = 9
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_expose_fx.material = m
		_expose_fx.draw.connect(_draw_expose)
		add_child(_expose_fx)


## 头顶一排小红格（每 +0.1 一格，最多 10 格）、身上的过热裂纹
func _draw_expose() -> void:
	if _expose_mult <= 1.0 or dead or dying():
		return
	var lv := int(roundf((_expose_mult - 1.0) / EXPOSE_STEP))
	var hot := Color(1.0, 0.35, 0.2)
	var warm := Color(1.0, 0.75, 0.35)
	var blink := int(_time * (3.0 + lv * 1.2)) % 2 == 0
	var top := body_rect.position.y - 5.0
	var w := lv * 3 - 1
	var x0 := roundf(-w / 2.0)
	for i in lv:
		var c := hot if (i < lv - 1 or blink) else warm
		_expose_fx.draw_rect(Rect2(x0 + i * 3, top, 2, 2), c)
	# 裂纹：从身子上沿往下几道折线，倍率越高越多、越亮
	var cracks := clampi(lv / 2 + 1, 1, 5)
	var a := 0.45 + 0.08 * lv
	for k in cracks:
		var fx := body_rect.position.x + body_rect.size.x * (0.2 + 0.6 * float(k) / maxf(cracks - 1, 1))
		var y := body_rect.position.y + 2.0
		var x := roundf(fx)
		for j in 3 + lv / 3:
			_expose_fx.draw_rect(Rect2(x, y + j * 2, 1, 2), Color(hot, a))
			x += 1.0 if (k + j) % 2 == 0 else -1.0


## 出场时打不动的白边：一闪一闪（打上去那一下全亮），出场完了收起来
func _sync_shield(delta: float) -> void:
	_shield_ping = maxf(_shield_ping - delta, 0.0)
	var on := in_intro() and not dead and _sprite.visible
	var a := 0.0
	if on:
		a = 1.0 if _shield_ping > 0.0 else 0.45 + 0.35 * sin(_time * 18.0)
	for sh in _shield:
		sh.visible = on
		if not on:
			continue
		sh.frame = _sprite.frame
		sh.flip_h = _sprite.flip_h
		sh.offset = _sprite.offset
		sh.position = _sprite.position + (sh.get_meta("off") as Vector2)
		(sh.material as ShaderMaterial).set_shader_parameter("tint", Color(SHIELD_COLOR, a))


## 亮层跟着贴图走（帧、翻转、抖动、白闪）；预警时贴图一闪一闪发红，越到最后闪得越快
func _sync_lift() -> void:
	if not warn_tint:
		pass
	elif _warn_t > 0.0 and not dead:
		var pulse := 0.5 + 0.5 * sin(_time * (16.0 + 18.0 / maxf(_warn_t, 0.15)))
		_sprite.modulate = Color.WHITE.lerp(Color(1.8, 0.75, 0.6), pulse * 0.75)
	else:
		_sprite.modulate = Color.WHITE
	_lift_layer.visible = _sprite.visible
	_lift_layer.frame = _sprite.frame
	_lift_layer.flip_h = _sprite.flip_h
	_lift_layer.offset = _sprite.offset
	_lift_layer.position = _sprite.position
	_lift_layer.modulate = Color(_sprite.modulate.lerp(Color(3, 3, 3), _flash), fill_alpha)


## 出场动画这段时间代替 EnemyBase._physics_process：只受重力、落地，不调子类的 _tick、不伤人
func _tick_intro(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta * 8.0, 0.0)
	velocity.x = 0.0
	if not flying:
		velocity.y = minf(velocity.y + gravity * delta, 400.0)
		move_and_slide()
	set_frame(0)
	if intro_t < 0.0:
		_fall_t += delta
		if flying or is_on_floor() or _fall_t >= INTRO_MAX_FALL:
			_intro_land()
	else:
		var was := intro_t
		intro_t += delta
		_intro_beats(was, intro_t)
	_update_visual()
	_intro_visual()
	_fx.queue_redraw()


func _intro_land() -> void:
	intro_t = 0.0
	_land_pos = global_position.round()
	var p := nearest_player()
	if p:
		dir = 1 if p.global_position.x > global_position.x else -1
	Game.sfx("clang", -4.0, 0.55)
	Game.sfx("land", -2.0, 0.5)
	Game.dust(get_parent(), global_position, 10)
	Game.add_shake(5.0)
	Game.hitstop(0.06)


## 落地以后到点触发的事（was → now 这一帧跨过了哪个时间点）
func _intro_beats(was: float, now: float) -> void:
	if was < INTRO_BOOT and now >= INTRO_BOOT:
		Game.sfx("title_on", -4.0, 0.9)
	if was < INTRO_POSE and now >= INTRO_POSE:
		Game.sfx("jet", -8.0, 0.6)
		Game.sfx("crack", -8.0, 0.7)
		Game.add_shake(3.0)
		Game.flash(Color(1.0, 0.25, 0.15), 0.18, 0.35)
		_flash = 0.8                        # 身上闪白一下，暗处也看得清摆的姿势
	if was < INTRO_POSE_END and now >= INTRO_POSE_END:
		Game.sfx("ready", -10.0, 0.8)
	if was < INTRO_TIME and now >= INTRO_TIME:
		remove_from_group("camera_focus")
		(_led.get_child(0) as PointLight2D).energy = 0.9


## 帧、落地一沉、红灯开机：在 _update_visual() 之后盖上去
func _intro_visual() -> void:
	var glow := _led.get_child(0) as PointLight2D
	if intro_t < 0.0:
		_led.visible = false
		return
	# 落地那一下整只往下沉 1 格再弹回来（不缩放贴图：canvas_items 模式下缩放会把像素拉得一大一小）
	if intro_t < 0.1:
		_sprite.position.y += 1.0
	if intro_t >= INTRO_POSE and intro_t < INTRO_POSE_END and intro_frame >= 0:
		set_frame(intro_frame)
		_sprite.frame = frame
		# 摆姿势那一下抖两帧
		if intro_t < INTRO_POSE + 0.1:
			_sprite.position.x += 1.0 if int(intro_t * 40.0) % 2 == 0 else -1.0
	# 红灯：开机前是灭的，跟着灯管的"嗒、嗒、嗒"闪三下才亮稳，亮稳时光一下子很亮再落回去
	var b := intro_t - INTRO_BOOT
	var on := false
	for f in INTRO_FLICKERS:
		if b >= f[0] and b < f[1]:
			on = true
	_led.visible = _led.visible and on
	var steady := b - INTRO_FLICKERS[2][0]
	glow.energy = 0.9 + 2.2 * clampf(1.0 - steady / 0.6, 0.0, 1.0) if steady >= 0.0 else 0.9


func _draw_fx() -> void:
	if not in_intro():
		return
	var o := -_fx.global_position
	var foot := global_position.round()
	var half := frame_size.x / 2.0
	if intro_t < 0.0:
		# 往下掉：身子上面拖几道竖的速度线
		if velocity.y > 120.0:
			for i in 4:
				var x := roundf(foot.x - half * 0.7 + i * half * 0.45) + (1.0 if i % 2 == 0 else 0.0)
				var ln := 10.0 + 6.0 * ((i * 7) % 3)
				var top := foot.y - frame_size.y - ln - 2.0 - 4.0 * (i % 2)
				_fx.draw_rect(Rect2(o + Vector2(x, top), Vector2(1, ln)), Color(1.0, 0.92, 0.8, 0.35))
		return
	# 落地：两道贴地的冲击波往两边推出去，越推越淡
	var k := clampf(intro_t / 0.35, 0.0, 1.0)
	if k < 1.0:
		var reach := roundf(half + 36.0 * (1.0 - pow(1.0 - k, 2.0)))
		var col := Color(1.0, 0.9, 0.75, 0.7 * (1.0 - k))
		for s in [-1.0, 1.0]:
			_fx.draw_rect(Rect2(o + Vector2(_land_pos.x + s * reach - (6.0 if s > 0 else 0.0), _land_pos.y - 1),
					Vector2(6, 1)), col)
			_fx.draw_rect(Rect2(o + Vector2(_land_pos.x + s * (reach - 9.0) - (3.0 if s > 0 else 0.0), _land_pos.y - 2),
					Vector2(3, 1)), Color(col, col.a * 0.6))
	# 开机：红灯亮稳的那一刻，一圈红光从灯上扩出去（一格一个点的像素圆）
	var r := intro_t - INTRO_BOOT - INTRO_FLICKERS[2][0]
	if r >= 0.0 and r < 0.45:
		var kk := r / 0.45
		var center := o + _led.global_position.round()
		_pixel_circle(center, roundi(4.0 + 44.0 * (1.0 - pow(1.0 - kk, 2.0))), Color(LED_COLOR, 0.8 * (1.0 - kk)))
		if kk < 0.5:
			_pixel_circle(center, roundi(2.0 + 20.0 * kk), Color(1, 0.8, 0.7, 0.6 * (1.0 - kk * 2.0)))


## 中点画圆法：半径 radius 的一圈 1×1 像素点（每个点只画一次，半透明时不会叠出亮点）
func _pixel_circle(c: Vector2, radius: int, col: Color) -> void:
	var pts := {}
	var x := radius
	var y := 0
	var err := 1 - radius
	while x >= y:
		for p in [Vector2i(x, y), Vector2i(y, x), Vector2i(-y, x), Vector2i(-x, y),
				Vector2i(-x, -y), Vector2i(-y, -x), Vector2i(y, -x), Vector2i(x, -y)]:
			pts[p] = true
		y += 1
		if err < 0:
			err += 2 * y + 1
		else:
			x -= 1
			err += 2 * (y - x) + 1
	for p in pts:
		_fx.draw_rect(Rect2(c + Vector2(p), Vector2.ONE), col)


## 出场时打不动：冒一点火星、响一下，告诉玩家"还没开打"
func hurt(damage: float, from_dir: Vector2, full: bool) -> void:
	if _death_t >= 0.0:
		return
	if in_intro():
		# 护盾挡住："叮"一声、冒一点冷白的火花、白边全亮一下（连发武器时声音 0.12 秒最多一次）
		Game.sparks(get_parent(), aim_point() - from_dir.normalized() * 6.0, SHIELD_COLOR, 5, 70.0, -from_dir.normalized())
		if _shield_ping <= 0.0:
			Game.sfx("ding", -16.0, 1.7, 0.1)
		_shield_ping = 0.12
		return
	super.hurt(damage * _expose_mult, from_dir, full)
	_hit_jolt = HIT_JOLT
	_jolt_dir = signf(from_dir.x) if from_dir.x != 0.0 else 0.0


func _draw_warn() -> void:
	if _warn_t <= 0.0 or dead:
		return
	# 3 像素宽的感叹号，一闪一闪
	if int(_warn_t * 16.0) % 2 == 0:
		return
	_warn_node.draw_rect(Rect2(-1, -9, 3, 6), WARN_COLOR)
	_warn_node.draw_rect(Rect2(-1, -1, 3, 2), WARN_COLOR)
	_warn_node.draw_rect(Rect2(0, -8, 1, 4), Color(1, 0.8, 0.7))


func _die() -> void:
	# 有死亡演出的：第一次血打空先"坏掉"，演完 _tick_death 再调回来真炸
	if death_time > 0.0 and _death_t < 0.0:
		_death_t = 0.0
		_death_pop = 0.0
		velocity.x = 0.0
		_warn_t = 0.0
		_contact.set_deferred("monitoring", false)
		Game.hitstop(0.1, 0.25)
		Game.sfx("crack", -4.0, 0.7)
		if death_scrap:
			Game.sfx("jet", -10.0, 0.9)
		else:
			Game.sfx("charge", -8.0, 0.4)
		Game.add_shake(3.0)
		_flash = 1.0
		return
	# 10-18 作者："打死往外扩散的一圈粒子，这个不会让打击感更好"：改成顺着最后一下挨打的方向迸（同小怪击杀，HitFx / Splatter，游戏设计会话做的接口）
	var hd := _hit_dir if _hit_dir != Vector2.ZERO else Vector2(-dir, -0.3).normalized()
	var n := 10 if big or body_rect.size.x > 50.0 else 8
	if death_scrap:
		var tint: Color = death_colors[0] if not death_colors.is_empty() else Color8(150, 140, 125)
		var body := Rect2(global_position + body_rect.position, body_rect.size)
		if death_colors.is_empty():
			EliteFx.scrap_dir(get_parent(), body, hd, n + 4)
		else:
			EliteFx.scrap_dir(get_parent(), body, hd, n + 4, death_colors)
		HitFx.debris(get_parent(), aim_point(), hd, global_position.y, 6, false, tint)
		Splatter.spray(self, aim_point(), hd, 14, false)
	else:
		HitFx.debris(get_parent(), aim_point(), hd, global_position.y, n, true)
		Splatter.spray(self, aim_point(), hd, 16, true)
		Game.dust(get_parent(), global_position + Vector2(hd.x * body_rect.size.x * 0.3, 0), 10, signf(hd.x))
		Game.sfx("boom", -4.0, 0.55)
	Game.sparks(get_parent(), aim_point(), death_spark_colors_big[0], 12, 160.0, hd)
	Game.sparks(get_parent(), aim_point(), death_spark_colors_big[1], 15, 140.0, hd)
	HitFx.silhouette(get_parent(), self)          # 白剪影亮 3 帧（顿帧时定格），和小怪击杀一样
	WeaponPickup.drop_from(self)                  # 有些精英固定掉一把武器（weapon_pickup.gd 的 DROPS）
	Game.flash(Color(1, 0.9, 0.8), 0.25, 0.4)
	Game.add_shake(6.0)
	Game.hitstop(0.12, 0.3)
	Game.sfx(death_boom_sfx, -2.0, death_boom_pitch)
	super._die()


## "坏掉"的那一段：不调子类的 _tick、不伤人、打不动。越抖越厉害，红灯接触不良一样闪着灭掉，
## 身上噼啪冒火星（活物冒灰），机器"呜——"地降调停转；最后半段白闪越来越密，到点真炸
func _tick_death(delta: float) -> void:
	_death_t += delta
	_time += delta
	var k := clampf(_death_t / death_time, 0.0, 1.0)
	_flash = maxf(_flash - delta * 6.0, 0.0)
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	if not flying:
		velocity.y = minf(velocity.y + gravity * delta, 400.0)
		move_and_slide()
	if death_frame >= 0:
		set_frame(death_frame)
	# 机器"呜——"地一档一档降调停转
	if death_scrap:
		for i in 3:
			var at_t := death_time * (0.25 + 0.25 * i)
			if _death_t - delta < at_t and _death_t >= at_t:
				Game.sfx("jet", -12.0 - 2.0 * i, 0.75 - 0.15 * i)
	_death_pop -= delta
	if _death_pop <= 0.0:
		_death_pop = lerpf(0.22, 0.07, k)
		var at := global_position + Vector2(randf_range(body_rect.position.x, body_rect.end.x) * 0.8,
				randf_range(body_rect.position.y, body_rect.end.y) * 0.9)
		if death_scrap:
			Game.sparks(get_parent(), at, Color8(255, 210, 140), 3, 70.0, Vector2(randf_range(-0.5, 0.5), -1.0).normalized())   # 往上噼啪，不撒一圈
			Game.sfx("hit", -16.0, randf_range(1.6, 2.4))
		else:
			Game.dust(get_parent(), Vector2(at.x, global_position.y), 2)
		if k > 0.5:
			_flash = 0.7
	_update_visual()
	var amp := 1.0 if k < 0.6 else 2.0
	_sprite.position.x += amp if int(_death_t * 30.0) % 2 == 0 else -amp
	# 红灯：接触不良，越来越常灭，最后全灭
	_led.visible = _led.visible and k < 0.85 and randf() > k * 0.9
	(_led.get_child(0) as PointLight2D).energy = 0.9 * (1.0 - k)
	if _lift_layer:
		_sync_lift()
	if _death_t >= death_time:
		_die()


## 屏幕最底下一行：名字 + 血条。挂在精英怪身上，跟着它一起消失。
## 出场动画时：摆姿势那一刻才出来，血条从空涨满。
## 10-18（游戏细节讨论会话）：作者说第三关血条会挡住弹幕。名字和血条从 y 224~242（第三关正好是地面那一层）
## 挪到画面最底下排成一行，血条 4 像素改 3 像素；子弹、怪、主角走到后面时整条变淡（见 BarFade）
class EliteBar:
	extends CanvasLayer

	const FILL_START := 0.05
	const FILL_TIME := 0.7
	const BAR_W := 200.0
	const BAR_H := 3.0

	var elite: EliteBase
	var _shown := 0.0
	var _root: Control
	var _label: Label
	var _rect := Rect2()
	var _alpha := 1.0

	func _ready() -> void:
		layer = 40
		# 底部血条亮着的时候，hud 把同一行的操作说明藏起来（10-18 作者：不要有文字重叠）
		add_to_group("hp_bar")
		_root = Control.new()
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.draw.connect(_draw_bar)
		add_child(_root)
		_label = Label.new()
		_label.label_settings = Hud.small_text(Color8(255, 211, 138))
		_label.text = elite.elite_name
		_root.add_child(_label)
		var w := _label.get_minimum_size().x
		var at: Array = BarFade.row(w, BAR_W, BAR_H)
		_label.position = at[0]
		_label.size = Vector2(w, 12)
		_rect = at[1]
		_shown = 1.0
		visible = not elite.in_intro()

	## 出场动画里血条涨到哪了（0~1）；没在出场就是 1
	func _fill() -> float:
		if not elite.in_intro():
			return 1.0
		return clampf((elite.intro_t - EliteBase.INTRO_POSE - FILL_START) / FILL_TIME, 0.0, 1.0)

	func _process(delta: float) -> void:
		visible = is_instance_valid(elite) and not elite.dead \
				and (not elite.in_intro() or elite.intro_t >= EliteBase.INTRO_POSE)
		if not visible:
			return
		if elite.in_intro():
			_shown = _fill()
		else:
			_shown = move_toward(_shown, elite.hp / elite.max_hp, delta * 1.5)
		_alpha = BarFade.step(_alpha, BarFade.crowded(self, _rect.merge(Rect2(_label.position, _label.size))), delta)
		_root.modulate.a = _alpha
		_root.queue_redraw()

	func _draw_bar() -> void:
		var r := _rect
		var hp := minf(elite.hp / elite.max_hp, _fill())
		_root.draw_rect(r.grow(1), Color(0, 0, 0, 0.7))
		_root.draw_rect(Rect2(r.position, Vector2(r.size.x * _shown, r.size.y)), Color8(120, 40, 30))
		_root.draw_rect(Rect2(r.position, Vector2(r.size.x * hp, r.size.y)), Color8(230, 70, 50))
		if elite.in_intro() and hp > 0.0 and hp < 1.0:
			_root.draw_rect(Rect2(r.position + Vector2(r.size.x * hp - 1.0, -1), Vector2(2, r.size.y + 2)),
					Color8(255, 230, 200))


## 出场动画的屏幕层：上下黑边 + 屏幕上方正中的名字，像老终端：
## 两条细横线从中间往两边拉开 → 小标题闪两下亮起 → 大名字一个字母一个字母打出来（嗒嗒声 + 闪烁的方块光标）
## → 收场时字像显像管关机一样闪几下灭掉，横线缩回中间。全是横平竖直的像素，没有斜边。
class IntroCard:
	extends CanvasLayer

	const BAR_H := 18.0
	const CENTER_X := 240.0
	const TITLE_Y := 26.0
	const NAME_Y := 36.0
	const LINE_TOP := 24.0
	const LINE_BOTTOM := 64.0
	const LINE_COLOR := Color8(255, 90, 60)
	const NAME_SIZE := 22
	## 打一个字母的时间
	const TYPE_TIME := 0.035
	const TYPE_START := 0.12
	const OUT_TIME := 0.18

	var elite: EliteBase
	var _root: Control
	var _title: Label
	var _name: Label
	var _name_w := 0.0
	var _typed := 0

	func _ready() -> void:
		layer = 45
		# 名字卡在的时候，hud 的横幅排队等它走完（同一时间只出一段字）
		add_to_group("name_card")
		_root = Control.new()
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.draw.connect(_draw_card)
		add_child(_root)
		_title = Label.new()
		_title.label_settings = Hud.small_text(Color8(255, 130, 100))
		_title.text = elite.intro_title if elite.intro_title != "" else "ELITE"
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title.size = Vector2(480, 12)
		_title.position = Vector2(0, TITLE_Y)
		_root.add_child(_title)
		_name = Label.new()
		var big := Hud.small_text(Color8(255, 236, 214))
		big.font_size = NAME_SIZE
		big.outline_size = 4
		big.outline_color = Color8(30, 8, 6)
		_name.label_settings = big
		# 逐字打出来、量宽度都用翻好的名字
		_name.text = tr(elite.elite_name)
		# 先排好整行再一个个露出来，字不会随着打字往两边挪
		_name.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		_name_w = Hud.font().get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
		_name.position = Vector2(roundf(CENTER_X - _name_w / 2.0), NAME_Y)
		_root.add_child(_name)
		visible = false

	func _process(_delta: float) -> void:
		visible = is_instance_valid(elite) and elite.in_intro() and elite.intro_t >= 0.0
		if not visible:
			return
		var t := elite.intro_t - EliteBase.INTRO_POSE
		var n := clampi(int((t - TYPE_START) / TYPE_TIME) + 1, 0, _name.text.length()) if t >= TYPE_START else 0
		if n > _typed:
			_typed = n
			if _name.text[n - 1] != " ":
				Game.sfx("ui_move", -14.0, randf_range(1.5, 1.8))
		_name.visible_characters = n
		var on := _text_on(t)
		# 小标题：亮起时闪两下
		_title.visible = on and t >= 0.05 and not (t < 0.2 and int(t / 0.05) % 2 == 1)
		_name.visible = on and n > 0
		_root.queue_redraw()

	## 收场：显像管关机一样闪几下再灭
	func _text_on(t: float) -> bool:
		var o := elite.intro_t - EliteBase.INTRO_OUT
		if o < 0.0:
			return t >= 0.0
		return o < OUT_TIME and int(o / 0.04) % 2 == 0

	func _draw_card() -> void:
		var it := elite.intro_t
		# 上下黑边：落地时滑进来，收场时退出去
		var k := clampf(it / 0.2, 0.0, 1.0) * (1.0 - clampf((it - EliteBase.INTRO_OUT - 0.05) / 0.2, 0.0, 1.0))
		var h := roundf(BAR_H * (1.0 - pow(1.0 - k, 3.0)))
		if h > 0.0:
			_root.draw_rect(Rect2(0, 0, 480, h), Color.BLACK)
			_root.draw_rect(Rect2(0, 270 - h, 480, h), Color.BLACK)
		var t := it - EliteBase.INTRO_POSE
		if t < 0.0:
			return
		# 两条横线：从中间往两边拉开，收场时缩回中间
		var grow := 1.0 - pow(1.0 - clampf(t / 0.15, 0.0, 1.0), 3.0)
		grow *= 1.0 - clampf((it - EliteBase.INTRO_OUT) / OUT_TIME, 0.0, 1.0)
		var half := roundf((_name_w / 2.0 + 28.0) * grow)
		if half >= 1.0:
			for y in [LINE_TOP, LINE_BOTTOM]:
				_root.draw_rect(Rect2(CENTER_X - half, y, half * 2.0, 1), LINE_COLOR)
				# 两头各一个小竖钩
				var tick_y: float = y - 1.0 if y == LINE_BOTTOM else y
				_root.draw_rect(Rect2(CENTER_X - half, tick_y, 1, 2), LINE_COLOR)
				_root.draw_rect(Rect2(CENTER_X + half - 1.0, tick_y, 1, 2), LINE_COLOR)
		# 方块光标：跟在打出来的最后一个字母后面闪，打完以后再闪一会儿
		if _name.visible and int(t / 0.12) % 2 == 0:
			var shown := _name.text.substr(0, _typed)
			var w := Hud.font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
			_root.draw_rect(Rect2(roundf(_name.position.x + w + 2.0), NAME_Y + 8.0, 8, 14), Color8(255, 236, 214))
