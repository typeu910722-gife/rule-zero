class_name Interiors
extends RefCounted
## 每個角色的小屋（室內）：點擊調查裡面的東西。
##
## 美術還沒畫之前，用程式畫的「紙模型」房間代替（scripts/ui/interior.gd 的 _draw_prop）。
## 美術畫好後：放 art/int_<房間>.jpg（1280×720），房間就直接用那張圖，
## 下面每個熱點的 rect 對到圖上的位置即可（prop 只在沒有美術時才畫）。
##
## 熱點欄位：
##   id      對話標籤（game/dialogue/chapter1.txt 的 === int_xxx）
##   name    滑過去時顯示的名字
##   rect    位置（1280×720 畫面座標）
##   prop    沒有美術時要畫的東西
##   hidden  true＝不閃亮、不起眼（嚇人用的）
##   when    出現條件（GameState.check）

const ROOMS := {
	"lulu": {
		"name": "露露的家",
		"wall": Color("#f6d6dc"), "wall2": Color("#f0c2cc"), "pattern": "stripes",
		"trim": Color("#c27a8c"), "floor": Color("#d9b48f"), "floor2": Color("#c79f7a"),
		"decor": [
			{"prop": "window", "rect": Rect2(520, 70, 230, 190)},
			{"prop": "rug", "rect": Rect2(420, 560, 440, 110)},
			{"prop": "lamp", "rect": Rect2(880, 0, 70, 150)},
		],
		"hotspots": [
			{"id": "int_lulu_mirror", "name": "破掉的鏡子", "rect": Rect2(735, 10, 240, 360), "prop": "mirror_broken"},
			{"id": "int_lulu_sill", "name": "窗台上的小東西", "rect": Rect2(62, 268, 196, 56), "prop": "sill"},
			{"id": "int_lulu_sketch", "name": "素描本", "rect": Rect2(458, 255, 150, 78), "prop": "sketchbook"},
			{"id": "int_lulu_letter", "name": "寫到一半的信", "rect": Rect2(606, 290, 104, 48), "prop": "desk_letter"},
			{"id": "int_lulu_wardrobe", "name": "衣櫃", "rect": Rect2(1062, 20, 216, 500), "prop": "wardrobe"},
		],
	},
	"popo": {
		"name": "郵局",
		"wall": Color("#d7e3ec"), "wall2": Color("#c4d4e0"), "pattern": "planks",
		"trim": Color("#2f3352"), "floor": Color("#b9a08a"), "floor2": Color("#a68d77"),
		"decor": [
			{"prop": "window", "rect": Rect2(90, 80, 200, 170)},
			{"prop": "counter", "rect": Rect2(380, 400, 560, 120)},
		],
		"hotspots": [
			{"id": "int_popo_slots", "name": "信件格子", "rect": Rect2(40, 20, 750, 240), "prop": "slots"},
			{"id": "int_popo_pink", "name": "粉紅色的信", "rect": Rect2(560, 378, 190, 44), "prop": "pink_letter"},
			{"id": "int_popo_photos", "name": "照片牆", "rect": Rect2(830, 10, 292, 250), "prop": "photos_board"},
			{"id": "int_popo_stamps", "name": "郵票簿", "rect": Rect2(545, 280, 240, 58), "prop": "stamp_book"},
			{"id": "int_popo_scale", "name": "包裹秤", "rect": Rect2(775, 222, 112, 112), "prop": "scale"},
		],
	},
	"fen": {
		"name": "Fen 的樹屋",
		"wall": Color("#8a6a4f"), "wall2": Color("#7a5c43"), "pattern": "planks",
		"trim": Color("#4d3828"), "floor": Color("#6e5340"), "floor2": Color("#5f4736"),
		"dark": 0.25,
		"decor": [
			{"prop": "window_round", "rect": Rect2(560, 70, 160, 160)},
			{"prop": "hammock", "rect": Rect2(820, 300, 360, 140)},
		],
		"hotspots": [
			{"id": "int_fen_tally", "name": "牆上的刻痕", "rect": Rect2(200, 20, 290, 190), "prop": "tally"},
			{"id": "int_fen_photo", "name": "釘在牆上的照片", "rect": Rect2(490, 36, 250, 182), "prop": "class_photo"},
			{"id": "int_fen_notebook", "name": "筆記本", "rect": Rect2(404, 240, 200, 80), "prop": "notebook"},
			{"id": "int_fen_plank", "name": "翹起來的木板", "rect": Rect2(478, 408, 262, 64), "prop": "plank"},
			{"id": "int_fen_slingshot", "name": "彈弓和糖果", "rect": Rect2(640, 238, 160, 82), "prop": "slingshot"},
			# 不起眼的小樹洞：湊近看會突臉
			{"id": "int_fen_knothole", "name": "樹洞", "rect": Rect2(112, 232, 40, 34), "prop": "knothole", "hidden": true},
		],
	},
	"mayor": {
		"name": "鎮長公館",
		"wall": Color("#3f5a45"), "wall2": Color("#4a6852"), "pattern": "diamond",
		"trim": Color("#c9a24a"), "floor": Color("#7a4e36"), "floor2": Color("#6a432e"),
		"dark": 0.15,
		"decor": [
			{"prop": "rug", "rect": Rect2(360, 580, 560, 110)},
			{"prop": "lamp", "rect": Rect2(610, 0, 70, 110)},
			{"prop": "table", "rect": Rect2(430, 520, 340, 110)},
		],
		"hotspots": [
			{"id": "int_mayor_portrait", "name": "鎮長的肖像畫", "rect": Rect2(525, 10, 245, 275), "prop": "portrait_bear"},
			{"id": "int_mayor_jars", "name": "糖果罐", "rect": Rect2(150, 120, 250, 96), "prop": "jars"},
			{"id": "int_mayor_rules", "name": "抽屜櫃", "rect": Rect2(95, 325, 300, 155), "prop": "cabinet"},
			{"id": "int_mayor_rollbook", "name": "點名簿", "rect": Rect2(580, 340, 125, 60), "prop": "rollbook"},
			{"id": "int_mayor_chalk", "name": "絨布盒子", "rect": Rect2(720, 315, 92, 82), "prop": "chalk_box"},
			{"id": "int_mayor_coat", "name": "衣架", "rect": Rect2(1130, 170, 140, 250), "prop": "coat"},
			# 牆角的老鼠洞：趴下來看會突臉
			{"id": "int_mayor_mousehole", "name": "老鼠洞", "rect": Rect2(1062, 448, 46, 50), "prop": "mousehole", "hidden": true},
		],
	},
	"mochi": {
		"name": "麻糬的小屋",
		"wall": Color("#fbe9d0"), "wall2": Color("#f6dcb8"), "pattern": "dots",
		"trim": Color("#c07a4f"), "floor": Color("#d6b28e"), "floor2": Color("#c49f7c"),
		"decor": [
			{"prop": "window", "rect": Rect2(560, 80, 200, 170)},
		],
		"hotspots": [
			{"id": "int_mochi_drawing", "name": "蠟筆畫", "rect": Rect2(45, 25, 305, 210), "prop": "family_drawing"},
			{"id": "int_mochi_lockers", "name": "置物櫃", "rect": Rect2(340, 270, 585, 112), "prop": "lockers"},
			{"id": "int_mochi_bed", "name": "床", "rect": Rect2(930, 70, 350, 470), "prop": "pillow_bed"},
			{"id": "int_mochi_paper", "name": "桌上的紙", "rect": Rect2(110, 285, 160, 66), "prop": "zhuyin_paper"},
			{"id": "int_mochi_drawer", "name": "抽屜", "rect": Rect2(135, 385, 110, 56), "prop": "drawer"},
		],
	},
	"tama": {
		"name": "小玉的小屋",
		"wall": Color("#e4ddf2"), "wall2": Color("#d6cdea"), "pattern": "stripes",
		"trim": Color("#5f5a8a"), "floor": Color("#cdb79c"), "floor2": Color("#bba488"),
		"decor": [
			{"prop": "window", "rect": Rect2(90, 90, 200, 170)},
			{"prop": "rug", "rect": Rect2(380, 600, 520, 90)},
			{"prop": "table", "rect": Rect2(440, 480, 420, 110)},
		],
		"hotspots": [
			{"id": "int_tama_awards", "name": "獎狀", "rect": Rect2(435, 0, 580, 265), "prop": "awards"},
			{"id": "int_tama_test", "name": "考卷", "rect": Rect2(575, 308, 185, 68), "prop": "test_paper"},
			{"id": "int_tama_pencils", "name": "鉛筆", "rect": Rect2(780, 268, 120, 82), "prop": "pencils"},
			{"id": "int_tama_trash", "name": "垃圾桶", "rect": Rect2(985, 405, 145, 165), "prop": "trash_stars"},
			{"id": "int_tama_badge", "name": "布做的徽章", "rect": Rect2(850, 343, 100, 48), "prop": "badge"},
		],
	},
	"station": {
		"name": "站務室",
		"wall": Color("#d9cbb8"), "wall2": Color("#cbbba5"), "pattern": "planks",
		"trim": Color("#4a2a32"), "floor": Color("#8f8478"), "floor2": Color("#7f756a"),
		"dark": 0.1,
		"decor": [
			{"prop": "window", "rect": Rect2(1000, 80, 200, 170)},
			{"prop": "counter", "rect": Rect2(300, 420, 640, 110)},
		],
		"hotspots": [
			{"id": "int_station_timetable", "name": "時刻表", "rect": Rect2(525, 15, 355, 240), "prop": "timetable"},
			{"id": "int_station_tickets", "name": "一疊車票", "rect": Rect2(475, 338, 102, 68), "prop": "tickets"},
			{"id": "int_station_docs", "name": "文件夾", "rect": Rect2(620, 358, 136, 62), "prop": "documents"},
			{"id": "int_station_lunch", "name": "便當盒", "rect": Rect2(795, 345, 160, 76), "prop": "lunchbox"},
			{"id": "int_station_cap", "name": "掛著的帽子", "rect": Rect2(900, 55, 82, 130), "prop": "cap"},
		],
	},
}

## 從地圖上哪個物件進去 → 哪個房間
const DOOR_TO_ROOM := {
	"lulu_house": "lulu",
	"popo_house": "popo",
	"fen_tree": "fen",
	"mayor_door": "mayor",
	"mochi_house": "mochi",
	"tama_house": "tama",
	"station_office": "station",
}
