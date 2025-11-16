return {
  "voldikss/vim-floaterm",
  config = function()
    -- let g:floaterm_keymap_toggle = "<leader>ft"
    -- let g:floaterm_keymap_kill = "<leader>fk"
    vim.keymap.set("n", "<leader>tt", vim.cmd.FloatermToggle, { desc = "Hide / Show terminal" })
    vim.keymap.set("n", "<leader>ta", vim.cmd.FloatermNew, { desc = "New terminal" })
    vim.keymap.set("n", "<leader>tn", vim.cmd.FloatermNext, { desc = "Cycle terminal instance" })
  end,
}
