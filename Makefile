# ============================================================================
# Makefile - gnatmem_fsf build and test targets
# ============================================================================
# Copyright (c) 2026 Michael Gardner, A Bit of Help, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later
# See LICENSE file in the project root.
#
# Purpose:
#   Targets: all/build (debug), debug, release, test, toolcheck, help,
#   clean, distclean. BUILD=debug|release selects the build.
# ============================================================================


SHELL := /bin/sh
BUILD ?= debug
ifeq ($(OS),Windows_NT)
EXE := .exe
else
EXE :=
endif

GPRFLAGS := -P gnatmem_fsf.gpr -XBUILD=$(BUILD)
GNATMEM := bin/$(BUILD)/gnatmem_fsf$(EXE)

.PHONY: all build debug release toolcheck help test clean distclean
all: build
build: toolcheck
	@gprbuild $(GPRFLAGS)
debug:
	@$(MAKE) BUILD=debug build
release:
	@$(MAKE) BUILD=release build
toolcheck:
	@command -v gprbuild >/dev/null 2>&1 || { echo 'ERROR: gprbuild not found in PATH' >&2; exit 1; }
	@command -v gprclean >/dev/null 2>&1 || { echo 'ERROR: gprclean not found in PATH' >&2; exit 1; }
help: build
	@'$(GNATMEM)'; true
test: build
	@bash tests/run_tests.sh '$(GNATMEM)'
clean:
	@gprclean -q $(GPRFLAGS)
	@gprclean -q -P tests/leaker/leaker.gpr
distclean:
	@rm -rf obj bin tests/leaker/obj tests/leaker/bin
