-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
  "nvim-neo-tree/neo-tree.nvim",
  version = "*",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
    "MunifTanjim/nui.nvim",
  },
  lazy = false,
  keys = {
    { "\\", ":Neotree reveal<CR>", desc = "NeoTree reveal", silent = true },
    { "<leader><c-l>", ":Neotree left<CR>", desc = "Show NeoTree on left side", silent = true },
    { "<leader><c-f>", ":Neotree float<CR>", desc = "Float NeoTree (default)", silent = true },
  },
  opts = {
    popup_border_style = "rounded",
    filesystem = {
      follow_current_file = {
        enabled = true,
      },
      filtered_items = {
        -- visible = true,
        show_hidden_count = true,
        hide_dotfiles = false,
        hide_gitignore = false,
      },
      window = {
        position = "float",
        mappings = {
          ["\\"] = "close_window",
        },
      },
    },
  },
}
