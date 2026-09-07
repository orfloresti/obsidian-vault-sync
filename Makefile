.PHONY: install uninstall test

install:
	@bash scripts/install.sh

uninstall:
	@bash scripts/uninstall.sh

test:
	@bash tests/test_vsync.sh
