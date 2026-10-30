local M = {}

---@type table<integer, scroll.State>
local states = {}
---@type fun(buf: integer): boolean
local is_enabled = function(_buf)
	return false
end
---@type fun(): boolean
local plugin_enabled = function()
	return false
end

---@param enabled fun(buf: integer): boolean
---@param active fun(): boolean
function M.configure(enabled, active)
	is_enabled = enabled
	plugin_enabled = active
end

---@class scroll.State
local State = {}
State.__index = State

---@param win integer
---@return scroll.State?
function M.get(win)
	local buf = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win)
	if not buf or not is_enabled(buf) then
		if states[win] then
			states[win]:stop()
		end
		states[win] = nil
		return nil
	end

	---@type scroll.View
	local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
	local ret = states[win]
	if not (ret and ret:valid()) then
		if ret then
			ret:stop()
		end
		ret = setmetatable({
			buf = buf,
			_wo = {},
			changedtick = vim.api.nvim_buf_get_changedtick(buf),
			current = vim.deepcopy(view),
			last = 0,
			target = vim.deepcopy(view),
			win = win,
		}, State)
	end

	ret.scrolloff = ret._wo.scrolloff or vim.wo[win].scrolloff
	ret.view = view
	states[win] = ret
	return ret
end

---@param self scroll.State
function State:stop()
	self:wo()
	if self.animation then
		self.animation:stop()
		self.animation = nil
	end
end

---@param self scroll.State
---@param opts? table<string, any>
function State:wo(opts)
	if not opts then
		if vim.api.nvim_win_is_valid(self.win) then
			for key, value in pairs(self._wo) do
				---@diagnostic disable-next-line: assign-type-mismatch
				vim.wo[self.win][key] = value
			end
		end
		self._wo = {}
		return
	end
	for key, value in pairs(opts) do
		self._wo[key] = self._wo[key] or vim.wo[self.win][key]
		vim.wo[self.win][key] = value
	end
end

---@param self scroll.State
---@return boolean
function State:valid()
	return plugin_enabled()
		and states[self.win] == self
		and vim.api.nvim_win_is_valid(self.win)
		and vim.api.nvim_buf_is_valid(self.buf)
		and is_enabled(self.buf)
		and vim.api.nvim_win_get_buf(self.win) == self.buf
		and vim.api.nvim_buf_get_changedtick(self.buf) == self.changedtick
end

---@param self scroll.State
function State:update()
	if vim.api.nvim_win_is_valid(self.win) then
		self.current = vim.api.nvim_win_call(self.win, vim.fn.winsaveview)
	end
end

---@param win integer
function M.reset(win)
	if states[win] then
		states[win]:stop()
		states[win] = nil
	end
end

---@return table<integer, scroll.State>
function M.all()
	return states
end

function M.clear()
	for _, state in pairs(states) do
		state:stop()
	end
	states = {}
end

return M
