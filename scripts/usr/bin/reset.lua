--HELP: \b6Usage: \b16reset \n
-- \b6Description: \b7Resets the gpu translate stack and palette, useful when programs that use \b16cam() \b7or custom palettes crash

local pal = {
  {24,   24,   24},
  {29,   43,   82},
  {126,  37,   83},
  {0,    134,  81},
  {171,  81,   54},
  {86,   86,   86},
  {157,  157,  157},
  {255,  0,    76},
  {255,  163,  0},
  {255,  240,  35},
  {0,    231,  85},
  {41,   173,  255},
  {130,  118,  156},
  {255,  119,  169},
  {254,  204,  169},
  {236,  236,  236}
}

while gpu.pop() do end
gpu.blitPalette(pal)