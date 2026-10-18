extends RefCounted
## 第二关的地图数据，草图/第二关/level2_map.py 生成的，别手改（改脚本重新跑）。
## 坐标都是地图像素：3700×600，前半交换台 x 0~1000，胶片天桥 1000~2840，后半放映厅 2840~3700。

const BOUNDS := Rect2(0, 0, 3700, 600)
## 大图层（far / mid / main）切成几条、每条多宽（网页版贴图不能超过 2048 宽）
const TILE_W := 2048
const TILES := 2
const SPAWN := Vector2(70, 540)
## 出口：舞台上的小门，从门左边一直延到右墙（乐池那场打的时候人常挤在墙角，打完站着就能走）
const EXIT := Rect2(3652, 470, 32, 34)
const A_X1 := 1000
const B_X0 := 2840
const BRIDGE_Y := 300
const FILM_TOP := 223
const FILM_BOT := 313
## 换卷点：镜头中心走到这里停下，打一场精英怪
const REEL_CHANGES: Array[float] = [1640.0, 2280.0]
## 墙上的电话（遭遇战来波前响铃），和 ENCOUNTERS 一一对应
const PHONES: Array[Vector2] = [Vector2(250, 500), Vector2(720, 392), Vector2(250, 212), Vector2(3520, 470)]
## 碰撞矩形（名字见 level2_collision.json）
const SOLIDS: Array[Rect2] = [
	Rect2(28, 428, 404, 12),  # R1 接线员大厅 天花板
	Rect2(28, 540, 404, 60),  # R1 接线员大厅 地面
	Rect2(28, 440, 12, 100),  # R1 接线员大厅 左墙
	Rect2(420, 440, 12, 100),  # R1 接线员大厅 右墙
	Rect2(520, 328, 392, 12),  # R2 继电器机房 天花板
	Rect2(520, 430, 392, 12),  # R2 继电器机房 地面
	Rect2(520, 340, 12, 90),  # R2 继电器机房 左墙
	Rect2(900, 340, 12, 90),  # R2 继电器机房 右墙
	Rect2(40, 138, 412, 12),  # R3 电话簿仓库 天花板
	Rect2(40, 250, 412, 12),  # R3 电话簿仓库 地面
	Rect2(40, 150, 12, 100),  # R3 电话簿仓库 左墙
	Rect2(440, 150, 12, 100),  # R3 电话簿仓库 右墙
	Rect2(548, 188, 452, 12),  # R4 片库 天花板
	Rect2(548, 300, 452, 12),  # R4 片库 地面
	Rect2(548, 200, 12, 100),  # R4 片库 左墙
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
	{"name": "E1 接线员大厅", "left": 110, "right": 396, "ceil": 440, "floor_l": 540, "floor_r": 540},
	{"name": "E2 继电器机房", "left": 566, "right": 880, "ceil": 340, "floor_l": 430, "floor_r": 430},
	{"name": "E3 电话簿仓库", "left": 72, "right": 410, "ceil": 150, "floor_l": 250, "floor_r": 250},
	{"name": "E4 乐池", "left": 3470, "right": 3684, "ceil": 330, "floor_l": 476, "floor_r": 520},
]
## 气动管：mouth 是管口（人走进去就被吸走），path 是管子的折线，out/vel 是喷出来的位置和速度，
## needs 是先打完 ARENAS 里第几场管口才开
const TUBES := [
	{"mouth": Rect2(404, 516, 16, 24), "path": [Vector2(426, 528), Vector2(468, 528), Vector2(468, 410), Vector2(526, 410)], "out": Vector2(548, 429), "vel": Vector2(130, -90), "needs": 0},
	{"mouth": Rect2(884, 406, 16, 24), "path": [Vector2(906, 418), Vector2(940, 418), Vector2(940, 470), Vector2(500, 470), Vector2(500, 236), Vector2(446, 236)], "out": Vector2(424, 249), "vel": Vector2(-130, -90), "needs": 1},
	{"mouth": Rect2(52, 226, 16, 24), "path": [Vector2(46, 238), Vector2(20, 238), Vector2(20, 62), Vector2(640, 62), Vector2(640, 194)], "out": Vector2(640, 214), "vel": Vector2(60, 40), "needs": 2},
]
## 单向平台（顶面 y，4 像素厚，可以从下面跳上去、按下键跳下来）
const PLATFORMS: Array[Rect2] = [Rect2(190, 504, 46, 4), Rect2(276, 474, 64, 4), Rect2(636, 394, 64, 4), Rect2(744, 364, 56, 4), Rect2(80, 224, 90, 4), Rect2(210, 200, 90, 4), Rect2(346, 176, 74, 4), Rect2(600, 264, 90, 4), Rect2(712, 236, 78, 4)]
## 藏起来的小奖励：kind = part（零件）/ oil（灯油），pos 是脚下的位置
const PICKUPS := [{"kind": "part", "pos": Vector2(320, 474)}, {"kind": "oil", "pos": Vector2(780, 364)}, {"kind": "part", "pos": Vector2(400, 176)}, {"kind": "oil", "pos": Vector2(735, 236)}, {"kind": "part", "pos": Vector2(770, 236)}, {"kind": "oil", "pos": Vector2(1980, 300)}, {"kind": "oil", "pos": Vector2(2620, 300)}]
## 会自己亮灭的小灯：(x, y, kind)，kind 0 插孔空位 1 插孔亮着 2 继电器琥珀 3 继电器红 4 继电器空位
const BLINKS: Array[Vector3i] = [Vector3i(54, 459, 1), Vector3i(59, 473, 0), Vector3i(79, 473, 1), Vector3i(84, 494, 0), Vector3i(69, 508, 0), Vector3i(74, 508, 0), Vector3i(84, 508, 0), Vector3i(136, 459, 0), Vector3i(106, 466, 0), Vector3i(136, 466, 1), Vector3i(106, 480, 0), Vector3i(126, 480, 0), Vector3i(136, 480, 0), Vector3i(106, 494, 0), Vector3i(126, 494, 0), Vector3i(111, 501, 1), Vector3i(136, 501, 1), Vector3i(158, 452, 0), Vector3i(163, 452, 0), Vector3i(173, 452, 1), Vector3i(178, 452, 0), Vector3i(188, 452, 0), Vector3i(178, 466, 1), Vector3i(173, 480, 1), Vector3i(178, 480, 0), Vector3i(173, 501, 1), Vector3i(178, 501, 0), Vector3i(210, 452, 0), Vector3i(220, 452, 0), Vector3i(230, 452, 0), Vector3i(235, 452, 1), Vector3i(225, 459, 0), Vector3i(235, 459, 1), Vector3i(235, 466, 0), Vector3i(220, 473, 0), Vector3i(225, 473, 0), Vector3i(235, 473, 0), Vector3i(220, 494, 0), Vector3i(235, 494, 0), Vector3i(240, 494, 0), Vector3i(225, 501, 1), Vector3i(267, 459, 0), Vector3i(282, 459, 0), Vector3i(292, 466, 0), Vector3i(287, 494, 0), Vector3i(262, 508, 0), Vector3i(282, 508, 0), Vector3i(292, 508, 0), Vector3i(314, 466, 1), Vector3i(329, 466, 1), Vector3i(344, 466, 0), Vector3i(324, 494, 0), Vector3i(329, 494, 0), Vector3i(334, 494, 0), Vector3i(344, 494, 0), Vector3i(319, 508, 0), Vector3i(329, 508, 1), Vector3i(344, 508, 0), Vector3i(366, 466, 0), Vector3i(371, 466, 0), Vector3i(386, 466, 1), Vector3i(366, 480, 0), Vector3i(381, 480, 0), Vector3i(386, 480, 0), Vector3i(386, 487, 0), Vector3i(381, 501, 1), Vector3i(396, 501, 0), Vector3i(543, 365, 4), Vector3i(555, 365, 4), Vector3i(567, 365, 4), Vector3i(543, 374, 4), Vector3i(555, 374, 4), Vector3i(567, 374, 4), Vector3i(543, 383, 4), Vector3i(555, 383, 4), Vector3i(567, 383, 4), Vector3i(543, 392, 4), Vector3i(555, 392, 4), Vector3i(567, 392, 4), Vector3i(543, 401, 4), Vector3i(555, 401, 4), Vector3i(567, 401, 4), Vector3i(543, 410, 4), Vector3i(555, 410, 4), Vector3i(567, 410, 4), Vector3i(543, 419, 4), Vector3i(555, 419, 4), Vector3i(567, 419, 4), Vector3i(543, 428, 2), Vector3i(555, 428, 4), Vector3i(567, 428, 4), Vector3i(591, 365, 4), Vector3i(595, 365, 2), Vector3i(603, 365, 2), Vector3i(591, 374, 4), Vector3i(603, 374, 4), Vector3i(591, 383, 4), Vector3i(603, 383, 4), Vector3i(591, 392, 4), Vector3i(603, 392, 4), Vector3i(591, 401, 3), Vector3i(603, 401, 4), Vector3i(591, 410, 2), Vector3i(587, 419, 2), Vector3i(591, 419, 4), Vector3i(591, 428, 4), Vector3i(595, 428, 2), Vector3i(599, 428, 3), Vector3i(603, 428, 4), Vector3i(627, 365, 4), Vector3i(639, 365, 4), Vector3i(623, 374, 3), Vector3i(627, 374, 4), Vector3i(631, 374, 2), Vector3i(635, 374, 2), Vector3i(639, 374, 4), Vector3i(627, 383, 4), Vector3i(639, 383, 4), Vector3i(623, 392, 3), Vector3i(627, 392, 4), Vector3i(639, 392, 4), Vector3i(627, 401, 4), Vector3i(627, 428, 4), Vector3i(639, 428, 4), Vector3i(663, 365, 4), Vector3i(675, 365, 4), Vector3i(679, 365, 3), Vector3i(687, 365, 3), Vector3i(663, 374, 4), Vector3i(675, 374, 2), Vector3i(687, 374, 4), Vector3i(663, 383, 3), Vector3i(675, 383, 4), Vector3i(687, 383, 4), Vector3i(663, 392, 4), Vector3i(667, 392, 2), Vector3i(675, 392, 2), Vector3i(687, 392, 4), Vector3i(663, 401, 4), Vector3i(667, 401, 3), Vector3i(675, 401, 3), Vector3i(687, 401, 4), Vector3i(663, 410, 4), Vector3i(675, 410, 4), Vector3i(687, 410, 4), Vector3i(663, 419, 4), Vector3i(675, 419, 4), Vector3i(687, 419, 4), Vector3i(663, 428, 4), Vector3i(671, 428, 2), Vector3i(675, 428, 4), Vector3i(683, 428, 3), Vector3i(687, 428, 4), Vector3i(711, 365, 4), Vector3i(723, 365, 4), Vector3i(711, 374, 4), Vector3i(719, 374, 3), Vector3i(723, 374, 4), Vector3i(711, 383, 4), Vector3i(723, 383, 4), Vector3i(711, 392, 4), Vector3i(715, 392, 2), Vector3i(711, 401, 4), Vector3i(711, 410, 4), Vector3i(723, 410, 4), Vector3i(711, 419, 4), Vector3i(723, 419, 4), Vector3i(703, 428, 2), Vector3i(707, 428, 3), Vector3i(711, 428, 4), Vector3i(723, 428, 4), Vector3i(747, 374, 4), Vector3i(759, 374, 4), Vector3i(767, 374, 3), Vector3i(747, 383, 4), Vector3i(759, 383, 4), Vector3i(747, 392, 4), Vector3i(759, 392, 4), Vector3i(747, 401, 4), Vector3i(751, 401, 2), Vector3i(759, 401, 4), Vector3i(743, 410, 2), Vector3i(747, 410, 4), Vector3i(759, 410, 3), Vector3i(767, 410, 3), Vector3i(747, 419, 4), Vector3i(759, 419, 4), Vector3i(747, 428, 4), Vector3i(759, 428, 4), Vector3i(807, 365, 3), Vector3i(783, 374, 4), Vector3i(795, 374, 4), Vector3i(807, 374, 4), Vector3i(783, 383, 4), Vector3i(795, 383, 4), Vector3i(807, 383, 4), Vector3i(783, 392, 4), Vector3i(795, 392, 4), Vector3i(807, 392, 3), Vector3i(783, 401, 4), Vector3i(795, 401, 4), Vector3i(807, 401, 4), Vector3i(783, 410, 4), Vector3i(791, 410, 3), Vector3i(795, 410, 4), Vector3i(803, 410, 3), Vector3i(807, 410, 4), Vector3i(783, 419, 3), Vector3i(795, 419, 4), Vector3i(807, 419, 4), Vector3i(783, 428, 4), Vector3i(795, 428, 4), Vector3i(807, 428, 4), Vector3i(831, 365, 4), Vector3i(843, 365, 4), Vector3i(831, 374, 2), Vector3i(839, 374, 3), Vector3i(827, 383, 2), Vector3i(831, 383, 4), Vector3i(831, 392, 4), Vector3i(843, 392, 4), Vector3i(831, 401, 4), Vector3i(843, 401, 4), Vector3i(831, 410, 4), Vector3i(843, 410, 2), Vector3i(831, 419, 4), Vector3i(843, 419, 4), Vector3i(831, 428, 2), Vector3i(835, 428, 2), Vector3i(839, 428, 2), Vector3i(843, 428, 4), Vector3i(867, 365, 4), Vector3i(875, 365, 3), Vector3i(879, 365, 4), Vector3i(867, 374, 4), Vector3i(879, 374, 4), Vector3i(863, 383, 3), Vector3i(867, 383, 4), Vector3i(879, 383, 4), Vector3i(863, 392, 3), Vector3i(867, 392, 4), Vector3i(879, 392, 4), Vector3i(867, 401, 4), Vector3i(879, 401, 4), Vector3i(887, 401, 2), Vector3i(867, 410, 4), Vector3i(871, 410, 2), Vector3i(879, 410, 4), Vector3i(867, 419, 2), Vector3i(879, 419, 4), Vector3i(867, 428, 4), Vector3i(879, 428, 4)]
## 灯的颜色（褪过色的）：灭、琥珀、红、最亮的芯
const BLINK_COLORS: Array[Color] = [Color8(96, 74, 56), Color8(212, 175, 121), Color8(174, 108, 84), Color8(238, 221, 189)]
## 机房（室内范围），提示牌和调试用
const ROOMS := [
	{"name": "R1 接线员大厅", "rect": Rect2(40, 440, 380, 100)},
	{"name": "R2 继电器机房", "rect": Rect2(532, 340, 368, 90)},
	{"name": "R3 电话簿仓库", "rect": Rect2(52, 150, 388, 100)},
	{"name": "R4 片库", "rect": Rect2(560, 200, 440, 100)},
]
