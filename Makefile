.PHONY: test

# Set the path to themis binary - can be overridden by setting THEMIS_PATH
THEMIS_PATH ?= themis

test:
	$(THEMIS_PATH) test/*.vim
