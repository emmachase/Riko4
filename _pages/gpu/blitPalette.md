---
layout: doc
title: "gpu.blitPalette"
permalink: "/gpu/blitPalette"
categories:
 - gpu

usage: "gpu.blitPalette(blitTable)"
returns: "nil"
excerpt: "Modifies entire sections of the palette at once using `blitTable`."
---

{{ page.excerpt }}

The structure for the `blitTable` is as follows:

Each color to be changed must be present in the table at its color index, each color is represented as a table of `{r, g, b}`. Also any colors that should remain unchanged should be present as a `0` (or any number, it just cannot be a table) instead of an RGB list. These filler values need to be used from index `1` to the max index that will be changed, but any indexes afterwards can be left out. For example:
```lua
local blitTable = {
    [1] = {60,  35, 128},
    [2] = 0, -- Color 2 will be unchanged
    [3] = {90,  20, 20 },
    [4] = {111, 34, 4  }
    -- Only changing up to 4..
    -- so we can leave the rest out
}
```

**WARNING:** Please note that new palette colors will persist, and the built-in shell does not revert colors. Thus, a good practice is to use [gpu.getPalette](/gpu/getPalette) at the very beginning of the application, store this and restore that palette at cleanup, see example for details.

|Parameter|Type|Description|
|:--------|---:|-----------|
|blitTable|table|The colors to set the new palette to, spec above|

Example Usage:
```lua
local oldPal = gpu.getPalette()

-- Change first half of palette to gray ramp
local newPal = {}
for i = 0, 7 do
  newPal[i + 1] = {i * 32, i * 32, i * 32}
end

gpu.blitPalette(newPal)

-- Do application stuff...

-- At cleanup we should restore the old palette..
gpu.blitPalette(oldPal)
```
