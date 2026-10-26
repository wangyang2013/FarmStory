extends Node2D
class_name MapEntity
## 地图实体标记：建筑 / NPC / 设施 / 资源区。
## 挂到 Farm 下后自动加入 map_entities 组，由大地图与小地图统一读取。
## 规范见《全局地图系统规范.md》。

@export_enum("Building", "NPC", "Facility", "Resource") var entity_type: String = "Building"
@export var display_name: String = "未知目标"
@export_multiline var tooltip_desc: String = ""
@export var map_icon: Texture2D
@export var show_on_minimap: bool = true
@export var show_on_bigmap: bool = true
## 地图标签相对图标锚点的偏移（仅大地图使用）。
@export var label_offset: Vector2 = Vector2(7, 3)
## 是否绘制文字标签（出货箱等紧凑设施可关闭，靠悬停提示）。
@export var show_label: bool = true

## 动态状态：例如商店是否营业、NPC 是否在家。
var is_active := true


func _ready() -> void:
	add_to_group("map_entities")
