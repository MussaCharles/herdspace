-- Folder icons in colors by folder name, as in common code editor themes.
local folder_colors = {
  src = "#61afef", lib = "#61afef", app = "#61afef", pkg = "#61afef",
  test = "#98c379", tests = "#98c379", spec = "#98c379",
  docs = "#e5c07b", doc = "#e5c07b",
  config = "#c678dd", configs = "#c678dd", [".github"] = "#c678dd",
  bin = "#e06c75", scripts = "#e06c75", tools = "#e06c75",
  assets = "#d19a66", public = "#d19a66", static = "#d19a66", media = "#d19a66",
}
local default_folder_color = "#90a4ae"

local function folder_highlight(color)
  local name = "HerdspaceFolder" .. color:gsub("#", "")
  vim.api.nvim_set_hl(0, name, { fg = color })
  return name
end

local function preview_node(state)
  local node = state.tree:get_node()
  if node and node.type == "file" then require("preview").open(node:get_id()) end
end

local function move(key)
  return function(state)
    vim.cmd.normal({ key, bang = true })
    preview_node(state)
  end
end

local function keep_open(state)
  local node = state.tree:get_node()
  if node and node.type == "file" then
    require("preview").open(node:get_id())
    require("preview").pin()
  else
    require("neo-tree.sources.filesystem.commands").toggle_node(state)
  end
end

local function click(state)
  local node = state.tree:get_node()
  if node and node.type == "file" then
    preview_node(state)
  elseif node then
    require("neo-tree.sources.filesystem.commands").toggle_node(state)
  end
end

return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    default_component_configs = {
      icon = {
        provider = function(icon, node)
          if node.type == "directory" then
            icon.text = node:is_expanded() and "󰝰" or "󰉋"
            icon.highlight = folder_highlight(folder_colors[node.name:lower()] or default_folder_color)
          elseif node.type == "file" then
            local ok, devicons = pcall(require, "nvim-web-devicons")
            if ok then
              local glyph, hl = devicons.get_icon(node.name)
              icon.text = glyph or icon.text
              icon.highlight = hl or icon.highlight
            end
          end
        end,
      },
    },
    filesystem = {
      follow_current_file = { enabled = true },
      filtered_items = { visible = false, hide_dotfiles = false, hide_gitignored = true },
      window = { mappings = { ["/"] = "none" } },
    },
    window = {
      width = 34,
      mappings = {
        ["j"] = move("j"),
        ["k"] = move("k"),
        ["<Down>"] = move("j"),
        ["<Up>"] = move("k"),
        ["<LeftRelease>"] = click,
        ["<2-LeftMouse>"] = keep_open,
        ["<cr>"] = keep_open,
      },
    },
  },
}
