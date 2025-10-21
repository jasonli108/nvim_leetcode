# Makefile

.PHONY: test

test:
	@echo "Running tests..."
	@nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
