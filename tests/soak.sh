#!/bin/bash
# Soak runs: every map of each IWAD present, played for a few thousand tics
# by a scripted player (idkfa, cycling weapons, firing, opening doors,
# turning), hashed through -worldtrace. The hash covers every mobj (with
# its target, tracer, player and list links), player, sector, line and
# side every tic, so it pins far more of the playsim than the IWAD demos
# do: Nightmare respawns, revenant tracers, arch-viles, the boss brain,
# rockets and the BFG, crushers and lifts, death and reborn. A few runs
# also save a screenshot every 125 tics, hashed together, and two capture
# the mixed sound and music, to pin the renderer and the mixer the same way.
#
# The golden hashes in tests/soak.golden were recorded from this port, not
# from linuxdoom (the demos pin that), so they catch changes, not bugs.
# Re-record only for an intentional playsim or rendering change:
#
#     tests/soak.sh > tests/soak.golden
#
# Prints "NAME MD5" per run. Usage: tests/soak.sh [BIN [DATA_DIR]]

cd "$(dirname "$0")/.."
BIN=${1:-$(make -s print-bin)}
DATA=${2:-${DOOM_FC_DATA_DIR:-data}}
export DOOM_FC_DATA_DIR=$DATA
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export DOOM_FC_HOME="$TMP/home"
mkdir -p "$DOOM_FC_HOME"

have() { [ -f "$DATA/$1" ] || [ -f "$DATA/${1,,}" ]; }

# idkfa, then 60 rounds of: face somewhere new, pick a weapon, run and
# fire, use, sidestep. With god mode (iddqd) on even-numbered runs, so
# half the runs die, press use and are reborn.
script() {    # god?
    local t="w20"
    [ "$1" = 1 ] && t="$t pi pd pd pq pd w2"
    t="$t pi pd pk pf pa w2"
    local ang=0 k
    for k in $(seq 0 59); do
        ang=$(( (ang + 137) % 360 ))
        local w=$(( k % 7 + 1 ))
        t="$t t$ang d$w w2 u$w w6 dup dctrl w12 dspace w2 uspace w6 uup w4 dshift dright w3 uright ushift uctrl w2"
    done
    echo "$t"
}
GOD=$(script 1)
MORTAL=$(script 0)

one() {    # name iwadflag skill god warp...
    local name=$1 iwad=$2 skill=$3 god=$4
    shift 4
    local s=$MORTAL
    [ "$god" = 1 ] && s=$GOD
    local h
    h=$("$BIN" -headless "$iwad" -skill "$skill" -warp "$@" -quitat 2500 -worldtrace -script "$s" 2>&1 \
        | grep -E '^W [0-9]' | md5sum | cut -c1-32)
    echo "$name $h"
}
export -f one
export BIN GOD MORTAL TMP

jobs=()
if have DOOM.WAD; then
    n=0
    for e in 1 2 3 4; do
        for m in 1 2 3 4 5 6 7 8 9; do
            # skill 4 (UV) mostly, every third map Nightmare (fast, respawning)
            sk=4; [ $((n % 3)) = 2 ] && sk=5
            jobs+=("one doom1-e${e}m$m -doom1 $sk $((n % 2 == 0)) $e $m")
            n=$((n + 1))
        done
    done
fi
if have DOOM2.WAD; then
    for m in $(seq 1 32); do
        sk=4; [ $((m % 3)) = 0 ] && sk=5
        jobs+=("one doom2-map$(printf %02d $m) -doom2 $sk $((m % 2 == 0)) $m")
    done
fi

# Rendering: the same scripted runs, a screenshot every 125 tics, on a
# few maps with the powers that change how things are drawn (partial
# invisibility's fuzz, the light amp's and invulnerability's fixed
# colormaps), one of them at 3x.
render() {    # name iwadflag cheat scale warp...
    local name=$1 iwad=$2 cheat=$3 scale=$4
    shift 4
    local dir="$TMP/$name"
    mkdir -p "$dir"
    "$BIN" -headless "$iwad" -skill 4 -warp "$@" -scale "$scale" -quitat 2500 -shotdir "$dir" -shotevery 125 \
        -script "w20 pi pd pd pq pd w2 $cheat w2 ${GOD#w20 pi pd pd pq pd w2 }" >/dev/null 2>&1
    echo "$name $(cat "$dir"/*.png | md5sum | cut -c1-32)"
}
export -f render
IDBEHOLD="pi pd pb pe ph po pl pd"
if have DOOM.WAD; then
    jobs+=("render render-e1m1-invis -doom1 '$IDBEHOLD pi' 1 1 1")
    jobs+=("render render-e2m2-lightamp -doom1 '$IDBEHOLD pl' 1 2 2")
    jobs+=("render render-e3m3-invuln -doom1 '$IDBEHOLD pv' 1 3 3")
    jobs+=("render render-e1m3-x3 -doom1 '' 3 1 3")
fi
if have DOOM2.WAD; then
    jobs+=("render render-map07 -doom2 '' 1 7")
    jobs+=("render render-map15-invis -doom2 '$IDBEHOLD pi' 1 15")
fi

# Sound: the mixed output (effects and music) of a scripted fight,
# captured headless and hashed.
audio() {    # name iwadflag warp...
    local name=$1 iwad=$2
    shift 2
    "$BIN" -headless "$iwad" -skill 4 -warp "$@" -quitat 1200 -sndcapture "$TMP/$name.wav" -script "$GOD" >/dev/null 2>&1
    echo "$name $(md5sum < "$TMP/$name.wav" | cut -c1-32)"
}
export -f audio
if have DOOM.WAD; then jobs+=("audio audio-e1m2 -doom1 1 2"); fi
if have DOOM2.WAD; then jobs+=("audio audio-map10 -doom2 10"); fi

# the IWAD demos too: they already match linuxdoom tic for tic, this pins
# the rest of the world along the way
demo() {    # name iwadflag demo
    echo "$1 $("$BIN" -headless "$2" -playdemo "$3" -worldtrace 2>&1 | grep -E '^W [0-9]' | md5sum | cut -c1-32)"
}
export -f demo
if have DOOM.WAD; then
    for d in 1 2 3 4; do jobs+=("demo doom1-demo$d -doom1 demo$d"); done
fi
if have DOOM2.WAD; then
    for d in 1 2 3; do jobs+=("demo doom2-demo$d -doom2 demo$d"); done
fi

printf '%s\n' "${jobs[@]}" | xargs -P "$(nproc)" -L1 bash -c '"$@"' _ | sort

# A save made mid-fight (monsters awake, targets set, specials moving)
# loads and plays on identically every time. The MAP13 save has revenant
# missiles in flight, whose tracers a load clears.
saveload() {    # name map tic
    local home="$TMP/$1"
    mkdir -p "$home"
    DOOM_FC_HOME=$home "$BIN" -headless -doom2 -skill 4 -warp "$2" -quitat $(($3 + 40)) \
        -script "w20 pi pd pd pq pd w2 pi pd pk pf pa w2 d4 w2 u4 $4 pf2 w2 penter w2 pt w1 penter w10" >/dev/null 2>&1
    h=$(DOOM_FC_HOME=$home "$BIN" -headless -doom2 -loadgame 0 -quitat $(($3 + 300)) -worldtrace \
        -script "dctrl dup w300 uup dleft w100 uleft w200 uctrl" 2>&1 | grep -E '^W [0-9]' | md5sum | cut -c1-32)
    echo "$1 $h"
}
if have DOOM2.WAD; then
    saveload zz-saveload-map07 7 600 "dctrl w300 dright w40 uright w200 uctrl"
    saveload zz-saveload-map13 13 300 "dup dctrl w150 dright w20 uright w90 uctrl uup"
fi
