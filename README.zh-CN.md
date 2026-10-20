# scroll.nvim

一个独立的 Neovim 平滑滚动插件。它对垂直滚动和水平光标移动进行动画处理，同时保留 Neovim 原有的窗口滚动行为。

[English](README.md)

## 环境要求

- Neovim 0.10 或更新版本。
- [animate.nvim](https://codeberg.org/aevre/animate.nvim)。

## 安装

项目托管于 Codeberg：<https://codeberg.org/aevre/scroll.nvim>。

使用 lazy.nvim：

```lua
{
  "https://codeberg.org/aevre/scroll.nvim",
  dependencies = {
    "https://codeberg.org/aevre/animate.nvim",
  },
  opts = {},
}
```

调用 `setup()` 时插件默认启用。需要等 UI 就绪后再加载时，可在插件管理器中使用 `UIEnter` 事件。

## 配置

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

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `enabled` | 未设置时为 `true` | 在 setup 时启用或禁用插件。 |
| `animate` | step `10`、total `200` | 普通滚动使用的动画配置。 |
| `animate_repeat` | delay `100`、step `5`、total `50` | 连续滚动使用的较快动画配置。 |
| `filter` | 跳过 terminal buffer | 接收 buffer 编号的函数，返回 true 才执行动画。 |
| `debug` | `false` | 通过通知显示内部状态变化。 |

动画选项会传给 [animate.nvim](https://codeberg.org/aevre/animate.nvim)。设置 `vim.g.core_scroll = false`、`vim.b[buf].core_scroll = false` 或对应的 `core_animate` 变量，可以按作用域关闭动画。

## API

```lua
local scroll = require("scroll")

scroll.setup(opts?)
scroll.enable()
scroll.disable()
scroll.check(win)
scroll.debug()
```

`enable()` 安装滚动 autocmd 并初始化可见窗口。`disable()` 删除这些 autocmd 并停止跟踪。需要为指定窗口请求更新的集成可以调用 `check(win)`。

## 开发

在仓库根目录运行 `make check`。带 guard 的 `plugin/scroll.lua` 入口应用默认配置，滚动逻辑保留在 `lua/scroll/`。插件管理器随后以用户选项再次调用 `setup()` 时必须保持安全。
