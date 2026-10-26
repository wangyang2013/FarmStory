extends SceneTree
var frames := 0
var farm: Node
func _initialize() -> void:
	farm = load("res://scenes/Farm.tscn").instantiate()
	root.add_child(farm)
func _process(_d: float) -> bool:
	frames += 1
	if frames == 10:
		print("modal before=", farm.ui.get_modal(), " open=", farm.ui.is_modal_open())
		farm.ui.open_storage("storage")
		print("modal after=", farm.ui.get_modal(), " visible=", farm.ui.storage_panel.visible if farm.ui.storage_panel != null else "null")
		print("panel size=", farm.ui.storage_panel.get_child(0).size if farm.ui.storage_panel != null and farm.ui.storage_panel.get_child_count() > 0 else "n/a")
		quit(0)
	return false
