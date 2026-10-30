LUA_FILES := $(shell find lua plugin -name '*.lua')

.PHONY: fmt fmt-check lint check test

fmt:
	stylua $(LUA_FILES)

fmt-check:
	stylua --check $(LUA_FILES)

lint:
	selene $(LUA_FILES)

check: fmt-check lint

test:
	NVIM_BIN="$${NVIM_BIN:-nvim}"; "$$NVIM_BIN" --headless -u NONE --cmd 'set rtp+=.,../animate.nvim' -l tests/recording.lua
