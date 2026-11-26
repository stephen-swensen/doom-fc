# doom-fc

DOOM in [FC](../fc-lang). This is a port of id Software's **linuxdoom-1.10**
source release, transposed module by module from C into FC, running on SDL2.
It plays the original IWADs, Ultimate DOOM and DOOM II, and replays their
demos in sync with linuxdoom itself, tic for tic.

The playsim, renderer, status bar, automap, menus, intermission, finale,
savegames and demo code started as straight transpositions of the C. The
renderer has since grown a higher internal resolution (see
[Display](#display)). Video, input and sound are new, because linuxdoom's X11
and `/dev/dsp` layers have no modern equivalent. They sit behind the same
`I_*` boundaries. Music is
OPL2 FM synthesis driven by the WAD's own GENMIDI instruments, as DOS DOOM
played it on an AdLib or Sound Blaster.

## License

GPL v2, inherited from the linuxdoom-1.10 release (see `LICENSE`). The
vendored OPL2 emulator and General MIDI player (`src/opl2*.fc`,
`src/opl_midi.fc`) come from fc-lang's `demos/shared`.

## Data files

The IWADs are copyrighted and are not in this repository. Copy them from a
legitimate copy of the game. Steam's *Ultimate Doom* ships both, under
`base/DOOM.WAD` and `base/doom2/DOOM2.WAD`. The data directory is searched in
this order (the same scheme as wolf-fc):

1. `$DOOM_FC_DATA_DIR`
2. `./data/`, if it contains an IWAD
3. the install location, `$(PREFIX)/share/doom-fc/data`

Within that directory doom-fc looks for linuxdoom's IWAD names, upper or
lower case, in linuxdoom's order: `doom2f.wad`, `doom2.wad`, `plutonia.wad`,
`tnt.wad`, `doomu.wad`, `doom.wad`, `doom1.wad`. With both DOOM and DOOM II
installed, DOOM II wins. Use `-doom1` (or `-iwad DOOM.WAD`) for Ultimate DOOM.

## Build and run

Needs `fcc` on `PATH` (install from `../fc-lang`) and SDL2 (`libsdl2-dev`).

```sh
make                 # build/<os>/doom-fc
./run.sh             # build if needed, then run
./run.sh -doom1      # Ultimate DOOM instead of DOOM II
make check           # regression suite (headless)
make native          # fcc --native build: sub-second compiles, slower code
make install         # binary + ./data/*.WAD under $(PREFIX)
```

Config and screenshots live in `~/.doom-fc/`, or in `$DOOM_FC_HOME` if that
is set. Savegames (`doomsavN.dsg`) go in a folder per IWAD under it, such as
`savegames/doom2.wad/`.

## Controls

The classic defaults: arrows move and turn, **Ctrl** fires, **Space** uses,
**Alt** strafes, **Shift** runs, **1-7** select weapons, **Tab** is the
automap, **Esc** opens the menu, **F1-F11** are the usual function keys (F11
cycles gamma), **Pause** pauses, and **-** / **=** change the view size. The
mouse is captured while you are playing a level. It turns and fires. Forward
and back on the mouse are off by default; `-mousemove` turns them on, and
`-nomouse` disables the mouse. **Alt+Enter** toggles fullscreen. **`**
(backquote) toggles the debug overlay.

**Options → Graphic Detail** sets the render scale: Auto, or 1x to 12x, plus
5x 4:3 and 10x 4:3 for native 4:3 rendering (see [Display](#display)).

Keys are configurable in `~/.doom-fc/default.cfg` (linuxdoom's format and
names, Doom key codes).

## Command line

All of linuxdoom's `D_DoomMain` options: `-warp E M` (or `-warp M` for DOOM
II), `-skill N`, `-episode N`, `-nomonsters`, `-respawn`, `-fast`,
`-turbo [N]`, `-file pwad...`, `-playdemo name`, `-timedemo name`,
`-record name`, `-loadgame N`, `-devparm`, `-config file`. Additions:

| option | |
|---|---|
| `-iwad file` | pick the IWAD (a path, or a name in the data directory) |
| `-doom1` | prefer DOOM / Ultimate DOOM over DOOM II |
| `-fullscreen` | start fullscreen |
| `-nosound`, `-nomusic` | silence |
| `-pitchshift` | linuxdoom's random sound pitch (DOS v1.9 plays sounds unshifted, which is the default) |
| `-nomouse`, `-mousemove` | see Controls |
| `-scale N` | render at N times 320x200 for this session (0 = Auto, 1..12), overriding the saved setting; `5n` or `10n` renders native 4:3 |
| `-maxscale N` | cap Auto's pick (default 6) |
| `-debug` | start with the debug overlay on |
| `-nointerp` | draw one frame per tic, as linuxdoom does, instead of interpolating frames at the display's refresh rate (see [Frame interpolation](#frame-interpolation)) |

### Headless / test mode

`-headless` runs without a window or audio. Tics run back to back
(singletics) instead of in real time, so a run is deterministic. The
regression suite is built on it:

| option | |
|---|---|
| `-script "..."` | scripted input, one token per tic boundary: `wN` waits N tics, `dKEY`/`uKEY` key down/up, `pKEY` both, `s:NAME` writes `NAME.png` to the shot dir, `tDEG` turns the player to face DEG degrees (0 = east, 90 = north), `x` exits the level. KEY is a character or `esc enter tab space up down left right ctrl shift alt minus equals pause f1`..`f12`. |
| `-shotdir DIR` | where screenshots go |
| `-shotevery N` | a screenshot every N gametics |
| `-quitat TIC` | quit at that gametic |
| `-demostats` | print the player's end state when a demo or run ends |
| `-tictrace` | print `T gametic rndindex x y health` every tic |
| `-worldtrace` | print `W gametic HASH` every tic in a level: a hash of every mobj (with its target, tracer and links), player, sector, line and side |
| `-sndtrace` | print `S gametic start\|stop NAME ...` for every sound effect started or stopped |
| `-sndcapture FILE` | run the real mixer (effects and music) one tic at a time and write the run to a WAV |
| `-musictest LUMP` | render 20 s of a music lump to `musictest.wav` and report its level |
| `-interptest` | draw every frame half way through its tic (frame interpolation's blend), to check it never reaches the playsim |

Headless runs render at 1x unless `-scale N` says otherwise, so the golden
frame hashes stay fixed.

`tools/refdemo/build.sh` builds linuxdoom-1.10 itself, from `../DOOM`, as a
headless demo player with the same `-tictrace` output. `make check` diffs the
two traces for every IWAD demo. They are identical on every tic.

`tests/soak.sh` plays every map of each IWAD present for 2500 tics with a
scripted player (idkfa, every weapon, doors, Nightmare on every third map,
god mode on every other run) and hashes its `-worldtrace`, along with the
IWAD demos' and a mid-fight save that is loaded and played on. `make check`
compares the hashes with `tests/soak.golden`. Those were recorded from this
port, not from linuxdoom, so they catch changes rather than bugs: a
refactor must leave them alone. Re-record them (`tests/soak.sh >
tests/soak.golden`) only for an intentional playsim change.

## Display

The game draws into 8-bit screens of `hires` times 320x200 (`v.hires`,
`v.sw` x `v.sh`). Each frame goes through the palette into one ARGB
streaming texture. SDL stretches that texture to 4:3, which restores the
original's tall pixels, and letterboxes it into the window. Video work in
SDL stops at that one texture.

In **native 4:3** the screens are `hires` times 320 by `hy` = `hires` x 6/5
times 200: 1600x1200 at 5x, square pixels, so SDL copies the texture
without stretching it. It is offered only where 6/5 of the factor is a
whole number (5x and 10x), so every 2D pixel is a whole block (5x6 at 5x)
and nothing is resampled in either axis. See
[Native 4:3](#native-43).

- **The 3D view renders at full resolution.** Walls, flats, sprites and the
  sky are drawn at `v.sw` x `v.sh`, with the original's projection, field
  of view and light levels. The weapon sprite and the sky keep their size
  relative to the 320-wide original.
- **The 2D layer keeps its 320x200 coordinates.** Status bar, menus, HUD
  text, intermission and finale call the same `v.draw_patch` and
  `v.copy_rect` as before, and those drawers scale each patch pixel into a
  `hires` x `hy` block. The automap and the wipe work in screen pixels.
  Automap lines get thicker as the scale rises.
- **Scale factor** (Options → Graphic Detail, saved as `scale_factor`).
  Auto picks the largest integer factor whose 4:3 output fits the drawable
  in both axes, capped at 6 (`-maxscale N` raises or lowers the cap), and
  renders native 4:3 when that factor is 5 or 10. The picker runs Auto, 1X
  .. 5X, 5X 4:3, 6X .. 10X, 10X 4:3, 11X, 12X; a pinned factor ignores the
  cap. `scale_factor` saves Auto as 0, a stretched factor as N and a
  native one as 100 + N. Auto re-picks when the window is resized,
  goes fullscreen, or moves to a display with a different DPI. The switch
  happens at the next frame: the screens and renderer buffers are
  reallocated and the border, status bar and intermission backdrop
  repainted.
- **Below the drawable's size** (a pinned low factor, or the cap), the frame
  is replicated in software up to the size the drawable could take, so SDL's
  linear stretch stays sharp. At 1x in a 960x720 window that is the old
  4x replication.

These are the Auto picks for some full-screen drawables:

| Drawable | Scale | Render | Shown at | Notes |
|---|---|---|---|---|
| 1280 x 720 | 3 | 960 x 600 | 960 x 720 | |
| 1920 x 1080 | 4 | 1280 x 800 | 1280 x 960 | height-bound |
| 1920 x 1200 | 5, native | 1600 x 1200 | 1600 x 1200 | 1:1 both ways |
| 2560 x 1440 | 6 | 1920 x 1200 | 1920 x 1440 | |
| 3840 x 2160 | 6 (cap) | 1920 x 1200 | 2880 x 2160 | `-maxscale 9` renders 2880 x 1800 |

Outside native 4:3 the texture is 200 rows per factor and is shown at 240,
so the 4:3 stretch is a 5:6 vertical resample: pinned 5X on a 1920x1200
panel shows 1000 rows as 1200, though its columns map 1:1.

### Native 4:3

The original's 320x200 was shown on a 4:3 monitor, so its pixels were 1.2
times as tall as wide, and the stretched path above reproduces that by
resampling rows. Every resample of 5 rows to 6 either repeats a row
(nearest) or blends neighbours (linear). On Doom's perspective-textured
floors and ceilings, and its distance light bands, that shows as a
regular stepping that crawls as you move.

Native 4:3 renders the stretch instead of resampling it:

- **3D view.** The vertical projection (`r.focaly`) is 6/5 of the
  horizontal one (`r.focalx`). Every scale the renderer compares or draws
  with (a wall column's, drawseg and vissprite scales, `spryscale`, the
  flat row distances) is vertical and built from it, and the texture step
  down a sprite or the sky is the reciprocal of its vertical scale. Sprite
  x positions and the step across a sprite stay horizontal. Light levels
  divide `hy` back out, so they are unchanged.
- **2D layer.** Each patch pixel is a `hires` x `hy` block, so the status
  bar, menus and text are exact.
- **Automap.** It draws in square screen pixels, so the map has its true
  proportions rather than the original's 1.2x vertical stretch.

At 5x it draws 20% more pixels than stretched 5x: DEMO1 renders headless
in 1.47 s against 1.14 s, about 0.9 ms a frame. Frames match stretched
5x scaled to 4:3 except along edges, where the 1200-row render is more
precise. Rendering is outside the playsim, so demos are unaffected.

Rendering at 5x costs about 1.3 ms a frame on the development machine (2000
tics of DEMO1 in 2.6 s headless), well inside the 28.6 ms tic.

### Frame interpolation

The playsim runs at 35 tics a second. Drawing one frame per tic, as
linuxdoom does, cannot pace evenly on a 60 Hz or faster display: each frame
stays up for one refresh or two in an uneven pattern, and motion judders.
So by default doom-fc draws a frame per display refresh and shows the world
part of the way through the latest tic (`interp.fc`). `-nointerp` turns it
off. Headless and `-timedemo` runs always draw one frame per tic.

- Before each tic, `interp.snapshot` records everything that moves: mobj
  positions and angles (`mobj.interp`), the player's view height and
  weapon sprite, sector floor and ceiling heights, and scrolling walls.
- Each frame, `interp.begin` writes values blended between that snapshot
  and the current state into the live fields, D_Display draws, and
  `interp.finish` puts the real values back. No tic runs in between, so the
  playsim never sees a blended value; demos play identically with every
  frame blended (`-interptest`, in `make check`).
- The blend shows the world up to one tic behind, except the player's own
  turn: mouse movement that has not reached a ticcmd yet is added to the
  view angle, and the latest tic's mouse turn is shown in full, so mouse
  turning has less latency than drawing one frame per tic. Keyboard
  turning is blended like everything else.
- New, respawned and teleported things, and anything that moved more than
  128 units in a tic, are drawn where they are. A level load starts
  blending from the next tic. Animation frames, lighting and flats still
  change once per tic.
- Input is read every frame, so mouse events now add up until the next
  ticcmd (G_Responder used to keep only the last event).
- `SDL_RenderPresent` waits for vsync. Since a renderer can claim vsync
  without waiting for it, each frame is also held to at least 3/4 of a
  refresh period, which never delays a real vsync present.

**Debug overlay** (`-debug`, or **`**). This is a top-right readout drawn into
the upload buffer after the frame is converted, so it is never in
screenshots. It shows:

- **fps**: the displayed frame rate: the display's refresh rate with frame
  interpolation, 35 with `-nointerp`.
- **work**: the time spent running the frame's tics, rendering and
  uploading, against the frame budget (a refresh period, or the 28.6 ms
  tic with `-nointerp`).
- **drops**: tics that ran without being displayed, because a frame took
  longer than a tic.
- **jit**: the average distance of each displayed-frame period from the
  frame budget. With frame interpolation it should be near 0. With
  `-nointerp` on a 60 Hz display, 35 fps presents as alternating one- and
  two-refresh frames, so a few ms here is the normal 35-on-60 cadence.
- the render size, its scale (with "4:3" when native) and whether that is
  Auto, and the drawable with its refresh rate.

The first line turns red while work is over budget or just after a drop.

## Where doom-fc departs from linuxdoom

During demos the port reproduces linuxdoom's playsim exactly, bugs
included. These are the deliberate exceptions:

- **Playsim bugs fixed outside demos.** In normal play doom-fc fixes these
  linuxdoom bugs, which DOS DOOM shares. While a demo plays or records
  (`ds.demo_compat`) it keeps the original behaviour, so demos stay in sync
  both ways:
  - `P_DivlineSide` compares `x` against the node's `y` for horizontal
    lines, which skews sight checks.
  - `A_VileTarget` spawns the fire at `(target->x, target->x)`. The fire
    keeps that spot's floor and ceiling heights, which can clip it and
    change whether the vile's blast is seen.
  - `A_Saw` compares against an unsigned `-ANG90/20`, so the chainsaw never
    snaps onto a target to the player's right.
  - `P_LoadThings` uses `break` for a DOOM II-only thing in a DOOM 1 map, so
    every later thing on the map is dropped too.
- **Loading a savegame clears every thing's `tracer`**, as linuxdoom
  already clears `target`. linuxdoom restores the saved pointer, which
  points into the level it has just freed, so loading a save with a
  revenant missile in flight crashes. Here the missile flies straight.
  Demos never load a game.
- **A linedef with no front side is an error at load.** linuxdoom gives it
  a null front sector and crashes in `P_GroupLines`.
- **`EV_DoDonut`** tests `!flags & ML_TWOSIDED`, which is always false, so
  a one-sided line could hand it a null sector. doom-fc skips one-sided
  lines, in demos too, because the fix only changes the case that would
  crash.

- **Savegames are kept per IWAD,** in `savegames/<iwad>/` (the IWAD's file
  name, lowercased). linuxdoom keeps every game's saves in one place, but a
  save records only the episode and map numbers, so a DOOM E1M1 save loaded
  in DOOM II is read onto MAP01 and crashes.
- **Ultimate DOOM detection.** linuxdoom recognises Ultimate DOOM only by the
  file name `doomu.wad`. doom-fc also treats a `doom.wad` that contains E4M1
  as retail, so episode 4 is available.
- **Demo version 109.** linuxdoom writes and expects version 110. Its playsim
  is the v1.9 one, so doom-fc uses 109 and the IWADs' demos play.
- **No crashes on vanilla overflows.** The intercepts table, the spechit
  list and the line-specials list are larger than the originals. When the
  originals overflow they corrupt memory, and FC's bounds checks would abort
  instead. Normal play never reaches the old limits.
- **Numeric arguments are strict.** linuxdoom reads `-warp` (DOOM II),
  `-timer`, `-turbo` and `-maxdemo` values with `atoi`, which takes `3x`
  as 3 and `abc` as 0. doom-fc stops with an error such as
  `Bad -warp argument: 3x`, and so do its own `-scale`, `-maxscale`,
  `-quitat` and `-shotevery`. A value that is another option, as in
  `-turbo -nomonsters`, is an error too. `-timer` with no value is an error,
  where linuxdoom read past the end of `argv`. A trailing `-turbo` with no
  value still means 200%.
- **Quit messages.** linuxdoom's `endmsg[]` is missing two commas and can run
  off its end, so doom-fc uses the DOS v1.9 messages.
- **Intermission animations.** linuxdoom's `WI_drawAnimatedBack` tests
  `if (commercial)`, an always-true constant, so it never draws the episode
  map animations. doom-fc tests the game mode, as DOS DOOM did.
- **Sound.** It is a new SDL2 mixer with the same volume and separation
  formula as linuxdoom's `i_sound.c`. It mixes at the output device's own
  rate (usually 48 kHz) rather than linuxdoom's 11 kHz, at unchanged
  pitch. Pitch shifting is off unless you pass `-pitchshift`. Both switch
  sounds play at the switch's sector. linuxdoom plays the press at
  `buttonlist[0]`'s origin, usually null, and the release at a pointer's
  address.
- **Higher internal resolution.** See [Display](#display). To keep the
  original's look at any scale, the renderer divides the scale back out of
  its light-level index, sizes the weapon sprite and the sky against 320
  columns, and gives the fuzz effect a block grain one 320x200 pixel across.
  The visplane rows are 16-bit.
- **Floating-point projection.** linuxdoom projects in 16.16 fixed point
  through angle tables: 8192 fine angles, a 2048-entry `tantoangle`, a
  4096-entry `viewangletox`. Past about 6x they run out of resolution.
  Neighbouring columns share an angle, so wall textures repeat and skip
  columns, distant wall tops step, and flats swim. doom-fc's renderer
  projects in `f64` instead. Each column's wall depth and texture column
  come from intersecting its ray with the seg, each flat span from its
  row's exact distance, each sprite's edges from its exact projected size,
  and the BSP's clipping angles from `atan2`. Pixels are sampled at their
  centres, where linuxdoom used the top or left edge (and, for flats, a
  mix). The inner column and span loops still step in fixed point, 32.32
  in an `i64`. The playsim keeps the tables, so demos are unaffected. At
  1x, frames differ from linuxdoom's by the half-pixel shift and by
  linuxdoom's own table error (its wall scales are off by up to about
  0.1%).
- **Native 4:3 rendering.** At 5x and 10x the renderer can draw square
  pixels with a 6/5 vertical projection, instead of drawing 320x200
  proportions for SDL to stretch. See [Native 4:3](#native-43). The
  automap then shows true proportions.
- **Frame interpolation.** linuxdoom draws one frame per tic. doom-fc draws
  one per display refresh, blending positions between tics, and turns the
  view with mouse input that has not reached a tic yet. See
  [Frame interpolation](#frame-interpolation). `-nointerp` restores one
  frame per tic. Mouse events also add up between ticcmds instead of the
  last one winning.
- **Graphic Detail is the render scale.** linuxdoom's low-detail toggle on
  that menu row printed "low detail mode n.a." and did nothing. The row now
  sets the scale factor, and its value is drawn in the HUD font. F5 still
  behaves as in linuxdoom: it toggles detail, which takes effect at the
  next change of screen size.
- **Low detail draws correctly.** linuxdoom's `R_DrawColumnLow` doubles the
  global `dc_x`, which sends the sprite and masked-wall loops off the
  screen (an abort here), and `R_DrawSpanLow` counts a span after doubling
  its ends, so every flat span is drawn twice as wide.
- **A removed thinker's memory stays until the level ends.** linuxdoom
  leaves pointers to removed mobjs (`target`, `tracer`, a player's
  `attacker`) that the playsim goes on reading, and its zone keeps a freed
  block's contents until it reuses the block. doom-fc unlinks a removed
  thinker but frees it with the rest of the level, so those reads see the
  mobj as it was removed. Handing it back to the heap at once would make
  them depend on the heap's layout.
- **Not ported:** network games (`d_net` is single player only), the
  multiplayer chat widgets, and the co-op/deathmatch intermission tallies.
  Screenshots are PNG, not PCX. Savegames are not interchangeable with DOS
  saves, because the structs they snapshot have different layouts.

## Source map

Every `src/*.fc` file maps to one or more of id's C files.

| file | from | |
|---|---|---|
| `defs.fc` | doomdef.h, d_player.h, p_mobj.h, r_defs.h, p_spec.h, m_fixed, d_items | shared structs and constants |
| `system.fc` | m_argv, i_system, z_zone, w_wad | |
| `doomstat.fc` | doomstat, the shared globals of d_main/g_game | |
| `video.fc` | v_video, i_video (new, SDL2) | |
| `render.fc` | r_main, r_bsp, r_segs, r_plane, r_things, r_draw, r_data, r_sky | |
| `play.fc` | every p_*.c | the playsim |
| `sound.fc` | s_sound, i_sound (new mixer) | |
| `music.fc` | (new) MUS to OPL2 through GENMIDI | |
| `hud.fc` | hu_lib, hu_stuff, st_lib, st_stuff, m_cheat | |
| `automap.fc` | am_map | |
| `wipe.fc`, `finale.fc`, `intermission.fc` | f_wipe, f_finale, wi_stuff | |
| `menu.fc` | m_misc, m_menu | |
| `game.fc` | g_game | |
| `interp.fc` | (new) | frame interpolation |
| `dmain.fc` | d_main, d_net (single player) | |
| `info.fc`, `sounds.fc`, `tables.fc`, `dstrings.fc`, `gamma.fc`, `random.fc` | info, sounds, tables, d_englsh, v_video's gamma table, m_random | generated by `tools/gen_tables.py` |
