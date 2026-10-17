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

## 屏幕下方显示的名字（英文大写，评委看得懂）
var elite_name := "ELITE"
## 名字上面那行小字（英文大写），空的就写 ELITE
var intro_title := ""
## 摆招牌姿势时显示的帧，-1 就一直用第 0 帧
var intro_frame := -1

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


## 头顶的红色"!"：offset 是相对脚底中间的位置，默认在贴图上面 6 像素
func warn(time := 0.5, offset := Vector2.INF) -> void:
	_warn_t = time
	_warn_offset = offset if offset != Vector2.INF else Vector2(0, -frame_size.y - 6)
	Game.sfx("charge", -16.0, 2.2)


func in_intro() -> bool:
	return intro_t < INTRO_TIME and not dead


func _physics_process(delta: float) -> void:
	if in_intro():
		_tick_intro(delta)
	else:
		super._physics_process(delta)
	if _warn_t > 0.0:
		# 最后一帧减到 0 以下时也重画一次，把"!"擦掉
		_warn_t -= delta
		_warn_node.position = _warn_offset
		_warn_node.queue_redraw()


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
	if in_intro():
		Game.sparks(get_parent(), aim_point(), Color8(255, 220, 170), 4, 60.0)
		Game.sfx("hit", -14.0, 2.2, 0.1)
		return
	super.hurt(damage, from_dir, full)


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
	Game.sparks(get_parent(), aim_point(), Color8(255, 200, 130), 24, 160.0)
	Game.sparks(get_parent(), aim_point(), Color8(160, 150, 135), 30, 140.0)
	Game.flash(Color(1, 0.9, 0.8), 0.25, 0.4)
	Game.add_shake(6.0)
	Game.hitstop(0.12, 0.3)
	Game.sfx("crack", -2.0, 0.5)
	super._die()


## 屏幕下方的名字 + 血条。挂在精英怪身上，跟着它一起消失。
## 出场动画时：摆姿势那一刻才出来，血条从空涨满
class EliteBar:
	extends CanvasLayer

	const FILL_START := 0.05
	const FILL_TIME := 0.7

	var elite: EliteBase
	var _shown := 0.0
	var _root: Control
	var _label: Label

	func _ready() -> void:
		layer = 40
		_root = Control.new()
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.draw.connect(_draw_bar)
		add_child(_root)
		_label = Label.new()
		_label.label_settings = Hud.small_text(Color8(255, 211, 138))
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.size = Vector2(200, 12)
		_label.position = Vector2(140, 224)
		_label.text = elite.elite_name
		_root.add_child(_label)
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
		_root.queue_redraw()

	func _draw_bar() -> void:
		var r := Rect2(140, 238, 200, 4)
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
