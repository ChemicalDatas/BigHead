# Generated accessories — fitting, fidelity, style

Techniques for generating rigid accessories (hats, glasses, horns, crowns) on
the phone at the player's request, so they fit the head and look like they
belong in Big Head. Shared accessories travel between players as a PNG plus a
small JSON file.

Status: design notes. Nothing here has run on a phone yet. Numbers are
starting values to tune, not measured results.

## Fitting

### The head already gives you a rigid frame

`HeadView._draw()` draws every head layer inside one
`draw_set_transform(bobble.offset, bobble.angle, ...)`, with the head centre at
`c = Vector2(0, -0.92 * r)` and `r = head_radius`. Anything drawn in
`_draw_accessory(c, r)` bobbles, swings and scales with the head
automatically. A generated accessory needs no animation work. It needs only a
rectangle in head units:

```gdscript
# rect is in units of r, relative to c
draw_texture_rect(tex, Rect2(c + rect.position * r, rect.size * r), false)
```

### Slots

Each accessory belongs to a slot. A slot is a rectangle in r units, relative
to c. Starting values, taken from the code-drawn accessories:

| Slot | Rect (x, y, w, h) | Covers |
| --- | --- | --- |
| `top` | (-0.8, -1.9, 1.6, 1.3) | Party hat, crown, horns |
| `eyes` | (-0.85, -0.4, 1.7, 0.55) | Glasses |

Because positions are in r units, an accessory made on one player's head fits
every head at every `head_radius`. All face shapes fit inside the same
standard outline (see `_face_polygon`).

### The shared file

```json
{ "slot": "top", "rect": [-0.8, -1.9, 1.6, 1.3], "prompt": "flaming wizard hat" }
```

Send this next to the PNG. The receiver needs nothing else.

### Inpaint onto the real head, then subtract it

Don't generate the accessory on its own. Generate it on the player's own
head, so size, angle and overlap with their hair come out right:

1. Render the player's `HeadView` into a `SubViewport` with a transparent
   background: `accessory = 0`, `show_body = false`, `interactive = false`,
   bobble at rest. Read it back with `get_texture().get_image()` after
   `await RenderingServer.frame_post_draw`.
2. Crop a square around the slot rectangle with some margin, because the
   model needs to see the head for context. Scale the crop to 512×512.
3. Mask the slot rectangle, feathered by a few pixels, and run inpainting with
   the prompt.
4. Diff the result against the "before" image, inside the mask only. Pixels
   whose colour changed beyond a threshold become the accessory, and the rest
   become transparent. The head is drawn in code, so the "before" image is
   exact and the diff is clean.
5. Clean the alpha: drop small islands, fill small holes.
6. Crop the result back to the slot rectangle and save it as a PNG.

Known weak spot: where the model paints the accessory in nearly the same
colour as the hair or skin under it, the diff misses those pixels. One fix is
to render the "before" image with the masked area filled with a flat key
colour (magenta) instead of hair. The cost is that the model then can't see
the hair it has to sit on.

## Fidelity (matching the code-drawn look)

Big Head is not pixel art. Heads are flat fills with a dark outline
(`OUTLINE = #2a1d17`, 3–6 px at `r = 140`). Diffusion models add soft shading
and texture, which is where generated items look out of place. Fix it after
generation, in GDScript on the `Image`:

- **Flatten colours.** Cluster the accessory's pixels into 5–8 colours
  (k-means), then replace each pixel with its cluster colour. Snap any cluster
  close to a game constant (`GOLD`, `BONE`, `HAIR_COLOR`, `SUIT`) to that
  constant.
- **Redraw the outline yourself.** Don't trust the model's outline. Dilate
  the alpha by about `0.03 * r` worth of texels and fill the new ring with
  `OUTLINE`. That gives the accessory the same stroke as everything else on
  the head.
- **Resolution.** The head is vector and the accessory is raster, so size the
  texture for the largest head on screen: one texel per screen pixel at the
  largest `head_radius` used. At `r = 140`, the `top` slot is 224 px wide, so
  a 256 px texture is enough. Use linear filtering with mipmaps, not nearest,
  because the head scales and the look is smooth.

## Style

- **Prompt template.** Wrap the player's text:
  `"<player text>, flat cartoon sticker, solid colours, thick dark brown outline, no shading, centred"`.
  Negative prompt: `"photo, realistic, gradient, shadow, texture, text"`.
  The post-processing above does most of the work. The prompt just keeps the
  model closer to start with.
- **Start from a code-drawn accessory.** Render an existing accessory (the
  party hat, say) as the starting image and run image-to-image at strength
  about 0.6 with "flaming party hat". The shape and placement carry over and
  the model changes the surface.
- **Train a style add-on (LoRA) later.** Train on a PC, ship the LoRA file,
  and load it at runtime next to the base model. The four code-drawn
  accessories are too few to train on. It needs roughly 20–50 images in the
  house style.

## Unverified assumptions

- stable-diffusion.cpp runs inpainting with a mask on Android arm64 when
  wrapped as a GDExtension.
- Readback from a `SubViewport` works under the GL Compatibility renderer on
  the target phones.
- Inpainting a 512×512 crop with a Turbo-style model finishes in a wait
  players will accept.
