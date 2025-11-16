-- COLOUR

--return {
--  "folke/tokyonight.nvim",
--  lazy = false,
--  priority = 1000,
--  opts = {},
--  config = function()
--    local color = "tokyonight-storm"
--    vim.cmd.colorscheme(color)
--
--    -- Transparency doesn't work with neo tree
--    --vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
--    --vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
--    --vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
--    --vim.api.nvim_set_hl(0, "TabStop", { bg = "none" })
--  end,
--}
--
return {
  "loctvl842/monokai-pro.nvim",
  config = function()
    require("monokai-pro").setup()
  end,
}
-- return { "catppuccin/nvim", name = "catppuccin", priority = 1000 }
