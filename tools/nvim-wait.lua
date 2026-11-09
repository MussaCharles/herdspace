-- Neovim installs its language tools in the background after it starts. This
-- waits until no install runs and no new parser appears, and then it quits.
local parsers = vim.fn.stdpath("data") .. "/site/parser"
local last, quiet, limit = -1, 0, 300

local function busy()
  local ok, registry = pcall(require, "mason-registry")
  if not ok then return false end
  for _, pkg in ipairs(registry.get_all_packages()) do
    if pkg:is_installing() then return true end
  end
  return false
end

local timer = vim.uv.new_timer()
timer:start(5000, 2000, vim.schedule_wrap(function()
  limit = limit - 2
  local count = #vim.fn.glob(parsers .. "/*", false, true)
  if busy() or count ~= last then
    quiet = 0
  else
    quiet = quiet + 2
  end
  last = count
  if quiet >= 20 or limit <= 0 then
    timer:stop()
    vim.cmd("qa!")
  end
end))
