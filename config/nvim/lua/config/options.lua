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
-- The reader mode, the default: no warnings of linters and language servers
-- on the screen, because the agents write the code and you read it.
-- <leader>ud shows them again. "herdspace editor normal" keeps the defaults
-- of LazyVim, and writes the choice in ~/.config/herdspace/editor.
local mode_file = vim.fn.expand("~/.config/herdspace/editor")
local mode = vim.fn.filereadable(mode_file) == 1 and vim.trim(vim.fn.readfile(mode_file)[1] or "") or ""
vim.g.herdspace_reader = mode ~= "normal"
if vim.g.herdspace_reader then vim.diagnostic.enable(false) end
