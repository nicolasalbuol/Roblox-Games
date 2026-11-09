"""Renders original marketing art (icon + thumbnails) from a simulated Chroma Turf round.

Usage:
  EXPORT_SIM=build/sim_grid.json lune run tests/run.luau match
  python3 scripts/render_marketing.py build/sim_grid.json assets/marketing
"""
import json
import math
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"
BG_TOP, BG_BOTTOM = (34, 24, 78), (10, 8, 26)
NEUTRAL_A, NEUTRAL_B = (30, 34, 58), (38, 43, 70)


def gradient(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def project(x, z, size, cx, cy, scale, tilt):
    # Simple perspective-ish tilt: rows further away (low z) are narrower and higher.
    depth = 1.0 / (1.0 + tilt * (1 - z / size))
    px = cx + (x - size / 2) * scale * depth
    py = cy + (z - size / 2) * scale * 0.62 * depth
    return px, py


def draw_grid(img, grid, cx, cy, scale, tilt, trail_path=None):
    d = ImageDraw.Draw(img, "RGBA")
    size = grid["size"]
    owner, colors = grid["owner"], grid["colors"]
    trail_cells = set(trail_path or [])
    for z in range(size):
        for x in range(size):
            i = z * size + x
            o = owner[i]
            if o == -1:
                fill = (110, 90, 230)
            elif o > 0:
                base = tuple(colors[str(o)])
                fill = base if (x + z) % 2 == 0 else shade(base, 0.86)
            else:
                fill = NEUTRAL_A if (x + z) % 2 == 0 else NEUTRAL_B
            if (x, z) in trail_cells:
                fill = (255, 255, 255)
            g = 0.08
            quad = [
                project(x + g, z + g, size, cx, cy, scale, tilt),
                project(x + 1 - g, z + g, size, cx, cy, scale, tilt),
                project(x + 1 - g, z + 1 - g, size, cx, cy, scale, tilt),
                project(x + g, z + 1 - g, size, cx, cy, scale, tilt),
            ]
            d.polygon(quad, fill=fill)
    return d


def blob(d, x, y, r, color):
    d.ellipse([x - r, y - r * 1.05, x + r, y + r * 0.95], fill=color, outline=(15, 12, 30), width=max(2, int(r / 8)))
    for side in (-0.35, 0.35):
        ex, ey = x + side * r, y - r * 0.2
        d.ellipse([ex - r * 0.22, ey - r * 0.26, ex + r * 0.22, ey + r * 0.26], fill=(255, 255, 255))
        d.ellipse([ex - r * 0.1, ey - r * 0.08, ex + r * 0.12, ey + r * 0.16], fill=(20, 20, 30))


def title(img, text, cx, y, size, glow=True):
    font = ImageFont.truetype(FONT, size)
    d = ImageDraw.Draw(img)
    w = d.textlength(text, font=font)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).text((cx - w / 2, y), text, font=font, fill=255)
    grad = Image.new("RGB", img.size)
    gd = ImageDraw.Draw(grad)
    stops = [(62, 240, 178), (72, 170, 255), (255, 92, 200)]
    x0 = int(cx - w / 2)
    for x in range(img.size[0]):
        t = min(1, max(0, (x - x0) / max(1, w)))
        a, b, k = (stops[0], stops[1], t * 2) if t < 0.5 else (stops[1], stops[2], (t - 0.5) * 2)
        gd.line([(x, 0), (x, img.size[1])], fill=tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3)))
    outline = mask.filter(ImageFilter.MaxFilter(max(3, size // 9 * 2 + 1)))
    img.paste((14, 10, 30), (0, 0), outline)
    if glow:
        img.paste((120, 200, 255), (0, 0), outline.filter(ImageFilter.GaussianBlur(size / 6)).point(lambda v: v * 0.5))
        img.paste((14, 10, 30), (0, 0), outline)
    img.paste(grad, (0, 0), mask)


def subtitle(img, text, cx, y, size, color=(235, 232, 255)):
    font = ImageFont.truetype(FONT, size)
    d = ImageDraw.Draw(img)
    w = d.textlength(text, font=font)
    d.text((cx - w / 2, y), text, font=font, fill=color, stroke_width=max(2, size // 10), stroke_fill=(14, 10, 30))


def loop_path(x0, z0, w, h):
    cells = []
    for x in range(x0, x0 + w):
        cells.append((x, z0))
    for z in range(z0, z0 + h):
        cells.append((x0 + w, z))
    for x in range(x0 + w, x0, -1):
        cells.append((x, z0 + h))
    return cells


def main(sim_path, out_dir):
    grid = json.load(open(sim_path))
    size = grid["size"]
    # Make a neutral pocket in the middle so the loop reads clearly.
    for z in range(13, 27):
        for x in range(12, 28):
            if grid["owner"][z * size + x] > 0:
                grid["owner"][z * size + x] = 0
    path = loop_path(14, 15, 11, 8)

    # Thumbnail A: the core verb.
    w, h = 1920, 1080
    img = gradient(w, h, BG_TOP, BG_BOTTOM)
    d = draw_grid(img, grid, w / 2, h * 0.62, 34, 0.55, path)
    hx, hy = project(14.5, 23.5, size, w / 2, h * 0.62, 34, 0.55)
    blob(d, hx, hy - 30, 42, (62, 240, 178))
    title(img, "CHROMA TURF", w / 2, 40, 150)
    subtitle(img, "DRAW A LOOP. CLAIM THE LAND.", w / 2, 230, 64)
    img.save(f"{out_dir}/thumbnail_1_draw_a_loop.png")

    # Thumbnail B: the social hook.
    img = gradient(w, h, (70, 20, 60), BG_BOTTOM)
    d = draw_grid(img, grid, w / 2, h * 0.6, 34, 0.55, path)
    ax, ay = project(24.5, 19.5, size, w / 2, h * 0.6, 34, 0.55)
    blob(d, ax, ay - 30, 48, (255, 104, 104))
    d.text((ax - 40, ay - 190), "SNAP!", font=ImageFont.truetype(FONT, 96), fill=(255, 210, 70), stroke_width=8, stroke_fill=(14, 10, 30))
    title(img, "CUT THEIR TRAIL", w / 2, 40, 140)
    subtitle(img, "steal the whole map", w / 2, 220, 60, (255, 210, 70))
    img.save(f"{out_dir}/thumbnail_2_cut_their_trail.png")

    # Icon 512: big blob on a loop, no small text.
    s = 512
    icon = gradient(s, s, BG_TOP, BG_BOTTOM)
    d = draw_grid(icon, grid, s / 2, s * 0.6, 13.5, 0.4, path)
    ix, iy = project(25, 19, size, s / 2, s * 0.6, 13.5, 0.4)
    blob(d, ix, iy - 20, 70, (62, 240, 178))
    title(icon, "TURF", s / 2, 22, 120, glow=False)
    icon.save(f"{out_dir}/icon_512.png")
    print("wrote", out_dir)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
