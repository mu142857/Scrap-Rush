class_name BarFade
extends RefCounted
## 精英、Boss 血条共用的两件事（作者 10-18："第三关有时候血条会挡住弹幕"）：
## 1. 位置：名字和血条排成一行，贴在画面最底下（row）。原来精英的名字在 y 224、血条在 y 238，
##    第三关镜头大，那正好是主角站的地面那一层，贴地飞的子弹从名字和血条后面穿过去就看不见了。
## 2. 自动变淡：子弹、怪、主角走到血条后面时，整条淡到 FADED，走开再回来（crowded / step）。

## 血条的中线（480×270 的画面里）。名字的字和血条都以它为中心
const ROW_Y := 261.0
## 名字和血条之间空多少
const GAP := 6.0
## 平时、有东西在后面时的不透明度
const SHOWN := 1.0
const FADED := 0.22
## 每秒变多少（约 0.2 秒淡下去）
const SPEED := 4.0
## 判断"在后面"时，名字 + 血条那块往外再扩这么多
const MARGIN := 8.0


## 名字和血条排成一行、整体居中。返回 [名字的位置, 血条的矩形]
static func row(name_w: float, bar_w: float, bar_h: float) -> Array:
	var total := name_w + GAP + bar_w
	var x0 := roundf(240.0 - total * 0.5)
	var bar := Rect2(x0 + name_w + GAP, roundf(ROW_Y - bar_h * 0.5), bar_w, bar_h)
	# 11 号像素字：Label 顶上留 2 像素，字身 11 像素，让字身的中线对上 ROW_Y
	var name_pos := Vector2(x0, roundf(ROW_Y - 7.5))
	return [name_pos, bar]


## 屏幕上 rect 这块后面有没有东西：主角、怪、Boss 的子弹，以及关卡根节点下直接挂的 Area2D / 角色（各种子弹、碎块）
static func crowded(from: Node, rect: Rect2) -> bool:
	var tree := from.get_tree()
	var xf := from.get_viewport().get_canvas_transform()
	var r := rect.grow(MARGIN)
	for g in [&"player", &"enemy", &"boss_bullet"]:
		for n in tree.get_nodes_in_group(g):
			if n is Node2D and r.has_point(xf * (n as Node2D).global_position):
				return true
	var lvl := tree.current_scene
	if lvl:
		for n in lvl.get_children():
			if (n is Area2D or n is CharacterBody2D) and r.has_point(xf * (n as Node2D).global_position):
				return true
	return false


## 不透明度往目标走一步
static func step(current: float, is_crowded: bool, delta: float) -> float:
	return move_toward(current, FADED if is_crowded else SHOWN, delta * SPEED)
