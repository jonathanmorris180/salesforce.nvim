# disable the `all` command because some external tool might run it automatically
.SUFFIXES:
.PHONY: deps

all:

test:
	nvim --version | head -n 1 && echo ""
	nvim --headless --noplugin -u ./scripts/minimal_init.lua \
		-c "lua MiniTest.run({ execute = { reporter = MiniTest.gen_reporter.stdout({ group_depth = 1 }) }, script_path = 'scripts/minitest.lua' })"

test-debug:
	export DEBUG=true && $(MAKE) test

deps:
	@mkdir -p deps
	@test -d deps/mini.nvim || git clone --depth 1 https://github.com/echasnovski/mini.nvim deps/mini.nvim
	@test -d deps/plenary.nvim || git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git deps/plenary.nvim
	@test -d deps/nvim-treesitter || git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter.git deps/nvim-treesitter

test-ci: deps test

# generates the documentation
documentation:
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua require('mini.doc').generate()" -c "qa!"

documentation-ci: deps documentation

lint:
	stylua .
