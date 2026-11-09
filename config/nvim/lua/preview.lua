-- One preview buffer, as in a graphical editor. A new preview replaces the old
-- one. A file stays open after you pin it or change it.
local M = {}

local preview_buf = nil

local function main_window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype ~= "neo-tree" and vim.api.nvim_win_get_config(win).relative == "" then
      return win
    end
  end
end

--- Show PATH without moving the cursor out of the current window.
function M.open(path)
  local win = main_window()
  if not win then return end
  local old = preview_buf
  vim.api.nvim_win_call(win, function() vim.cmd.edit({ args = { vim.fn.fnameescape(path) } }) end)
  local buf = vim.api.nvim_win_get_buf(win)
  if old and old ~= buf and vim.api.nvim_buf_is_valid(old) and not vim.bo[old].modified then
    vim.api.nvim_buf_delete(old, { force = false })
  end
  if old ~= buf and vim.fn.getbufinfo(buf)[1].changed == 0 then
    preview_buf = buf
    vim.api.nvim_create_autocmd({ "TextChanged", "InsertEnter" }, {
      buffer = buf,
      once = true,
      callback = function() if preview_buf == buf then preview_buf = nil end end,
    })
  end
end

--- Keep the current preview open.
function M.pin() preview_buf = nil end

function M.current() return preview_buf end

return M
