local config = {
  codes = true, -- Enable warning codes

  self = false, -- Ignore unused self warnings
  max_line_length = false, -- Disable max line length warnings.

  std = "luajit", -- LuaJIT standard environment.

  globals = {
    "fs",
    "gpu",
    "image",
    "shell",
    "speaker",

    "write",
    "addRequirePath",
    "sleep"
  },

  ignore = {
    "212", -- Unused argument.
    "213"  -- Unused loop variable.
  },

  files = {
    ["**/*.rlua"] = {
      globals = {
        "cls", "pix", "rectFill", "rect", "cls", "pal", "pixb", "cam",
        "push", "sheet", "spr", "pop", "pget", "swap", "trans",

        "_eventDefault", "_cleanup", "_init", "_event", "_update", "_draw",

        "_w", "_h", "_running",

        "rnd", "range", "elip", "elipFill", "circ", "circFill", "line",
        "poly", "class", "all",

        "PI", "cos", "sin", "tan", "atan2",

        "flr", "ceil"
      }
    },
    ["scripts/lib/loops.lua"] = {
      globals = {
        "_eventDefault", "_cleanup", "_init", "_event", "_update",
        "_draw", "_running"
      }
    }
  }
}

config.files["scripts/lib/header.lua"] = config.files["**/*.rlua"]
config.files["scripts/lib/extras.lua"] = config.files["**/*.rlua"]

return config
