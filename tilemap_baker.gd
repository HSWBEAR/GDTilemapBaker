@tool
extends EditorPlugin

var inspector_plugin
var dock
var current_selection_is_valid = false
var bottom_panel_button = null

func _enter_tree():
	# Add the inspector plugin
	inspector_plugin = load("res://addons/tilemap_baker/tilemap_baker_inspector_plugin.gd").new()
	add_inspector_plugin(inspector_plugin)
	
	# Add the dock
	dock = preload("res://addons/tilemap_baker/tilemap_baker_dock.tscn").instantiate()
	
	# Make sure to call setup after the dock is fully initialized
	call_deferred("_setup_dock")
	
	# Add the dock to the editor - but don't make it visible yet
	bottom_panel_button = add_control_to_bottom_panel(dock, "TileMap Baker")
	
	# Initially hide the bottom panel button
	if bottom_panel_button:
		bottom_panel_button.hide()
	
	# Connect to the selection changed signal
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)

# Setup the dock with the editor interface after it's fully initialized
func _setup_dock():
	if dock and is_instance_valid(dock):
		dock.setup(get_editor_interface())

func _exit_tree():
	# Disconnect from the selection changed signal
	if get_editor_interface().get_selection().selection_changed.is_connected(_on_selection_changed):
		get_editor_interface().get_selection().selection_changed.disconnect(_on_selection_changed)
	
	# Remove the dock
	if dock and is_instance_valid(dock):
		remove_control_from_bottom_panel(dock)
		dock.free()
	
	# Remove the inspector plugin
	if inspector_plugin:
		remove_inspector_plugin(inspector_plugin)

func _handles(object):
	if object is TileMap:
		return true
	
	# For TileMapLayer, we need to check the class name
	if object != null:
		var obj_class = ""
		if object.has_method("get_class"):
			obj_class = object.get_class()
		return obj_class == "TileMapLayer"
	
	return false

func _make_visible(visible):
	if inspector_plugin:
		inspector_plugin.visible = visible

func _on_selection_changed() -> void:
	# Get the selected nodes
	var selected = get_editor_interface().get_selection().get_selected_nodes()
	
	# Check if a TileMap or TileMapLayer is selected
	if selected.size() == 1:
		var node = selected[0]
		
		if node is TileMap or (node != null and node.has_method("get_class") and node.get_class() == "TileMapLayer"):
			# Show the bottom panel button
			if bottom_panel_button and not current_selection_is_valid:
				bottom_panel_button.show()
				current_selection_is_valid = true
			
			# Auto-select the node in our dock
			if dock and is_instance_valid(dock):
				# Call the internal method to simulate node selection
				dock.select_node(node)
				
			# Also update the inspector plugin if needed
			if inspector_plugin:
				if node is TileMap:
					inspector_plugin.current_tilemap = node
					inspector_plugin.current_tilemap_layer = null
					inspector_plugin.current_layer_index = -1
				elif node.get_class() == "TileMapLayer":
					inspector_plugin.current_tilemap_layer = node
					
					# Also get the parent TileMap if available
					var parent = node.get_parent()
					if parent != null and parent is TileMap:
						inspector_plugin.current_tilemap = parent
						
						# Find the layer index safely
						var layer_index = -1
						if parent.has_method("get_layers_count"):
							for i in range(parent.get_layers_count()):
								if parent.has_method("get_layer_as_node"):
									var layer_node = parent.get_layer_as_node(i)
									if layer_node == node:
										layer_index = i
										break
						
						inspector_plugin.current_layer_index = layer_index
					else:
						inspector_plugin.current_tilemap = null
				
				inspector_plugin.update_ui()
		else:
			# Not a TileMap or TileMapLayer, hide the panel button
			if bottom_panel_button and current_selection_is_valid:
				bottom_panel_button.hide()
				current_selection_is_valid = false
			
			# Not a TileMap or TileMapLayer
			if inspector_plugin:
				inspector_plugin.current_tilemap = null
				inspector_plugin.current_tilemap_layer = null
				inspector_plugin.hide_baker_button()
	else:
		# Multiple or no selection, hide the panel button
		if bottom_panel_button and current_selection_is_valid:
			bottom_panel_button.hide()
			current_selection_is_valid = false
		
		# Multiple or no selection
		if inspector_plugin:
			inspector_plugin.current_tilemap = null
			inspector_plugin.current_tilemap_layer = null
			inspector_plugin.hide_baker_button()

# Helper function to get the path to a selected node
func get_path_to_selected_node(node: Node) -> String:
	var edited_scene_root = get_editor_interface().get_edited_scene_root()
	if edited_scene_root:
		return edited_scene_root.get_path_to(node)
	return ""

func _create_output_dialog() -> void:
	if inspector_plugin:
		inspector_plugin.create_output_dialog()

func _on_baker_button_pressed() -> void:
	if inspector_plugin and (inspector_plugin.current_tilemap or inspector_plugin.current_tilemap_layer):
		# Show the dialog
		inspector_plugin.popup_output_dialog()

func _on_bake_confirmed() -> void:
	if not inspector_plugin or (not inspector_plugin.current_tilemap and not inspector_plugin.current_tilemap_layer):
		return
	
	var out_path = inspector_plugin.output_path.text
	var create_sprite = inspector_plugin.create_sprite_checkbox.button_pressed
	
	# Validate output path
	if out_path.is_empty():
		inspector_plugin.show_error("Output path cannot be empty")
		return
	
	if not out_path.ends_with(".png"):
		out_path += ".png"
		inspector_plugin.output_path.text = out_path
	
	# Bake the TileMap or TileMapLayer
	var result = false
	if inspector_plugin.current_tilemap_layer and not inspector_plugin.current_tilemap:
		# Bake the TileMapLayer directly
		result = inspector_plugin.bake_tilemap_layer_direct(inspector_plugin.current_tilemap_layer, out_path, create_sprite)
	else:
		# Bake the TileMap layer
		var layer_index = inspector_plugin.layer_option.get_selected_id()
		result = inspector_plugin.bake_tilemap_layer(inspector_plugin.current_tilemap, layer_index, out_path, create_sprite)
	
	if result:
		inspector_plugin.show_message("TileMap baked successfully to " + out_path)
	else:
		inspector_plugin.show_error("Failed to bake TileMap")

func _show_error(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = message
	dialog.size = Vector2(300, 100)
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _show_message(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Success"
	dialog.dialog_text = message
	dialog.size = Vector2(300, 100)
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _get_layer_node(tilemap: TileMap, layer_index: int) -> Node:
	if tilemap == null:
		return null
		
	if not tilemap.has_method("get_layer_as_node"):
		return null
		
	# Make sure the layer index is valid
	if not tilemap.has_method("get_layers_count"):
		return null
		
	if layer_index < 0 or layer_index >= tilemap.get_layers_count():
		return null
		
	return tilemap.get_layer_as_node(layer_index) 