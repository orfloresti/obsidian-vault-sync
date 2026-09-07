.PHONY: install uninstall test check

check:
	@bash scripts/check.sh

install: check
	@bash scripts/install.sh

uninstall:
	@bash scripts/uninstall.sh

test: check
	@bash tests/test_vsync.sh
