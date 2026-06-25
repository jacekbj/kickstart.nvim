-- glance.nvim: peek definitions / references / implementations in a floating
-- window without leaving your current position.
-- https://github.com/dnlhc/glance.nvim

---@module 'lazy'
---@type LazySpec
return {
  'dnlhc/glance.nvim',
  cmd = 'Glance',
  -- `gp` prefix = [P]eek. Lazy-loads on first use of any of these.
  keys = {
    { 'gpd', '<cmd>Glance definitions<cr>', desc = 'Glance: [P]eek [D]efinitions' },
    { 'gpr', '<cmd>Glance references<cr>', desc = 'Glance: [P]eek [R]eferences' },
    { 'gpi', '<cmd>Glance implementations<cr>', desc = 'Glance: [P]eek [I]mplementations' },
    { 'gpt', '<cmd>Glance type_definitions<cr>', desc = 'Glance: [P]eek [T]ype definitions' },
  },
  opts = {},
}
