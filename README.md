# doom-fc

DOOM in [FC](../fc-lang). This is a port of id Software's **linuxdoom-1.10**
source release, transposed module by module from C into FC, running on SDL2.
It plays the original IWADs, Ultimate DOOM and DOOM II, and replays their
demos in sync with linuxdoom itself, tic for tic.

The playsim, renderer, status bar, automap, menus, intermission, finale,
savegames and demo code are all straight transpositions of the C. Video,
input and sound are new, because linuxdoom's X11 and `/dev/dsp` layers have
no modern equivalent. They sit behind the same `I_*` boundaries. Music is
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
`-nomouse` disables the mouse. **Alt+Enter** toggles fullscreen.

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

### Headless / test mode

`-headless` runs without a window or audio. Tics run back to back
(singletics) instead of in real time, so a run is deterministic. The
regression suite is built on it:

| option | |
|---|---|
| `-script "..."` | scripted input, one token per tic boundary: `wN` waits N tics, `dKEY`/`uKEY` key down/up, `pKEY` both, `s:NAME` writes `NAME.png` to the shot dir, `x` exits the level. KEY is a character or `esc enter tab space up down left right ctrl shift alt minus equals pause f1`..`f12`. |
| `-shotdir DIR` | where screenshots go |
| `-shotevery N` | a screenshot every N gametics |
| `-quitat TIC` | quit at that gametic |
| `-demostats` | print the player's end state when a demo or run ends |
| `-tictrace` | print `T gametic rndindex x y health` every tic |
| `-musictest LUMP` | render 20 s of a music lump to `musictest.wav` and report its level |

`tools/refdemo/build.sh` builds linuxdoom-1.10 itself, from `../DOOM`, as a
headless demo player with the same `-tictrace` output. `make check` diffs the
two traces for every IWAD demo. They are identical on every tic.

## Where doom-fc departs from linuxdoom

The port reproduces linuxdoom's playsim exactly, including its bugs (the
vile's fire spawn, the "-ANG90/20" chainsaw comparison, EV_DoDonut's
precedence slip, the P_LoadThings early `break`, and so on). These are the
deliberate exceptions:

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
  formula as linuxdoom's `i_sound.c`. Pitch shifting is off unless you pass
  `-pitchshift`. The switch-button release sound plays at the sector's sound
  origin, not at a pointer's address.
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
