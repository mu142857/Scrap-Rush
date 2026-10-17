class_name EliteBase
extends EnemyBase
## 精英怪的公共底子（策划案第九节：每场遭遇战最后一波出一个，带一招独门技能）。在 EnemyBase 上多了：
## - 登场：屏幕下方出名字和血条（打死消失）；遭遇战里登场时情绪 +10 由 Encounter 负责。
## - 很重：挨打不后退（knockback 为 0），不会被打断招式，除非子类自己在 _on_hurt 里处理。
## - warn(offset, time)：头顶冒一个红色"!"，大招之前用（照 story_jam 的预警）。
## - 死亡：更大的火花、顿帧、震屏。
## 子类和 EnemyBase 一样：在 _setup() 里填参数（记得填 elite_name），在 _tick() 里写招式。

const WARN_COLOR := Color(1.0, 0.25, 0.2)

## 屏幕下方显示的名字（英文大写，评委看得懂）
var elite_name := "ELITE"

var _bar: EliteBar
var _warn_t := 0.0
var _warn_offset := Vector2.ZERO
var _warn_node: Node2D


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
	_bar = EliteBar.new()
	_bar.elite = self
	add_child(_bar)
	Game.sfx("crack", -6.0, 0.6)
	Game.add_shake(3.0)


## 头顶的红色"!"：offset 是相对脚底中间的位置，默认在贴图上面 6 像素
func warn(time := 0.5, offset := Vector2.INF) -> void:
	_warn_t = time
	_warn_offset = offset if offset != Vector2.INF else Vector2(0, -frame_size.y - 6)
	Game.sfx("charge", -16.0, 2.2)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _warn_t > 0.0:
		# 最后一帧减到 0 以下时也重画一次，把"!"擦掉
		_warn_t -= delta
		_warn_node.position = _warn_offset
		_warn_node.queue_redraw()


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


## 屏幕下方的名字 + 血条。挂在精英怪身上，跟着它一起消失
class EliteBar:
	extends CanvasLayer

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

	func _process(delta: float) -> void:
		visible = is_instance_valid(elite) and not elite.dead
		if visible:
			_shown = move_toward(_shown, elite.hp / elite.max_hp, delta * 1.5)
			_root.queue_redraw()

	func _draw_bar() -> void:
		var r := Rect2(140, 238, 200, 4)
		_root.draw_rect(r.grow(1), Color(0, 0, 0, 0.7))
		_root.draw_rect(Rect2(r.position, Vector2(r.size.x * _shown, r.size.y)), Color8(120, 40, 30))
		_root.draw_rect(Rect2(r.position, Vector2(r.size.x * elite.hp / elite.max_hp, r.size.y)), Color8(230, 70, 50))
