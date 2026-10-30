---@class scroll.Configuration
local M = {}

---@type scroll.Config
local defaults = {
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
		return vim.g.core_scroll ~= false and vim.b[buf].core_scroll ~= false and vim.bo[buf].buftype ~= "terminal"
	end,
	debug = false,
}

---@type scroll.Config
local config = vim.deepcopy(defaults)

---@param opts? scroll.Config
---@return scroll.Config
function M.setup(opts)
	config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
	return config
end

---@return scroll.Config
function M.get()
	return config
end

return M
