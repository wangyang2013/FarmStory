extends Node
## 启动时加载只读配置（Autoload：ConfigBootstrap）。
## 游戏逻辑不直接读 JSON，统一走 ConfigDB。

const DB := preload("res://scripts/core/ConfigDB.gd")


func _ready() -> void:
	var ok := DB.load_all()
	if not ok:
		push_error("[ConfigBootstrap] 配置加载失败，请检查 res://config/ 下的 JSON 文件。")
		return

	var problems := DB.validate()
	for message: String in problems:
		push_warning("[ConfigBootstrap] " + message)
