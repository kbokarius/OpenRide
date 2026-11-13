# Lane Smash — revision 7

## Requested changes

Make the psychedelic scenery stream past the rider at the same speed as the ride. Show each track's colors and an animated preview in its menu card. Give the selector and settings a clean, professional color palette with readable text.

## Distance-driven scenery

The sky samples an analytic cylinder with a 28-metre radius. Each view ray intersects that cylinder at `depth = 28 × forward / radial`. The pattern's longitudinal coordinate is `road_distance + depth`, in metres. Advancing the actual rider distance brings each fixed feature closer, so it expands outward from the opening and passes outside the view. The previous logarithmic depth and separately accumulated cadence clock are removed.

The rules remain the only source of forward travel. Zero distance change produces zero forward background motion, regardless of render-frame count, sensor recovery or elapsed wall time. The existing 140-rpm / 60-km/h cap applies automatically. Resistance smoothly shifts the palette without changing the pattern's longitudinal coordinate. Full and Reduced motion use the same physical travel distance; Reduced dims and softens the scenery and retains revision 6's gentle road without inversions.

All four patterns share `psychedelic_tunnel.gdshaderinc`. Pixel derivatives suppress distant detail that would otherwise shimmer. The sky remains one bounded rendering pass with inexpensive cubemap lighting. Fixed road geometry, camera path, score formulas and ghost comparison keys remain unchanged.

This is an analytic tunnel effect, not additional physical world meshes. Its orientation follows the existing road-aligned opening. Its forward motion is synchronized with physical travel; it does not simulate independently collidable scenery.

## Track library

Each named track card uses its configured palette and background ID. A canvas shader shares the ride's pattern function, with a slow five-metres-per-second preview. The title, pattern, color name and previous score appear on a dark gradient scrim. A color strip, border and explicit SELECTED badge identify the chosen track without relying only on color. Cards keep stable 1016 × 188 logical dimensions.

Only visible cards update their animation uniforms. Offscreen cards and cards covered by settings stop updating. Reduced motion freezes menu previews. No per-card cameras or subviewports are created. The library remains scrollable without visible scrollbars.

The selector, settings and history use a shared navy/slate palette, pale cyan selected outlines, restrained blue fills, and the existing clean Rajdhani font. Duration and difficulty controls keep their existing dimensions and spacing. Each duration still provides 25 tracks, and random generation still selects its own theme and pattern.

## Stars — existing behavior, unchanged

Stars require completing the selected ride duration. The percentage is `baseUnits / maxBaseUnits`, weighted by available section credit for the portion of the road actually reached:

| Rating | Required credit |
| --- | --- |
| 0 stars | Under 25%, or ended early |
| 1 star | At least 25% |
| 2 stars | At least 60% |
| 3 stars | At least 90% |

Bars require the correct lane. Cadence arrows require both the correct lane and the inclusive target RPM range. Powerups use actual output, with star credit capped at the internal 150 W target for valid time. Output above that target still increases points. Stars therefore describe weighted section performance, not a percentage of the raw score or a comparison against another rider.

## Build and references

Version code 15; `1.2.0-lane-smash.7`. The package and signing identity remain the same. No database migration or scoring-content change is involved. See [validation](lane-smash-v7-validation.md) and the [installation guide](../LANE_SMASH.md).

Rendering references: [Godot sky shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html), [Godot shader functions](https://docs.godotengine.org/en/latest/tutorials/shaders/shader_reference/shader_functions.html). Shared canvas shaders were chosen over one live 3D scene per card to keep tablet rendering cost bounded.
