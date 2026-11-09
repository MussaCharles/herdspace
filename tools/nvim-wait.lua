-- Neovim installs its language tools in the background after it starts. This
-- waits until no install runs and no new parser appears, and then it quits.
local parsers = vim.fn.stdpath("data") .. "/site/parser"
local packages = vim.fn.stdpath("data") .. "/mason/packages"
local last, quiet, limit = -1, 0, 420

local function busy()
  local ok, registry = pcall(require, "mason-registry")
  if not ok then return false end
  for _, pkg in ipairs(registry.get_all_packages()) do
    if pkg:is_installing() then return true end
  end
  return false
end

-- Neovim starts these servers only when it opens a matching file, so install
-- them by name. Then the first real start shows no install messages.
local servers = { "vtsls", "json-lsp", "lua-language-server", "marksman", "pyright", "ruff", "taplo" }
vim.schedule(function()
  local ok, registry = pcall(require, "mason-registry")
  if not ok then return end
  registry.refresh(function()
    for _, name in ipairs(servers) do
      if registry.has_package(name) then
        local pkg = registry.get_package(name)
        if not pkg:is_installed() and not pkg:is_installing() then pkg:install() end
      end
    end
  end)
end)

local timer = vim.uv.new_timer()
timer:start(5000, 2000, vim.schedule_wrap(function()
  limit = limit - 2
  local count = #vim.fn.glob(parsers .. "/*", false, true) + #vim.fn.glob(packages .. "/*", false, true)
  if busy() or count ~= last then
    quiet = 0
  else
    quiet = quiet + 2
  end
  last = count
  if quiet >= 30 or limit <= 0 then
    timer:stop()
    vim.cmd("qa!")
  end
end))
