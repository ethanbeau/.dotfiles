rex.bind("cmd+s", "client.sidebar.toggle")
rex.bind("cmd+n", "session.new")
rex.bind("cmd+shift+n", "client.window.new")
rex.bind("cmd+shift+backspace", "com.superlogical.terminal.clear")
rex.bind("cmd+opt+h", "pane.focus", { direction = "left" })
rex.bind("cmd+opt+j", "pane.focus", { direction = "down" })
rex.bind("cmd+opt+k", "pane.focus", { direction = "up" })
rex.bind("cmd+opt+l", "pane.focus", { direction = "right" })
rex.bind("cmd+shift+h", "pane.split", { direction = "left" })
rex.bind("cmd+shift+j", "pane.split", { direction = "down" })
rex.bind("cmd+shift+k", "pane.split", { direction = "up" })
rex.bind("cmd+shift+l", "pane.split", { direction = "right" })

rex.action{
  name = "contrast_up",
  title = "Increase Theme Contrast",
  run = function()
    rex.client.queue("client.setting.themes.dark.palette", {
      value = "Monokai Pro Spectrum High Contrast",
    })
    rex.client.queue("client.setting.themes.light.palette", {
      value = "Monokai Pro Light Sun High Contrast",
    })
  end,
}

rex.action{
  name = "contrast_down",
  title = "Decrease Theme Contrast",
  run = function()
    rex.client.queue("client.setting.themes.dark.palette", {
      value = "Monokai Pro Spectrum",
    })
    rex.client.queue("client.setting.themes.light.palette", {
      value = "Monokai Pro Light Sun",
    })
  end,
}

rex.bind("cmd+shift+=", "contrast_up")
rex.bind("cmd+shift+-", "contrast_down")
