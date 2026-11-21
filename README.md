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

Config, savegames (`doomsavN.dsg`) and screenshots live in `~/.doom-fc/`, or
in `$DOOM_FC_HOME` if that is set.

## Controls

The classic defaults: arrows move and turn, **Ctrl** fires, **Space** uses,
**Alt** strafes, **Shift** runs, **1-7** select weapons, **Tab** is the
automap, **Esc** opens the menu, **F1-F11** are the usual function keys (F11
cycles gamma), **Pause** pauses, and **-** / **=** change the view size. The
mouse is captured while you are playing a level. It turns and fires. Forward
and back on the mouse are off by default; `-mousemove` turns them on, and
`-nomouse` disables the mouse. **Alt+Enter** toggles fullscreen. **`**
(backquote) toggles the debug overlay.

**Options → Graphic Detail** sets the render scale: Auto, or 1x to 12x (see
[Display](#display)).

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
| `-scale N` | render at N times 320x200 for this session (0 = Auto, 1..12), overriding the saved setting |
| `-maxscale N` | cap Auto's pick (default 6) |
| `-debug` | start with the debug overlay on |

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
| `-sndtrace` | print `S gametic start\|stop NAME ...` for every sound effect started or stopped |
| `-sndcapture FILE` | run the real mixer (effects and music) one tic at a time and write the run to a WAV |
| `-musictest LUMP` | render 20 s of a music lump to `musictest.wav` and report its level |

Headless runs render at 1x unless `-scale N` says otherwise, so the golden
frame hashes stay fixed.

`tools/refdemo/build.sh` builds linuxdoom-1.10 itself, from `../DOOM`, as a
headless demo player with the same `-tictrace` output. `make check` diffs the
two traces for every IWAD demo. They are identical on every tic.

## Display

The game draws into 8-bit screens of `hires` times 320x200 (`v.hires`,
`v.sw` x `v.sh`). Each frame goes through the palette into one ARGB
streaming texture. SDL stretches that texture to 4:3, which restores the
original's tall pixels, and letterboxes it into the window. Video work in
SDL stops at that one texture.

- **The 3D view renders at full resolution.** Walls, flats, sprites and the
  sky are drawn at `v.sw` x `v.sh`, with the original's projection, field
  of view and light levels. The weapon sprite and the sky keep their size
  relative to the 320-wide original.
- **The 2D layer keeps its 320x200 coordinates.** Status bar, menus, HUD
  text, intermission and finale call the same `v.draw_patch` and
  `v.copy_rect` as before, and those drawers scale each patch pixel into a
  `hires` x `hires` block. The automap and the wipe work in screen pixels.
  Automap lines get thicker as the scale rises.
- **Scale factor** (Options → Graphic Detail, saved as `scale_factor`).
  Auto picks the largest integer factor whose 4:3 output fits the drawable
  in both axes, capped at 6 (`-maxscale N` raises or lowers the cap). A
  pinned 1x..12x ignores the cap. Auto re-picks when the window is resized,
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
| 1920 x 1200 | 5 | 1600 x 1000 | 1600 x 1200 | 1:1 horizontally |
| 2560 x 1440 | 6 | 1920 x 1200 | 1920 x 1440 | |
| 3840 x 2160 | 6 (cap) | 1920 x 1200 | 2880 x 2160 | `-maxscale 9` renders 2880 x 1800 |

The texture is always 200 rows per factor and is shown at 240, so the 4:3
stretch is a 5:6 vertical resample. At 5x on a 1920x1200 panel that means
1000 rows shown as 1200. Columns map 1:1.

Rendering at 5x costs about 1.3 ms a frame on the development machine (2000
tics of DEMO1 in 2.6 s headless), well inside the 28.6 ms tic.

**Debug overlay** (`-debug`, or **`**). This is a top-right readout drawn into
the upload buffer after the frame is converted, so it is never in
screenshots. It shows:

- **fps**: the displayed frame rate. Doom draws one frame per tic, so it
  reads 35.
- **work**: the time spent running the frame's tics, rendering and
  uploading, against the 28.6 ms tic budget.
- **drops**: tics that ran without being displayed, because a frame took
  longer than a tic.
- **jit**: the average distance of each displayed-frame period from 28.6 ms.
  On a 60 Hz display, 35 fps presents as alternating one- and two-refresh
  frames, so a few ms here is the normal 35-on-60 cadence.
- the render size, its scale and whether that is Auto, and the drawable
  with its refresh rate.

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
- **`EV_DoDonut`** tests `!flags & ML_TWOSIDED`, which is always false, so
  a one-sided line could hand it a null sector. doom-fc skips one-sided
  lines, in demos too, because the fix only changes the case that would
  crash.

- **Ultimate DOOM detection.** linuxdoom recognises Ultimate DOOM only by the
  file name `doomu.wad`. doom-fc also treats a `doom.wad` that contains E4M1
  as retail, so episode 4 is available.
- **Demo version 109.** linuxdoom writes and expects version 110. Its playsim
  is the v1.9 one, so doom-fc uses 109 and the IWADs' demos play.
- **No crashes on vanilla overflows.** The intercepts table, the spechit
  list and the line-specials list are larger than the originals. When the
  originals overflow they corrupt memory, and FC's bounds checks would abort
  instead. Normal play never reaches the old limits.
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
  It also scales the cap on wall scale with the screen, so walls close up
  are not cut short, and does wall and sprite edge maths in 64 bits, where
  the higher scales would overflow 32. The visplane rows are 16-bit. At 1x
  the golden test frames are unchanged.
- **Graphic Detail is the render scale.** linuxdoom's low-detail toggle on
  that menu row printed "low detail mode n.a." and did nothing. The row now
  sets the scale factor, and its value is drawn in the HUD font. F5 still
  behaves as in linuxdoom.
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
| `dmain.fc` | d_main, d_net (single player) | |
| `info.fc`, `sounds.fc`, `tables.fc`, `dstrings.fc`, `gamma.fc`, `random.fc` | info, sounds, tables, d_englsh, v_video's gamma table, m_random | generated by `tools/gen_tables.py` |
