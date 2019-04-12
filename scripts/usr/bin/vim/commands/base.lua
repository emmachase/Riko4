return function(context)
  local cmdBar = context:get "commandbar"

  cmdBar.registerCommand({"q", "quit"}, function()
    context:set("running", false)
  end)
end
