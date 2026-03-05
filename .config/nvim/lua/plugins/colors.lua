return {
  -- DARK: OneDarkPro base + your overrides
  {
    "olimorris/onedarkpro.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.opt.termguicolors = true

      local C = {
        -- from your VSCode JSON
        bg          = "#121212",
        fg          = "#bbbbbb",
        ui0         = "#020202", -- status/titlebar bg
        ui1         = "#181a1f", -- widgets/sidebar/tab inactive
        ui2         = "#1d1f23", -- input/activitybar/cursorline bg
        border      = "#181a1f",
        sep         = "#181a1f",
        cursor      = "#f8f8f0",

        sel         = "#3e4451",
        find        = "#314365",
        pmenu_sel   = "#2c313a",

        linenr      = "#495162",
        whitespace  = "#484a50",
        indentguide = "#3b4048",

        -- VSCode uses RGBA; Neovim highlights require #RRGGBB.
        -- Pre-blended over bg (#121212):
        scrollbar   = "#30343c", -- blend(#4e5666 @ 0x80 over #121212)
        scrollbar_h = "#363b44", -- blend(#5a6375 @ 0x80 over #121212)
        scrollbar_a = "#434852", -- blend(#747d91 @ 0x80 over #121212)

        diag_err    = "#704040",
        diag_warn   = "#407040",
        diag_info   = "#707040",

        -- token palette (from your JSON)
        comment     = "#5c6370",
        red         = "#e06c75",
        green       = "#98c379",
        yellow      = "#e5c07b",
        blue        = "#61afef",
        cyan        = "#56b6c2",
        purple      = "#c678dd",
        orange      = "#d19a66",
        fg2         = "#abb2bf",
        fg_hi       = "#d7dae0",

        -- VSCode diff inserted bg was #00809b33; pre-blended over #121212:
        diff_add_bg = "#0e282d",
      }

      require("onedarkpro").setup({
        -- onedarkpro is designed to be overridden via colors + highlights
        colors = {
          bg = C.bg,
          fg = C.fg,
          cursor = C.cursor,
          comment = C.comment,
          red = C.red,
          green = C.green,
          yellow = C.yellow,
          blue = C.blue,
          cyan = C.cyan,
          purple = C.purple,
          orange = C.orange,
        },
        highlights = {
          ------------------------------------------------------------------------
          -- Core editor surfaces (maps VSCode "colors" -> Neovim UI groups)
          ------------------------------------------------------------------------
          Normal        = { fg = C.fg, bg = C.bg },
          NormalNC      = { fg = C.fg, bg = C.bg },
          EndOfBuffer   = { fg = C.bg, bg = C.bg },
          ColorColumn   = { bg = C.ui2 },

          Cursor        = { fg = C.bg, bg = C.cursor },
          CursorLine    = { bg = C.ui2 }, -- editor.lineHighlightBackground
          CursorLineNr  = { fg = C.fg_hi, bg = C.ui2 },
          LineNr        = { fg = C.linenr, bg = C.bg },

          Visual        = { bg = C.sel }, -- editor.selectionBackground
          Search        = { bg = C.find, fg = C.fg_hi }, -- editor.findMatchHighlightBackground
          IncSearch     = { bg = C.find, fg = C.fg_hi },
          MatchParen    = { bg = C.pmenu_sel, fg = C.fg_hi },

          Whitespace    = { fg = C.whitespace },
          NonText       = { fg = C.whitespace },
          IblIndent     = { fg = C.indentguide },
          IblScope      = { fg = C.indentguide },

          WinSeparator  = { fg = C.sep, bg = C.bg }, -- focusBorder-ish
          VertSplit     = { fg = C.sep, bg = C.bg },
          FloatBorder   = { fg = C.border, bg = C.ui1 },
          NormalFloat   = { fg = C.fg, bg = C.ui1 }, -- editorWidget/hover/suggest bg

          ------------------------------------------------------------------------
          -- Popup menu (cmp + built-in) ~= VSCode suggest widget
          ------------------------------------------------------------------------
          Pmenu         = { fg = C.fg, bg = C.ui1 },
          PmenuSel      = { fg = C.fg_hi, bg = C.pmenu_sel },
          PmenuSbar     = { bg = C.scrollbar },
          PmenuThumb    = { bg = C.scrollbar_a },

          ------------------------------------------------------------------------
          -- Tabs + statusline ~= VSCode tabs/status bar/title bar
          ------------------------------------------------------------------------
          TabLine       = { fg = C.fg, bg = C.ui1 },
          TabLineSel    = { fg = C.fg_hi, bg = C.bg },
          TabLineFill   = { bg = C.ui1 },

          StatusLine    = { fg = "#9da5b4", bg = C.ui0 },
          StatusLineNC  = { fg = "#6b717d", bg = C.ui0 },

          ------------------------------------------------------------------------
          -- Diagnostics (use your JSON’s muted non-vibrant colors)
          ------------------------------------------------------------------------
          DiagnosticError = { fg = C.diag_err },
          DiagnosticWarn  = { fg = C.diag_warn },
          DiagnosticInfo  = { fg = C.diag_info },
          DiagnosticHint  = { fg = C.diag_info },

          DiagnosticVirtualTextError = { fg = C.diag_err, bg = C.bg },
          DiagnosticVirtualTextWarn  = { fg = C.diag_warn, bg = C.bg },
          DiagnosticVirtualTextInfo  = { fg = C.diag_info, bg = C.bg },
          DiagnosticVirtualTextHint  = { fg = C.diag_info, bg = C.bg },

          ------------------------------------------------------------------------
          -- Token mapping (Tree-sitter captures; closer to your tokenColors)
          ------------------------------------------------------------------------
          Comment       = { fg = C.comment, italic = true },

          ["@string"]   = { fg = C.yellow },
          ["@number"]   = { fg = C.purple },
          ["@constant"] = { fg = C.cyan },
          ["@type"]     = { fg = C.blue },     -- your JSON "Class name" is blue
          ["@keyword"]  = { fg = C.red },
          ["@function"] = { fg = C.green },
          ["@parameter"]= { fg = C.orange, italic = true },
          ["@variable"] = { fg = C.blue },     -- variable.readwrite -> blue
          ["@property"] = { fg = C.fg2 },      -- variable.other.property -> abb2bf

          ------------------------------------------------------------------------
          -- Diff (VSCode uses alpha backgrounds; we pre-blend)
          ------------------------------------------------------------------------
          DiffAdd       = { bg = C.diff_add_bg },
          DiffDelete    = { fg = C.purple },
          DiffChange    = { bg = C.ui2 },
          DiffText      = { bg = C.sel },

          ------------------------------------------------------------------------
          -- Common plugin surfaces (match your widget backgrounds)
          ------------------------------------------------------------------------
          TelescopeNormal       = { fg = C.fg, bg = C.ui1 },
          TelescopeBorder       = { fg = C.border, bg = C.ui1 },
          TelescopePromptNormal = { fg = C.fg, bg = C.ui2 },
          TelescopePromptBorder = { fg = C.border, bg = C.ui2 },

          CmpPmenu       = { fg = C.fg, bg = C.ui1 },
          CmpSel         = { fg = C.fg_hi, bg = C.pmenu_sel },
          CmpBorder      = { fg = C.border, bg = C.ui1 },

          -- If you use Noice/Notify, this keeps their floats consistent too
          NoicePopupmenu = { fg = C.fg, bg = C.ui1 },
          NotifyBackground = { bg = C.ui1 },
        },
      })

      vim.opt.background = "dark"
      vim.cmd("colorscheme onedark_dark")
    end,
  },

  -- LIGHT: FlatUI
  {
    "john2x/flatui.vim",
    lazy = false,
    priority = 900,
  },

  -- SYSTEM: follow OS light/dark and call our switchers
  {
    "f-person/auto-dark-mode.nvim",
    lazy = false,
    priority = 800,
    opts = {
      -- per plugin docs: must be >= OS query time; ms
      update_interval = 1000,
      fallback = "dark",

      -- hooks called when system appearance changes; override for custom behavior
      set_dark_mode = function()
        vim.opt.background = "dark"
        vim.cmd("colorscheme onedark_dark")
      end,

      set_light_mode = function()
        vim.opt.background = "light"
        vim.cmd("colorscheme flatui")
      end,
    },
  },
}