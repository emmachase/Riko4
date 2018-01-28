---
layout: doc
title: "gpu.drawPixel"
permalink: "/gpu/drawPixel"
categories:
 - gpu

usage: "gpu.drawPixel(x, y, [color])"
returns: "nil"
excerpt: "Plots a pixel at `x`, `y` with `color`."
---

{{ page.excerpt }}

This function draws to the main screen, if you wish to draw to an image, use [image:drawPixel](/image/drawPixel).
Respects transformations made by [gpu.translate](/gpu/translate).


|Parameter|Type|Description|
|:--------|---:|-----------|
|x        |number|The X coordinate to draw the pixel at|
|y        |number|The Y coordinate to draw the pixel at|
|color    |number|Color index, 1-16|


Example Usage:
```lua
gpu.drawPixel(5, 10, 8) -- Draws a red pixel at x, y = 5, 10
```
