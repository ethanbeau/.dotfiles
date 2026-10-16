-- bootstrap lazy.nvim, LazyVim and your plugins
-- Older native distro packages can still provide a usable terminal editor.
if vim.fn.has("nvim-0.11.2") == 0 then
  vim.opt.number = true
  vim.opt.expandtab = true
  vim.opt.shiftwidth = 2
  vim.opt.tabstop = 2
  vim.schedule(function()
    vim.notify("LazyVim needs Neovim >= 0.11.2; using basic editor settings.", vim.log.levels.WARN)
  end)
  return
end

require("config.lazy")
