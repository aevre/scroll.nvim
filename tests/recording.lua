-- Run from the repository root:
-- nvim --headless -u NONE --cmd 'set rtp+=.,../animate.nvim' -l tests/recording.lua
local scroll = require("scroll")

vim.cmd("vnew")
local win = vim.api.nvim_get_current_win()
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_win_set_buf(win, buf)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.fn["repeat"]({ "scroll regression" }, 300))
vim.wo[win].scrolloff = 3
vim.wo[win].virtualedit = ""

local function reset()
	scroll.disable()
	vim.fn.winrestview({ topline = 1, lnum = 1, col = 0 })
	scroll.setup()
end

local function start()
	vim.fn.winrestview({ topline = 60, lnum = 65, col = 0 })
	scroll.check(win)
end

local function restored()
	return vim.wo[win].virtualedit == "" and vim.wo[win].scrolloff == 3
end

-- A completed recording must not disable future scrolling.
vim.api.nvim_feedkeys("qajq", "xt", false)
assert(vim.fn.reg_recorded() == "a" and vim.fn.reg_recording() == "")
reset()
start()
assert(vim.wo[win].virtualedit == "all", "scrolling disabled after recording a macro")
assert(vim.wait(1000, restored), "animation did not restore window options")

-- Starting a recording or disabling animation must also stop an active animation.
for _, condition in ipairs({ "recording", "paste", "core_scroll", "core_animate" }) do
	reset()
	start()
	assert(vim.wo[win].virtualedit == "all")
	if condition == "recording" then
		vim.api.nvim_feedkeys("qa", "xt", false)
	elseif condition == "paste" then
		vim.o.paste = true
	else
		vim.g[condition] = false
	end
	assert(vim.wait(1000, restored), "animation continued during " .. condition)
	if condition == "recording" then
		vim.api.nvim_feedkeys("q", "xt", false)
	elseif condition == "paste" then
		vim.o.paste = false
	else
		vim.g[condition] = nil
	end
end

-- Buffer replacement and window closure must clean up active animations.
reset()
start()
vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(false, true))
vim.api.nvim_buf_delete(buf, { force = true })
assert(vim.wait(1000, restored), "buffer replacement did not restore window options")
scroll.disable()
vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn["repeat"]({ "scroll regression" }, 300))
reset()
start()
vim.api.nvim_win_close(win, true)
assert(vim.wait(300, function()
	return not vim.api.nvim_win_is_valid(win)
end))
vim.wait(250, function()
	return false
end)
scroll.check(win)
scroll.disable()
assert(vim.v.errmsg == "", vim.v.errmsg)
print("scroll recording/lifecycle regression checks passed")
