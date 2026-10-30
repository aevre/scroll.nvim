local Animate = require("animate")
local config = require("scroll.config")
local state = require("scroll.state")

---@class scroll
local M = {}

local mouse_scrolling = false
local function keycode(key)
	return vim.api.nvim_replace_termcodes(key, true, true, true)
end

local on_key_callbacks = {}
local on_key_ns
local function on_key(key, callback)
	local code = keycode(key)
	on_key_callbacks[code] = on_key_callbacks[code] or {}
	table.insert(on_key_callbacks[code], callback)
	on_key_ns = on_key_ns
		or vim.on_key(function(resolved, typed)
			for _, cb in ipairs(on_key_callbacks[typed or resolved] or {}) do
				pcall(cb, typed)
			end
		end)
end

local SCROLL_UP, SCROLL_DOWN = keycode("<c-y>"), keycode("<c-e>")

---@type boolean
M.enabled = false
local uv = vim.uv
local debug_timer = uv.new_timer()
local stats = { targets = 0, animating = 0, reset = 0, skipped = 0, scrolls = 0, mousescroll = 0 }

local function is_enabled(buf)
	local current = config.get()
	return M.enabled
		and buf
		and not vim.o.paste
		and vim.fn.reg_executing() == ""
		and vim.fn.reg_recording() == ""
		and (current.filter and current.filter(buf))
		and Animate.enabled({ buf = buf, name = "scroll" })
end

state.configure(is_enabled, function()
	return M.enabled
end)

---@param opts? scroll.Config
function M.setup(opts)
	local current = config.setup(opts)
	Animate.setup(current.animate)
	if current.enabled == false then
		M.disable()
	else
		M.enable()
		if current.debug and debug_timer and not debug_timer:is_active() then
			M.debug()
		elseif not current.debug and debug_timer and debug_timer:is_active() then
			debug_timer:stop()
		end
	end
	return M
end

function M.enable()
	if M.enabled then
		return
	end
	M.enabled = true
	state.clear()

	if config.get().debug then
		M.debug()
	end

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		state.get(win)
	end

	local group = vim.api.nvim_create_augroup("core_scroll", { clear = true })

	on_key("<ScrollWheelDown>", function()
		mouse_scrolling = true
	end)
	on_key("<ScrollWheelUp>", function()
		mouse_scrolling = true
	end)

	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = group,
		callback = vim.schedule_wrap(function(ev)
			for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
				state.get(win)
			end
		end),
	})

	vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function(ev)
			for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
				state.get(win)
			end
		end,
	})

	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		callback = vim.schedule_wrap(function(ev)
			for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
				local current = state.all()[win]
				if current then
					current:update()
				end
			end
		end),
	})

	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		callback = function(ev)
			local win = tonumber(ev.match) --[[@as integer|nil]]
			if win then
				state.reset(win)
			end
		end,
	})

	vim.api.nvim_create_autocmd("CmdlineLeave", {
		group = group,
		callback = function(ev)
			if (ev.file == "/" or ev.file == "?") and vim.o.incsearch then
				for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
					state.reset(win)
				end
			end
		end,
	})

	vim.api.nvim_create_autocmd("WinScrolled", {
		group = group,
		callback = function()
			for win, changes in pairs(vim.v.event) do
				---@diagnostic disable-next-line: assign-type-mismatch
				win = tonumber(win)
				if win and changes.topline ~= 0 then
					M.check(win)
				end
			end
		end,
	})
end

function M.disable()
	if not M.enabled then
		return
	end
	M.enabled = false
	mouse_scrolling = false
	state.clear()
	if on_key_ns then
		vim.on_key(nil, on_key_ns)
		on_key_ns = nil
	end
	on_key_callbacks = {}
	if debug_timer and debug_timer:is_active() then
		debug_timer:stop()
	end
	pcall(vim.api.nvim_del_augroup_by_name, "core_scroll")
end

---@param win integer
---@param from scroll.View
---@param to scroll.View
---@return integer
local function scroll_lines(win, from, to)
	if from.topline == to.topline then
		return math.abs(from.topfill - to.topfill)
	end
	if to.topline < from.topline then
		from, to = to, from
	end
	local start_row, end_row, offset = from.topline - 1, to.topline - 1, 0
	if from.topfill > 0 then
		start_row = start_row + 1
		offset = from.topfill + 1
	end
	if to.topfill > 0 then
		offset = offset - to.topfill
	end
	if not vim.api.nvim_win_text_height then
		return end_row - start_row + offset
	end
	return vim.api.nvim_win_text_height(win, { start_row = start_row, end_row = end_row }).all + offset - 1
end

---@param win integer
function M.check(win)
	local current = state.get(win)
	if not current then
		return
	end
	if vim.wo[current.win].scrollbind and vim.api.nvim_get_current_win() ~= current.win then
		current:stop()
		return
	end
	if mouse_scrolling then
		current:stop()
		mouse_scrolling = false
		stats.mousescroll = stats.mousescroll + 1
		current.current = vim.deepcopy(current.view)
		return
	elseif math.abs(current.view.topline - current.current.topline) <= 1 then
		stats.skipped = stats.skipped + 1
		current.current = vim.deepcopy(current.view)
		return
	end

	stats.scrolls = stats.scrolls + 1
	stats.targets = stats.targets + 1
	current.target = vim.deepcopy(current.view)
	current:stop()
	current:wo({ virtualedit = "all", scrolloff = 0 })

	local now = uv.hrtime()
	local repeat_delta = (now - current.last) / 1e6
	current.last = now
	local current_config = config.get()
	local is_repeat = repeat_delta <= current_config.animate_repeat.delay
	local animation_config = is_repeat and current_config.animate_repeat or current_config.animate
	local opts = vim.tbl_deep_extend("force", vim.deepcopy(animation_config or {}), {
		int = true,
		id = ("scroll%s%d"):format(is_repeat and "_repeat_" or "_", win),
		buf = current.buf,
	}) --[[@as animate.Opts]]

	local scrolls = 0
	local col_from, col_to = 0, 0
	local move_from, move_to = 0, 0
	vim.api.nvim_win_call(current.win, function()
		move_to = vim.fn.winline()
		---@diagnostic disable-next-line: param-type-mismatch
		vim.fn.winrestview(current.current)
		move_from = vim.fn.winline()
		current:update()
		scrolls = scroll_lines(current.win, current.current, current.target)
		col_from = vim.fn.virtcol({ current.current.lnum, current.current.col }) --[[@as integer]]
		col_to = vim.fn.virtcol({ current.target.lnum, current.target.col }) --[[@as integer]]
	end)

	local down = current.target.topline > current.current.topline
		or (current.target.topline == current.current.topline and current.target.topfill < current.current.topfill)
	local scrolled = 0
	current.animation = Animate(0, scrolls, function(value, ctx)
		if not current:valid() then
			current:stop()
			return
		end
		vim.api.nvim_win_call(win, function()
			if ctx.done then
				---@diagnostic disable-next-line: param-type-mismatch
				vim.fn.winrestview(current.target)
				current:update()
				current:stop()
				return
			end
			local count = vim.v.count
			local commands = {}
			local scroll_target = math.floor(value)
			local scroll = scroll_target - scrolled
			if scroll > 0 then
				scrolled = scrolled + scroll
				commands[#commands + 1] = ("%d%s"):format(scroll, down and SCROLL_DOWN or SCROLL_UP)
			end
			local move = math.floor(value * math.abs(move_to - move_from) / scrolls)
			local move_target = move_from + ((move_to < move_from) and -1 or 1) * move
			commands[#commands + 1] = ("%dH"):format(move_target)
			local virtcol = math.floor(col_from + (col_to - col_from) * value / scrolls)
			commands[#commands + 1] = ("%d|"):format(virtcol + 1)
			vim.cmd(("keepjumps normal! %s"):format(table.concat(commands, "")))
			if vim.v.count ~= count then
				local cursor = vim.api.nvim_win_get_cursor(win)
				vim.cmd(("keepjumps normal! %dzh"):format(count))
				vim.api.nvim_win_set_cursor(win, cursor)
			end
			current:update()
		end)
	end, opts)
end

---@private
function M.debug()
	if not debug_timer then
		return
	end
	if debug_timer:is_active() then
		return debug_timer:stop()
	end
	local last = {}
	debug_timer:start(50, 50, function()
		local data = vim.tbl_extend("force", { stats = stats }, state.all())
		for key, value in pairs(data) do
			if not vim.deep_equal(last[key], value) then
				vim.notify(vim.inspect(value))
			end
		end
		last = vim.deepcopy(data)
	end)
end

return M
