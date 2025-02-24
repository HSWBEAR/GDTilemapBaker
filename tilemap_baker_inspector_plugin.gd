@tool
extends EditorInspectorPlugin

var current_tilemap: TileMap
var current_tilemap_layer: TileMapLayer
var current_layer_index: int = -1
var output_dialog: ConfirmationDialog
var layer_option: OptionButton
var output_path: LineEdit
var create_sprite_checkbox: CheckBox
var baker_button: Button
var visible: bool = true

func _can_handle(object):
	# We'll handle TileMap and TileMapLayer objects
	if object is TileMap:
		return true
	
	# For TileMapLayer, we need to check the class name
	if object != null:
		var obj_class = ""
		if object.has_method("get_class"):
			obj_class = object.get_class()
		return obj_class == "TileMapLayer"
	
	return false

func _get_layer_node(tilemap: TileMap, layer_index: int) -> Node:
	if tilemap.has_method("get_layer_as_node"):
		return tilemap.get_layer_as_node(layer_index)
	return null

func _parse_category(object, category):
	# Only add our controls after all other categories
	if category != "":
		return
	
	# Check if we're dealing with a TileMap or TileMapLayer
	if object is TileMap:
		current_tilemap = object as TileMap
		current_tilemap_layer = null
		current_layer_index = -1
	elif object != null and object.get_class() == "TileMapLayer":
		# For TileMapLayer, we can work directly with it
		current_tilemap_layer = object
		var parent = object.get_parent()
		if parent != null and parent is TileMap:
			current_tilemap = parent
			# Find the layer index more safely
			var layer_index = -1
			if current_tilemap.has_method("get_layers_count"):
				for i in range(current_tilemap.get_layers_count()):
					if current_tilemap.has_method("get_layer_as_node"):
						var layer_node = current_tilemap.get_layer_as_node(i)
						if layer_node == current_tilemap_layer:
							layer_index = i
							break
			current_layer_index = layer_index
		else:
			current_tilemap = null
	else:
		# Not a TileMap or TileMapLayer
		current_tilemap = null
		current_tilemap_layer = null
	
	# Add a custom category
	var category_control = preload("res://addons/tilemap_baker/tilemap_baker_category.gd").new()
	category_control.set_category_name("TileMap Baker")
	add_custom_control(category_control)
	
	# Create a margin container for better spacing
	var margin_container = MarginContainer.new()
	var margin_v = 10
	margin_container.add_theme_constant_override("margin_left", 10)
	margin_container.add_theme_constant_override("margin_top", margin_v)
	margin_container.add_theme_constant_override("margin_right", 10)
	margin_container.add_theme_constant_override("margin_bottom", margin_v)
	add_custom_control(margin_container)
	
	# Create a VBox container for the button
	var vbox_container = VBoxContainer.new()
	margin_container.add_child(vbox_container)
	
	# If no TileMap or TileMapLayer is selected, show a message
	if not current_tilemap and not current_tilemap_layer:
		var info_label = Label.new()
		info_label.text = "Select a TileMap or TileMapLayer to enable baking"
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_container.add_child(info_label)
	
	# Add the baker button
	baker_button = Button.new()
	baker_button.text = "Bake to Sprite"
	baker_button.tooltip_text = "Bake the current TileMap layer to a Sprite"
	baker_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	baker_button.custom_minimum_size = Vector2(0, 50)
	baker_button.pressed.connect(_on_baker_button_pressed)
	baker_button.disabled = (current_tilemap == null and current_tilemap_layer == null)
	vbox_container.add_child(baker_button)
	
	# Create the output dialog if it doesn't exist
	if not output_dialog:
		create_output_dialog()
	elif current_tilemap:
		# Update the layer options
		update_layer_options()

func hide_baker_button():
	if baker_button:
		baker_button.disabled = true

func update_ui():
	if baker_button:
		baker_button.visible = true
		baker_button.disabled = (current_tilemap == null and current_tilemap_layer == null)
	
	if current_tilemap and layer_option:
		update_layer_options()

# Update the layer dropdown with current TileMap layers
func update_layer_options():
	if not current_tilemap or not layer_option:
		return
		
	layer_option.clear()
	
	var layer_count = current_tilemap.get_layers_count()
	for i in range(layer_count):
		var layer_name = "Layer " + str(i)
		# Try to get a more descriptive name if available
		if current_tilemap.has_method("get_layer_name") and not current_tilemap.get_layer_name(i).is_empty():
			layer_name = current_tilemap.get_layer_name(i)
		layer_option.add_item(layer_name, i)
	
	# Select the first layer by default or the current layer if set
	if layer_option.item_count > 0:
		if current_layer_index >= 0 and current_layer_index < layer_option.item_count:
			layer_option.select(current_layer_index)
		else:
			layer_option.select(0)
			current_layer_index = 0

func _on_baker_button_pressed():
	if not current_tilemap and not current_tilemap_layer:
		show_message("Please select a TileMap or TileMapLayer first")
		return
		
	# Set default output path if empty
	if output_path.text.is_empty():
		var scene_root = current_tilemap_layer.get_tree().edited_scene_root if current_tilemap_layer else current_tilemap.get_tree().edited_scene_root
		var scene_path = scene_root.scene_file_path
		var dir_path = scene_path.get_base_dir()
		var file_name = scene_path.get_file().get_basename() + "_tilemap.png"
		output_path.text = dir_path + "/" + file_name
	
	# If we're working with a TileMapLayer directly, hide the layer selection
	if current_tilemap_layer and not current_tilemap:
		layer_option.get_parent().get_parent().visible = false
	else:
		layer_option.get_parent().get_parent().visible = true
	
	# Show the dialog
	popup_output_dialog()

func popup_output_dialog():
	if output_dialog:
		output_dialog.popup_centered()

func create_output_dialog():
	output_dialog = ConfirmationDialog.new()
	output_dialog.title = "Bake TileMap to Sprite"
	output_dialog.size = Vector2(400, 200)
	output_dialog.confirmed.connect(_on_bake_confirmed)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	output_dialog.add_child(vbox)
	
	# Layer selection
	var layer_hbox = HBoxContainer.new()
	vbox.add_child(layer_hbox)
	
	var layer_label = Label.new()
	layer_label.text = "Layer:"
	layer_hbox.add_child(layer_label)
	
	layer_option = OptionButton.new()
	layer_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_hbox.add_child(layer_option)
	
	# Output path
	var path_hbox = HBoxContainer.new()
	vbox.add_child(path_hbox)
	
	var path_label = Label.new()
	path_label.text = "Output Path:"
	path_hbox.add_child(path_label)
	
	output_path = LineEdit.new()
	output_path.placeholder_text = "res://assets/baked_tilemap.png"
	output_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_hbox.add_child(output_path)
	
	# Create sprite option
	var sprite_hbox = HBoxContainer.new()
	vbox.add_child(sprite_hbox)
	
	var sprite_label = Label.new()
	sprite_label.text = "Create Sprite2D:"
	sprite_hbox.add_child(sprite_label)
	
	create_sprite_checkbox = CheckBox.new()
	create_sprite_checkbox.button_pressed = true
	sprite_hbox.add_child(create_sprite_checkbox)
	
	# Add the dialog to the editor
	var editor_interface = EditorScript.new().get_editor_interface()
	editor_interface.get_base_control().add_child(output_dialog)
	
	# Update layer options
	update_layer_options()

func _on_bake_confirmed():
	if not current_tilemap and not current_tilemap_layer:
		return
	
	var out_path = output_path.text
	var create_sprite = create_sprite_checkbox.button_pressed
	
	# Validate output path
	if out_path.is_empty():
		show_error("Output path cannot be empty")
		return
	
	if not out_path.ends_with(".png"):
		out_path += ".png"
		output_path.text = out_path
	
	# Bake the TileMap or TileMapLayer
	var result = false
	if current_tilemap_layer and not current_tilemap:
		# Bake the TileMapLayer directly
		result = bake_tilemap_layer_direct(current_tilemap_layer, out_path, create_sprite)
	else:
		# Bake the TileMap layer
		var layer_index = layer_option.get_selected_id()
		result = bake_tilemap_layer(current_tilemap, layer_index, out_path, create_sprite)
	
	if result:
		show_message("TileMap baked successfully to " + out_path)
	else:
		show_error("Failed to bake TileMap")

func bake_tilemap_layer(tilemap: TileMap, layer_index: int, output_path: String, create_sprite: bool) -> bool:
	# Get the used cells in the specified layer
	var used_cells = tilemap.get_used_cells(layer_index)
	if used_cells.is_empty():
		show_error("No cells found in the specified layer")
		return false
	
	# Calculate the bounds of the TileMap
	var min_pos = Vector2i(INF, INF)
	var max_pos = Vector2i(-INF, -INF)
	
	for cell_pos in used_cells:
		min_pos.x = min(min_pos.x, cell_pos.x)
		min_pos.y = min(min_pos.y, cell_pos.y)
		max_pos.x = max(max_pos.x, cell_pos.x)
		max_pos.y = max(max_pos.y, cell_pos.y)
	
	var tile_size = tilemap.tile_set.tile_size
	var map_width = (max_pos.x - min_pos.x + 1) * tile_size.x
	var map_height = (max_pos.y - min_pos.y + 1) * tile_size.y
	
	# Create a new image with the calculated size
	var image = Image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Transparent background
	
	# Create a temporary viewport to render the TileMap
	var viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.size = Vector2(map_width, map_height)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Create a temporary TileMap and TileMapLayer to render
	var temp_tilemap = TileMap.new()
	temp_tilemap.tile_set = tilemap.tile_set
	
	var temp_layer = TileMapLayer.new()
	temp_layer.tile_set = tilemap.tile_set
	temp_layer.position = Vector2(-min_pos.x * tile_size.x, -min_pos.y * tile_size.y)
	temp_tilemap.add_child(temp_layer)
	
	# Copy the cells from the original TileMap
	for cell_pos in used_cells:
		var source_id = tilemap.get_cell_source_id(layer_index, cell_pos)
		var atlas_coords = tilemap.get_cell_atlas_coords(layer_index, cell_pos)
		var alternative_tile = tilemap.get_cell_alternative_tile(layer_index, cell_pos)
		temp_layer.set_cell(cell_pos, source_id, atlas_coords, alternative_tile)
	
	# Add the TileMap to the viewport
	viewport.add_child(temp_tilemap)
	
	# Add the viewport to the scene tree temporarily
	var editor_interface = EditorScript.new().get_editor_interface()
	editor_interface.get_base_control().add_child(viewport)
	
	# Wait for the viewport to render (using a timer instead of await)
	var timer = Timer.new()
	editor_interface.get_base_control().add_child(timer)
	timer.wait_time = 0.1
	timer.one_shot = true
	timer.start()
	
	# Use a signal connection instead of await
	timer.timeout.connect(func():
		# Get the image from the viewport
		var viewport_texture = viewport.get_texture()
		var viewport_image = viewport_texture.get_image()
		
		# Copy the viewport image to our image
		image.blit_rect(viewport_image, Rect2(0, 0, map_width, map_height), Vector2(0, 0))
		
		# Clean up
		viewport.queue_free()
		timer.queue_free()
		
		# Save the image
		var error = image.save_png(output_path)
		if error != OK:
			show_error("Failed to save image to " + output_path)
			return
		
		# Create a Sprite2D node if requested
		if create_sprite:
			var sprite = Sprite2D.new()
			
			# Try to use a more descriptive name if layer name is available
			var layer_name = ""
			if tilemap.has_method("get_layer_name") and not tilemap.get_layer_name(layer_index).is_empty():
				layer_name = tilemap.get_layer_name(layer_index)
				sprite.name = "BakedTileMap_" + layer_name
			else:
				sprite.name = "BakedTileMap_Layer" + str(layer_index)
				
			sprite.texture = load(output_path)
			sprite.position = Vector2(min_pos.x * tile_size.x, min_pos.y * tile_size.y)
			
			# Add the sprite to the scene
			var parent = tilemap.get_parent()
			parent.add_child(sprite)
			
			# Get the edited scene root from the editor interface
			var edited_scene_root = editor_interface.get_edited_scene_root()
			sprite.owner = edited_scene_root
			
			# Update the editor
			editor_interface.get_selection().clear()
			editor_interface.get_selection().add_node(sprite)
			
			show_message("Created Sprite2D node: " + sprite.name)
	)
	
	return true

func bake_tilemap_layer_direct(tilemap_layer: TileMapLayer, output_path: String, create_sprite: bool) -> bool:
	# Get the used cells in the TileMapLayer
	var used_cells = tilemap_layer.get_used_cells()
	if used_cells.is_empty():
		show_error("No cells found in the TileMapLayer")
		return false
	
	# Calculate the bounds of the TileMapLayer
	var min_pos = Vector2i(INF, INF)
	var max_pos = Vector2i(-INF, -INF)
	
	for cell_pos in used_cells:
		min_pos.x = min(min_pos.x, cell_pos.x)
		min_pos.y = min(min_pos.y, cell_pos.y)
		max_pos.x = max(max_pos.x, cell_pos.x)
		max_pos.y = max(max_pos.y, cell_pos.y)
	
	var tile_size = tilemap_layer.tile_set.tile_size
	var map_width = (max_pos.x - min_pos.x + 1) * tile_size.x
	var map_height = (max_pos.y - min_pos.y + 1) * tile_size.y
	
	# Create a new image with the calculated size
	var image = Image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Transparent background
	
	# Create a temporary viewport to render the TileMap
	var viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.size = Vector2(map_width, map_height)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Create a temporary TileMap and TileMapLayer to render
	var temp_tilemap = TileMap.new()
	temp_tilemap.tile_set = tilemap_layer.tile_set
	
	var temp_layer = TileMapLayer.new()
	temp_layer.tile_set = tilemap_layer.tile_set
	temp_layer.position = Vector2(-min_pos.x * tile_size.x, -min_pos.y * tile_size.y)
	temp_tilemap.add_child(temp_layer)
	
	# Copy the cells from the original TileMapLayer
	for cell_pos in used_cells:
		var source_id = tilemap_layer.get_cell_source_id(cell_pos)
		var atlas_coords = tilemap_layer.get_cell_atlas_coords(cell_pos)
		var alternative_tile = tilemap_layer.get_cell_alternative_tile(cell_pos)
		temp_layer.set_cell(cell_pos, source_id, atlas_coords, alternative_tile)
	
	# Add the TileMap to the viewport
	viewport.add_child(temp_tilemap)
	
	# Add the viewport to the scene tree temporarily
	var editor_interface = EditorScript.new().get_editor_interface()
	editor_interface.get_base_control().add_child(viewport)
	
	# Wait for the viewport to render (using a timer instead of await)
	var timer = Timer.new()
	editor_interface.get_base_control().add_child(timer)
	timer.wait_time = 0.1
	timer.one_shot = true
	timer.start()
	
	# Use a signal connection instead of await
	timer.timeout.connect(func():
		# Get the image from the viewport
		var viewport_texture = viewport.get_texture()
		var viewport_image = viewport_texture.get_image()
		
		# Copy the viewport image to our image
		image.blit_rect(viewport_image, Rect2(0, 0, map_width, map_height), Vector2(0, 0))
		
		# Clean up
		viewport.queue_free()
		timer.queue_free()
		
		# Save the image
		var error = image.save_png(output_path)
		if error != OK:
			show_error("Failed to save image to " + output_path)
			return
		
		# Create a Sprite2D node if requested
		if create_sprite:
			var sprite = Sprite2D.new()
			
			# Use the TileMapLayer name if available
			var layer_name = tilemap_layer.name
			sprite.name = "BakedTileMap_" + layer_name
				
			sprite.texture = load(output_path)
			sprite.position = Vector2(min_pos.x * tile_size.x, min_pos.y * tile_size.y)
			
			# Add the sprite to the scene
			var parent = tilemap_layer.get_parent().get_parent()
			parent.add_child(sprite)
			
			# Get the edited scene root from the editor interface
			var edited_scene_root = editor_interface.get_edited_scene_root()
			sprite.owner = edited_scene_root
			
			# Update the editor
			editor_interface.get_selection().clear()
			editor_interface.get_selection().add_node(sprite)
			
			show_message("Created Sprite2D node: " + sprite.name)
	)
	
	return true

func show_error(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = message
	dialog.size = Vector2(300, 100)
	var editor_interface = EditorScript.new().get_editor_interface()
	editor_interface.get_base_control().add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func show_message(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Success"
	dialog.dialog_text = message
	dialog.size = Vector2(300, 100)
	var editor_interface = EditorScript.new().get_editor_interface()
	editor_interface.get_base_control().add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free()) 