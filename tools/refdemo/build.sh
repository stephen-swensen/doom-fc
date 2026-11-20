#!/bin/bash
# Build linuxdoom-1.10 itself as a headless demo player: the sync oracle
# doom-fc's playsim is checked against (tests/run-tests.sh, "demo sync").
#
#   tools/refdemo/build.sh [path/to/linuxdoom-1.10] [outdir]
#   build/refdemo/refdemo data/DOOM.WAD demo1 [-tictrace]
#
# linuxdoom is 32-bit code; the sed lines below are the minimum needed for
# a 64-bit build of the parts a demo touches (pointer-sized allocations, a
# pointer in an on-disk struct, (int) pointer alignment), plus VERSION 109
# so the IWADs' v1.9 demos are accepted. Nothing in the playsim is changed.
set -e
SRC=${1:-../DOOM/linuxdoom-1.10}
OUT=${2:-build/refdemo}
HERE=$(cd "$(dirname "$0")" && pwd)
rm -rf "$OUT"
mkdir -p "$OUT"
cp "$SRC"/*.[ch] "$OUT"/
cp "$HERE/harness.c" "$OUT"/
cd "$OUT"
sed -i 's/VERSION =  110/VERSION =  109/' doomdef.h
sed -i 's/void\t\t\*\*columndirectory;/int columndirectory;/' r_data.c
sed -i 's/Z_Malloc (numtextures\*4, PU_STATIC, 0)/Z_Malloc (numtextures*sizeof(void*), PU_STATIC, 0)/g' r_data.c
sed -i 's/(byte \*)( ((int)colormaps + 255)&~0xff)/(byte *)( ((long)colormaps + 255)\&~0xffL)/' r_data.c
sed -i 's/(byte \*)(( (int)translationtables + 255 )& ~255)/(byte *)(( (long)translationtables + 255 )\& ~255L)/' r_draw.c
sed -i 's/linebuffer = Z_Malloc (total\*4, PU_LEVEL, 0);/linebuffer = Z_Malloc (total*sizeof(line_t*), PU_LEVEL, 0);/' p_setup.c
SRCS="doomdef.c doomstat.c dstrings.c info.c sounds.c tables.c m_fixed.c m_random.c m_bbox.c m_argv.c m_swap.c z_zone.c w_wad.c p_ceilng.c p_doors.c p_enemy.c p_floor.c p_inter.c p_lights.c p_map.c p_maputl.c p_mobj.c p_plats.c p_pspr.c p_saveg.c p_setup.c p_sight.c p_spec.c p_switch.c p_telept.c p_tick.c p_user.c r_data.c r_main.c r_bsp.c r_plane.c r_segs.c r_things.c r_draw.c r_sky.c v_video.c g_game.c d_items.c harness.c"
gcc -O1 -w -DNORMALUNIX -DLINUX -o refdemo $SRCS -lm
echo "built $OUT/refdemo"
