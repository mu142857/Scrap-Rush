class_name Level3Camera
extends GameCamera
## 第三关的镜头：人在哪块屏幕里，就把这块屏幕居中摆在画面正中，不跟着人左右晃。
## 缩放挑能把整块屏幕（加一圈外壳）装下的最大一档：2、5/3、4/3、1。
## 窗口是游戏画面的 3 倍，这几档在窗口上正好是 6、5、4、3 个像素一格，像素不会糊。
## 不在任何屏幕里（起点的仓库地面、爬洞的半路上）就照常跟人（GameCamera 的做法），缩放保持上一块屏幕的。
## 多人不在同一块屏幕里时也照常跟人，并退到 4/3 倍，免得有人出画面。
## 小屏幕（玻璃窄于 SMALL_W 或矮于 SMALL_H，天气预报那种过道）不锁、不缩放，照常跟人（作者 2026-10-17）。
## 大到 1 倍也装不下的屏幕：用 4/3 倍跟人，但镜头不出这块屏幕。

const ZOOMS := [2.0, 5.0 / 3.0, 4.0 / 3.0, 1.0]
## 屏幕四周多看这么多（外壳、控制条）
const MARGIN := Vector2(14, 12)
const LOCK_SPEED := 7.0
const SMALL_W := 200.0
const SMALL_H := 120.0
const ZOOM_SPEED := 5.0

## [{rect: Rect2（屏幕玻璃）, floor: float}]，关卡填
var screens: Array = []

var _zoom_target := ZOOM


func _ready() -> void:
	super._ready()
	_zoom_target = zoom.x


func snap() -> void:
	super.snap()
	var s := _current_screen()
	if not s.is_empty():
		var r: Rect2 = s["rect"]
		if r.size.x >= SMALL_W and r.size.y >= SMALL_H and _fits(r, _fit_zoom(r)):
			_zoom_target = _fit_zoom(r)
			zoom = Vector2(_zoom_target, _zoom_target)
			global_position = r.get_center()


func _process(delta: float) -> void:
	var s := _current_screen()
	if s.is_empty():
		if _players().size() > 1 and not _all_in_one_screen():
			_zoom_target = minf(_zoom_target, ZOOMS[2])
		_apply_zoom(delta)
		super._process(delta)
		return
	var rect: Rect2 = s["rect"]
	if rect.size.x < SMALL_W or rect.size.y < SMALL_H:
		_zoom_target = ZOOM
		_apply_zoom(delta)
		super._process(delta)
		return
	_zoom_target = _fit_zoom(rect)
	_apply_zoom(delta)
	if not _fits(rect, _zoom_target):
		super._process(delta)
		var half := get_viewport_rect().size * 0.5 / zoom
		global_position.x = clampf(global_position.x, rect.position.x + half.x - MARGIN.x, maxf(rect.position.x + half.x - MARGIN.x, rect.end.x - half.x + MARGIN.x))
		global_position.y = clampf(global_position.y, rect.position.y + half.y - MARGIN.y, maxf(rect.position.y + half.y - MARGIN.y, rect.end.y - half.y + MARGIN.y))
		return
	var target := rect.get_center()
	global_position = global_position.lerp(target, 1.0 - exp(-LOCK_SPEED * delta))
	if global_position.distance_to(target) < 0.25:
		global_position = target
	offset = (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * Game.shake / zoom.x * 2.0).round() / 2.0


func _apply_zoom(delta: float) -> void:
	var z := lerpf(zoom.x, _zoom_target, 1.0 - exp(-ZOOM_SPEED * delta))
	if absf(z - _zoom_target) < 0.002:
		z = _zoom_target
	zoom = Vector2(z, z)


func _fits(rect: Rect2, z: float) -> bool:
	var view := get_viewport_rect().size
	var need := rect.size + MARGIN * 2.0
	return need.x <= view.x / z and need.y <= view.y / z


func _fit_zoom(rect: Rect2) -> float:
	for z in ZOOMS:
		if _fits(rect, z):
			return z
	return ZOOMS[2]


## 所有玩家都在同一块屏幕里，就返回那块；否则返回空
func _current_screen() -> Dictionary:
	var players := _players()
	if players.is_empty():
		return {}
	var found: Dictionary = {}
	for p in players:
		var s := _screen_at(p.global_position)
		if s.is_empty():
			return {}
		if found.is_empty():
			found = s
		elif found != s:
			return {}
	return found


func _all_in_one_screen() -> bool:
	return not _current_screen().is_empty()


## 脚底在屏幕玻璃里（地面那一行也算）
func _screen_at(feet: Vector2) -> Dictionary:
	for s in screens:
		var r: Rect2 = s["rect"]
		if feet.x >= r.position.x and feet.x <= r.end.x and feet.y >= r.position.y and feet.y <= float(s["floor"]) + 1.0:
			return s
	return {}
