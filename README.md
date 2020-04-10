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
  - Hand-drawn or procedurally generated
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

## References 
- [The Real-Time Volumetric Cloudscapes of Horizon Zero Dawn](https://www.guerrilla-games.com/read/the-real-time-volumetric-cloudscapes-of-horizon-zero-dawn)
- [Convincing Cloud Rendering: An Implementation of Real-Time Dynamic Volumetric Clouds in Frostbite](http://publications.lib.chalmers.se/records/fulltext/241770/241770.pdf)
- [Optimisations for Real-Time Volumetric Cloudscapes](https://arxiv.org/abs/1609.05344)
- [Coding Adventure: Clouds](https://www.youtube.com/watch?v=4QOcCGI6xOU)
