-- Closer to a graphical code editor: absolute line numbers, the mouse, and a
-- question before quitting with unsaved changes.
vim.opt.relativenumber = false
vim.opt.mouse = "a"
vim.opt.confirm = true
vim.opt.showtabline = 2
-- Wrap long lines in the editor, with the indent of the line, and no sideways scroll.
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
-- No folder listing of netrw in the editor. The file tree owns the folders.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
