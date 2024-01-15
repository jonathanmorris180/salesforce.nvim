# we disable the `all` command because some external tool might run it automatically
.SUFFIXES:
.PHONY: deps

all:

# runs all the test files.
test:
	nvim --version | head -n 1 && echo ''
	nvim --headless --noplugin -u ./scripts/minimal_init.lua \
		-c "lua MiniTest.run({ execute = { reporter = MiniTest.gen_reporter.stdout({ group_depth = 1 }) } })"

test-debug:
	export DEBUG=true && $(MAKE) test

# installs `mini.nvim`, used for both the tests and documentation.
deps:
	@mkdir -p deps
	@test -d deps/mini.nvim || git clone --depth 1 https://github.com/echasnovski/mini.nvim deps/mini.nvim
	@test -d deps/plenary.nvim || git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git deps/plenary.nvim
	@test -d deps/nvim-treesitter || git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter.git deps/nvim-treesitter

# installs deps before running tests, useful for the CI.
test-ci: deps test

# generates the documentation.
documentation:
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua require('mini.doc').generate()" -c "qa!"

# installs deps before running the documentation generation, useful for the CI.
documentation-ci: deps documentation

# performs a lint check and fixes issue if possible, following the config in `stylua.toml`.
lint:
	stylua .
