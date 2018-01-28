---
layout: doc
title: "gpu.setPaletteColor"
permalink: "Riko4/gpu/setPaletteColor/"
categories:
 - gpu

usage: "gpu.setPaletteColor(slot, r, g, b)"
returns: "nil"
excerpt: "Sets color index `slot` to rgb values `r`, `g`, and `b`."
---

{{ page.excerpt }}

This function is for setting a single color at a time, if you wish to modify multiple colors, consider using [gpu.blitPalette](/gpu/blitPalette)

|Parameter|Type|Description|
|:--------|---:|-----------|
|slot     |number|Color index, 1-16|
|r        |number|Red value, 0-255|
|g        |number|Green value, 0-255|
|b        |number|Blue value, 0-255|


Example Usage:
```lua
gpu.drawPixel(50, 50, 8) -- Red pixel

gpu.setPaletteColor(8, 0, 255, 0)

gpu.drawPixel(50, 50, 8) -- Green pixel
```
