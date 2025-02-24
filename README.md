# TileMap Baker Plugin for Godot 4.4

A Godot plugin that allows you to easily convert a TileMap layer into a Sprite2D texture. The plugin appears in the bottom panel only when a TileMap or TileMapLayer node is selected.

## Features

- Context-sensitive bottom panel that only appears when a TileMap or TileMapLayer is selected
- Direct node selection through a visual node picker
- Automatic filename suggestion based on the selected node
- Simplified output path handling with separate folder selection and filename input
- Automatic .png extension handling
- Bake any TileMap layer into a PNG texture
- Automatically selects the correct layer when a TileMapLayer is selected
- Automatically calculates the bounds of the TileMap
- Preserves transparency
- Seamless integration with Godot's editor workflow

## Installation

1. Copy the `tilemap_baker` folder into your project's `addons` directory
2. Go to Project > Project Settings > Plugins
3. Enable the "TileMap Baker" plugin

## Usage

1. Select a TileMap node or a TileMapLayer node in your scene
2. The "TileMap Baker" panel will automatically appear in the bottom panel
3. If needed, click "Select Node" to choose a different TileMap or TileMapLayer
4. For TileMap nodes, select the layer index you want to bake
5. Click "Select Folder" to choose where to save the PNG file
6. Enter a filename (without extension) - it will automatically be saved as .png
7. Click "Bake TileMap to Sprite" to generate the sprite image

## How It Works

The plugin works by:

1. Finding all used cells in the specified TileMap layer
2. Calculating the bounds of the TileMap
3. Creating a temporary viewport with the exact size needed
4. Rendering the TileMap into the viewport
5. Capturing the viewport as an image
6. Saving the image to the specified path with .png extension


## Notes

- The plugin will automatically handle TileMap transformations and tile alternatives
- For large TileMaps, the baking process might take a moment to complete
- The plugin supports named TileMap layers in Godot 4.4
- When selecting a TileMapLayer node, the plugin will automatically select that layer

## License

This plugin is released under the MIT License.

