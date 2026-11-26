-- Ctrl+Q closes the file, as Cmd+W closes an editor tab in VS Code. With no
-- other file open, it quits Neovim, so that a pane of quick open closes, or
-- the shell comes back. Neovim asks first only about unsaved changes.
--
-- The key is in the spec of snacks.nvim, which loads at startup. The keymaps
-- file of LazyVim loads later, so a key there does nothing in the first
-- moment after Neovim starts.
local function close_file()
  -- A file buffer counts. An empty buffer with no name and no change, which
  -- Neovim can keep after it starts, does not.
  local files = vim.tbl_filter(function(b)
    return vim.bo[b.bufnr].buftype == "" and (b.name ~= "" or b.changed == 1)
  end, vim.fn.getbufinfo({ buflisted = 1 }))
  if #files > 1 then
    Snacks.bufdelete()
  elseif #vim.tbl_filter(function(b) return b.changed == 1 end, vim.fn.getbufinfo({ buflisted = 1 })) > 0 then
    vim.cmd("confirm qall")
  else
    -- Nothing to save. Quit with no question, also while a plugin still
    -- downloads a parser or a tool in the background. It starts again the
    -- next time Neovim opens.
    vim.cmd("qall!")
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
