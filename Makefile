SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

SHS          := $(shell git ls-files '*.sh' 2>/dev/null)
BATS         := $(shell command -v bats 2>/dev/null)
SHFMT_OPTS   := -i 4 -ci -sr

# Versioning
VERSION_FILE ?= VERSION
# Accept both classic 3-part semver and the project's 4-part date scheme
# (YYYY.MM.DD.N), e.g. 2026.06.25.0.
SEMVER_RE    := ^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$

# --------------------------------------------------------------------
# Help
# --------------------------------------------------------------------
.PHONY: help
help: ## Show help
	@awk 'BEGIN{FS=":.*##"; print "Targets:"} /^[a-zA-Z0-9_.-]+:.*##/{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# --------------------------------------------------------------------
# Code quality
# --------------------------------------------------------------------
.PHONY: fmt fmt-check lint test ci style
fmt: ## Format with shfmt (writes in place)
	@if [ -n "$(SHS)" ]; then shfmt -w $(SHFMT_OPTS) $(SHS); else echo "No *.sh files to format."; fi

fmt-check: ## Check formatting without writing (CI-safe)
	@if [ -n "$(SHS)" ]; then shfmt -d $(SHFMT_OPTS) $(SHS); else echo "No *.sh files to check."; fi

lint: ## Lint with shellcheck
	@if [ -n "$(SHS)" ]; then shellcheck -x $(SHS); else echo "No *.sh files to lint."; fi

test: ## Run bats tests
	@if [ -z "$(BATS)" ]; then echo "bats not installed"; exit 1; fi
	@if ls tests/*.bats >/dev/null 2>&1; then bats -r tests; else echo "No tests/ found; ok."; fi

style: ## Run comprehensive style checks
	@bash tools/check_bash_style.sh

ci: fmt-check lint test ## Format check + lint + test (non-mutating)

# --------------------------------------------------------------------
# Versioning
# --------------------------------------------------------------------
.PHONY: version show-version set-version tag release release-today check-version
version show-version: ## Print current version
	@if [ ! -f "$(VERSION_FILE)" ]; then echo "0.0.0" > $(VERSION_FILE); fi
	@echo "Version: $$(cat $(VERSION_FILE))"

set-version: ## Set VERSION file (V=YYYY.MM.DD.N)
	@test -n "$(V)" || { echo "Usage: make set-version V=2026.06.25.0"; exit 2; }
	@echo "$(V)" | grep -Eq '$(SEMVER_RE)' || { echo "Invalid version: $(V)"; exit 2; }
	@echo "$(V)" > $(VERSION_FILE)
	@git add $(VERSION_FILE)
	@git commit -m "chore: bump version to $(V)" || true
	@echo "Set version to $(V)"

tag: ## Create annotated git tag from VERSION
	@test -f $(VERSION_FILE) || { echo "Missing $(VERSION_FILE)"; exit 2; }
	@v=$$(cat $(VERSION_FILE)); \
		echo "$$v" | grep -Eq '$(SEMVER_RE)' || { echo "Invalid version: $$v"; exit 2; }; \
		git tag -a "v$$v" -m "Release v$$v"; \
		echo "Tagged v$$v"

release: ci ## Cut release: stamp CHANGELOG + bump VERSION + commit + tag + push (V=YYYY.MM.DD.N)
	@test -n "$(V)" || { echo "Usage: make release V=2026.06.25.0"; exit 2; }
	@echo "$(V)" | grep -Eq '$(SEMVER_RE)' || { echo "Invalid version: $(V)"; exit 2; }
	@test -z "$$(git status --porcelain)" || { echo "Working tree not clean; commit or stash first"; exit 2; }
	@test -f CHANGELOG.md || { echo "CHANGELOG.md not found"; exit 2; }
	@grep -q '^## \[Unreleased\]' CHANGELOG.md || { echo "CHANGELOG.md has no [Unreleased] section"; exit 2; }
	@! grep -q "^## \[$(V)\] " CHANGELOG.md || { echo "CHANGELOG.md already has [$(V)] entry"; exit 2; }
	@today=$$(date -u +%Y-%m-%d); \
		awk -v v="$(V)" -v d="$$today" '/^## \[Unreleased\]/{print; print ""; print "## [" v "] - " d; next} 1' CHANGELOG.md > CHANGELOG.md.tmp \
		&& mv CHANGELOG.md.tmp CHANGELOG.md \
		|| { rm -f CHANGELOG.md.tmp; echo "Failed to stamp CHANGELOG"; exit 2; }
	@echo "$(V)" > $(VERSION_FILE)
	@git add $(VERSION_FILE) CHANGELOG.md
	@git commit -m "chore(release): cut $(V)"
	@git tag -a "v$(V)" -m "Release v$(V)"
	@git push --follow-tags
	@echo "Released v$(V)"

release-today: ## Cut release using today's UTC date (override with N=1 for 2nd cut of day)
	@$(MAKE) --no-print-directory release V=$$(date -u +%Y.%m.%d).$${N:-0}

check-version: ## Validate VERSION file format
	@test -f $(VERSION_FILE) || { echo "Missing $(VERSION_FILE)"; exit 2; }
	@v=$$(cat $(VERSION_FILE)); \
		echo "$$v" | grep -Eq '$(SEMVER_RE)' || { echo "Invalid version: $$v"; exit 2; }; \
		echo "VERSION OK: $$v"

# --------------------------------------------------------------------
# Install / Run
# --------------------------------------------------------------------
.PHONY: install update uninstall
install: ## Install dotfiles
	@bash install.sh install

update: ## Update changed dotfiles only
	@bash install.sh update

uninstall: ## Restore original dotfiles
	@bash install.sh uninstall

# --------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------
.PHONY: clean
clean: ## Clean temp files
	find . -type f -name '*.tmp' -delete 2>/dev/null || true
	find . -type f -name '.DS_Store' -delete 2>/dev/null || true
