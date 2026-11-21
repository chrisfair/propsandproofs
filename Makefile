SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

ROOT_DIR := $(CURDIR)
NIMBLE_DIR ?= $(ROOT_DIR)/.nimble
GODOT_BIN ?= /usr/bin/godot

BUILD_DIR ?= $(ROOT_DIR)/build
NIMCACHE_UNIT_DIR ?= $(BUILD_DIR)/nimcache_unit
NIMCACHE_TEST_DIR ?= $(BUILD_DIR)/nimcache_test
COVERAGE_DIR ?= $(ROOT_DIR)/build/coverage
COVERAGE_MIN_PCT ?= 85.0

TEST_ENTRY := tests/test_all.nim
TEST_BIN := $(BUILD_DIR)/test_runner
COVERAGE_REPORT := $(COVERAGE_DIR)/summary.md

MISE_EXEC := $(shell command -v nim >/dev/null 2>&1 || echo "mise exec --")

export NIMBLE_DIR
export PATH := $(NIMBLE_DIR)/bin:$(PATH)

.PHONY: help all check test unit-test coverage cov report deps build smoke run dev editor clean

help: ## Show available targets for testing, coverage, building, and running
	@printf "Props & Proofs (Nim + Godot 4) targets:\n\n"
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@printf "\nVariables:\n"
	@printf "  COVERAGE_MIN_PCT=%s  Minimum required Nim line coverage percentage\n" "$(COVERAGE_MIN_PCT)"
	@printf "  GODOT_BIN=%s         Godot 4 executable path\n" "$(GODOT_BIN)"

all: check build ## Run unit tests, enforce >= 85% coverage, and build GDExtension

check: test coverage ## Run unit tests and enforce minimum code coverage

test: ## Compile and run headless Nim unit & logic/modal/AI tests
	@mkdir -p "$(BUILD_DIR)" "$(NIMCACHE_UNIT_DIR)"
	$(MISE_EXEC) env NIMBLE_DIR="$(NIMBLE_DIR)" \
		nim c -r \
		--path:nim/src \
		--nimCache:"$(NIMCACHE_UNIT_DIR)" \
		-o:"$(TEST_BIN)" \
		"$(TEST_ENTRY)"

unit-test: test ## Alias for test

coverage: ## Run gcov-instrumented unit tests and enforce >= COVERAGE_MIN_PCT% coverage
	$(MISE_EXEC) env \
		NIMBLE_DIR="$(NIMBLE_DIR)" \
		NIMCACHE_TEST_DIR="$(NIMCACHE_TEST_DIR)" \
		COVERAGE_DIR="$(COVERAGE_DIR)" \
		COVERAGE_MIN_PCT="$(COVERAGE_MIN_PCT)" \
		bash scripts/check_coverage.sh

cov: coverage ## Alias for coverage

report: $(COVERAGE_REPORT) ## Print the latest markdown coverage summary
	@cat "$(COVERAGE_REPORT)"

$(COVERAGE_REPORT):
	@$(MAKE) --no-print-directory coverage

deps: ## Install project-local Nimble dependencies (gdext)
	rm -rf "$(NIMBLE_DIR)"/pkgs2/gdext-*
	$(MISE_EXEC) env NIMBLE_DIR="$(NIMBLE_DIR)" \
		nimble install -y 'https://github.com/godot-nim/gdext-nim@#v0.17.1'

build: ## Compile the Nim GDExtension shared library for Godot 4
	@mkdir -p .godot
	@printf "res://nim/PropsAndProofs.gdextension\n" > .godot/extension_list.cfg
	cd nim && $(MISE_EXEC) env NIMBLE_DIR="$(NIMBLE_DIR)" nim c bootstrap.nim

smoke: build ## Run headless Godot 4 integration smoke check
	"$(GODOT_BIN)" --headless --path . --quit-after 10

run: build ## Build Nim GDExtension and launch Props & Proofs in Godot 4
	"$(GODOT_BIN)" --path .

dev: run ## Alias for run

editor: build ## Build Nim GDExtension and open the Godot 4 editor
	"$(GODOT_BIN)" --editor --path .

clean: ## Remove compiled unit test binaries, nimcache, and coverage artifacts
	rm -rf "$(BUILD_DIR)"
