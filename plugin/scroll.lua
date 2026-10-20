if vim.g.loaded_scroll_nvim then
	return
end
vim.g.loaded_scroll_nvim = true

require("scroll").setup()
