-- One Dark, the colors of VS Code, on the background of the terminal: the
-- editor has no background of its own, so it sits flush in Ghostty, also with
-- the background opacity of Ghostty.
return {
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "dark",
      transparent = true,
      term_colors = false,
      ending_tildes = false,
      lualine = { transparent = true },
      highlights = {
        NeoTreeNormal = { bg = "none" },
        NeoTreeNormalNC = { bg = "none" },
        NeoTreeEndOfBuffer = { bg = "none" },
        NeoTreeWinSeparator = { fg = "$bg1", bg = "none" },
      },
    },
    config = function(_, opts)
      require("onedark").setup(opts)
      require("onedark").load()
    end,
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "onedark" } },
  { "akinsho/bufferline.nvim", opts = { options = { always_show_bufferline = true } } },
}
