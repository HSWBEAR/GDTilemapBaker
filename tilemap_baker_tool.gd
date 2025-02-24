@tool
extends Node

## A standalone tool script that can be attached to any node to bake a TileMapLayer to a sprite
## Usage: Attach this script to any node, then call bake_tilemap_to_sprite() from the editor

## The TileMapLayer to bake
@export var tilemap_layer_path: NodePath
## The output path for the PNG file
@export var output_path: String = "res://baked_tilemap.png"
## Whether to create a Sprite2D node automatically
@export var create_sprite: bool = true
## The parent node for the created Sprite2D
@export var sprite_parent_path: NodePath

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	
	if tilemap_layer_path.is_empty():
		warnings.append("TileMapLayer node path is not set")
	
	if output_path.is_empty():
		warnings.append("Output path is not set")
		
	return warnings

## Bakes the specified TileMapLayer to a PNG file and optionally creates a Sprite2D
func bake_tilemap_to_sprite() -> void:
	# Get the TileMapLayer node
	var tilemap_layer = get_node_or_null(tilemap_layer_path)
	if not tilemap_layer or not tilemap_layer is TileMapLayer:
		push_error("Invalid TileMapLayer path")
		return
	
	# Get the tile set from the TileMapLayer
	var tile_set = tilemap_layer.tile_set
	if not tile_set:
		push_error("TileMapLayer has no tile set")
		return
	
	# Get the used cells in the TileMapLayer
	var used_cells = tilemap_layer.get_used_cells()
	if used_cells.is_empty():
		push_error("No cells found in the TileMapLayer")
		return
	
	# Calculate the bounds of the TileMapLayer
	var min_pos = Vector2i(INF, INF)
	var max_pos = Vector2i(-INF, -INF)
	
	for cell_pos in used_cells:
		min_pos.x = min(min_pos.x, cell_pos.x)
		min_pos.y = min(min_pos.y, cell_pos.y)
		max_pos.x = max(max_pos.x, cell_pos.x)
		max_pos.y = max(max_pos.y, cell_pos.y)
	
	var tile_size = tile_set.tile_size
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
	temp_tilemap.tile_set = tile_set
	
	var temp_layer = TileMapLayer.new()
	temp_layer.tile_set = tile_set
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
		push_error("Failed to save image to " + output_path)
		return
	
	print("TileMapLayer baked successfully to " + output_path)
	
	# Create a Sprite2D node if requested
	if create_sprite:
		var sprite_parent = get_node_or_null(sprite_parent_path)
		if not sprite_parent:
			sprite_parent = get_parent()
		
		var sprite = Sprite2D.new()
		sprite.name = "BakedTileMap"
		sprite.texture = load(output_path)
		sprite.position = Vector2(min_pos.x * tile_size.x, min_pos.y * tile_size.y)
		
		sprite_parent.add_child(sprite)
		sprite.owner = get_tree().edited_scene_root
		
		print("Created Sprite2D node: " + sprite.name)

## Editor button to trigger the baking process
func _get_property_list() -> Array:
	var properties = []
	
	properties.append({
		"name": "Bake",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CATEGORY
	})
	
	properties.append({
		"name": "bake_tilemap",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NO_INSTANCE_STATE
	})
	
	return properties

func _set(property, value):
	if property == "bake_tilemap" and value:
		call_deferred("bake_tilemap_to_sprite")
		return true
	return false 