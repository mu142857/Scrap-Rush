class_name L3Elite
extends EliteBase
## 第三关的精英怪（每种屏幕场景一只：老冰箱、电视壳大寄居蟹……）。贴图在 cfg 里（见 L3Mob），打法看 ARCH。
## 帧：0 待机、1 走（飞的是飘）、2 蓄力、3 出招、4 空中、5 亮相（出场动画和叫小怪时用）。
##
## 打法原型（10-18 作者："第三关的精英怪倒是没啥新意……全都是一个大小的放弹幕的，来点差异化"）：
##   charger  近战冲撞（中）：冲撞、来回冲（冲到头刹一下再冲回来，路线两头都标出来）、主题弹扇射
##   giant    砸地大块头（大）：走得慢；原地跺地（冲击波贴地往两边推，要跳）、跳砸（落地震塌天花板，碎块掉在标好的地方）、主题弹抛射
##   flyer    飞行俯冲（小）：悬在半空跟着人；斜着俯冲扑过来、从头顶往下扔一排东西、主题弹扇射；挨打会闪身
##   summoner 召唤（中）：和人拉开距离；叫小怪、在主角两边各落一只夹击、主题弹抛射
##   shield   护盾（中）：正面挨打只吃两成（冒火花"叮"一声），转身慢，绕到背后打 1.5 倍；出招那一下正面也吃全伤
##   blinker  瞬移（中）：像换台一样先在主角另一边标红框、再闪过去；贴地横扫一道扫描线（要跳）；主题弹扇射
##   gunner   远程弹幕（中）：保留原来的扇射、抛射、叫小怪
## 每只的子弹是自己的主题弹（L3Shot）：水塔喷水团、末班车打车灯、落地钟甩齿轮……
## 体型：giant 用大号贴图（scripts/enemies/l3/l3_elite_art.gd，放映机会话画），还没画好时先把原图整数放大 2 倍顶着；
## flyer 有小号贴图就用小号。
##
## 共同（10-18 夜间打磨）：
## - 预警 0.85 秒，整只一闪一闪发白（第三关的贴图着色器把颜色映射成单色，发红看不出来，白闪在映射之后叠）。
## - 出招前摇标记（红色，不吃色调映射）：冲撞路线、落点、射线、冲击波能推多远、瞬移的目的地、扫描线……
##   落点类在预警开始时就锁定，标记就是实际打到的地方。跳砸、抛射、俯冲按主角的跑法预判一点（LEAD_TIME）。
## - 死亡演出（EliteBase）：坏掉 1.1 秒再炸成碎块，碎块颜色跟着屏幕色调；挨打顿一格。
## - 信号串色（SIGNAL_FRINGE）：身后叠一红一青两层错开 1 像素的剪影，单色屏幕里也和背景分得开。
## - 半血狂暴：吼一声、震屏，之后出招间隔 ×0.6、走路和冲撞更快，头顶冒火、红边一跳一跳。
## - 抽签不放回出招（同 Boss1），每种招放的次数一样多。

enum { WALK, WARN, CHARGE, AIR, SHOOT, SUMMON, RECOVER, SKID, DIVE, BEAM }

const ARCH := {
	"last_train": {"type": "charger", "shot": "headlight"},
	"rockhorse": {"type": "charger", "shot": "marble", "hop": true},
	"sy_blower": {"type": "charger", "shot": "snow"},
	"ds_locomotive": {"type": "charger", "shot": "cinder"},
	"clawtub": {"type": "charger", "shot": "water", "slide": true},
	"water_tower": {"type": "giant", "shot": "water"},
	"ferris_wheel": {"type": "giant", "shot": "bulb"},
	"hb_octopus": {"type": "giant", "shot": "ink"},
	"fr_stump": {"type": "giant", "shot": "acorn"},
	"space_rocket": {"type": "flyer", "shot": "flame"},
	"weather_storm": {"type": "flyer", "shot": "rain", "air_trim": 6},
	"aq_angler": {"type": "flyer", "shot": "bubble"},
	"dustsheet": {"type": "flyer", "shot": "dust"},
	"tool_chest": {"type": "summoner", "shot": "nail"},
	"chalkboard": {"type": "summoner", "shot": "chalk"},
	"fridge": {"type": "shield", "shot": "ice"},
	"tvcrab": {"type": "shield", "shot": "sand"},
	"wardrobe": {"type": "shield", "shot": "hanger"},
	"static_noise": {"type": "blinker", "shot": "noise"},
	"test_colorbars": {"type": "blinker", "shot": "bars"},
	"street_lamp": {"type": "gunner", "shot": "moth"},
	"grandclock": {"type": "gunner", "shot": "gear"},
	"radiogram": {"type": "gunner", "shot": "note"},
}
const MOVES := {
	"charger": ["charge", "rush", "spray"],
	"giant": ["stomp", "slam", "volley"],
	"flyer": ["dive", "drop", "spray"],
	"summoner": ["summon", "flank", "volley"],
	"shield": ["bash", "spray", "slam"],
	"blinker": ["blink", "scan", "spray"],
	"gunner": ["spray", "volley", "summon"],
}
## 每种打法：走路速度、和主角保持的距离（近了退 / 远了追；near 为 0 就不退）、血量倍数
const TYPE := {
	"charger": {"walk": 34.0, "near": 0.0, "far": 50.0, "hp": 1.0},
	"giant": {"walk": 16.0, "near": 0.0, "far": 34.0, "hp": 1.05},
	"flyer": {"walk": 60.0, "near": 0.0, "far": 0.0, "hp": 1.1},
	"summoner": {"walk": 26.0, "near": 80.0, "far": 130.0, "hp": 0.95},
	"shield": {"walk": 22.0, "near": 0.0, "far": 46.0, "hp": 0.62},
	"blinker": {"walk": 28.0, "near": 40.0, "far": 90.0, "hp": 0.95},
	"gunner": {"walk": 30.0, "near": 56.0, "far": 100.0, "hp": 1.0},
}
## 大号、小号贴图（放映机会话画，见开头）。没有这个文件或者里面没有这只，就用原图
const ART_PATH := "res://scripts/enemies/l3/l3_elite_art.gd"

## 2026-10-17 作者试玩：屏幕小、躲不开，所以预警拉长、子弹变慢
const CHARGE_SPEED := 140.0
const CHARGE_TIME := 0.9
const WARN_TIME := 0.85
const JUMP_VY := -320.0
## 跳砸（10-18 美术哥 Oscar 试玩："把一些跳跃攻击滞空时长加长点儿"）：跳得更高、在空中更久，人能从它肚子底下钻过去。
## 原来起跳 320、重力 900，最高 57 像素、空中 0.71 秒；现在大块头最高 110、别的 85，空中重力 620：
## 大块头空中约 1.2 秒、别的约 1.05 秒。头顶有天花板就按能跳的高度算（不撞头），落点预警照这个算。
const SLAM_RISE := 85.0
const SLAM_RISE_GIANT := 110.0
const SLAM_GRAVITY := 620.0
const SLAM_MAX_VX := 170.0
const SHOCK_SPEED := 115.0
const BULLET_SPEED := 88.0
const MAX_SUMMONS := 2
const COOLDOWN := Vector2(0.35, 0.7)  # 10-18 作者：招和招之间停太久
## 血量在 level3_mobs.gd（生成的，别手改）里，这里统一乘上去，再乘打法的倍数
const HP_MULT := 2.5  # 10-18 作者：血不够，三把武器 20～35 秒（2.3 → 2.5：分打法以后站桩快了一点）
## 预判：落点按主角现在的水平速度再跑这么久来算，最多偏 LEAD_MAX
const LEAD_TIME := 0.45
const LEAD_MAX := 56.0
const SPRAY_SHOTS := 5
const SPRAY_STEP := 15.0
const VOLLEY_SIDE := 40.0
## 狂暴
const RAGE_HP := 0.5
const RAGE_COOL := 0.6
const RAGE_SPEED := 1.3
const RAGE_CHARGE := 1.15
## 来回冲：冲到头刹多久再冲回来
const SKID_TIME := 0.35
## 跺地冲击波：推多远、多快；跳砸落地震下来几块碎块、隔多远
const STOMP_REACH := 170.0
const WAVE_SPEED := 130.0
const SLAM_WAVE_REACH := 90.0
const DEBRIS_GAP := 34.0
## 飞的：悬多高、离人多远；俯冲多快；往下扔几个、隔多远
const HOVER_H := 34.0
const HOVER_DX := 34.0
const DIVE_SPEED := 230.0
## 走路被矮坎挡住时跳多高（约 43 像素）
const HOP_VY := -280.0
const DROP_COUNT := 4
const DROP_GAP := 22.0
const DODGE_CD := 2.5
const DODGE_DIST := 36.0
## 护盾：正面伤害倍数、背后倍数、主角绕到背后多久才转身
const FRONT_MULT := 0.3
const BACK_MULT := 1.5
const TURN_DELAY := 0.7
## 瞬移：落在主角另一边多远；扫描线多长、亮多久
const BLINK_DX := 48.0
const SCAN_REACH := 160.0
const BEAM_TIME := 0.35
## 信号串色
const SIGNAL_FRINGE := true
const FRINGE_COLORS := [Color(1.0, 0.25, 0.3, 0.55), Color(0.2, 0.95, 1.0, 0.5)]
const FRINGE_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}
"""
static var _fringe_shader: Shader
static var _big_tex := {}

var cfg: Dictionary = {}
var tint := "color"
var mob_name := ""

var arch := "gunner"
var shot := "rivet"
var _tp: Dictionary = {}
var _art: Dictionary = {}       # 大号 / 小号贴图（有的话）
var _upscale := 1               # 没有大号贴图时，原图整数放大几倍顶着
var _state := WALK
var _timer := 0.0
var _cool := 0.8                # 出场后第一招（10-18 压迫感：2.0 → 0.8）
var _move := ""
var _last_move := ""
var _bag: Array = []            # 这一副还没出的招
var _pattern := ""              # 正在放的招（预警到出完），招和招之间是空的；给 tools/qa/elite_regression.gd 分招数用
var _summons: Array[Node] = []
## 预警开始时锁定的目标（主角当时的脚底，跳砸、抛射、俯冲按预判以后的位置）
var _aim := Vector2.ZERO
var _tele: Node2D
var _tele_end_x := 0.0
var _tele_start_x := 0.0
var _tele_pts: Array[Vector2] = []
var _tele_y := 0.0
var _drop_y0: Array[float] = []   # 头顶扔一排：每颗从多高开始掉（预警时算好，和标记一致）
var _jump_v := Vector2.ZERO        # 跳砸的起跳速度（预警时按落点算好）
var _base_gravity := 900.0
var _fringe: Array[Sprite2D] = []
var _rage := false
var _rage_fx: Node2D
var _leg := 0                   # 来回冲：第几趟
var _dodge_cd := 0.0
var _behind_t := 0.0            # 护盾：主角在背后待了多久
var _block_t := 0.0             # 护盾：刚挡下一下（盾面闪一下）
var _beam_x := Vector2.ZERO     # 扫描线的左右两头
var _hover_side := 1.0
var _takeoff := 0.3
var _hop_cd := 0.0
var _hopping := false


func _setup() -> void:
	var name_key := mob_name
	if name_key == "":
		name_key = _name_from_cfg()
	var a: Dictionary = ARCH.get(name_key, {})
	arch = a.get("type", "gunner")
	shot = a.get("shot", "water")
	_tp = TYPE[arch]
	L3Mob.apply_cfg(self, cfg)
	_load_art(name_key)
	elite_name = cfg.get("elite_name", "ELITE")
	intro_title = cfg.get("title", "")
	intro_frame = 5
	max_hp = cfg.get("hp", 900.0) * HP_MULT * float(_tp["hp"])
	contact_damage = 12.0
	death_time = 1.1
	death_frame = 3
	hit_jolt = true
	warn_tint = false
	big = arch == "giant"
	if arch == "giant":
		knockback = Vector2(20.0, 8.0)
	# 飞的：出场照常落地（出场动画要落地），出场完了 0.3 秒再飞起来
	flying = false


func _name_from_cfg() -> String:
	for k in L3Mob.DATA.MOBS:
		if L3Mob.DATA.MOBS[k] == cfg:
			return k
	return ""


## 大号 / 小号贴图：有就换上尺寸数据（贴图在 _ready 里换，原图路径留给怪物图鉴认）；giant 没有就原图放大 2 倍
func _load_art(key: String) -> void:
	if ResourceLoader.exists(ART_PATH):
		var scr := load(ART_PATH) as GDScript
		if scr:
			var all: Dictionary = scr.get_script_constant_map().get("ART", {})
			_art = all.get(key, {})
	if not _art.is_empty():
		hframes = _art.get("hframes", hframes)
		frame_size = _art["frame_size"]
		body_rect = _art["body_rect"]
		led_by_frame = _art["leds"]
		led_pixel = led_by_frame.get(0, Vector2i(-1, -1))
	elif arch == "giant":
		_upscale = 2
		frame_size *= 2
		body_rect = Rect2(body_rect.position * 2.0, body_rect.size * 2.0)
		var leds := {}
		for k in led_by_frame:
			leds[k] = led_by_frame[k] * 2
		led_by_frame = leds
		led_pixel = led_by_frame.get(0, Vector2i(-1, -1))
	# 碰撞框（也是挨打框）一定要到脚底：框底比脚底高，站在地上时脚就陷进地里（10-18 第三关自检报 fr_stump、weather_storm 陷 3、6 像素）
	if body_rect.end.y < 0.0:
		body_rect.size.y -= body_rect.end.y


func _ready() -> void:
	super._ready()
	# 换成大号 / 小号贴图：所有用着原图的贴图层（本体、出场护盾白边、暗处亮层……）一起换
	var old := _sprite.texture
	var tex: Texture2D = null
	if not _art.is_empty():
		tex = load(_art["texture"])
	elif _upscale > 1:
		tex = _scaled(old, _upscale)
	if tex:
		for c in get_children():
			var s := c as Sprite2D
			if s and s.texture == old:
				s.texture = tex
				s.hframes = hframes


static func _scaled(src: Texture2D, k: int) -> Texture2D:
	var key := "%s@%d" % [src.resource_path, k]
	if not _big_tex.has(key):
		var img := src.get_image()
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
		_big_tex[key] = ImageTexture.create_from_image(img)
	return _big_tex[key]


func _after_ready() -> void:
	L3Mob.apply_look(self, tint)
	# 碎块用这块屏幕的色调（彩色屏幕用默认的暖灰）
	if L3Mob.RAMPS.has(tint):
		var r: Array = L3Mob.RAMPS[tint]
		death_colors = [r[1], r[2], r[3], r[4]]
	_tele = Node2D.new()
	_tele.top_level = true
	_tele.z_index = 8
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_tele.material = mat
	_tele.draw.connect(_draw_tele)
	add_child(_tele)
	_rage_fx = Node2D.new()
	_rage_fx.z_index = 7
	var rm := CanvasItemMaterial.new()
	rm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_rage_fx.material = rm
	_rage_fx.draw.connect(_draw_rage)
	add_child(_rage_fx)
	if SIGNAL_FRINGE:
		if _fringe_shader == null:
			_fringe_shader = Shader.new()
			_fringe_shader.code = FRINGE_SHADER
		for c in FRINGE_COLORS:
			var f := Sprite2D.new()
			f.texture = _sprite.texture
			f.hframes = hframes
			f.centered = false
			var fm := ShaderMaterial.new()
			fm.shader = _fringe_shader
			fm.set_shader_parameter("tint", c)
			f.material = fm
			add_child(f)
			move_child(f, _sprite.get_index())          # 放在贴图后面
			_fringe.append(f)


func _tick(delta: float) -> void:
	_timer -= delta
	_cool -= delta
	_dodge_cd -= delta
	_block_t -= delta
	if not _rage and hp <= max_hp * RAGE_HP and not dying():
		_enrage()
	var p := nearest_player(420.0)
	if arch == "flyer" and not flying:
		_takeoff -= delta
		if _takeoff <= 0.0:
			flying = true
			motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
			velocity = Vector2(0, -60)
			_trim_air()
	match _state:
		WALK:
			if flying:
				_hover(p, delta)
			else:
				_walk(p, delta)
			set_frame(int(_time / 0.25) % 2)
			if p and _cool <= 0.0 and (is_on_floor() or flying):
				_begin(p)
		WARN:
			if arch == "flyer":
				velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			set_frame(5 if _move == "summon" or _move == "flank" else 2)
			if _timer <= 0.0:
				_start_move(p)
		CHARGE:
			var spd := CHARGE_SPEED * speed_mult() * (RAGE_CHARGE if _rage else 1.0)
			if _move == "bash":
				spd *= 1.15
			velocity.x = dir * spd
			if cfg_flag("hop") and is_on_floor():
				velocity.y = -150.0         # 摇摇马：一蹦一蹦地冲
			set_frame(3)
			if int(_time / 0.08) != int((_time - delta) / 0.08):
				Game.dust(get_parent(), global_position + Vector2(-dir * body_rect.size.x * 0.4, 0), 2, -dir)
			if _timer <= 0.0 or is_on_wall() or not _charge_ground():
				velocity.x = 0.0
				Game.add_shake(3.0)
				if _move == "rush" and _leg == 0:
					_leg = 1
					_state = SKID
					_timer = SKID_TIME
				else:
					_recover(1.0 if _move != "bash" else 0.6)
		SKID:
			velocity.x = 0.0
			set_frame(2)
			if _timer <= 0.0:
				dir = -dir
				_state = CHARGE
				_timer = absf(_tele_start_x - global_position.x) / (CHARGE_SPEED * speed_mult() * (RAGE_CHARGE if _rage else 1.0)) + 0.05
		AIR:
			set_frame(4)
			if is_on_floor() and _timer < 0.25:
				_land()
		DIVE:
			set_frame(3)
			var to := _aim + Vector2(0, -2) - global_position
			if to.length() < 6.0 or _timer <= 0.0 or is_on_floor() or is_on_wall():
				velocity = Vector2.ZERO
				Game.add_shake(3.0)
				Game.dust(get_parent(), global_position, 6)
				Game.sfx("land", -8.0, 1.2)
				_recover(0.9)
			else:
				velocity = to.normalized() * DIVE_SPEED * (RAGE_CHARGE if _rage else 1.0)
		SHOOT:
			set_frame(3)
			if arch == "flyer":
				velocity = Vector2.ZERO
			if _timer <= 0.0:
				_recover(0.5)
		SUMMON:
			set_frame(5)
			if _timer <= 0.0:
				_recover(0.6)
		BEAM:
			set_frame(3)
			velocity.x = 0.0
			_beam_hit()
			if _timer <= 0.0:
				_recover(0.5)
		RECOVER:
			if arch == "flyer":
				velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			set_frame(0)
			if _timer <= 0.0:
				_state = WALK
				_cool = randf_range(COOLDOWN.x, COOLDOWN.y) * interval_mult() * (RAGE_COOL if _rage else 1.0)
				if _move == "blink":
					_cool *= 0.5        # 闪到背后马上接下一招（下一招照样有完整预警）
	move_and_slide()
	_tele.queue_redraw()
	_pattern = "" if _state == WALK or _state == RECOVER else _move
	if _rage or arch == "shield":
		_rage_fx.queue_redraw()


## 飞起来以后，碰撞框（也是挨打框、碰人框）去掉身子底下那几行装饰（风暴云的雨点）：打和被碰都只算云身。
## 站在地上时（出场、俯冲落地）还是用到脚底的框，不然脚会陷进地里
func _trim_air() -> void:
	var trim: float = ARCH.get(_key(), {}).get("air_trim", 0.0)
	if trim <= 0.0:
		return
	body_rect = Rect2(body_rect.position, body_rect.size - Vector2(0, trim))
	for sh in [_shape, _contact.get_child(0) as CollisionShape2D]:
		if sh and sh.shape is RectangleShape2D:
			(sh.shape as RectangleShape2D).size = body_rect.size
			sh.position = body_rect.get_center()


## 前面 dist 以内有没有挡路的东西（墙、台阶、第三关的隐形挡怪墙），脚下有没有地。冲撞前用
func _path_clear(d: int, dist: float) -> bool:
	var space := get_world_2d().direct_space_state
	var half := body_rect.size.x / 2.0
	for h in [3.0, body_rect.size.y * 0.5]:
		var from := global_position + Vector2(0, -h)
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(d * (half + dist), 0), collision_mask)
		q.exclude = [get_rid()]
		if not space.intersect_ray(q).is_empty():
			return false
	var g := global_position + Vector2(d * (half + 6.0), -2)
	return not space.intersect_ray(PhysicsRayQueryParameters2D.create(g, g + Vector2(0, 10), 1)).is_empty()


## 前面是不是一道跳得过去的矮坎：贴地被真的地形（第 1 层）挡住，跳起来那么高是空的，坎后面有地。
## 只被第三关洞口的隐形挡怪墙挡住时不跳（那是不让怪掉进洞的）
func _can_hop(d: int) -> bool:
	var space := get_world_2d().direct_space_state
	var half := body_rect.size.x / 2.0
	var low := global_position + Vector2(0, -3)
	var q0 := PhysicsRayQueryParameters2D.create(low, low + Vector2(d * (half + 12.0), 0), 1)
	q0.exclude = [get_rid()]
	if space.intersect_ray(q0).is_empty():
		return false
	var top := global_position + Vector2(0, -body_rect.size.y - 34.0)
	var q := PhysicsRayQueryParameters2D.create(top, top + Vector2(d * (half + 24.0), 0), collision_mask)
	q.exclude = [get_rid()]
	if not space.intersect_ray(q).is_empty():
		return false
	var land := global_position + Vector2(d * (half + 20.0), -44.0)
	return not space.intersect_ray(PhysicsRayQueryParameters2D.create(land, land + Vector2(0, 60), 1)).is_empty()


## 冲撞时前面还有没有地。摇摇马一蹦一蹦地冲，蹦在半空时原来的"脚下 8 像素有没有地"总是没有，
## 冲一下就停、像撞了墙（10-18 作者："摇摇马会卡墙"）：在空中时往下多看 40 像素
func _charge_ground() -> bool:
	if is_on_floor():
		return ground_ahead(16.0)
	var from := global_position + Vector2(dir * 16.0, -2.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 40), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func cfg_flag(k: String) -> bool:
	return ARCH.get(_key(), {}).get(k, false)


func _key() -> String:
	return mob_name if mob_name != "" else _name_from_cfg()


## 地上走：远了追、近了退（near 为 0 就不退）；护盾的转身慢
func _walk(p: Player, delta: float) -> void:
	_hop_cd -= delta
	# 正在跳出凹槽：空中保持往前的速度
	if _hopping:
		if is_on_floor() and velocity.y >= 0.0:
			_hopping = false
		else:
			return
	velocity.x = 0.0
	if p == null:
		return
	var want := 1 if p.global_position.x > global_position.x else -1
	if arch == "shield" and want != dir:
		_behind_t += delta
		if _behind_t < TURN_DELAY:
			return
	_behind_t = 0.0
	dir = want
	var dist := absf(p.global_position.x - global_position.x)
	var spd: float = _tp["walk"] * speed_mult() * _rage_mult()
	if dist > float(_tp["far"]) and ground_ahead(12.0) and not is_on_wall():
		velocity.x = dir * spd
	elif dist > float(_tp["far"]) and is_on_floor() and _hop_cd <= 0.0 and _can_hop(dir):
		# 前面一道矮坎挡住（生在凹槽里、台阶）：跳过去，不站着干瞪眼（10-18 美术哥试玩"冲不出去"）
		_hop_cd = 0.8
		_hopping = true
		velocity = Vector2(dir * maxf(spd, 50.0), HOP_VY)
		Game.dust(get_parent(), global_position, 4)
	elif dist < float(_tp["near"]):
		# 往后退，但脸还朝着人；背后没地方就站着
		dir = -dir
		if ground_ahead(12.0) and not is_on_wall():
			velocity.x = dir * spd * 0.8
		dir = -dir


## 飞的：悬在主角斜上方，留在自己这一边，一上一下地飘
func _hover(p: Player, _delta: float) -> void:
	if p == null:
		velocity = Vector2.ZERO
		return
	dir = 1 if p.global_position.x > global_position.x else -1
	_hover_side = -float(dir)
	var target := p.global_position + Vector2(_hover_side * HOVER_DX, -HOVER_H + sin(_time * 3.0) * 4.0)
	var to := target - global_position
	var spd: float = _tp["walk"] * speed_mult() * _rage_mult()
	velocity = to.normalized() * minf(spd, to.length() * 4.0)


## 挑一招，进预警：锁定目标、算好标记
func _begin(p: Player) -> void:
	_pick_move()
	# 冲撞型被地形挡着（生在凹槽里、贴着台阶）：冲不出去就改成跳砸，朝人跳出来（预警照样 0.85 秒，标落点）
	if (_move == "charge" or _move == "rush" or _move == "bash") and not _path_clear(1 if p.global_position.x > global_position.x else -1, 40.0):
		_move = "slam"
	_state = WARN
	_timer = WARN_TIME
	if arch != "flyer":
		velocity.x = 0.0
	warn(WARN_TIME)
	p = pick_focus(p)      # 双人时每招轮着盯一个人，预警开始就锁定
	dir = 1 if p.global_position.x > global_position.x else -1
	_behind_t = 0.0
	_leg = 0
	match _move:
		"slam", "volley", "dive", "drop":
			_aim = _lead(p)
		_:
			_aim = p.global_position
	_tele_start_x = global_position.x
	_plan_tele(p)
	if _move == "blink" or _move == "scan":
		Game.sfx("charge", -12.0, 1.6)


func _pick_move() -> void:
	var moves: Array = MOVES[arch]
	_summons = _summons.filter(func(n): return is_instance_valid(n) and not n.get("dead"))
	# 叫出来的小怪同时最多 MAX_SUMMONS 只（10-18 第三关会话：作者嫌怪多，一场压到 3+2，精英叫的最多 2 只）
	var cap := MAX_SUMMONS
	if _bag.is_empty():
		_bag = moves.duplicate()
		_bag.shuffle()
		if _bag.size() > 1 and _bag.back() == _last_move:
			_bag.reverse()
	var pick: String = _bag.pop_back()
	# 小怪已经召满了：这张先放回去垫底，换下一张
	var need := 2 if pick == "flank" else 1
	if (pick == "summon" or pick == "flank") and _summons.size() + need > cap:
		var other := moves.filter(func(m): return m != "summon" and m != "flank" and m != _last_move)
		if other.is_empty():
			other = moves.filter(func(m): return m != "summon" and m != "flank")
		_bag.push_front(pick)
		pick = other[0] if not other.is_empty() else "spray"
	_move = pick
	_last_move = _move


func _start_move(p: Player) -> void:
	match _move:
		"charge", "rush", "bash":
			_state = CHARGE
			_timer = CHARGE_TIME * (1.4 if cfg_flag("slide") else 1.0) * (0.5 if _move == "bash" else 1.0)
			Game.sfx("crack", -10.0, 1.2, 0.05)
		"slam":
			velocity = _jump_v
			_base_gravity = gravity
			gravity = SLAM_GRAVITY
			_state = AIR
			_timer = 0.6
		"stomp":
			_stomp()
			_state = SHOOT
			_timer = 0.5
		"spray":
			for i in SPRAY_SHOTS:
				_shoot_at(_muzzle() + _spray_dir(i) * 100.0)
			_state = SHOOT
			_timer = 0.4
		"volley":
			# 预判点一颗，两边各一颗夹住；落地都烧一小块地（颜色跟子弹走）
			for x in _volley_offsets():
				var b := _shoot_at(_aim + Vector2(x, 0), "arc")
				var z := FireZone.new()
				z.bullet = b
				z.arena = L3Mob.arena
				z.cols = _zone_cols()
				get_parent().add_child(z)
			_state = SHOOT
			_timer = 0.4
		"summon":
			_summon([-dir])
			_state = SUMMON
			_timer = 0.5
		"flank":
			_flank()
			_state = SUMMON
			_timer = 0.5
		"dive":
			_state = DIVE
			_timer = 1.2
			Game.sfx("jet", -8.0, 1.4)
		"drop":
			for i in _tele_pts.size():
				var x := _tele_pts[i].x
				# 从落点上方 80 像素（顶到天花板为止）开始掉：落 0.5 秒左右，看得见、躲得开（原来从云底只掉 27 像素，一出来就到地）
				var y0: float = _drop_y0[i] if i < _drop_y0.size() else global_position.y + 4.0
				var b := L3Shot.fire(get_parent(), shot if L3Shot.STYLES[shot]["move"] == "fall" else "rock", Vector2(x, y0), Vector2(x, _tele_pts[i].y))
				b.arena = L3Mob.arena
			Game.sfx("hit", -10.0, 0.8, 0.1)
			_state = SHOOT
			_timer = 0.5
		"blink":
			_blink()
		"scan":
			_state = BEAM
			_timer = BEAM_TIME
			Game.sfx("jet", -6.0, 1.8)
			Game.add_shake(2.0)
		_:
			_recover(0.3)


func _muzzle() -> Vector2:
	return aim_point() + Vector2(dir * body_rect.size.x * 0.35, -4)


## 打一颗主题弹。force_move = "arc"：抛射时不管这种子弹本来怎么飞，一律抛过去（落地烧地）
func _shoot_at(target: Vector2, force_move := "") -> Node2D:
	Game.sfx("hit", -12.0, 1.2, 0.1)
	var style := shot
	if force_move == "arc":
		var mv: String = L3Shot.STYLES[style]["move"]
		if mv != "arc" and mv != "roll":
			style = {"flame": "cinder", "rain": "water", "bubble": "water", "dust": "sand", "nail": "rock",
				"chalk": "rock", "ice": "snow", "noise": "rock", "bars": "bulb", "moth": "sand", "note": "bulb",
				"headlight": "cinder"}.get(style, "water")
	elif L3Shot.STYLES[style]["move"] == "fall":
		style = "drizzle"           # 往下掉的子弹不管瞄哪：扇射、直射时换成照方向飞的那一种
	var b := L3Shot.fire(get_parent(), style, _muzzle(), target, BULLET_SPEED)
	b.arena = L3Mob.arena
	b.target = focus_player()
	return b


func _zone_cols() -> Array:
	match shot:
		"water", "rain", "bubble", "snow", "ice":
			return [Color(0.3, 0.55, 1.0), Color(0.6, 0.85, 1.0), Color(0.95, 1.0, 1.0)]
		"ink":
			return [Color(0.35, 0.1, 0.45), Color(0.85, 0.3, 0.8), Color(1.0, 0.6, 0.95)]
		"bulb", "bars", "note":
			return [Color(0.9, 0.7, 0.2), Color(1.0, 0.9, 0.4), Color(1.0, 1.0, 0.85)]
	return [EnemyBase.LED_COLOR, EnemyBase.LED_HOT, Color(1.0, 0.8, 0.35)]


func _spray_dir(i: int) -> Vector2:
	var a := deg_to_rad((i - (SPRAY_SHOTS - 1) / 2.0) * SPRAY_STEP)
	var base := Vector2(dir, 0)
	if arch == "flyer":
		# 飞在上面：整扇朝人斜下方
		var p := focus_player()
		if p:
			base = (p.global_position + Vector2(0, -6) - _muzzle()).normalized()
	return base.rotated(a * dir)


func _volley_offsets() -> Array[float]:
	return [-VOLLEY_SIDE, 0.0, VOLLEY_SIDE]


## 预判：主角照现在的水平速度再跑 LEAD_TIME 秒会在哪（只预判一点，最多偏 LEAD_MAX）
func _lead(p: Player) -> Vector2:
	return p.global_position + Vector2(clampf(p.velocity.x * LEAD_TIME, -LEAD_MAX, LEAD_MAX), 0)


func _rage_mult() -> float:
	return RAGE_SPEED if _rage else 1.0


## 血掉到一半：吼一声、震屏、冒一圈火花，之后一直冒火
func _enrage() -> void:
	_rage = true
	Game.add_shake(6.0)
	Game.sfx("jet", -4.0, 0.55)
	Game.sfx("crack", -6.0, 0.7)
	Game.sparks(get_parent(), aim_point(), EnemyBase.LED_HOT, 16, 120.0)
	_flash = 1.0


func _land() -> void:
	gravity = _base_gravity
	Game.add_shake(8.0 if arch == "giant" else 5.0)
	Game.sfx("land", -4.0 if arch == "giant" else -6.0, 0.55 if arch == "giant" else 0.7)
	Game.dust(get_parent(), global_position, 12 if arch == "giant" else 8)
	velocity.x = 0.0
	if arch == "giant":
		_waves(SLAM_WAVE_REACH)
		# 震塌天花板：碎块掉在预警时标好的地方
		for i in range(1, _tele_pts.size()):
			var x := _tele_pts[i].x
			var top := _ceiling_above(Vector2(x, _tele_pts[i].y))
			var b := L3Shot.fire(get_parent(), "rock", Vector2(x, top), _tele_pts[i])
			b.arena = L3Mob.arena
	else:
		for s in [-1, 1]:
			var b := BossBullet.spawn(get_parent(), BossBullet.Kind.RIVET, global_position + Vector2(s * 10, -4), Vector2(s * SHOCK_SPEED, 0))
			b.arena = L3Mob.arena
			b.crt = true
	_recover(0.9)


## 跺地：身边一下，再往两边各推一道冲击波
func _stomp() -> void:
	Game.add_shake(7.0)
	Game.sfx("land", -3.0, 0.5)
	Game.dust(get_parent(), global_position, 14)
	_waves(STOMP_REACH)
	var half := body_rect.size.x / 2.0 + 12.0
	for n in get_tree().get_nodes_in_group("player"):
		var pl := n as Player
		if pl and absf(pl.global_position.x - global_position.x) < half and absf(pl.global_position.y - global_position.y) < 10.0:
			pl.hurt(global_position, 14.0 * damage_mult())


func _waves(reach: float) -> void:
	for s in [-1.0, 1.0]:
		var w := GroundWave.new()
		w.side = s
		w.reach = reach
		w.cols = _zone_cols()
		w.position = global_position + Vector2(s * body_rect.size.x * 0.45, 0)
		get_parent().add_child(w)


func _summon(sides: Array) -> void:
	var smalls := L3Mob.smalls(cfg.get("scene", ""))
	if smalls.is_empty():
		return
	for s in sides:
		var m := L3Mob.make(smalls[randi() % smalls.size()], tint)
		m.position = global_position + Vector2(s * 24, -frame_size.y * 0.5)
		get_parent().add_child(m)
		_summons.append(m)
		Game.sparks(get_parent(), m.position, Color8(255, 190, 120), 8, 70.0)
	Game.sfx("scrap", -8.0, 1.4)


## 夹击：主角两边（预警时标好的地方）各从上面落一只小怪
func _flank() -> void:
	var smalls := L3Mob.smalls(cfg.get("scene", ""))
	if smalls.is_empty():
		return
	for pt in _tele_pts:
		var m := L3Mob.make(smalls[randi() % smalls.size()], tint)
		m.position = pt + Vector2(0, -30)
		get_parent().add_child(m)
		_summons.append(m)
		Game.sparks(get_parent(), m.position, Color8(255, 190, 120), 8, 70.0)
	Game.sfx("scrap", -6.0, 1.2)


## 换台：本体炸一团雪花，出现在预警标好的地方
func _blink() -> void:
	var from := aim_point()
	Game.sparks(get_parent(), from, Color(0.9, 0.9, 0.95), 10, 90.0)
	Game.sfx("vent", -8.0, 2.0)
	global_position = _tele_pts[0] if not _tele_pts.is_empty() else global_position
	velocity = Vector2.ZERO
	var p := focus_player()
	if p:
		dir = 1 if p.global_position.x > global_position.x else -1
	Game.sparks(get_parent(), aim_point(), Color(0.9, 0.9, 0.95), 10, 90.0)
	_flash = 1.0
	_recover(0.35)


## 扫描线亮着时：脚站在这条线上的人挨一下（跳起来就躲过）
func _beam_hit() -> void:
	for n in get_tree().get_nodes_in_group("player"):
		var pl := n as Player
		if pl == null:
			continue
		var x := pl.global_position.x
		var dy := pl.global_position.y - _tele_y
		if x >= _beam_x.x and x <= _beam_x.y and dy > -9.0 and dy < 6.0:
			pl.hurt(Vector2(global_position.x, _tele_y), 10.0 * damage_mult())


## 预警开始时把这一招会打到哪里算好，画成标记
func _plan_tele(p: Player) -> void:
	_tele_pts.clear()
	var space := get_world_2d().direct_space_state
	match _move:
		"charge", "rush", "bash":
			var mult := (RAGE_CHARGE if _rage else 1.0) * (1.15 if _move == "bash" else 1.0)
			var t := CHARGE_TIME * (1.4 if cfg_flag("slide") else 1.0) * (0.5 if _move == "bash" else 1.0)
			var reach := CHARGE_SPEED * speed_mult() * mult * t
			var from := global_position + Vector2(0, -6)
			# 用自己的碰撞层（第三关遭遇战里还有挡怪的隐形墙，在屏幕边上），冲撞真会停在哪就标在哪
			var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(dir * (reach + body_rect.size.x / 2.0), 0), collision_mask)
			q.exclude = [get_rid()]
			var hit := space.intersect_ray(q)
			_tele_end_x = (hit["position"] as Vector2).x - dir * body_rect.size.x / 2.0 if not hit.is_empty() else global_position.x + dir * reach
			# 台子边也会停：沿路往前探地面
			var x := global_position.x
			while (_tele_end_x - x) * dir > 0.0:
				var nx := x + dir * 8.0
				var g := PhysicsRayQueryParameters2D.create(Vector2(nx + dir * 16.0, global_position.y - 4.0), Vector2(nx + dir * 16.0, global_position.y + 10.0), 1)
				if space.intersect_ray(g).is_empty():
					_tele_end_x = nx
					break
				x = nx
		"slam":
			# 能跳多高：想跳 SLAM_RISE（大块头更高），头顶有天花板就矮一点，别撞头（撞头会提前落地，落点就不准了）
			var rise := SLAM_RISE_GIANT if arch == "giant" else SLAM_RISE
			var head := global_position + Vector2(0, -body_rect.size.y)
			var up := PhysicsRayQueryParameters2D.create(head, head + Vector2(0, -rise - 8.0), 1)
			up.exclude = [get_rid()]
			var roof := space.intersect_ray(up)
			if not roof.is_empty():
				rise = clampf(head.y - (roof["position"] as Vector2).y - 6.0, 20.0, rise)
			var vy := -sqrt(2.0 * SLAM_GRAVITY * rise)
			var air := 2.0 * -vy / SLAM_GRAVITY
			var vx := clampf((_aim.x - global_position.x) / air, -SLAM_MAX_VX, SLAM_MAX_VX)
			_jump_v = Vector2(vx, vy)
			var land := _ground_below(Vector2(global_position.x + vx * air, global_position.y))
			_tele_pts.append(land)
			if arch == "giant":
				for k in [-1, 1]:
					_tele_pts.append(_ground_below(land + Vector2(k * DEBRIS_GAP, 0)))
		"volley":
			for x in _volley_offsets():
				_tele_pts.append(_ground_below(_aim + Vector2(x, 0)))
		"dive":
			_aim = _ground_below(_aim)
			_tele_pts.append(_aim)
		"drop":
			# 雨滴真会落在哪：从它开始掉的地方往下找第一个挡住的面（平台、家具顶），标记就画在那儿（10-18 作者："下雨会被平台挡住"）
			_drop_y0.clear()
			for i in DROP_COUNT:
				var base := _ground_below(_aim + Vector2((i - (DROP_COUNT - 1) / 2.0) * DROP_GAP, 0))
				var y0 := minf(global_position.y + 4.0, maxf(_ceiling_above(base) + 2.0, base.y - 80.0))
				var q := PhysicsRayQueryParameters2D.create(Vector2(base.x, y0), Vector2(base.x, base.y + 4.0), 1)
				var hit := space.intersect_ray(q)
				_tele_pts.append(((hit["position"] as Vector2) if not hit.is_empty() else base).round())
				_drop_y0.append(y0)
		"flank":
			for k in [-1, 1]:
				_tele_pts.append(_ground_below(p.global_position + Vector2(k * 50.0, 0)))
		"blink":
			# 主角的另一边；那边没地或者有墙，就落在主角这边离远一点
			var side := 1.0 if p.global_position.x > global_position.x else -1.0
			var dest := _blink_dest(p.global_position, side)
			if dest == Vector2.INF:
				dest = _blink_dest(p.global_position, -side)
			_tele_pts.append(dest if dest != Vector2.INF else global_position)
		"scan":
			_tele_y = global_position.y - 4.0
			var l := _wall_x(Vector2(global_position.x, _tele_y), -1.0)
			var r := _wall_x(Vector2(global_position.x, _tele_y), 1.0)
			_beam_x = Vector2(l, r)
		"stomp":
			_tele_end_x = STOMP_REACH


func _blink_dest(pp: Vector2, side: float) -> Vector2:
	var x := pp.x + side * BLINK_DX
	var g := _ground_below(Vector2(x, pp.y))
	if absf(g.y - pp.y) > 12.0:
		return Vector2.INF
	var q := PhysicsRayQueryParameters2D.create(pp + Vector2(0, -10), Vector2(x, pp.y - 10), 1)
	if not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
		return Vector2.INF
	return g


## 从 from 往 side 那边找墙，最远 SCAN_REACH
func _wall_x(from: Vector2, side: float) -> float:
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(side * SCAN_REACH, 0), 1)
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector2).x if not hit.is_empty() else from.x + side * SCAN_REACH


func _ground_below(p: Vector2) -> Vector2:
	var q := PhysicsRayQueryParameters2D.create(p + Vector2(0, -40), p + Vector2(0, 80), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return ((hit["position"] as Vector2) if not hit.is_empty() else p).round()


func _ceiling_above(p: Vector2) -> float:
	var q := PhysicsRayQueryParameters2D.create(p + Vector2(0, -8), p + Vector2(0, -150), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return ((hit["position"] as Vector2).y + 4.0) if not hit.is_empty() else p.y - 140.0


## 前摇标记：预警期间画（一闪一闪，最后 0.25 秒常亮）。红色不吃第三关的色调映射，哪种屏幕都看得见
func _draw_tele() -> void:
	if dead or dying():
		return
	var red := EnemyBase.LED_COLOR
	if _state == BEAM:
		# 扫描线亮起来：三色错开的一道横线
		var y := roundf(_tele_y)
		var cs := [Color(1.0, 0.3, 0.6), Color(0.3, 0.95, 1.0), Color(1, 1, 1)]
		for k in 3:
			_tele.draw_rect(Rect2(roundf(_beam_x.x), y - 1.0 + k, roundf(_beam_x.y - _beam_x.x), 1), cs[(k + int(_time * 20.0)) % 3])
		return
	if _state != WARN:
		return
	var on := _timer < 0.25 or int(_timer * 10.0) % 2 == 0
	var col := Color(red, 0.85 if on else 0.4)
	match _move:
		"charge", "rush", "bash":
			var y := roundf(global_position.y) - 1.0
			var x0 := roundf(global_position.x + dir * (body_rect.size.x / 2.0 + 4.0))
			var x1 := roundf(_tele_end_x)
			_arrows(x0, x1, y, dir, col)
			_tele.draw_rect(Rect2(x1, y - 8, 1, 8), col)
			if _move == "rush":
				# 冲回来：上面一排往回指的箭头
				_arrows(x1 - dir * 4.0, roundf(_tele_start_x), y - 5.0, -dir, col)
		"slam", "volley", "dive", "drop", "flank":
			for i in _tele_pts.size():
				var p := _tele_pts[i]
				if _move == "flank":
					_bracket(p + Vector2(0, -6), Vector2(14, 12), col)
					continue
				_tele.draw_rect(Rect2(p + Vector2(-5, -1), Vector2(11, 1)), col)
				_tele.draw_rect(Rect2(p + Vector2(-5, -3), Vector2(1, 2)), col)
				_tele.draw_rect(Rect2(p + Vector2(5, -3), Vector2(1, 2)), col)
				var bob := float(int(_timer * 6.0) % 2)
				for k in 3:
					_tele.draw_rect(Rect2(p + Vector2(-k, -8 + k + bob), Vector2(k * 2 + 1, 1)), col)
			if _move == "dive":
				# 俯冲路线：从身上一路点到落点
				var from := aim_point()
				var to := _tele_pts[0] + Vector2(0, -4)
				# 俯冲路线：从身上到落点一段一段的虚线（每 4 格亮 2 格）
				var n := int(from.distance_to(to))
				for k in range(4, n):
					if k % 4 < 2:
						_tele.draw_rect(Rect2(from.lerp(to, float(k) / n).round(), Vector2.ONE), col)
		"spray":
			var from := _muzzle()
			for i in SPRAY_SHOTS:
				var v := _spray_dir(i)
				for k in range(2, 9):
					_tele.draw_rect(Rect2((from + v * k * 5.0).round(), Vector2.ONE), col)
		"stomp":
			# 冲击波能推多远：两边贴地的虚线，头上一道竖线
			var y := roundf(global_position.y) - 1.0
			for s in [-1.0, 1.0]:
				var x0 := roundf(global_position.x + s * body_rect.size.x * 0.5)
				var x1 := roundf(global_position.x + s * (body_rect.size.x * 0.45 + STOMP_REACH))
				var x := x0
				while (x1 - x) * s > 0.0:
					_tele.draw_rect(Rect2(x, y, 3, 1), col)
					x += s * 6.0
				_tele.draw_rect(Rect2(x1, y - 6, 1, 6), col)
		"blink":
			if not _tele_pts.is_empty():
				var h := body_rect.size.y
				_bracket(_tele_pts[0] + Vector2(0, -h / 2.0), Vector2(body_rect.size.x + 6.0, h + 4.0), col)
		"scan":
			var y := roundf(_tele_y)
			var x := roundf(_beam_x.x)
			while x < _beam_x.y:
				_tele.draw_rect(Rect2(x, y, 4, 1), col)
				x += 8.0


func _arrows(x0: float, x1: float, y: float, d: int, col: Color) -> void:
	var x := x0
	while (x1 - x) * d > 0.0:
		_tele.draw_rect(Rect2(x, y, 1, 1), col)
		_tele.draw_rect(Rect2(x - d, y - 1, 1, 1), col)
		_tele.draw_rect(Rect2(x - d, y + 1, 1, 1), col)
		x += d * 8.0


## 四个角的红框（瞬移目的地、夹击落点）
func _bracket(c: Vector2, size: Vector2, col: Color) -> void:
	var r := Rect2((c - size / 2.0).round(), size.round())
	var k := 3.0
	for corner in [r.position, Vector2(r.end.x - 1, r.position.y), Vector2(r.position.x, r.end.y - 1), r.end - Vector2.ONE]:
		var sx := 1.0 if corner.x <= r.position.x else -1.0
		var sy := 1.0 if corner.y <= r.position.y else -1.0
		_tele.draw_rect(Rect2(corner if sx > 0 else corner - Vector2(k - 1, 0), Vector2(k, 1)), col)
		_tele.draw_rect(Rect2(corner if sy > 0 else corner - Vector2(0, k - 1), Vector2(1, k)), col)


## 挨打：护盾正面只吃两成、背后 1.5 倍；飞的挨打有机会闪开
func hurt(damage: float, from_dir: Vector2, full: bool) -> void:
	if arch == "shield" and not in_intro() and not dying():
		var front := from_dir.x * dir < 0.0
		var guarding := _state == WALK or _state == WARN or _state == RECOVER
		if front and guarding:
			damage *= FRONT_MULT
			_block_t = 0.15
			Game.sparks(get_parent(), global_position + Vector2(dir * body_rect.size.x * 0.5, -body_rect.size.y * 0.5), Color(0.85, 0.95, 1.0), 4, 70.0, Vector2(dir, 0))
			if _shield_ping <= 0.0:
				Game.sfx("ding", -14.0, 1.5, 0.1)
			_shield_ping = 0.12
		elif not front:
			damage *= BACK_MULT
	super.hurt(damage, from_dir, full)
	if arch == "flyer" and flying and _state == WALK and _dodge_cd <= 0.0 and not in_intro() and not dead and not dying() and randf() < 0.35:
		_dodge()


## 飞的挨打闪身：随机挑一边，那边有墙、闸门（都在第 1 层）就换另一边，两边都不行就不闪
## （10-18 质检：原来不查墙，会闪到闸门外面、闪进墙里）
func _dodge() -> void:
	var first := 1.0 if randf() < 0.5 else -1.0
	var space := get_world_2d().direct_space_state
	var half := body_rect.size.x / 2.0
	for side in [first, -first]:
		var from := aim_point()
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(side * (DODGE_DIST + half + 2.0), -6.0), 1)
		q.exclude = [get_rid()]
		if not space.intersect_ray(q).is_empty():
			continue
		var t := test_move(global_transform, Vector2(side * DODGE_DIST, -6.0))
		if t:
			continue
		_dodge_cd = DODGE_CD
		global_position += Vector2(side * DODGE_DIST, -6.0)
		Game.sparks(get_parent(), aim_point(), Color(0.9, 0.9, 0.95), 5, 60.0)
		Game.sfx("jump", -12.0, 1.6)
		return


## 预警：整只一闪一闪发白（第三关的着色器把颜色映射成单色，发红看不出来；白闪在映射之后叠，哪种屏幕都看得见）
func _update_visual() -> void:
	super._update_visual()
	# 信号串色：红的往左错一格、青的往右错一格，跟着贴图换帧、翻转
	for i in _fringe.size():
		var f := _fringe[i]
		f.visible = _sprite.visible
		f.frame = _sprite.frame
		f.flip_h = _sprite.flip_h
		f.offset = _sprite.offset
		f.position = _sprite.position + Vector2(-1.0 if i == 0 else 1.0, 0)
		if _rage and not dead:
			# 狂暴：两层都变红，一跳一跳
			var c: Color = FRINGE_COLORS[0]
			c.a = 0.55 + 0.4 * (0.5 + 0.5 * sin(_time * 9.0))
			(f.material as ShaderMaterial).set_shader_parameter("tint", c)
	if _state == WARN and not dead and not dying():
		var k := clampf(1.0 - _timer / WARN_TIME, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(_time * (14.0 + 26.0 * k))
		var mat := _sprite.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("flash", maxf(_flash, pulse * (0.25 + 0.35 * k)))
		# 瞬移预警：本体一抖一抖，像信号不好
		if _move == "blink":
			_sprite.position.x += float(int(_time * 30.0) % 3 - 1)


func _recover(t: float) -> void:
	_state = RECOVER
	_timer = t


## 狂暴时身上冒火；护盾怪在正面画一道盾（挡下一下时闪亮）
func _draw_rage() -> void:
	if dead or dying():
		return
	var top := -float(body_rect.size.y) - 1.0
	var w := int(body_rect.size.x)
	var x0 := int(body_rect.position.x)
	if arch == "shield" and (_state == WALK or _state == WARN or _state == RECOVER):
		var fx := roundf(dir * (body_rect.size.x / 2.0 + 2.0))
		var a := 0.95 if _block_t > 0.0 else 0.45 + 0.15 * sin(_time * 4.0)
		var hgt := int(body_rect.size.y * 0.8)
		for y in hgt:
			var c := Color(0.75, 0.92, 1.0, a * (0.6 + 0.4 * float((y + int(_time * 8.0)) % 4 == 0)))
			_rage_fx.draw_rect(Rect2(fx, -2 - y, 1, 1), c)
		_rage_fx.draw_rect(Rect2(fx - dir, -2 - hgt, 1, 1), Color(1, 1, 1, a))
		_rage_fx.draw_rect(Rect2(fx - dir, -2, 1, 1), Color(1, 1, 1, a))
	if not _rage:
		return
	var cols := [EnemyBase.LED_COLOR, EnemyBase.LED_HOT, Color(1.0, 0.8, 0.35)]
	var tick := int(_time * 12.0)
	for i in range(0, w, 3):
		var h := (tick * 7 + i * 13) % 6
		var base := Vector2(x0 + i + (tick + i) % 2, top + 2)
		for k in h:
			var c: Color = cols[mini(k * 3 / maxi(h, 1), 2)]
			c.a = 0.9 - 0.12 * k
			_rage_fx.draw_rect(Rect2(base + Vector2(0, -k), Vector2.ONE), c)
	# 往上飘的火星
	for j in 3:
		var t := fmod(_time * 1.3 + j * 0.37, 1.0)
		var sx := x0 + (j * 17 + int(_time * 3.0) * 5) % maxi(w, 1)
		_rage_fx.draw_rect(Rect2(Vector2(sx, top - 4.0 - t * 14.0).round(), Vector2.ONE), Color(EnemyBase.LED_HOT, 1.0 - t))


## 抛射弹落地后烧（浇、染）的一小块地：跟着子弹，子弹没了（落地、打中人）就在那儿贴地留 LIFE 秒，站在上面挨一下
class FireZone extends Node2D:
	const LIFE := 1.6
	const HALF := 12.0
	const HEIGHT := 10.0
	const DAMAGE := 8.0
	var bullet: Node2D
	var arena := Rect2()
	var cols: Array = [EnemyBase.LED_COLOR, EnemyBase.LED_HOT, Color(1.0, 0.8, 0.35)]
	var _last := Vector2.ZERO
	var _t := -1.0

	func _ready() -> void:
		z_index = 6
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m
		if is_instance_valid(bullet):
			_last = bullet.global_position

	func _physics_process(delta: float) -> void:
		if _t < 0.0:
			if is_instance_valid(bullet):
				_last = bullet.global_position
				return
			# 子弹飞出场子就不烧
			if arena.size != Vector2.ZERO and not arena.has_point(_last):
				queue_free()
				return
			var q := PhysicsRayQueryParameters2D.create(_last + Vector2(0, -6), _last + Vector2(0, 40), 1)
			var hit := get_world_2d().direct_space_state.intersect_ray(q)
			if hit.is_empty():
				queue_free()
				return
			global_position = (hit["position"] as Vector2).round()
			_t = 0.0
			Game.sfx("vent", -14.0, 1.8, 0.1)
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		for n in get_tree().get_nodes_in_group("player"):
			var p := n as Player
			if p and absf(p.global_position.x - global_position.x) <= HALF and absf(p.global_position.y - global_position.y) <= HEIGHT:
				p.hurt(global_position, DAMAGE * EnemyBase.damage_mult())
		queue_redraw()

	func _draw() -> void:
		if _t < 0.0:
			return
		var fade := 1.0 - maxf(0.0, _t - (LIFE - 0.4)) / 0.4
		var tick := int(_t * 14.0)
		# 贴地两行底，上面一列列一窜一窜（1 像素一列，最高 7 格）
		draw_rect(Rect2(-HALF, -1, HALF * 2.0 + 1.0, 1), Color(cols[0], 0.9 * fade))
		draw_rect(Rect2(-HALF + 1.0, -2, HALF * 2.0 - 1.0, 1), Color(cols[1], 0.8 * fade))
		for i in range(-int(HALF) + 1, int(HALF)):
			var edge := 1.0 - absf(i) / HALF
			var h := int(((tick * 5 + i * 7 + 40) % 5 + 3) * (0.4 + 0.6 * edge))
			for k in h:
				var c: Color = cols[mini(k * 3 / maxi(h, 1), 2)]
				c.a = (0.95 - 0.1 * k) * fade
				draw_rect(Rect2(i, -3 - k, 1, 1), c)


## 跺地的冲击波：贴着地面往一边推，推到 reach、撞墙或者台子边就散；碰到脚的挨一下（跳起来躲）
class GroundWave extends Node2D:
	const HIT := 12.0
	var side := 1.0
	var reach := 170.0
	var cols: Array = [EnemyBase.LED_COLOR, EnemyBase.LED_HOT, Color(1.0, 0.8, 0.35)]
	var _went := 0.0
	var _t := 0.0
	var _hit: Array[Node] = []

	func _ready() -> void:
		z_index = 7
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m

	func _physics_process(delta: float) -> void:
		_t += delta
		var step := L3Elite.WAVE_SPEED * delta
		var space := get_world_2d().direct_space_state
		var wall := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -5), global_position + Vector2(side * (step + 3.0), -5), 1)
		var floor_q := PhysicsRayQueryParameters2D.create(global_position + Vector2(side * 4.0, -3), global_position + Vector2(side * 4.0, 6), 1)
		if _went >= reach or not space.intersect_ray(wall).is_empty() or space.intersect_ray(floor_q).is_empty():
			Game.dust(get_parent(), global_position, 3)
			queue_free()
			return
		global_position.x += side * step
		_went += step
		if int(_t / 0.1) != int((_t - delta) / 0.1):
			Game.dust(get_parent(), global_position, 1, side)
		for n in get_tree().get_nodes_in_group("player"):
			var p := n as Player
			if p and not _hit.has(p) and absf(p.global_position.x - global_position.x) < 5.0 \
					and p.global_position.y - global_position.y > -9.0 and p.global_position.y - global_position.y < 4.0:
				if p.hurt(global_position, HIT * EnemyBase.damage_mult()):
					_hit.append(p)
		queue_redraw()

	func _draw() -> void:
		# 一道往前卷的土浪：前面高、后面低，最上面一格亮
		var hs := [2, 4, 6, 7, 5]
		for i in hs.size():
			var x := -side * (hs.size() - 1 - i)
			for k in hs[i]:
				var c: Color = cols[mini(2 - (k * 3 / hs[i]), 2)] if k < hs[i] - 1 else cols[2]
				draw_rect(Rect2(roundf(x), -1 - k, 1, 1), c)
