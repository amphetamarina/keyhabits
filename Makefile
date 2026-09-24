NVIM ?= nvim
STYLUA ?= stylua
LUALS ?= lua-language-server

.PHONY: test lint

# --clean keeps the user's config and plugins out of the specs.
test:
	timeout -s KILL 120 $(NVIM) --headless --clean -l tests/run.lua </dev/null

# The language server needs Neovim's runtime for the vim.* types; its path is
# asked from Neovim, so the config is written at run time.
lint:
	$(STYLUA) --check lua plugin tests
	@runtime=$$($(NVIM) --clean --headless -c 'lua io.write(vim.env.VIMRUNTIME)' -c qa 2>&1); \
	config=$$(mktemp); \
	printf '{"runtime.version":"LuaJIT","workspace.library":["%s/lua"],"workspace.checkThirdParty":false}' "$$runtime" > $$config; \
	$(LUALS) --check lua --checklevel=Warning --configpath=$$config; status=$$?; rm -f $$config; exit $$status
