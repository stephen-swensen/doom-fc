# CLAUDE.md

## Mission

doom-fc is a port of id Software's linuxdoom-1.10 to FC, and an end-to-end
FC demo. Unlike wolf-fc, it is **not** license-clean, and that is
deliberate. The user chose to transpose the GPL source "with abandon", so
the port started as a close transposition: names, structure, comments and
bugs. The project is GPL v2.

- **The port is now ours to evolve.** Since the transposition was finished,
  the user wants the code free to depart from linuxdoom and to use FC idioms
  where they fit, done opportunistically rather than as a rewrite. Consult
  linuxdoom when a question needs an authoritative answer. Existing
  linuxdoom names and comments can stay where they still help.
- **OG means `../DOOM/linuxdoom-1.10/`.** Behaviour questions are settled
  there. The playsim must stay in sync with it tic for tic. `make check`
  diffs `-tictrace` output against linuxdoom built from that tree
  (`tools/refdemo`) for every IWAD demo. Any divergence in a demo trace is a
  bug in the port.
- **Data files are user-supplied**, following wolf-fc's precedent. IWADs go in
  `data/` (gitignored), `$DOOM_FC_DATA_DIR`, or the install dir. The engine
  reads WADs directly, with no conversion step.
- **Deliberate departures from linuxdoom** are listed in README.md. Add to
  that list whenever behaviour intentionally differs.
- **Obvious linuxdoom playsim bugs are fixed, but only outside demos.** If a
  fix could change a demo, keep the original behaviour while
  `ds.demo_compat()` is true (a demo is playing or recording), so IWAD
  demos and demos recorded here stay in sync. A fix that only changes a
  case where the original would crash (EV_DoDonut) needs no gate. Leave the
  original as a comment next to the fix.

## Sibling repositories

- `../fc-lang/`: the compiler and stdlib. Read `spec/examples.fc` at the
  start of a session. `spec/fc-spec.html` is authoritative. Use the
  installed `fcc` on `PATH`.
- `../DOOM/linuxdoom-1.10/`: the source being ported. Files use tabs, so
  read them through a tab-expanding filter.
- `../wolf-fc/`: the sister project. Its build, data-dir, headless-test and
  SDL patterns are mirrored here.

## Build and test

- `make` builds `build/<os>/doom-fc`. `make check` runs `tests/run-tests.sh`
  against a fresh binary. `make native` uses `fcc --native`.
- Everything testable runs `-headless` (no window or audio, singletics,
  deterministic). See README for `-script`, `-shotdir`, `-shotevery`,
  `-quitat`, `-demostats`, `-tictrace` and `-musictest`. Screenshots are PNGs
  you can open with the Read tool.
- In `-script`, a key held across a tic needs `dKEY w2 uKEY`. `pKEY` presses
  and releases before the next ticcmd is built, so the game never sees it,
  though the menus do. `s:NAME` ends that tic's tokens. `tDEG` sets the
  player's facing, so you can aim at a target without fiddling with turn
  tics.
- Sound is testable headless: `-sndtrace` logs each effect by name, and
  `-sndcapture FILE` writes the mixed output as a WAV, at 1260 frames per
  gametic, so tic N starts at frame N*1260.
- The golden values in `tests/run-tests.sh` were recorded from linuxdoom.
  Frame hashes pin the headless renderer, at 1x and at `-scale 3`. Update
  them only for intentional rendering changes. Headless runs render at 1x
  unless given `-scale N`. Tests that read screenshots must run under a
  scratch `$DOOM_FC_HOME`, because the user's `default.cfg` (screen size and
  so on) changes frames.
- `tools/gen_tables.py ../DOOM/linuxdoom-1.10 src` regenerates `info.fc`,
  `sounds.fc`, `tables.fc`, `dstrings.fc`, `gamma.fc` and `random.fc`. Never
  hand-edit those files.

## Architecture

FC forbids cycles between top-level modules, and a module is one file.
Doom's C files call each other in every direction, so:

- Each strongly connected group of C files is **one module in one file**.
  `play.fc` (module `p`) holds every `p_*.c`. `render.fc` (module `r`) holds
  every `r_*.c`. The layering, low to high, is: libc/sdl2, tables/info,
  `fx`/`dd`/... constants in defs.fc, `i`/`z`/`w` (system.fc), `ds`
  (doomstat), `v`/`iv`, `r`, `isnd`/`snd`/`musplay`, `p`, `hu`/`st`,
  `amap`, `wipe`/`f`/`wi`, `misc`/`m`, `g`, `d`.
- **Upward calls go through the forwarders at the top of `main.fc`**
  (`g_player_reborn`, `st_start`, `am_stop`, `g_world_done`,
  `d_start_title`, `i_quit`, ...). Entry-file functions sit outside the
  module graph. Add a forwarder rather than creating a cycle.
- Calls that only set state (G_ExitLevel, G_DeferedInitNew, G_LoadGame,
  G_SaveGame, D_AdvanceDemo, D_PostEvent) live in `ds` (doomstat.fc), so
  lower layers can call them directly.
- Globals are module-level `let mut`, named as in C but snake_case
  (`ds.gametic`, `r.viewx`, `p.tmfloorz`). Unlike wolf-fc, mutable module
  globals are fine here, because that is Doom's design.
- C function pointers become small dispatches. A thinker's function is
  `enum thinkf`, dispatched in `p.run_thinker`. A state's codepointer is
  `enum actionf`, dispatched in `p.call_mobj_action` / `p.call_psp_action`.
  Menu routines are ints, dispatched in `m.call_routine`. The column drawer
  is `r.colfunc`.
- C enums with arithmetic on them are `i32` constants in small modules named
  after the C prefix: `wp.pistol`, `am.clip`, `gs.level`, `sn.play_run1`
  (statenum), `mt.troop` (mobjtype), `spr.troo`, `sfx.pistol`, `mus.e1m1`.
  Watch for collisions: `am` is ammo (the automap is `amap`), and `mus` is
  the music enum (the player is `musplay`).
- **Audio threading follows wolf-fc, and it is load-bearing.** The main
  thread never takes SDL's audio lock and never closes the device or calls
  `SDL_Quit`, not even in `I_Error`. On this machine PipeWire can wedge the
  audio thread, and anything that waits on it (a lock, or the join inside a
  close) then hangs the game. Game code posts commands on `isnd`'s ring.
  The callback alone touches the mixer channels and the music player, and
  publishes per-slot `finished` handles back. SDL audio prefers the native
  `pipewire` driver, falling back to SDL's default list. The mix runs at
  the device's own rate (`SDL_GetDefaultAudioInfo`, else 48000) with a
  1024-frame buffer, so SDL doesn't resample. Pitch doesn't depend on the
  rate. Headless capture and `-musictest` are pinned at 44100.
- **Two coordinate spaces.** The screens are `v.hires` times 320x200
  (`v.sw` x `v.sh`). Every 2D caller (status bar, menus, HUD, intermission,
  finale) works in 320x200 units through `v.draw_patch`, `v.copy_rect`,
  `v.fill_flat` and `v.draw_patch_column`, which scale. The renderer, the
  automap and the wipe work in screen pixels, and so do `ds.viewwindowx`,
  `ds.viewwidth` and the rest of the view geometry. Convert with `v.hires`
  wherever the two meet (the pause patch, the border patches, HU erase,
  automap marks). Never write a raw 320 or 200 against `v.screens`.
- **The render scale changes at runtime.** `iv.want_hires` is picked from
  the drawable (Auto) or the `scale_factor` setting. `d.apply_hires`
  switches at the top of D_Display: `v.set_hires` reallocates the screens,
  `r.init_resolution` the renderer buffers, and the view size, automap,
  status bar and intermission backdrop are redone. Anything new that caches
  a screen pointer or a screen-sized buffer must be redone there too.
- In-memory `short` fields are `i32`. On-disk map lumps are decoded
  explicitly in `p.load_*`. `ticcmd` keeps exact widths (`i8`/`i16`/`u8`),
  because demos depend on them.
- Unsigned angle maths is `u32`. Where C mixes `int` and `angle_t`, mirror
  the C conversions exactly with `(i32)` / `(u32)` casts. Demo sync depends
  on them.

## fcc corners hit in this port

- **Recursion and cross-module pointer globals need no workarounds** as of
  fcc rc.9 (86182d3f). Early returns in call cycles are written as in the
  C, both value-returning (`p.set_mobj_state`) and bare (`p.a_lower`,
  `p.a_raise`). `g` assigns `p.save_p` directly.
- An `if ... then` that ends its line inside an expression needs its `else`
  at the enclosing statement's column (or keep `then X` on one line).
  Continuation lines must be indented deeper than the statement.
- Closures cannot capture `let mut` locals. Use a struct and pointer (see
  music.fc's parser) or module state.
- Reserved words that bite in Doom code: `error`, `free`, `ok`, `none`,
  `in`, `from`. So it's `i.fatal` (I_Error), `z.zfree` (Z_Free),
  `res_ok`/`okay`, `none_x`, and `in_game`.
- A parameter or local named after a module (`z`, `r`, `p`, `c`, `i`, `w`,
  `v`) shadows it. That's why `spawn_mobj` takes `z0`.
