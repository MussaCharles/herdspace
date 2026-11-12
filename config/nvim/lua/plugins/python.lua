-- Python: open a project with its own .venv or venv, as "Select Interpreter"
-- does in VS Code, so that the language server finds the packages.

local function find_venv_python(start)
  local path = start
  while path and path ~= "" do
    for _, rel in ipairs({ ".venv/bin/python", "venv/bin/python" }) do
      local candidate = path .. "/" .. rel
      if vim.uv.fs_stat(candidate) then return candidate end
    end
    local parent = vim.fs.dirname(path)
    if parent == path then break end
    path = parent
  end
end

local function activate_project_venv(buf)
  local ok, vs = pcall(require, "venv-selector")
  if not ok or vs.python() then return end
  local name = vim.api.nvim_buf_get_name(buf)
  local py = find_venv_python(name ~= "" and vim.fs.dirname(name) or vim.uv.cwd())
  if py then vs.activate_from_path(py, "venv") end
end

return {
  {
    "linux-cultist/venv-selector.nvim",
    opts = {
      options = {
        notify_user_on_venv_activation = true,
        cached_venv_automatic_activation = true,
      },
    },
    config = function(_, opts)
      require("venv-selector").setup(opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "python",
        callback = function(event)
          vim.schedule(function() activate_project_venv(event.buf) end)
        end,
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Pyright for go to definition and hover, with no type check errors.
        pyright = {
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "off",
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "openFilesOnly",
              },
            },
          },
        },
      },
    },
  },
}
