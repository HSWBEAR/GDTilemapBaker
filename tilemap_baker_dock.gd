@tool
extends Control

# UI elements
var tilemap_path_edit: LineEdit
var select_node_button: Button
var layer_spinbox: SpinBox
var output_path_edit: LineEdit
var browse_button: Button
var bake_button: Button
var status_label: Label
var filename_edit: LineEdit
var folder_path_label: Label

# Editor reference
var editor_interface: EditorInterface
var editor_file_system: EditorFileSystem
var selected_node: Node
var selected_folder_path: String = "res://"

# Node selection dialog
var node_selection_dialog: ConfirmationDialog
var node_tree: Tree

func _ready():
	# Get UI elements
	tilemap_path_edit = $MarginContainer/VBoxContainer/MainContainer/TileMapPathContainer/HBoxContainer/TileMapPath
	select_node_button = $MarginContainer/VBoxContainer/MainContainer/TileMapPathContainer/HBoxContainer/SelectNodeButton
	layer_spinbox = $MarginContainer/VBoxContainer/MainContainer/LayerContainer/LayerSpinBox
	output_path_edit = $MarginContainer/VBoxContainer/MainContainer/OutputPathContainer/HBoxContainer/OutputPath
	browse_button = $MarginContainer/VBoxContainer/MainContainer/OutputPathContainer/HBoxContainer/BrowseButton
	bake_button = $MarginContainer/VBoxContainer/MainContainer/ActionContainer/BakeButton
	status_label = $MarginContainer/VBoxContainer/StatusContainer/StatusLabel
	folder_path_label = $MarginContainer/VBoxContainer/MainContainer/OutputPathContainer/FolderPathLabel
	filename_edit = $MarginContainer/VBoxContainer/MainContainer/OutputPathContainer/HBoxContainer/OutputPath
	
	# Connect signals
	select_node_button.pressed.connect(_on_select_node_button_pressed)
	browse_button.pressed.connect(_on_browse_button_pressed)
	bake_button.pressed.connect(_on_bake_button_pressed)
	
	# Set default output path
	selected_folder_path = "res://"
	folder_path_label.text = "Folder: " + selected_folder_path
	filename_edit.placeholder_text = "Enter filename (without extension)"
	filename_edit.text = "baked_tilemap"
	
	# Create node selection dialog
	_create_node_selection_dialog()
	
	# Initialize status
	_show_status("Ready", false)

# Set the editor interface reference
func setup(editor_interface_ref: EditorInterface):
	if editor_interface_ref:
		editor_interface = editor_interface_ref
		editor_file_system = editor_interface.get_resource_filesystem()

func _create_node_selection_dialog():
	# Create the dialog
	node_selection_dialog = ConfirmationDialog.new()
	node_selection_dialog.title = "Select TileMap or TileMapLayer Node"
	node_selection_dialog.size = Vector2(400, 500)
	node_selection_dialog.confirmed.connect(_on_node_selected)
	
	# Create a VBox container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	node_selection_dialog.add_child(vbox)
	
	# Add a label
	var label = Label.new()
	label.text = "Select a TileMap or TileMapLayer node:"
	vbox.add_child(label)
	
	# Create the tree
	node_tree = Tree.new()
	node_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node_tree.select_mode = Tree.SELECT_SINGLE
	node_tree.hide_root = true
	vbox.add_child(node_tree)
	
	# Add the dialog to the editor
	add_child(node_selection_dialog)

func _on_select_node_button_pressed():
	# Populate the tree with scene nodes
	_populate_node_tree()
	
	# Show the dialog
	node_selection_dialog.popup_centered()

func _populate_node_tree():
	# Clear the tree
	node_tree.clear()
	
	# Get the edited scene root
	var edited_scene_root = editor_interface.get_edited_scene_root()
	if not edited_scene_root:
		return
	
	# Create the root item
	var root = node_tree.create_item()
	
	# Add the scene root
	var scene_item = node_tree.create_item(root)
	scene_item.set_text(0, edited_scene_root.name)
	scene_item.set_metadata(0, edited_scene_root)
	
	# Add all child nodes recursively
	_add_children_to_tree(edited_scene_root, scene_item)

func _add_children_to_tree(node: Node, parent_item: TreeItem):
	for child in node.get_children():
		var item = node_tree.create_item(parent_item)
		item.set_text(0, child.name)
		item.set_metadata(0, child)
		
		# Highlight TileMap and TileMapLayer nodes
		if child is TileMap:
			item.set_custom_color(0, Color(0.2, 0.8, 0.2))
		elif child.has_method("get_class") and child.get_class() == "TileMapLayer":
			item.set_custom_color(0, Color(0.2, 0.8, 0.8))
		
		# Add children recursively
		_add_children_to_tree(child, item)

func _on_node_selected():
	# Get the selected item
	var selected_item = node_tree.get_selected()
	if not selected_item:
		return
	
	# Get the node from the item metadata
	var node = selected_item.get_metadata(0)
	if not node:
		return
	
	# Check if it's a TileMap or TileMapLayer
	var is_tilemap = node is TileMap
	var is_tilemap_layer = false
	
	if not is_tilemap and node.has_method("get_class"):
		is_tilemap_layer = node.get_class() == "TileMapLayer"
	
	if not is_tilemap and not is_tilemap_layer:
		_show_status("Error: Selected node is not a TileMap or TileMapLayer", true)
		return
	
	# Store the selected node
	selected_node = node
	
	# Update the path edit
	var edited_scene_root = editor_interface.get_edited_scene_root()
	if edited_scene_root:
		tilemap_path_edit.text = edited_scene_root.get_path_to(node)
	
	# Update layer spinbox visibility
	$MarginContainer/VBoxContainer/MainContainer/LayerContainer.visible = is_tilemap
	
	# If it's a TileMapLayer, try to find its layer index
	if is_tilemap_layer:
		var parent = node.get_parent()
		if parent and parent is TileMap:
			var layer_index = -1
			
			if parent.has_method("get_layers_count"):
				for i in range(parent.get_layers_count()):
					if parent.has_method("get_layer_as_node"):
						var layer_node = parent.get_layer_as_node(i)
						if layer_node == node:
							layer_index = i
							break
			
			if layer_index >= 0:
				layer_spinbox.value = layer_index
	
	# Update the status
	_show_status("Node selected: " + node.name, false)
	
	# Set default filename based on node name
	filename_edit.text = node.name.to_lower() + "_tilemap"

func _on_browse_button_pressed():
	# Create a file dialog for folder selection
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.current_dir = selected_folder_path
	
	# Connect the folder selected signal
	file_dialog.dir_selected.connect(func(path):
		selected_folder_path = path
		folder_path_label.text = "Folder: " + selected_folder_path
		file_dialog.queue_free()
	)
	
	# Connect the canceled signal
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)
	
	# Add the dialog to the editor and show it
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2(800, 600))

func _on_bake_button_pressed():
	# Disable the button while processing
	bake_button.disabled = true
	_show_status("Processing...", false)
	
	# Validate input
	if not selected_node:
		_show_status("Error: No TileMap or TileMapLayer selected", true)
		bake_button.disabled = false
		return
	
	var filename = filename_edit.text.strip_edges()
	if filename.is_empty():
		_show_status("Error: Filename cannot be empty", true)
		bake_button.disabled = false
		return
	
	# Remove any extension from the filename if the user added one
	if filename.get_extension() != "":
		filename = filename.get_basename()
	
	# Construct the full output path
	var output_path = selected_folder_path.path_join(filename + ".png")
	
	# Check if it's a TileMap or TileMapLayer
	var is_tilemap = selected_node is TileMap
	var is_tilemap_layer = false
	if not is_tilemap:
		# Check if it's a TileMapLayer
		if selected_node.has_method("get_class"):
			is_tilemap_layer = selected_node.get_class() == "TileMapLayer"
	
	if not is_tilemap and not is_tilemap_layer:
		_show_status("Error: Selected node is not a TileMap or TileMapLayer", true)
		bake_button.disabled = false
		return
	
	# Bake the TileMap or TileMapLayer
	_process_baking(selected_node, is_tilemap, output_path)

# Process the baking in a separate function to handle coroutines properly
func _process_baking(node, is_tilemap: bool, output_path: String):
	var result = false
	
	if is_tilemap:
		var layer_index = int(layer_spinbox.value)
		result = await bake_tilemap_layer(node, layer_index, output_path)
	else:
		result = await bake_tilemap_layer_direct(node, output_path)
	
	if result:
		_show_status("Success: TileMap baked to " + output_path, false)
		# Refresh the filesystem if available
		if editor_file_system:
			editor_file_system.scan()
	else:
		_show_status("Error: Failed to bake TileMap", true)
	
	# Re-enable the button
	bake_button.disabled = false

func bake_tilemap_layer(tilemap: TileMap, layer_index: int, output_path: String) -> bool:
	# Get the used cells in the specified layer
	var used_cells = tilemap.get_used_cells(layer_index)
	if used_cells.is_empty():
		_show_status("Error: No cells found in the specified layer", true)
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
	add_child(viewport)
	
	# Wait for the viewport to render
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get the image from the viewport
	var viewport_texture = viewport.get_texture()
	var viewport_image = viewport_texture.get_image()
	
	# Copy the viewport image to our image
	image.blit_rect(viewport_image, Rect2(0, 0, map_width, map_height), Vector2(0, 0))
	
	# Clean up
	viewport.queue_free()
	
	# Save the image
	var error = image.save_png(output_path)
	if error != OK:
		_show_status("Error: Failed to save image to " + output_path, true)
		return false
	
	return true

func bake_tilemap_layer_direct(tilemap_layer: Node, output_path: String) -> bool:
	# Get the used cells in the TileMapLayer
	var used_cells = tilemap_layer.get_used_cells()
	if used_cells.is_empty():
		_show_status("Error: No cells found in the TileMapLayer", true)
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
	add_child(viewport)
	
	# Wait for the viewport to render
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get the image from the viewport
	var viewport_texture = viewport.get_texture()
	var viewport_image = viewport_texture.get_image()
	
	# Copy the viewport image to our image
	image.blit_rect(viewport_image, Rect2(0, 0, map_width, map_height), Vector2(0, 0))
	
	# Clean up
	viewport.queue_free()
	
	# Save the image
	var error = image.save_png(output_path)
	if error != OK:
		_show_status("Error: Failed to save image to " + output_path, true)
		return false
	
	return true

func _show_status(message: String, is_error: bool):
	status_label.text = message
	if is_error:
		status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		status_label.remove_theme_color_override("font_color")

# Method to handle node selection from the editor
func select_node(node: Node):
	if not node:
		return
		
	# Check if it's a TileMap or TileMapLayer
	var is_tilemap = node is TileMap
	var is_tilemap_layer = false
	
	if not is_tilemap and node.has_method("get_class"):
		is_tilemap_layer = node.get_class() == "TileMapLayer"
	
	if not is_tilemap and not is_tilemap_layer:
		return
	
	# Store the selected node
	selected_node = node
	
	# Update the path edit
	var edited_scene_root = editor_interface.get_edited_scene_root()
	if edited_scene_root:
		tilemap_path_edit.text = edited_scene_root.get_path_to(node)
	
	# Update layer spinbox visibility
	$MarginContainer/VBoxContainer/MainContainer/LayerContainer.visible = is_tilemap
	
	# If it's a TileMapLayer, try to find its layer index
	if is_tilemap_layer:
		var parent = node.get_parent()
		if parent and parent is TileMap:
			var layer_index = -1
			
			if parent.has_method("get_layers_count"):
				for i in range(parent.get_layers_count()):
					if parent.has_method("get_layer_as_node"):
						var layer_node = parent.get_layer_as_node(i)
						if layer_node == node:
							layer_index = i
							break
			
			if layer_index >= 0:
				layer_spinbox.value = layer_index
	
	# Set default filename based on node name
	filename_edit.text = node.name.to_lower() + "_tilemap"
	
	# Update the status
	_show_status("Node selected: " + node.name, false) 