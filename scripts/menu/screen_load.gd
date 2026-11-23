class_name ScreenLoad
extends Control
## Save slots.

@export var router: MenuRouter

const SLOTS := 5
var _list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 140)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)
	var column := UiKit.vbox(12)
	margin.add_child(column)
	var head := UiKit.hbox(12)
	var back := UiKit.button("‹ Back")
	back.pressed.connect(router.back)
	head.add_child(back)
	head.add_child(UiKit.label("Load game", 30, Color.WHITE))
	column.add_child(head)
	_list = UiKit.vbox(10)
	column.add_child(_list)


func on_show() -> void:
	for child in _list.get_children():
		child.queue_free()
	for slot in range(1, SLOTS + 1):
		var info := Config.slot_info(slot)
		var card := UiKit.panel("Card")
		var row := UiKit.hbox(14)
		card.add_child(UiKit.margin(row, 14))
		var text := UiKit.vbox(2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(UiKit.label("Slot %d" % slot, 18, Color.WHITE))
		if info.is_empty():
			text.add_child(UiKit.label("Empty", 14, Neon.TEXT_DIM))
		else:
			text.add_child(UiKit.label("%s · round %d · saved %s" % [Sim.MODE_NAMES[int(info.mode)], int(info.round), info.saved], 14, Neon.TEXT_MUTED))
		row.add_child(text)
		var load_button := UiKit.button("Load", "AccentButton")
		load_button.disabled = info.is_empty()
		load_button.pressed.connect(func() -> void:
			Config.load_pending = str(slot)
			Sfx.play_ui("ui_load")
			get_tree().change_scene_to_file("res://scenes/game/game.tscn"))
		row.add_child(load_button)
		var delete := UiKit.button("Delete", "DangerButton")
		delete.disabled = info.is_empty()
		delete.pressed.connect(func() -> void:
			DirAccess.remove_absolute(Config.save_path(slot))
			on_show())
		row.add_child(delete)
		_list.add_child(card)
