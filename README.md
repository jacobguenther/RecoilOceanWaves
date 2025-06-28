# Recoil Ocean Waves

This is a port of [Godot Ocean Waves](https://github.com/2Retr0/GodotOceanWaves) to [Recoil Engine](https://github.com/beyond-all-reason/RecoilEngine) games such as [Beyond All Reason](https://github.com/beyond-all-reason/Beyond-All-Reason), and [Zero-K](https://github.com/ZeroK-RTS/Zero-K).

screenshot here

## Install
* Open the install directory of your game
	* For BAR this can be done from the launcher
	* For Zero-K in Steam `right-click Zero-K->Properties->Installed Files->Browse`
* Navigate to LuaUI/Widgets
	* If the Widgets folder does not exist then create it(Note the capital W)
* Download the zip of this repository and put the contents of the zip archive in the Widgets folder
* In game you can enable this widget by pressing f11(Zero-K alt+F11)
	* Then either by searching for OceanWaves or scrolling to the bottom, select OceanWaves

## TextCommands
* `/oceanwaves ui` Enable/Disable the menu

## Settings
TODO
The settings menu does not work in Zero-K(for now) because it does not support rmlui the framework used to create it. Sorry.

### Material
TODO

### Wind
TODO

### Mesh/LOD
TODO

### Wave Resolution
The size of the spectrum, displacement, and normal maps used to generate the waves.

### Cascade
Refer to [Godot Ocean Waves](https://github.com/2Retr0/GodotOceanWaves)

#### Tile Length
How large of an area the wave resolution textures will be used on. Values larger than the wave resolution reduce the quality but are less noticable. Don't choose tile lengths that are multiples of your other tile lengths.

#### Wind Speed
In m/s

#### Wind Direction
In Degrees

#### Depth
In m (TODO)

#### Fetch Length
In km (TODO)

#### Swell
TODO

#### Spread
TODO

#### Detail
TODO

#### Whitecap
TODO

#### Foam Amount
TODO

## Development
Feedback is welcome!

If you find a bug or have a feature request let me know by opening an [issue](https://github.com/jacobguenther/RecoilOceanWaves/issues) or by finding the [post for this widget](https://discord.com/channels/549281623154229250/1113845509891829810/threads/1387909127233339482) on the [Beyond All Reason Discord](https://discord.com/invite/Q9MtKt48SX) and leave a comment.

## Roadmap

### UI Improvements
- [ ] Finish UI
- [X] Hookup change wave resolution
- [X] Fix Select/Option css
- [X] Fix Cascade button css
- [ ] Sliders where applicable
- [ ] Bound checking where applicable
- [ ] Configurable displacement falloff
- [ ] Mesh and LOD config
- [ ] Add tooltips
- [X] Text command enable/disable ui
- [X] Minimize/Close ui buttons
- [ ] ui mysteriously reopening [#2](/../../issues/2)

### Debug UI
- [X] disable displacement
- [X] primitive mode
- [ ] lod coloring
- [X] clipmap layer coloring
- [X] view various textures

### Map Settings
- [ ] Have cascade winds track map wind
- [ ] Use map gravity, normal or space/moon

### Settings
- [ ] Save settings
- [ ] Save settings per map
- [ ] Reset to default settings
- [ ] Text commands for all settings
	- [ ] material
	- [ ] Wind
	- [ ] Mesh
	- [ ] Waves
	- [ ] Debug
	- [ ] Saving/Loading

### Documentation
- [ ] Describe settings in this readme
- [ ] lua doc comments

### Preformance
- [ ] Use LOD for clipmap tiles
- [ ] CPU Culling of tiles
- [ ] GPU culling of tiles

### MVP Features/Bug Squashing
- [ ] Fix alpha blending between tiles [#1](/../../issues/1)
- [ ] Reduce foam with distance from camera
- [ ] Dampen displacement in shallow water
- [ ] Fix Subsurface color
- [ ] Verify shaders for AMD drivers

### Future Features
- [ ] Caustics
- [ ] Reflections
- [ ] Shore Foam
- [ ] Building Foam
- [ ] Unit Foam
- [ ] Unit Wakes
- [ ] Zero-K support
	- [X] It runs!
	- [ ] Add ui support (Chilli or wait for rmlui in Zero-K)
- [ ] GL3 support?

### Code Refactoring
- [ ] Decouple UI from widget

## License
All code(.lua, .glsl) files in this repository have the [GNU AGPLv3](LICENSE) license.

Some shaders have MIT license notices because significant portions of them where originally licensed under MIT but they are relicensed as AGPLv3.
