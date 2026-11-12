-- `nvim .` opens the file tree on the left and an empty editor on the right,
-- not a folder listing in the editor.

local function is_dir_buf(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= "" and vim.fn.isdirectory(name) == 1
end

local function empty_editor()
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.bo[scratch].bufhidden = "wipe"
  vim.bo[scratch].buftype = "nofile"
  return scratch
end

-- A folder buffer never stays in the editor.
vim.api.nvim_create_autocmd("BufEnter", {
  desc = "Keep no folder buffer in the editor",
  callback = function(event)
    if not is_dir_buf(event.buf) then return end
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(event.buf) then return end
      if vim.api.nvim_get_current_buf() == event.buf then
        vim.api.nvim_set_current_buf(empty_editor())
      end
      pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
    end)
  end,
})

-- With a folder or no file, open the file tree at the start.
vim.api.nvim_create_autocmd("UIEnter", {
  desc = "Open the file tree at the start",
  callback = function()
    local arg = vim.fn.argv(0)
    local stat = arg ~= "" and vim.uv.fs_stat(arg) or nil
    if arg ~= "" and (not stat or stat.type ~= "directory") then return end
    vim.schedule(function()
      pcall(function()
        require("neo-tree.command").execute({ action = "show", dir = vim.uv.cwd() })
      end)
    end)
  end,
})
