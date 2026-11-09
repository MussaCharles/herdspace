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
        ["<LeftRelease>"] = click,
        ["<2-LeftMouse>"] = keep_open,
        ["<cr>"] = keep_open,
      },
    },
  },
}
