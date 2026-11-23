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
- `tests/soak.sh` hashes `-worldtrace` (the whole playsim, every tic) over
  scripted runs of every map, the IWAD demos and two save/loads, plus
  screenshot series (fuzz, light amp, invulnerability, 3x) and captured
  audio. Its golden file, `tests/soak.golden`, was recorded from this
  port: any refactor must leave it unchanged. Re-record only for an
  intentional playsim, rendering or sound change, and say why.
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
  every `r_*.c`. The layering, low to high, is: `mem`/sdl2, tables/info,
  `fx`/`dd`/... constants in defs.fc, `i`/`z`/`w` (system.fc), `ds`
  (doomstat), `v`/`iv`, `r`, `isnd`/`snd`/`musplay`, `p`, `hu`/`st`,
  `amap`, `wipe`/`f`/`wi`, `misc`/`m`, `g`, `interp`, `d`.
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
- libc is bound only for what FC lacks: `memcpy`/`memset`, wrapped in
  `mem` (mem.fc) next to the other raw-memory helpers (`mem.name_view`
  for NUL-padded names, the little-endian `mem.rd_*`).
  `iabs` is `fx.iabs`, and `name8_eq` is `w.name8_eq`. File I/O, the
  environment, exit and ASCII case use std `io`/`sys`/`text`. Heap memory
  uses `alloc(T, n)!`/`free`, and a zeroed struct is `*p = default(T)`.
  Numeric command-line values go through `argv.int_after`, which is a
  fatal error on a bad value.
- **A pointer that can be absent is `T*?`; a raw `T*` is always valid**
  once set (late-initialized globals included), so never store a null in
  one. The optional ones: mobj `target`/`tracer`/`player` and the
  `snext`/`sprev`/`bnext`/`bprev` links, `blocklinks` slots, player
  `mo`/`attacker`, `pspdef.state`, sector `specialdata` (a `thinker*?`),
  `soundtarget` and `thinglist`, line/seg `backsector`, `p.linetarget`,
  the active plat/ceiling slots, the renderer's drawseg clips, vissprite
  `colormap` (none = fuzz) and `fixedcolormap`, and the zone's owner
  slots (`w.lumpcache`, `r.texturecomposite`). Where linuxdoom tests a
  pointer, `match` it; where it dereferences unchecked, use `!`, which
  aborts with the line where C would crash. `mobj.state` is never null (a
  mobj removed through S_NULL keeps `&states[S_NULL]`). Savegames store
  pointers as indices in the pointer's own bytes (`p.put_idx`/`get_idx`).
  A sound has an origin (`snd.start_sound(mo, id)`) or none
  (`snd.start_local_sound(id)`). An intercept is a union, `line` or
  `thing`.
- C function pointers that reach savegames or generated tables become
  small dispatches. A thinker's function is `enum thinkf`, dispatched in
  `p.run_thinker`. A state's codepointer is `enum actionf`, dispatched in
  `p.call_mobj_action` / `p.call_psp_action`. Menu routines, drawers and
  message responses are never saved, so they are FC function values
  (`menuitem.routine`, `menudef.drawer`, `m.message_routine`). The column
  drawer is `r.colfunc`.
- A C enum that is a closed set, only compared or switched on, is an FC
  `enum`, and its switches are exhaustive `match`es: `gs`, `ga`, `gmode`,
  `pst`, the p_spec thinker types (`plat_status`, `door_type`,
  `ceiling_type`, `floor_type`, `move_result`, ...), `wi_anim`,
  `f.stage`, `wi.stage`, `wipe.kind`, `item_status`. An enum keeps the
  C module's name where there was one, so `gs.level` reads as before.
  An `enum` of `i32` has the field's old layout, so savegames are
  unchanged. A sentinel outside the set (C's `wipegamestate = -1`) is an
  option (`gs?`). `event` is a union (`keydown`, `keyup`, `mouse`).
- C enums with arithmetic on them, sentinels such as `numweapons`, or
  loops over their values stay `i32` constants in small modules named
  after the C prefix: `wp.pistol`, `am.clip`, `sk.nightmare`,
  `sn.play_run1` (statenum), `mt.troop` (mobjtype), `spr.troo`,
  `sfx.pistol`, `mus.e1m1`. So do bit flags (`mf`, `ml`, `bt`, `cf`).
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
- **Two coordinate spaces.** The screens are `v.hires` times 320 across and
  `v.hy` times 200 down (`v.sw` x `v.sh`). `v.hy` equals `v.hires` except in
  native 4:3 (`v.native`, 5x and 10x only), where it is `hires * 6/5`.
  Every 2D caller (status bar, menus, HUD, intermission, finale) works in
  320x200 units through `v.draw_patch`, `v.copy_rect`, `v.fill_flat` and
  `v.draw_patch_column`, which scale. The renderer, the automap and the
  wipe work in screen pixels, and so do `ds.viewwindowx`, `ds.viewwidth`
  and the rest of the view geometry. Convert wherever the two meet (the
  pause patch, the border patches, HU erase, automap marks), with
  `v.hires` for x and `v.hy` for y. Never write a raw
  320 or 200 against `v.screens`. In the renderer, every "scale" is
  vertical (built from `r.projectiony`); `r.aspect_y` / `r.aspect_iy`
  convert horizontal scales and texture steps.
- **The render scale changes at runtime.** `iv.want_hires` and
  `iv.want_native` are picked from the drawable (Auto) or the
  `scale_factor` setting. `d.apply_hires`
  switches at the top of D_Display: `v.set_hires` reallocates the screens,
  `r.init_resolution` the renderer buffers, and the view size, automap,
  status bar and intermission backdrop are redone. Anything new that caches
  a screen pointer or a screen-sized buffer must be redone there too.
- **Frame interpolation (`interp.fc`, between `g` and `d`) writes blended
  values into live playsim fields around D_Display and restores them
  after.** So D_Display and everything it calls must never change playsim
  state, or the restore will clobber it. Something new that moves and is
  drawn must be added to `interp.snapshot` / `begin` / `finish`, or it
  steps at 35 Hz. `mobj.interp` must stay the last field of `mobj`:
  savegames store `p.saved_mobj_size` bytes, which leaves it off, so old
  saves still load. `-interptest` blends every headless frame, and `make
  check` requires demo traces to match with it.
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
- A character literal is a `u8`, and a shift masks its count to the
  operand's width, so `('a' << 24) + ('m' << 16)` is `0xce`, not C's
  `0x616d0000`. Cast first (`(i32) 'a' << 24`). This silently broke the
  automap's AM_MSGENTERED notice to the status bar until `event` became a
  union.
- Reserved words that bite in Doom code: `error`, `free`, `ok`, `none`,
  `in`, `from`. So it's `i.fatal` (I_Error), `z.zfree` (Z_Free),
  `res_ok`/`okay`, `none_x`, and `in_game`.
- A parameter or local named after a module (`z`, `r`, `p`, `i`, `w`, `v`,
  `mem`, `text`, `io`) shadows it. That's why `spawn_mobj` takes `z0`.
- **Comments and LSP hover.** The FC LSP's hover text is the contiguous
  run of `//` lines directly above a declaration, stopping at the first
  blank line. So a doc comment for one module / struct / enum / `let` goes
  *immediately* above it, with no rule lines and no blank line between.
  Banners (a `// ---` or `// ===` rule, the title, a closing rule) are
  only for section headers that group several declarations, and always
  have a blank line after, so they stay out of hover. File-header
  comments also end in a blank line.
