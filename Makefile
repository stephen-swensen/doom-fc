# doom-fc build. Same shape as ../wolf-fc: every FC source goes through fcc
# into one C file, then cc links it against SDL2. `make check` runs the
# regression suite against a fresh binary.

PREFIX  ?= /usr/local
DESTDIR ?=
bindir  := $(PREFIX)/bin
datadir := $(PREFIX)/share

CC      ?= cc
OPT     ?= -O2
CFLAGS   = -std=gnu11 -w -g $(OPT)
LIBS     = -lSDL2 -lm

UNAME_S := $(shell uname -s 2>/dev/null)
ifeq ($(UNAME_S),Darwin)
    BUILD_OS := macos
else ifeq ($(UNAME_S),Linux)
    BUILD_OS := linux
else
    BUILD_OS := $(UNAME_S)
endif
BUILD_DIR := build/$(BUILD_OS)

INSTALL_DATA_DIR := $(datadir)/doom-fc/data

ifeq ($(NATIVE),1)
    BIN := $(BUILD_DIR)/doom-fc-native
else
    BIN := $(BUILD_DIR)/doom-fc
endif
GEN_C  := $(BUILD_DIR)/doom-fc.c
GEN_FC := $(BUILD_DIR)/install_path.fc

# Low-level first, entry point last (fcc doesn't care about order).
SRCS_FC := $(addprefix src/,sdl2.fc libc.fc png.fc gamma.fc random.fc opl2_tables.fc opl2.fc opl_midi.fc tables.fc info.fc sounds.fc dstrings.fc \
           defs.fc system.fc doomstat.fc video.fc render.fc sound.fc music.fc play.fc hud.fc \
           automap.fc wipe.fc finale.fc intermission.fc menu.fc game.fc interp.fc \
           dmain.fc main.fc)
SRCS_FC := $(filter $(wildcard src/*.fc),$(SRCS_FC))

ifeq ($(strip $(FCC_STDLIB)),)
    FCC_BIN     := $(shell command -v fcc 2>/dev/null)
    FCC_PREFIX  := $(patsubst %/bin,%,$(patsubst %/,%,$(dir $(FCC_BIN))))
    STDLIB_DIR  := $(FCC_PREFIX)/share/fcc/stdlib
else
    STDLIB_DIR  := $(FCC_STDLIB)
endif
SRCS_STDLIB := $(addprefix $(STDLIB_DIR)/,io.fc text.fc sys.fc math.fc)

.PHONY: all dev native clean install uninstall check help print-bin FORCE

all: $(BIN)

print-bin:
	@echo $(BIN)

ifeq ($(NATIVE),1)
$(BIN): $(SRCS_FC) $(GEN_FC) | $(BUILD_DIR)
	fcc --native $(SRCS_FC) $(GEN_FC) $(SRCS_STDLIB) -o $@ $(LIBS)
else
$(BIN): $(GEN_C)
	$(CC) $(CFLAGS) -o $@ $(GEN_C) $(LIBS)
endif

$(GEN_C): $(SRCS_FC) $(GEN_FC) | $(BUILD_DIR)
	fcc $(SRCS_FC) $(GEN_FC) $(SRCS_STDLIB) -o $@

$(GEN_FC): FORCE | $(BUILD_DIR)
	@printf 'module install_path =\n    let data_dir = "%s"\n' "$(INSTALL_DATA_DIR)" > $@.tmp
	@if cmp -s $@.tmp $@ 2>/dev/null; then rm $@.tmp; else mv $@.tmp $@; fi

FORCE:

$(BUILD_DIR):
	@mkdir -p $@

dev:
	@$(MAKE) clean
	@$(MAKE) OPT=-O0

native:
	@$(MAKE) --no-print-directory NATIVE=1

clean:
	rm -rf build

install: $(BIN)
	install -d $(DESTDIR)$(bindir)
	install -m 755 $(BIN) $(DESTDIR)$(bindir)/doom-fc
	@if ls data/*.WAD >/dev/null 2>&1; then \
		install -d $(DESTDIR)$(INSTALL_DATA_DIR); \
		install -m 644 data/*.WAD $(DESTDIR)$(INSTALL_DATA_DIR)/; \
		echo "installed IWADs to $(DESTDIR)$(INSTALL_DATA_DIR)/"; \
	else \
		echo "note: no ./data/*.WAD found — install IWADs to $(INSTALL_DATA_DIR)/ or set DOOM_FC_DATA_DIR"; \
	fi

uninstall:
	rm -f $(DESTDIR)$(bindir)/doom-fc
	rm -rf $(DESTDIR)$(datadir)/doom-fc

check: $(BIN)
	bash tests/run-tests.sh

help:
	@echo "Targets: all (default), dev, native, clean, install, uninstall, check, print-bin"
