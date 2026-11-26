-- Ctrl+Q closes the file, as Cmd+W closes an editor tab in VS Code. With no
-- other file open, it quits Neovim, so that a pane of quick open closes, or
-- the shell comes back. Neovim asks first about unsaved changes.
--
-- The key is in the spec of snacks.nvim, which loads at startup. The keymaps
-- file of LazyVim loads later, so a key there does nothing in the first
-- moment after Neovim starts.
local function close_file()
  local files = vim.tbl_filter(function(b)
    return vim.bo[b.bufnr].buftype == ""
  end, vim.fn.getbufinfo({ buflisted = 1 }))
  if #files > 1 then
    Snacks.bufdelete()
  else
    vim.cmd("confirm qall")
  end
end

return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<C-q>", close_file, desc = "Close the file, or quit with no other file" },
    },
  },
}
