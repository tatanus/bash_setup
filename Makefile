SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

SHS          := $(shell git ls-files '*.sh' 2>/dev/null)
BINS         := $(shell find menu -type f -perm -111 2>/dev/null)
BATS         := $(shell command -v bats 2>/dev/null)
SHFMT_OPTS   := -i 4 -ci -sr

# Versioning (optional)
VERSION_FILE ?= VERSION
SEMVER_RE    := ^[0-9]+\.[0-9]+\.[0-9]+$

# --------------------------------------------------------------------
# Help
# --------------------------------------------------------------------
.PHONY: help
help: ## Show help
	@awk 'BEGIN{FS=":.*##"; print "Targets:"} /^[a-zA-Z0-9_.-]+:.*##/{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# --------------------------------------------------------------------
# Submodules
# --------------------------------------------------------------------
.PHONY: submodules-init submodules-update submodules-lock init update
submodules-init: ## git submodule init + sync + recursive update
	git submodule sync --recursive
	git submodule update --init --recursive

submodules-update: ## update submodules to latest tracked branches
	git submodule foreach 'git fetch --tags --all || true'
	git submodule update --remote --merge --recursive

submodules-lock: ## record current submodule commits (no fetch)
	git add .gitmodules
	git submodule status

init: submodules-init     ## alias
update: submodules-update ## alias

# --------------------------------------------------------------------
# Code quality
# --------------------------------------------------------------------
.PHONY: fmt lint test ci
fmt: ## Format with shfmt
	@if [ -n "$(SHS)" ]; then shfmt -w $(SHFMT_OPTS) $(SHS); else echo "No *.sh files to format."; fi

lint: ## Lint with shellcheck
	@if [ -n "$(SHS)" ]; then shellcheck -x $(SHS); else echo "No *.sh files to lint."; fi

test: ## Run bats tests
	@if [ -z "$(BATS)" ]; then echo "bats not installed"; exit 1; fi
	@if ls tests/*.bats >/dev/null 2>&1; then bats -r tests; else echo "No tests/ found; ok."; fi

ci: submodules-init fmt lint test ## Format + lint + test

# --------------------------------------------------------------------
# Versioning (optional)
# --------------------------------------------------------------------
.PHONY: version show-version set-version tag release check-version
version show-version: ## Print current version
	@if [ ! -f "$(VERSION_FILE)" ]; then echo "0.0.0" > $(VERSION_FILE); fi
	@echo "Version: $$(cat $(VERSION_FILE))"

set-version: ## Set VERSION file (V=MAJOR.MINOR.PATCH)
	@test -n "$(V)" || (echo "Usage: make set-version V=1.2.3" && exit 2)
	@echo "$(V)" | grep -Eq '$(SEMVER_RE)' || (echo "Invalid version: $(V)"; exit 2)
	@echo "$(V)" > $(VERSION_FILE)
	@git add $(VERSION_FILE)
	@git commit -m "chore: bump version to $(V)" || true
	@echo "Set version to $(V)"

tag: ## Create annotated git tag from VERSION
	@test -f $(VERSION_FILE) || (echo "Missing $(VERSION_FILE)"; exit 2)
	@v=$$(cat $(VERSION_FILE)); echo "$$v" | grep -Eq '$(SEMVER_RE)' || (echo "Invalid version: $$v"; exit 2)
	@git tag -a "v$$v" -m "Release v$$v"
	@echo "Tagged v$$v"

release: ## Bump VERSION, tag, and push with tags (V=1.2.3)
	@test -n "$(V)" || (echo "Usage: make release V=1.2.3" && exit 2)
	$(MAKE) set-version V=$(V)
	$(MAKE) tag
	@git push --follow-tags

check-version: ## Validate VERSION file format
	@test -f $(VERSION_FILE) || (echo "Missing $(VERSION_FILE)"; exit 2)
	@v=$$(cat $(VERSION_FILE)); echo "$$v" | grep -Eq '$(SEMVER_RE)' || (echo "Invalid version: $$v"; exit 2)
	@echo "VERSION OK: $$v"

# --------------------------------------------------------------------
# Install / Run
# --------------------------------------------------------------------
.PHONY: install run
install: ## Install menu scripts into /usr/local/bin
	install -d /usr/local/bin
	@if [ -n "$(BINS)" ]; then \
	  for f in $(BINS); do install -m 0755 $$f /usr/local/bin/$$(basename $$f); done; \
	else echo "No executable files in menu/"; fi

run: ## Run the setup menu
	bash menu/setup-menu.sh

# --------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------
.PHONY: clean
clean: ## Clean temp files
	find . -type f -name '*.tmp' -delete 2>/dev/null || true
