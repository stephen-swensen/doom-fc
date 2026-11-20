#!/bin/bash
# doom-fc regression suite. Run via `make check` (always against a fresh
# binary). Everything runs headless (-headless: no window, no audio,
# singletics) and deterministic.
#
# The heart of it is demo sync: the IWADs' own demos replayed through the
# playsim, checked against end states and per-tic trace hashes recorded
# from linuxdoom-1.10 itself (tools/refdemo). When ../DOOM is present the
# oracle is rebuilt and diffed live, tic by tic.
#
# Tests needing an IWAD are skipped (not failed) when it isn't in the data
# directory. Saves and config go to a scratch $DOOM_FC_HOME.

cd "$(dirname "$0")/.."
BIN=$(make -s print-bin)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export DOOM_FC_HOME="$TMP/home"
mkdir -p "$DOOM_FC_HOME"
DATA=${DOOM_FC_DATA_DIR:-data}

pass=0
fail=0
skip=0

section() { echo; echo "== $1"; }
ok()   { pass=$((pass + 1)); echo "  ok    $1"; }
bad()  { fail=$((fail + 1)); echo "  FAIL  $1"; [ -n "$2" ] && echo "        $2"; }
skp()  { skip=$((skip + 1)); echo "  skip  $1"; }

assert_eq() {    # name expected actual
    if [ "$2" == "$3" ]; then ok "$1"; else bad "$1" "expected [$2] got [$3]"; fi
}
assert_contains() {    # name haystack needle
    if [[ "$2" == *"$3"* ]]; then ok "$1"; else bad "$1" "missing [$3]"; fi
}

have() { [ -f "$DATA/$1" ] || [ -f "$DATA/${1,,}" ]; }

run() { "$BIN" -headless "$@" 2>&1; }

trace_md5() {    # args...
    run "$@" -tictrace | grep '^T ' | grep -v '^T 0 ' | md5sum | cut -c1-32
}

# ----------------------------------------------------------------------
section "demo sync: Ultimate DOOM (end state recorded from linuxdoom-1.10)"
if have DOOM.WAD; then
    declare -A END1=(
        [demo1]="DEMOEND gametic=1710 map=E1M5 health=0 kills=18 items=5 secrets=1 x=-2061659 y=5450445 rnd=148"
        [demo2]="DEMOEND gametic=2347 map=E2M2 health=0 kills=18 items=2 secrets=1 x=70814046 y=133290953 rnd=146"
        [demo3]="DEMOEND gametic=3863 map=E3M5 health=0 kills=7 items=3 secrets=1 x=62548762 y=21122819 rnd=124"
        [demo4]="DEMOEND gametic=818 map=E4M2 health=0 kills=10 items=0 secrets=0 x=-16748816 y=48093372 rnd=85"
    )
    declare -A MD51=(
        [demo1]=88f2006339c9b72cf5293c674d13a0db
        [demo2]=98d4f4d4e191732265c38679faa6dc0a
        [demo3]=2286aeaadf7833ae388ca6eb1504c0d6
        [demo4]=b82b413431e390664719a4324b9af4fb
    )
    for dm in demo1 demo2 demo3 demo4; do
        out=$(run -doom1 -playdemo $dm -demostats | grep DEMOEND)
        assert_eq "$dm end state" "${END1[$dm]}" "$out"
        assert_eq "$dm per-tic trace" "${MD51[$dm]}" "$(trace_md5 -doom1 -playdemo $dm)"
    done
else
    skp "DOOM.WAD not in $DATA"
fi

section "demo sync: DOOM II"
if have DOOM2.WAD; then
    declare -A END2=(
        [demo1]="DEMOEND gametic=1205 map=E1M11 health=0 kills=8 items=0 secrets=0 x=63752097 y=66879015 rnd=232"
        [demo2]="DEMOEND gametic=2001 map=E1M5 health=0 kills=19 items=1 secrets=0 x=42580418 y=-20036778 rnd=237"
        [demo3]="DEMOEND gametic=4471 map=E1M26 health=0 kills=35 items=24 secrets=0 x=-43365476 y=-8655350 rnd=175"
    )
    declare -A MD52=(
        [demo1]=22f70a3ff4d2d0c19c1e5abb5133219b
        [demo2]=6736349888efeaea10ae39732f3d9801
        [demo3]=038980b89f78ab9c0b438bc73848b1c9
    )
    for dm in demo1 demo2 demo3; do
        out=$(run -iwad DOOM2.WAD -playdemo $dm -demostats | grep DEMOEND)
        assert_eq "doom2 $dm end state" "${END2[$dm]}" "$out"
        assert_eq "doom2 $dm per-tic trace" "${MD52[$dm]}" "$(trace_md5 -iwad DOOM2.WAD -playdemo $dm)"
    done
else
    skp "DOOM2.WAD not in $DATA"
fi

section "demo sync: live diff against linuxdoom-1.10 (../DOOM)"
if [ -d ../DOOM/linuxdoom-1.10 ] && have DOOM.WAD; then
    if tools/refdemo/build.sh ../DOOM/linuxdoom-1.10 "$TMP/refdemo" >/dev/null 2>&1; then
        for dm in demo1 demo2 demo3 demo4; do
            "$TMP/refdemo/refdemo" "$DATA/DOOM.WAD" $dm -tictrace 2>/dev/null | grep '^T ' > "$TMP/ref.txt"
            run -doom1 -playdemo $dm -tictrace | grep '^T ' | grep -v '^T 0 ' > "$TMP/fc.txt"
            if cmp -s "$TMP/ref.txt" "$TMP/fc.txt"; then
                ok "$dm matches linuxdoom tic for tic ($(wc -l < "$TMP/ref.txt") tics)"
            else
                bad "$dm diverges from linuxdoom" "$(diff "$TMP/ref.txt" "$TMP/fc.txt" | head -3 | tr '\n' ' ')"
            fi
        done
    else
        skp "could not build tools/refdemo"
    fi
else
    skp "../DOOM/linuxdoom-1.10 not present"
fi

# ----------------------------------------------------------------------
section "rendering (headless frames are bit-stable)"
if have DOOM.WAD; then
    run -doom1 -shotdir "$TMP" -quitat 60 -script "w40 s:title" >/dev/null
    assert_eq "title screen frame" 486c60240384f0c184fdf17ac6df4e67 "$(md5sum < "$TMP/title.png" | cut -c1-32)"
    run -doom1 -warp 1 1 -shotdir "$TMP" -quitat 60 -script "w40 s:e1m1" >/dev/null
    assert_eq "E1M1 start frame" b2b8efadd0f6d6ec7982a53733289ec5 "$(md5sum < "$TMP/e1m1.png" | cut -c1-32)"
else
    skp "DOOM.WAD not in $DATA"
fi

# ----------------------------------------------------------------------
section "game flow"
if have DOOM.WAD; then
    # menu -> new game -> E1M1, walk forward
    out=$(run -doom1 -tictrace -quitat 200 -script "w20 pesc w5 penter w3 penter w3 penter w40 w20 dup w30 uup")
    assert_contains "new game from the menu reaches E1M1 and moves" "$out" "T 175 148 69199134 -220369329 100"
    # E1M1 exit -> intermission -> E1M2
    out=$(run -doom1 -warp 1 1 -quitat 400 -demostats -script "w40 x w60 dspace w3 uspace w3 dspace w3 uspace w30 dspace w3 uspace w40 dspace w3 uspace")
    assert_contains "exit E1M1, skip the tally, land on E1M2" "$out" "map=E1M2"
    # E1M8 exit -> episode finale
    run -doom1 -warp 1 8 -shotdir "$TMP" -quitat 600 -script "w40 x w400 s:finale" >/dev/null
    if [ -f "$TMP/finale.png" ]; then ok "E1M8 exit reaches the finale"; else bad "E1M8 exit reaches the finale"; fi
else
    skp "DOOM.WAD not in $DATA"
fi

# ----------------------------------------------------------------------
section "save / load"
if have DOOM.WAD; then
    rm -f "$DOOM_FC_HOME"/doomsav*.dsg
    saved=$(run -doom1 -warp 1 1 -tictrace -quitat 140 -script "w40 dup w30 uup w20 pf2 w2 penter w2 pt pe ps pt w1 penter w10" | grep '^T 95 ')
    [ -f "$DOOM_FC_HOME/doomsav0.dsg" ] && ok "F2 / slot 1 / typed name writes doomsav0.dsg" || bad "F2 / slot 1 / typed name writes doomsav0.dsg"
    loaded=$(run -doom1 -loadgame 0 -tictrace -quitat 3 | grep '^T 0 ')
    # The save is written at the start of the tic after the menu Enter, so
    # the loaded game's first tic is tic 95 of the saving run: position,
    # the momentum-driven step and health all survive the round trip
    # (the RNG index is not saved, as in the original)
    assert_eq "loaded game resumes exactly where it was saved" "$(echo "$saved" | cut -d' ' -f4-6)" "$(echo "$loaded" | cut -d' ' -f4-6)"
else
    skp "DOOM.WAD not in $DATA"
fi

# ----------------------------------------------------------------------
section "music (MUS -> OPL2 via GENMIDI)"
if have DOOM.WAD; then
    out=$( cd "$TMP" && DOOM_FC_DATA_DIR="$(cd "$OLDPWD" && cd "$DATA" && pwd)" "$OLDPWD/$BIN" -headless -doom1 -musictest D_E1M1 2>&1 | grep musictest)
    assert_contains "D_E1M1 converts to the expected event list" "$out" "events=5825"
    peak=$(echo "$out" | sed 's/.*peak=\([0-9]*\).*/\1/')
    if [ -n "$peak" ] && [ "$peak" -gt 1000 ]; then ok "music renders audibly (peak $peak)"; else bad "music renders audibly" "$out"; fi
else
    skp "DOOM.WAD not in $DATA"
fi

echo
echo "$pass passed, $fail failed, $skip skipped"
[ $fail -eq 0 ]
