class_name TutorialTarget
extends EnemyBase
## 教学关客厅的铁皮打靶机（10-19 作者挑的方案 2「训练靶场」）：游乐场那种圆靶立在木座上，不还手。
## 打中就"叮"一声往后翻倒，倒下就躺在那儿（不碎、不掉灯油、不降情绪），三个都倒了开门。
## 三种：
##   plain   站着不动，一下就倒
##   shield  前面一块铆钉铁板：蓄满的一下（full）才打得倒；没蓄满的打在铁板上"当"一声，
##           挨够 DENTS 下也会倒（铆钉枪这类不能蓄力的武器靠这个；闪光灯一直不蓄也不至于卡死）
##   rail    底下是小车，沿一段轨道来回滑（教松手会自动瞄准）
## 帧：0 立着、1 翻一半、2 倒平（草图/教学关/tutorial_mobs.py 画的，数据在 tutorial_mobs.gd）。

const M := preload("res://scripts/tutorial/tutorial_mobs.gd")
## 挡板款：没蓄满的打几下也倒。闪光灯（能蓄力）多一些，好让人先看到"当"、去试蓄满
const DENTS_FLASH := 6
const DENTS_OTHER := 8
const RAIL_SPEED := 34.0
const RAIL_COLOR := Color8(120, 140, 160)

var kind := "plain"
## 轨道款：左右两头（世界坐标 x）
var rail := Vector2.ZERO
## 挡板款：被挡下过（教学关看到就出提示）
var blocked := false

var _dents := 0
var _rail_node: Node2D


func _setup() -> void:
	var cfg: Dictionary = M.TARGETS[{"plain": "target", "shield": "target_shield", "rail": "target_rail"}[kind]]
	texture_path = cfg["texture"]
	hframes = cfg["hframes"]
	frame_size = cfg["frame_size"]
	body_rect = cfg["body_rect"]
	led_by_frame = cfg["leds"]
	led_pixel = led_by_frame.get(0, Vector2i(-1, -1))
	max_hp = 1.0
	contact_damage = 0.0
	knockback = Vector2.ZERO


func _after_ready() -> void:
	L3Mob.apply_look(self, "color")
	if kind == "rail":
		dir = -1
		_rail_node = Node2D.new()
		_rail_node.top_level = true
		_rail_node.z_index = -1
		_rail_node.draw.connect(_draw_rail)
		add_child(_rail_node)


func _draw_rail() -> void:
	var y := roundf(_home.y)
	_rail_node.draw_rect(Rect2(rail.x - 6, y - 1, rail.y - rail.x + 12, 1), RAIL_COLOR)
	for x in [rail.x - 6, rail.y + 5]:
		_rail_node.draw_rect(Rect2(x, y - 3, 1, 3), RAIL_COLOR.darkened(0.3))


func _tick(_delta: float) -> void:
	velocity.x = 0.0
	if kind == "rail":
		if global_position.x <= rail.x:
			dir = 1
		elif global_position.x >= rail.y:
			dir = -1
		velocity.x = dir * RAIL_SPEED
	move_and_slide()
	# 靶面一直朝着左边（人从左边进来）
	dir = -1 if kind != "rail" else dir
	set_frame(0)


func _update_visual() -> void:
	var d := dir
	dir = -1                       # 轨道款来回滑，靶面也一直朝左，不翻面
	super._update_visual()
	dir = d


func hurt(damage: float, from_dir: Vector2, full: bool) -> void:
	if dead:
		return
	if kind == "shield" and not full:
		_dents += 1
		blocked = true
		_flash = 0.6
		Game.sfx("clang", -10.0, 1.5, 0.08)
		Game.sparks(get_parent(), global_position + Vector2(-10, -12), Color8(255, 236, 170), 4, 60.0, Vector2.LEFT)
		if _dents < (DENTS_FLASH if Upgrades.weapon == "flash" else DENTS_OTHER):
			return
	super.hurt(maxf(damage, max_hp), from_dir, true)


## 不碎：叮一声往后翻倒，躺在原地
func _die() -> void:
	dead = true
	_shape.set_deferred("disabled", true)
	_contact.set_deferred("monitoring", false)
	Game.sfx("ding", -6.0, 1.3, 0.05)
	Game.sparks(get_parent(), aim_point(), Color8(255, 220, 160), 6, 70.0, _hit_dir)
	_show(1)
	await get_tree().create_timer(0.07, false).timeout
	if is_instance_valid(self):
		_show(2)
		Game.dust(get_parent(), global_position + Vector2(6, 0), 3)


func _show(f: int) -> void:
	set_frame(f)
	_flash = 0.0
	_update_visual()
