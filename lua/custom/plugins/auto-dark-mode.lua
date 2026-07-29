-- Follow the OS light/dark appearance: flip 'background' and re-apply the
-- colorscheme whenever macOS switches between light and dark mode, so a
-- long-running Neovim doesn't stay dark on a light desktop (or vice versa).
--
-- Neovim asks the terminal for its background colour at startup (OSC 11) and
-- picks up live changes from terminals that send DEC mode 2031 theme
-- notifications -- but iTerm2 doesn't send those, so nothing tells a running
-- session that the system theme changed. This plugin polls the OS setting
-- instead (`defaults read -g AppleInterfaceStyle` on macOS), which works in any
-- terminal.
--
-- The colorscheme itself is configured in init.lua; it must be loaded as plain
-- 'tokyonight' (not 'tokyonight-night') for these callbacks to have any effect.
return {
  'f-person/auto-dark-mode.nvim',
  lazy = false,
  priority = 999, -- Just after the colorscheme, before everything else.
  opts = {
    -- Setting 'background' alone does not re-source the colorscheme, so load it
    -- again explicitly -- tokyonight reads 'background' to choose its variant.
    set_dark_mode = function()
      vim.o.background = 'dark'
      vim.cmd.colorscheme 'tokyonight'
    end,
    set_light_mode = function()
      vim.o.background = 'light'
      vim.cmd.colorscheme 'tokyonight'
    end,
    update_interval = 3000, -- How often to poll the OS setting, in ms.
    fallback = 'dark', -- Used where the appearance can't be detected (ssh, tty).
  },
}
