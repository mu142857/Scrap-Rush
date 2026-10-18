class_name L3Mob
extends RefCounted
## 第三关的怪：每种屏幕场景有自己的一套（草图/第三关/怪物/ 画的，build_mobs.py --export 导出）。
## 小怪沿用现成的打法换皮：fly = 扑灯蛾、hop = 弹簧跳蚤、dash = 剃须刀，另加 shoot（L3Shoot）；
## 精英怪是 L3Elite，招式按配置组合。
## 怪长在屏幕里，所以和屏幕一样：不吃场景压暗，按屏幕的显示方式（彩色 / 黑白 / 绿荧光 / 琥珀）上色，带扫描线。
## 红色指示灯不染色，融进场景也认得出来。

const DATA := preload("res://scripts/levels/level3_mobs.gd")
## 子弹的活动范围（出了就消失），关卡开头填
static var arena := Rect2(0, 0, 2240, 1000)

const LOOK_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform float flash = 0.0;
uniform bool tinted = false;
uniform vec3 ramp[6];
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	bool led = distance(c.rgb, vec3(226.0, 72.0, 64.0) / 255.0) < 0.03;
	if (tinted && !led) {
		float l = dot(c.rgb, vec3(0.3, 0.55, 0.15));
		int i = clamp(int(l * 1.15 * 6.0), 0, 5);
		c.rgb = ramp[i];
	}
	// 扫描线：贴图里的偶数行暗一点
	if (!led && mod(floor(UV.y / TEXTURE_PIXEL_SIZE.y), 2.0) < 1.0) {
		c.rgb *= 0.93;
	}
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
"""
const RAMPS := {
	"bw": [Color8(34, 36, 44), Color8(70, 72, 82), Color8(112, 114, 124), Color8(156, 158, 166), Color8(204, 206, 210), Color8(236, 236, 236)],
	"green": [Color8(18, 36, 26), Color8(32, 70, 46), Color8(56, 116, 72), Color8(96, 170, 104), Color8(150, 220, 150), Color8(206, 246, 196)],
	"amber": [Color8(40, 22, 16), Color8(86, 46, 22), Color8(146, 84, 34), Color8(204, 128, 54), Color8(238, 178, 96), Color8(252, 222, 160)],
}
static var _shader: Shader


static func exists(mob_name: String) -> bool:
	return DATA.MOBS.has(mob_name)


## 这个场景的小怪名字（不含精英）
static func smalls(scene: String) -> Array[String]:
	var out: Array[String] = []
	for k in DATA.MOBS:
		if DATA.MOBS[k]["scene"] == scene and DATA.MOBS[k]["kind"] != "elite":
			out.append(k)
	return out


## 这个场景的精英怪，没有就返回空
static func elite(scene: String) -> String:
	for k in DATA.MOBS:
		if DATA.MOBS[k]["scene"] == scene and DATA.MOBS[k]["kind"] == "elite":
			return k
	return ""


static func make(mob_name: String, tint: String) -> EnemyBase:
	var cfg: Dictionary = DATA.MOBS[mob_name]
	var e: EnemyBase
	match cfg["kind"]:
		"fly":
			e = L3Fly.new()
		"hop":
			e = L3Hop.new()
		"dash":
			e = L3Dash.new()
		"shoot":
			e = L3Shoot.new()
		_:
			e = L3Elite.new()
	e.set("cfg", cfg)
	e.set("tint", tint)
	e.set("mob_name", mob_name)
	return e


## 子类的 _setup() 最后调：换成这只怪的贴图、帧、碰撞框、红灯
static func apply_cfg(e: EnemyBase, cfg: Dictionary) -> void:
	e.texture_path = cfg["texture"]
	e.hframes = cfg["hframes"]
	e.frame_size = cfg["frame_size"]
	e.body_rect = cfg["body_rect"]
	e.led_by_frame = cfg["leds"]
	e.led_pixel = cfg["leds"].get(0, Vector2i(-1, -1))
	e.respawn_time = 0.0
	if cfg["kind"] != "elite":
		e.max_hp = small_hp(cfg)


## 小怪血量（2026-10-18 作者："都是 100 生命值……不如从 90 到 120，有些差异化"）：
## 每一种固定一个值，按打法定底子（小而快的剃须刀、飞怪低，跳的、开枪的高），按贴图大小 ±7，
## 再按名字固定偏一档（-5 / 0 / +5），取整到 5，夹在 115～140（10-18 原来 90～120）。同一种怪永远一样，图鉴显示得对。
## 10-18 作者："有必要可以提升，比如部分第三关的小怪的血量"：按每场同屏怪数重平衡，整体加约 22，范围 90～120 → 115～140
## （第三关每场只有 4～5 只小怪，原来每场清场比第二关还快）。原来 dash 94、fly 97、hop 108、shoot 113
const HP_BASE := {"dash": 117.0, "fly": 120.0, "hop": 130.0, "shoot": 135.0}
## 每种打法贴图面积的中位数（level3_mobs.gd 里量的）
const HP_AREA := {"dash": 364.0, "fly": 350.0, "hop": 400.0, "shoot": 380.0}


static func small_hp(cfg: Dictionary) -> float:
	var kind: String = cfg["kind"]
	var fs: Vector2i = cfg["frame_size"]
	var size := clampf((fs.x * fs.y / HP_AREA.get(kind, 370.0) - 1.0) * 1.5, -1.0, 1.0) * 7.0
	var code := 0
	var tex: String = cfg["texture"]
	for c in tex.get_file().get_basename().to_utf8_buffer():
		code += c
	var jitter := float(code % 3 - 1) * 5.0
	return clampf(roundf((HP_BASE.get(kind, 100.0) + size + jitter) / 5.0) * 5.0, 115.0, 140.0)


## 子类的 _after_ready() 里调：换上屏幕色调的着色器（保留受击白闪的 flash 参数）
static func apply_look(e: EnemyBase, tint: String) -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = LOOK_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	if RAMPS.has(tint):
		var arr := PackedVector3Array()
		for c in RAMPS[tint]:
			arr.append(Vector3(c.r, c.g, c.b))
		mat.set_shader_parameter("ramp", arr)
		mat.set_shader_parameter("tinted", true)
	e._sprite.material = mat


static func bullet_kind(name: String) -> BossBullet.Kind:
	match name:
		"ember":
			return BossBullet.Kind.EMBER
		"note":
			return BossBullet.Kind.NOTE
	return BossBullet.Kind.RIVET


## 打一颗子弹：rivet 直线飞向 target，ember / note 朝 target 抛过去
static func fire(parent: Node, kind_name: String, from: Vector2, target: Vector2, speed := 120.0) -> BossBullet:
	var k := bullet_kind(kind_name)
	var vel: Vector2
	if k == BossBullet.Kind.RIVET:
		vel = (target - from).normalized() * speed
	else:
		var t := 0.9
		vel = Vector2(clampf((target.x - from.x) / t, -140.0, 140.0), (target.y - from.y) / t - 0.5 * BossBullet.EMBER_GRAVITY * t)
	var b := BossBullet.spawn(parent, k, from, vel)
	b.arena = arena
	# 第三关的子弹画成电视信号的样子，和第一关区分开
	b.crt = true
	b.queue_redraw()
	return b


## 贴图里（原图朝左）某个像素在世界里的位置：原点在脚底中间，朝右时左右翻
static func pixel_world(e: EnemyBase, px: Vector2i) -> Vector2:
	var col := px.x if e.dir < 0 else e.frame_size.x - 1 - px.x
	return e.global_position + Vector2(col - e.frame_size.x / 2, px.y - e.frame_size.y)
