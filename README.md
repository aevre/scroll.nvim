# scroll.nvim

A standalone smooth scrolling integration for Neovim. It animates vertical and horizontal cursor movement while preserving normal window scrolling behavior.

[简体中文](README.zh-CN.md)

## Requirements

- Neovim 0.10 or newer.
- [animate.nvim](https://github.com/aevre/animate.nvim).

## Installation

Available on Codeberg: <https://codeberg.org/aevre/scroll.nvim> and GitHub: <https://github.com/aevre/scroll.nvim>.

With lazy.nvim:

```lua
{
  "https://github.com/aevre/scroll.nvim",
  dependencies = {
    "https://github.com/aevre/animate.nvim",
  },
  opts = {},
}
```

The plugin is enabled by default when `setup()` is called. To defer loading until the UI is ready, use your plugin manager's `UIEnter` event.

## Configuration

```lua
require("scroll").setup({
  animate = {
    duration = { step = 10, total = 200 },
    easing = "linear",
  },
  animate_repeat = {
    delay = 100,
    duration = { step = 5, total = 50 },
    easing = "linear",
  },
  filter = function(buf)
    return vim.bo[buf].buftype ~= "terminal"
  end,
})
```

| Option | Default | Description |
| --- | --- | --- |
| `enabled` | `true` when omitted | Enable or disable the integration during setup. |
| `animate` | step `10`, total `200` | Animation options for ordinary scrolls. |
| `animate_repeat` | delay `100`, step `5`, total `50` | Faster animation options for repeated scrolls. |
| `filter` | skips terminal buffers | Function receiving a buffer number. Return true to animate it. |
| `debug` | `false` | Show internal state changes through notifications. |

Animation options are passed to [animate.nvim](https://github.com/aevre/animate.nvim). Set `vim.g.core_scroll = false`, `vim.b[buf].core_scroll = false`, or the corresponding `core_animate` variable to disable animation for a scope.

## API

```lua
local scroll = require("scroll")

scroll.setup(opts?)
scroll.enable()
scroll.disable()
scroll.check(win)
scroll.debug()
```

`enable()` installs the scroll autocmds and initializes visible windows. `disable()` removes them and stops tracking. `check(win)` is available for integrations that need to request an update for a specific window.

## Development

Run `make check` from the repository root. The guarded `plugin/scroll.lua` entrypoint applies defaults; scrolling logic stays under `lua/scroll/`. Keep `setup()` safe when a plugin manager calls it again with user options.
