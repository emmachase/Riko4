return {
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
  }
}
