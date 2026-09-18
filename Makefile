VIM ?= vim

.PHONY: test

# Vim under -es falls back to reading Ex commands from stdin when a script
# errors, and SIGTERM does not get it out: always feed </dev/null and use a
# hard-kill timeout.
test:
	timeout -s KILL 60 $(VIM) -Nu NONE -i NONE -es --not-a-term -S test/run.vim </dev/null
