# Frieren companion (data-only, PluginKit 6)

A calm elven mage for the desktop: 17 animations on the default skin
(idle, blink, walk, greet, sleep, rest, think, work, celebrate, worry,
approve, talk, listen, appear, leave, deny, look) plus a `nocturna`
variant skin (black hair, gray eyes, indigo robe) with its own
idle + greet. Unmapped actions fall back to the skin's own `idle`
per the companion platform contract.

Provenance: fan art of Frieren, character (c) Kanehito Yamada /
Tsukasa Abe / Shogakukan. The HorneroOS maintainer requested this
companion for the catalogue, and that decision is recorded here rather
than asserted as a cleared license. Source sheets (magenta-keyed,
generated with Muse image generation) live in `../.work-frieren/sheets/`; the
reframing recipe (split, chroma key, bottom-align content to ground
y=472 on a shared 512x512 canvas) is documented in the HorneroOS
companion authoring guide flow.

## Test locally

From the package directory (`companions/frieren/`):

```
horneroctl plugin install-local . --yes
horneroctl plugin enable frieren --yes
qs ipc call plugins reload
```

Then Centro de Control -> Companeros -> Agregar al escritorio.

## Status

- [x] idle (mandatory), greet, blink
- [x] walk cycle (2 frames), sleep, rest
- [x] think, work, celebrate, worry, approve, talk, listen
- [x] appear, leave, deny, look
- [x] Second skin: nocturna (idle + greet)
- [ ] Catalogue PR to HorneroOS/plugins (this package is the payload)

## Sprite map (default skin)

| Hornero action | Frame | Source |
|---|---|---|
| idle | idle-01.png | reframed pose |
| greet | greet-01.png | generated 2026-11-28 |
| blink | blink-01.png | generated 2026-11-28 |
| walk | walk-01/02.png | generated 2026-11-28 |
| sleep | sleep-01.png | reframed pose |
| rest/work | reading-01.png | reframed pose |
| think | think-01.png | reframed pose |
| celebrate | celebrate-01.png | reframed pose |
| worry | sad-01.png | reframed pose |
| approve/work | happy/cast-01.png | reframed poses |
| talk/listen | talk/listen-01.png | generated 2026-11-28 |
| appear/leave | appear/leave-01.png | generated 2026-11-28 |
| deny/look | deny/look-01.png | generated 2026-11-28 |

Known quirks (desktop size hides them, catalogue art pass can fix):
walk frames switch the staff hand; minor magenta halo on some hair
edges; generated frames carry a capelet the 8 original poses lack.
