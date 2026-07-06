-- Per-project Python type-checking with the mypy daemon (`dmypy`), wired through
-- nvim-lint so diagnostics match the project's pre-commit `mypy` hook.
--
-- It also silences pyrefly's diagnostics while KEEPING the pyrefly client alive,
-- so its code actions (auto-import, etc.) still work — only its type errors are
-- hidden, leaving mypy as the single source of type diagnostics.
--
-- Enable it from a project's `.nvim.lua` (requires `vim.o.exrc = true`, which is
-- set in init.lua):
--
--     require('custom.dmypy').enable()
--
-- Options (all optional):
--     require('custom.dmypy').enable {
--       root  = '/abs/path/to/project',     -- default: nearest pyproject.toml/.git up from cwd
--       dmypy = '/abs/path/to/.venv/bin/dmypy', -- default: <root>/.venv/bin/dmypy, else `dmypy` on PATH
--     }
--
-- The project venv's `dmypy` is preferred so mypy sees the project's installed
-- dependencies and type stubs (a bare `dmypy` off PATH usually can't, and floods
-- you with "cannot find implementation or library stub" errors).

local M = {}

local function project_root(opts)
  if opts.root then return opts.root end
  local found = vim.fs.root(vim.fn.getcwd(), { 'pyproject.toml', 'mypy.ini', 'setup.cfg', '.git' })
  return found or vim.fn.getcwd()
end

local function resolve_dmypy(root, opts)
  if opts.dmypy then return opts.dmypy end
  local venv = root .. '/.venv/bin/dmypy'
  if vim.fn.executable(venv) == 1 then return venv end
  return 'dmypy'
end

-- Derive a `dmypy` linter from nvim-lint's built-in `mypy` linter: identical
-- flags and output parser, but run through the persistent daemon for speed.
local function register_linter(root, cmd)
  local lint = require 'lint'
  local mypy = lint.linters.mypy

  -- Shallow copy so we reuse mypy's parser/severity handling untouched.
  local dmypy = {}
  for k, v in pairs(mypy) do
    dmypy[k] = v
  end

  -- `dmypy run -- <mypy flags> <file>`: everything after `--` is passed to mypy.
  -- `--follow-imports=silent` still type-checks imported modules (so results are
  -- accurate) but only reports errors for the file being edited, keeping
  -- diagnostics on the current buffer instead of dumping a dependency's errors
  -- onto it. Drop this line if you want whole-build reporting.
  local args = { 'run', '--' }
  for _, a in ipairs(mypy.args) do
    args[#args + 1] = a
  end
  args[#args + 1] = '--follow-imports=silent'

  dmypy.cmd = cmd
  dmypy.args = args
  dmypy.cwd = root -- run from the project root so mypy finds its config

  lint.linters.dmypy = dmypy
end

-- Hide pyrefly's diagnostics without stopping the client, so its code actions
-- (auto-import etc.) keep working.
local function silence_pyrefly(client)
  if not client or client.name ~= 'pyrefly' then return end

  -- Stop future pull diagnostics (textDocument/diagnostic).
  if client.server_capabilities then client.server_capabilities.diagnosticProvider = nil end
  -- Stop future push diagnostics (textDocument/publishDiagnostics).
  client.handlers = client.handlers or {}
  client.handlers['textDocument/publishDiagnostics'] = function() end

  -- Clear anything already shown and disable pyrefly's diagnostic namespaces so
  -- nothing it sends gets displayed, regardless of push/pull.
  pcall(function()
    for _, is_pull in ipairs { false, true } do
      local ns = vim.lsp.diagnostic.get_namespace(client.id, is_pull)
      vim.diagnostic.reset(ns)
      vim.diagnostic.enable(false, { ns_id = ns })
    end
  end)
end

function M.enable(opts)
  opts = opts or {}
  local root = project_root(opts)
  local cmd = resolve_dmypy(root, opts)
  local group = vim.api.nvim_create_augroup('custom-dmypy', { clear = true })

  register_linter(root, cmd)

  -- Lint this project's Python buffers with dmypy. We call try_lint('dmypy')
  -- explicitly instead of using linters_by_ft so it stays scoped to this project
  -- and doesn't fight the global nvim-lint config.
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost', 'InsertLeave' }, {
    group = group,
    callback = function(ev)
      if vim.bo[ev.buf].filetype ~= 'python' then return end
      local fname = vim.api.nvim_buf_get_name(ev.buf)
      if fname:sub(1, #root) ~= root then return end -- only files inside this project
      if vim.bo[ev.buf].modifiable then require('lint').try_lint 'dmypy' end
    end,
  })

  -- Mute pyrefly diagnostics, for clients attaching later and any already attached.
  vim.api.nvim_create_autocmd('LspAttach', {
    group = group,
    callback = function(ev) silence_pyrefly(vim.lsp.get_client_by_id(ev.data.client_id)) end,
  })
  for _, client in ipairs(vim.lsp.get_clients { name = 'pyrefly' }) do
    silence_pyrefly(client)
  end
end

return M
