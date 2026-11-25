-- Markdown in the herdspace Neovim. The LazyVim Markdown extra renders a
-- Markdown file with render-markdown.nvim, but it turns off the heading icons
-- and the checkboxes. herdspace turns them on again, so that a heading shows
-- an icon in place of ###, and a task shows a box. <leader>um shows the raw
-- text, and the line with the cursor always shows the raw text.
--
-- snacks.image shows images in a Markdown file, and image files, with the
-- Kitty graphics protocol. Ghostty supports it, and Herdr 0.9.2 and later pass
-- the images of a pane to the outer terminal. Without ImageMagick (magick),
-- snacks shows PNG files only. :checkhealth snacks shows what works.
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      heading = {
        sign = false,
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      },
      checkbox = { enabled = true },
    },
  },
  {
    "folke/snacks.nvim",
    opts = {
      image = { enabled = true },
    },
  },
}
