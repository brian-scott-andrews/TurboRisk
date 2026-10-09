# TRMap map editor

TRMap is a Lazarus/FPC desktop editor for TurboRisk `.trm` maps. It supports
the game's fixed 42-territory, six-continent Risk topology; territory borders
are kept canonical and are not edited in TRMap.

## Build

Open `TRMap.lpi` in Lazarus or build it with `lazbuild`. The project requires
the Lazarus `fpvectorial` package for SVG reading, rendering, and writing.

The bitmap- and SVG-backed import/save/reopen workflows can be exercised with:

```powershell
lazbuild tests\TRMapWorkflowTests.lpi
tests\TRMapWorkflowTests.exe
```

## Import and edit

- **New from SVG or BMP** imports vector artwork directly or uses a bitmap as
  raster artwork. For an SVG, select a territory and click a filled path to
  assign it. TRMap colors the assigned path and records a floodfill point.
- For a BMP, select a territory and click inside a flat-color region to record
  its seed. Use **Floodfill points - Autofind** to trace the selected regions
  into SVG paths. The original bitmap is retained as a separate background.
- BMP tracing follows one exact-color, four-connected region per seed. It is
  intended for simple, flat-color territories; anti-aliased borders, textured
  fills, holes, and complicated shapes may need cleanup in an SVG editor.
- **Open map** opens a `.trm` package or SVG source. Existing bitmap-backed
  `.trm` maps remain bitmap-backed when saved.
- The view selector supports floodfill points, text-box points, fixed links,
  and a simple ownership-color preview. **Validate map** checks territory
  points, vector assignments, and the fixed topology before use.

Saving a vector map writes a `.trm` file and a sibling `.svg`; if raster
artwork is present, it also writes a sibling `.bmp`. Keep those files together
when moving the map into the game's `maps` directory.
