#!/usr/bin/env python3
"""Draws assets/body_template.png (colored outlines and a legend) and
assets/body_template_blank.png (plain outlines) from the game's own body
shapes, so the templates always match BodyShapes.

    godot --headless --path . --script tools/dump_body_shapes.gd > /tmp/shapes.txt
    python3 tools/make_body_templates.py /tmp/shapes.txt
"""
import json
import sys
from PIL import Image, ImageDraw, ImageFont

SCALE = 6  # pixels per body unit
COLORS = ["#2b3f8c", "#23875a", "#cc3a3a", "#7a45b5", "#9a7a22", "#d6488f"]
BG = "#faf8f2"
FONT_PATHS = ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]


def font(size):
    for path in FONT_PATHS:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    return ImageFont.load_default()


def load(path):
    for line in open(path):
        if line.startswith("BODY_SHAPES_JSON "):
            return json.loads(line[len("BODY_SHAPES_JSON "):])
    sys.exit("No BODY_SHAPES_JSON line in " + path)


def to_px(box, p):
    return ((p[0] - box[0]) * SCALE, (p[1] - box[1]) * SCALE)


def draw_outlines(draw, data, colors, width):
    box = data["box"]
    for body, color in zip(data["bodies"], colors):
        for part in body["parts"]:
            pts = [to_px(box, p) for p in part]
            draw.line(pts + [pts[0]], fill=color, width=width, joint="curve")


def grid(draw, w, h):
    for x in range(0, w, 50):
        draw.line([(x, 0), (x, h)], fill="#ebe7dc", width=1)
    for y in range(0, h, 50):
        draw.line([(0, y), (w, y)], fill="#ebe7dc", width=1)
    draw.line([(w // 2, 0), (w // 2, h)], fill="#c9c4b8", width=2)


def main():
    data = load(sys.argv[1])
    box = data["box"]
    w, h = int(box[2] * SCALE), int(box[3] * SCALE)

    guide = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(guide)
    grid(d, w, h)
    draw_outlines(d, data, COLORS, 4)
    d.rectangle([0, 0, w - 1, h - 1], outline="#2a1d17", width=3)
    x0, y0 = w // 2 - 270, 250
    d.rectangle([x0 - 20, y0 - 20, x0 + 580, y0 + 262], fill=BG)
    d.text((x0, y0), "Big Head body template", fill="#2a1d17", font=font(30))
    small = font(19)
    d.text((x0, y0 + 46), "The whole image covers the body. Each body shape", fill="#5a5048", font=small)
    d.text((x0, y0 + 70), "shows what's inside its outlines, arms and legs too.", fill="#5a5048", font=small)
    for i, (body, color) in enumerate(zip(data["bodies"], COLORS)):
        x, y = x0 + (i % 3) * 185, y0 + 112 + (i // 3) * 36
        d.rectangle([x, y + 2, x + 22, y + 24], fill=color)
        d.text((x + 32, y), body["name"], fill="#2a1d17", font=small)
    d.text((x0, y0 + 196), "The goat and unicorn share the four legs. Not textured:", fill="#5a5048", font=small)
    d.text((x0, y0 + 220), "hands, the T-shirt's bare arms, hooves, the rainbow tail.", fill="#5a5048", font=small)
    guide.save("assets/body_template.png")

    blank = Image.new("RGB", (w, h), "#ffffff")
    d = ImageDraw.Draw(blank)
    draw_outlines(d, data, ["#b9b4aa"] * len(data["bodies"]), 2)
    blank.save("assets/body_template_blank.png")
    print("Wrote assets/body_template.png and assets/body_template_blank.png (%dx%d)" % (w, h))


if __name__ == "__main__":
    main()
