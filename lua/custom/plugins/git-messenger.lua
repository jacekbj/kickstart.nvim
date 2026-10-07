-- git-messenger.vim: show the commit that last touched the line under the
-- cursor in a floating popup, and walk back through older commits from there.
-- https://github.com/rhysd/git-messenger.vim

---@module 'lazy'
---@type LazySpec
return {
  'rhysd/git-messenger.vim',
  cmd = 'GitMessenger',
  -- The plugin's own <leader>gm mapping is only defined once it has loaded, so
  -- map it here instead to lazy-load on first use.
  keys = {
    { '<leader>gm', '<Plug>(git-messenger)', desc = 'Commit [m]essage for current line' },
  },
  -- Vimscript plugin: configured through g: variables, which must be set before
  -- it loads.
  init = function()
    vim.g.git_messenger_no_default_mappings = true
    -- Jump straight into the popup, so o/O/d/D/? work without a second <leader>gm.
    vim.g.git_messenger_always_into_popup = true
    vim.g.git_messenger_floating_win_opts = { border = 'rounded' }
  end,
}
