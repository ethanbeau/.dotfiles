return {
  -- Monokai Pro: The core theme
  {
    "loctvl842/monokai-pro.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.opt.termguicolors = true
      require("monokai-pro").setup({
        transparent_background = false,
        terminal_colors = true,
        devicons = true,
        styles = {
          comment = { italic = true },
          keyword = { italic = true },
          type = { italic = true },
        },
        -- Default to spectrum (dark)
        filter = "spectrum",
      })
      -- Initial load
      vim.cmd([[colorscheme monokai-pro]])
    end,
  },

  -- Auto dark mode: Follow system appearance
  {
    "f-person/auto-dark-mode.nvim",
    lazy = false,
    priority = 800,
    opts = {
      update_interval = 1000,
      fallback = "dark",
      set_dark_mode = function()
        vim.o.background = "dark"
        require("monokai-pro").set_filter("spectrum")
      end,
      set_light_mode = function()
        vim.o.background = "light"
        require("monokai-pro").set_filter("light")
      end,
    },
  },
}
