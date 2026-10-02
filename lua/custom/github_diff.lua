-- GitHub-style diff colours, painted over whichever colorscheme is loaded.
--
-- Two things make GitHub's diffs easy to scan, and this copies both:
--
--   1. Its own palette (Primer): a faintly tinted line, with the words that
--      changed inside it in a stronger shade of the same colour.
--   2. In the split view, the old side of a *modified* line is red and the new
--      side green. Vim's diff mode instead paints a modified line with a single
--      DiffChange colour on both sides, so most of a real diff reads as the same
--      colour left and right. `M.diffview_win_enter` remaps the diff groups per
--      pane in diffview to fix that.
--
-- The colours are re-applied on every `ColorScheme`, so they survive
-- auto-dark-mode flipping between light and dark, and a change of theme.
--
-- Wire-up: `M.setup()` before the first `:colorscheme`, and
-- `hooks = { diff_buf_win_enter = M.diffview_win_enter }` in diffview's setup.

local M = {}

-- GitHub's diff palette. Dark mode defines it as translucent colours over its
-- #0d1117 page, so they're blended over our own background to keep the same
-- tint on a lighter page; light mode uses solid tints on white, which read fine
-- as they are on a grey light background (and keep text contrast higher than a
-- tint multiplied into the grey would).
--
-- Plain `:diffthis` can't tell the old side from the new, so its changed lines
-- get GitHub's accent blue instead of red/green.
--
-- The dark line tints are stronger than GitHub's (0.15 green, 0.10 red):
-- tokyonight's page is lighter and bluer than GitHub's, which pulled the red
-- towards a dull maroon that merged into it. At these values both lines stand
-- out from the background equally (about 1.3:1).
local palette = {
  dark = {
    add = { color = '#2ea043', line = 0.18, word = 0.40 },
    delete = { color = '#f85149', line = 0.20, word = 0.40 },
    change = { color = '#388bfd', line = 0.10, word = 0.40 },
  },
  light = {
    add = { line = '#e6ffec', word = '#abf2bc' },
    delete = { line = '#ffebe9', word = '#ffc1c0' }, -- rgba(255,129,130,.4) on the line
    change = { line = '#ddf4ff', word = '#b6e3ff' },
  },
}

local function rgb(hex) return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16) end

-- `alpha` of `fg` painted over `bg`, as CSS rgba() composites it.
local function over(fg, alpha, bg)
  local fr, fg_, fb = rgb(fg)
  local br, bg_, bb = rgb(bg)
  local function mix(f, b) return math.floor(alpha * f + (1 - alpha) * b + 0.5) end
  return ('#%02x%02x%02x'):format(mix(fr, br), mix(fg_, bg_), mix(fb, bb))
end

-- Resolve one palette entry to { line = hex, word = hex }. GitHub layers the
-- word highlight over the already-tinted line, so blend it over that.
local function shades(spec, bg)
  if not spec.color then return spec end
  local line = over(spec.color, spec.line, bg)
  return { line = line, word = over(spec.color, spec.word, line) }
end

function M.apply()
  local p = palette[vim.o.background] or palette.dark
  local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
  -- A transparent theme has no Normal bg; fall back to GitHub's own page.
  local bg = normal.bg and ('#%06x'):format(normal.bg) or (vim.o.background == 'light' and '#ffffff' or '#0d1117')
  local fg = normal.fg and ('#%06x'):format(normal.fg) or nil
  local add, delete, change = shades(p.add, bg), shades(p.delete, bg), shades(p.change, bg)

  local function set(name, val) vim.api.nvim_set_hl(0, name, val) end

  -- What the diffview panes are remapped to, below.
  set('GitHubDiffAdd', { bg = add.line })
  set('GitHubDiffAddText', { bg = add.word })
  set('GitHubDiffDelete', { bg = delete.line })
  set('GitHubDiffDeleteText', { bg = delete.word })

  -- Plain diff mode (`:diffthis`, `:Gitsigns diffthis`), and the base that
  -- diffview's own groups link to. DiffTextAdd (text that exists on one side
  -- only) links to DiffText by default.
  set('DiffAdd', { bg = add.line })
  set('DiffDelete', { bg = delete.line })
  set('DiffChange', { bg = change.line })
  set('DiffText', { bg = change.word })

  -- Neogit's status-buffer diff (unified, so +/- lines already tell old from
  -- new). Neogit draws the line text in a muted git colour that all but
  -- vanishes on a tinted line, so use plain text and let the background carry
  -- it; `*Highlight` is the hunk under the cursor, `*Inline` the changed words.
  -- Neogit only fills in groups that are still empty, so these stick.
  set('NeogitDiffAdd', { bg = add.line, fg = fg })
  set('NeogitDiffAddHighlight', { bg = add.line, fg = fg })
  set('NeogitDiffAddInline', { bg = add.word })
  set('NeogitDiffDelete', { bg = delete.line, fg = fg })
  set('NeogitDiffDeleteHighlight', { bg = delete.line, fg = fg })
  set('NeogitDiffDeleteInline', { bg = delete.word })
end

function M.setup()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('custom.github_diff', { clear = true }),
    desc = 'Paint GitHub diff colours over the colorscheme',
    callback = M.apply,
  })
  if vim.g.colors_name then M.apply() end
end

-- Per-pane diff groups for diffview's two-way layouts. `a` is the old side and
-- `b` the new: a modified line goes red on the left and green on the right, a
-- line present on one side only takes that side's colour, and the filler rows
-- padding the other side are dimmed, since they hold no content.
local panes = {
  a = { line = 'GitHubDiffDelete', text = 'GitHubDiffDeleteText' },
  b = { line = 'GitHubDiffAdd', text = 'GitHubDiffAddText' },
}

-- Diffview's `diff_buf_win_enter` hook. It runs inside the diff window after
-- diffview has applied its own window options, so this 'winhighlight' wins.
-- Three- and four-way merge layouts keep diffview's defaults.
function M.diffview_win_enter(_, _, ctx)
  local pane = ctx.layout_name:match '^diff2' and panes[ctx.symbol]
  if not pane then return end
  vim.opt_local.winhighlight = {
    DiffAdd = pane.line,
    DiffChange = pane.line,
    DiffText = pane.text,
    DiffTextAdd = pane.text,
    DiffDelete = 'DiffviewDiffDeleteDim',
  }
end

return M
