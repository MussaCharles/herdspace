-- Keys that feel like a graphical code editor.
local map = vim.keymap.set

map("n", "<C-p>", function() LazyVim.pick("files")() end, { desc = "Find a file" })

local function search_project() LazyVim.pick("live_grep")() end
map("n", "<C-S-f>", search_project, { desc = "Search the project" })
map({ "n", "x" }, "/", search_project, { desc = "Search the project" })
map("n", "g/", "/", { desc = "Search inside the file" })

map({ "n", "i", "x" }, "<D-e>", function()
  require("neo-tree.command").execute({ action = "focus", dir = LazyVim.root() })
end, { desc = "Focus the file tree" })

map("n", "<leader>gc", function() Snacks.picker.git_branches() end, { desc = "Switch the git branch" })

local function definition_at_mouse()
  local pos = vim.fn.getmousepos()
  if pos.winid == 0 then return end
  vim.api.nvim_set_current_win(pos.winid)
  vim.api.nvim_win_set_cursor(pos.winid, { pos.line, math.max(pos.column - 1, 0) })
  if #vim.lsp.get_clients({ bufnr = 0, method = "textDocument/definition" }) > 0 then
    vim.lsp.buf.definition()
  end
end
map("n", "<C-LeftMouse>", definition_at_mouse, { desc = "Go to the definition" })
map("n", "<D-LeftMouse>", definition_at_mouse, { desc = "Go to the definition" })
map("n", "<C-RightMouse>", "<C-o>", { desc = "Go back" })
