# TODO

Graphics improvements worth considering. None started.

- **Smooth palette flashes.** The damage, pickup and radiation-suit tints
  step through linuxdoom's 8 red and 3 gold palettes (plus the suit's
  green), once per tic. The blit is already full colour, so the tint could
  be a continuous strength that fades every displayed frame. Pair it with
  caching the light table per palette: `iv.set_palette` now rebuilds all
  64K `lit_palette` entries (about 0.65 ms) on every flash step.
- **Fullscreen HUD.** The largest screen size only hides the status bar.
  An overlay of health, armour and ammo, drawn with the status bar's own
  number patches, would keep that information in a full view.
- **Widescreen.** Fill the drawable's aspect exactly, with no SDL scaling
  (as native 4:3 does at 5x and 10x): a wider field of view, the status
  bar centred and its sides filled with the border flat, and menus and
  other 2D screens centred. The renderer, the view geometry and
  `v.sw`/`v.sh` would need to stop assuming 320 base units across.
- **Animate lighting and scrolling between tics.** Sector light effects
  (flicker, glow, strobe) and scrolling walls still change once per tic.
  Blending glow and scroll offsets in `interp` would make them smooth.
  Flicker and strobe are random or stepped by design and should stay so.
