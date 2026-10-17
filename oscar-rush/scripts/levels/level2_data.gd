extends RefCounted
## 第二关的地图数据，草图/第二关/level2_map.py 生成的，别手改（改脚本重新跑）。
## 坐标都是地图像素：3700×600，前半交换台 x 0~1000，胶片天桥 1000~2840，后半放映厅 2840~3700。

const BOUNDS := Rect2(0, 0, 3700, 600)
const SPAWN := Vector2(40, 96)
## 出口：舞台上的小门，门前一块
const EXIT := Rect2(3652, 470, 24, 34)
const A_X1 := 1000
const B_X0 := 2840
const FLOORS := {"A1": 96, "A3": 200, "A2": 300, "orch": 520, "stage": 500}
const BRIDGE_Y := 300
const FILM_TOP := 223
const FILM_BOT := 313
## 换卷点：镜头中心走到这里停下，打一场精英怪
const REEL_CHANGES: Array[float] = [1640.0, 2280.0]
## 墙上的电话（遭遇战来波前响铃），和 ENCOUNTERS 一一对应
const PHONES: Array[Vector2] = [Vector2(520, 62), Vector2(540, 166), Vector2(560, 266), Vector2(3520, 470)]
## 碰撞矩形（名字见 level2_collision.json）
const SOLIDS: Array[Rect2] = [
	Rect2(0, 0, 1000, 24),  # A 天花板
	Rect2(0, 0, 16, 600),  # A 左墙
	Rect2(16, 96, 804, 10),  # A1 顶层
	Rect2(120, 200, 864, 10),  # A3 中层
	Rect2(984, 24, 16, 186),  # A 右墙（中层以上）
	Rect2(16, 300, 984, 300),  # A2 底层
	Rect2(1000, 300, 1840, 13),  # 胶片天桥
	Rect2(2840, 200, 276, 14),  # 放映室天花板
	Rect2(3100, 214, 16, 48),  # 放映室前墙（下面钻过去）
	Rect2(2840, 300, 330, 300),  # 放映室地板 + 包厢边
	Rect2(3170, 322, 40, 278),  # 座位第 1 排
	Rect2(3210, 344, 40, 256),  # 座位第 2 排
	Rect2(3250, 366, 40, 234),  # 座位第 3 排
	Rect2(3290, 388, 40, 212),  # 座位第 4 排
	Rect2(3330, 410, 40, 190),  # 座位第 5 排
	Rect2(3370, 432, 40, 168),  # 座位第 6 排
	Rect2(3410, 454, 40, 146),  # 座位第 7 排
	Rect2(3450, 476, 40, 124),  # 座位第 8 排
	Rect2(3490, 498, 40, 102),  # 座位第 9 排
	Rect2(3530, 520, 170, 80),  # 乐池地面
	Rect2(3600, 500, 100, 20),  # 舞台
	Rect2(3116, 0, 584, 40),  # 观众厅天花板
	Rect2(3684, 0, 16, 600),  # B 右墙
]
## 遭遇战的场子：left/right 是闸门 x，ceil 是天花板（怪从这里掉），floor 是地面
const ARENAS := [
	{"name": "E1 顶层", "left": 280, "right": 760, "ceil": 24, "floor_l": 96, "floor_r": 96},
	{"name": "E2 中层", "left": 200, "right": 820, "ceil": 106, "floor_l": 200, "floor_r": 200},
	{"name": "E3 底层", "left": 180, "right": 900, "ceil": 210, "floor_l": 300, "floor_r": 300},
	{"name": "E4 乐池", "left": 3470, "right": 3684, "ceil": 330, "floor_l": 476, "floor_r": 520},
]
