# godot-volumetric-clouds

A customizable addon for volumetric clouds in Godot using a raymarching shader.

__Not ready for production.__ Needs quite some optimization and bugfixing.

![Screenshots: Clouds in editor](https://github.com/kb173/godot-volumetric-clouds/blob/master/screenshot.png)

## Features

- Volumetric clouds which can be viewed from below, within and above
- Lighting calculation based on physical reality
- Clouds are within a curved atmosphere appropriate for the earth's curvature
  - This atmosphere can be moved to create other effects such as fog
- Weather texture which can modify density, size and raininess of clouds
- Visible within the editor when the CloudRenderer is instanced in the current scene

## Usage

Instance the CloudRenderer in your desired scene. Modify shader parameters as desired.

### Weather texture

The default weather texture (which is rather monotone) can be replaced. It is structured like this:

| Channel | Parameter |
| --- | --- |
| R | Density |
| G | Raininess (darkness) |
| B | Type (scale) |
