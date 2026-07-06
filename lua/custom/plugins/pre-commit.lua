-- pre-commit.nvim: run the pre-commit framework from inside Neovim and view
-- the results in a floating window. Requires a `.pre-commit-config.yaml` in the repo.
-- https://github.com/Ttibsi/pre-commit.nvim

---@module 'lazy'
---@type LazySpec
return {
  'Ttibsi/pre-commit.nvim',
  cmd = 'Precommit',
  keys = {
    { '<leader>gp', '<cmd>Precommit<cr>', desc = '[G]it [P]re-commit run' },
  },
}
