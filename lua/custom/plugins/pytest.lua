-- pytest.nvim: run the project's pytest suite from inside Neovim, executing the
-- tests in the docker-compose `app` container (not on the host).
-- https://github.com/richardhapb/pytest.nvim
--
-- Why the docker settings look the way they do:
--   * The plugin runs `docker exec -i <container> pytest ...` — it needs the
--     *container name/id*, not the compose service name. We resolve it at run
--     time from `docker compose ps -q app` so it targets whichever stack is up
--     in the current directory, rather than hard-coding one container name:
--     compose derives names per project directory (`<project>-app-1`), so a
--     worktree or a second checkout gets a different container than the main one.
--   * `enable_docker_compose` (the plugin's own compose parser) is intentionally
--     OFF: it expects the code to live in a sub-directory bind-mounted into the
--     container, but the projects this targets mount their root (`.:/app`). We
--     map paths directly instead: `docker_path = '/app'` with an empty
--     `local_path_prefix`, so a host file `<repo>/<pkg>/.../test_x.py` becomes
--     `/app/<pkg>/.../test_x.py` inside the container.
--
-- Assumes Neovim's cwd is the repo root (the plugin strips that prefix to build
-- the in-container path) and that the `app` service is already running.

---@module 'lazy'
---@type LazySpec
return {
  'richardhapb/pytest.nvim',
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  ft = 'python',
  config = function()
    -- pytest.nvim parses test files and the JUnit XML report via Treesitter.
    -- This config runs the `main` (rewrite) branch of nvim-treesitter, so use
    -- its install API rather than the plugin's suggested `configs.setup` (the
    -- legacy API, which no longer exists on `main`). install() is idempotent.
    require('nvim-treesitter').install { 'python', 'xml' }

    require('pytest').setup {
      docker = {
        enabled = true,
        -- No fallback name: if compose can't tell us the container, return nil so
        -- the plugin errors out instead of silently running tests somewhere else.
        container = function()
          local result = vim.system({ 'docker', 'compose', 'ps', '-q', 'app' }, { text = true }):wait()
          return (result.stdout or ''):match '[^\r\n]+'
        end,
        docker_path = '/app',
        local_path_prefix = '',
        enable_docker_compose = false,
      },

      open_output_onfail = true,

      keymaps_callback = function(bufnr)
        local map = function(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = bufnr, desc = desc }) end
        map('<leader>TT', '<CMD>Pytest<CR>', '[T]est run file')
        map('<leader>Ta', '<CMD>PytestAttach<CR>', '[T]est [A]ttach (run on save)')
        map('<leader>Td', '<CMD>PytestDetach<CR>', '[T]est [D]etach')
        map('<leader>To', '<CMD>PytestOutput<CR>', '[T]est [O]utput')
        map('<leader>Tu', '<CMD>PytestUI<CR>', '[T]est [U]I')
      end,
    }
  end,
}
