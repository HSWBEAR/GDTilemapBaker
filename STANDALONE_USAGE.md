# TileMap Baker Standalone Tool

Since you're experiencing issues with the plugin version, here's a standalone tool that you can use to bake a TileMap layer into a Sprite2D.

## How to Use the Standalone Tool

1. **Add the Script to Your Scene**:
   - Create a new Node in your scene (e.g., a Node or Node2D)
   - Attach the `tilemap_baker_tool.gd` script to this node

2. **Configure the Parameters**:
   - **TileMap Node Path**: Set this to the path of your TileMap node (e.g., "../TileMap")
   - **Layer Index**: Set this to the layer you want to bake (default is 0)
   - **Output Path**: Set this to where you want to save the PNG (e.g., "res://assets/baked_tilemap.png")
   - **Create Sprite**: Enable this if you want the tool to automatically create a Sprite2D node
   - **Sprite Parent Path**: Set this to the path of the node where you want the Sprite2D to be created (optional)

3. **Bake the TileMap**:
   - In the Inspector, you'll see a "Bake" section at the bottom
   - Check the "Bake Tilemap" checkbox to trigger the baking process
   - The tool will bake the TileMap layer and save it as a PNG file
   - If "Create Sprite" is enabled, it will also create a Sprite2D node with the baked texture

## Troubleshooting

If you encounter any issues:

1. **Check the Output Console**: The tool will print error messages to the console if something goes wrong
2. **Verify the TileMap Path**: Make sure the TileMap node path is correct
3. **Check the Layer Index**: Make sure the layer index exists in your TileMap
4. **Verify the Output Path**: Make sure the output directory exists and is writable

## How It Works

The tool works by:

1. Finding all used cells in the specified TileMap layer
2. Calculating the bounds of the TileMap
3. Creating a temporary viewport with the exact size needed
4. Rendering the TileMap into the viewport
5. Capturing the viewport as an image
6. Saving the image to the specified path
7. Optionally creating a Sprite2D node with the baked texture 
