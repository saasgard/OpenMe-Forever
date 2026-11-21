"""Generate OpenMe Forever art: in-game icon (TGA) and repo logo (PNG)."""
import math, random, sys, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
random.seed(7)
S = 512


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def vgrad(size, top, bottom):
    w, h = size
    g = Image.new("RGBA", size)
    d = ImageDraw.Draw(g)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=lerp(top, bottom, y / max(1, h - 1)))
    return g


def radial(size, center, radius, inner, outer):
    w, h = size
    img = Image.new("RGBA", size)
    px = img.load()
    cx, cy = center
    for y in range(h):
        for x in range(w):
            t = min(1.0, math.hypot(x - cx, y - cy) / radius)
            px[x, y] = lerp(inner, outer, t)
    return img


def noise(size, amount):
    w, h = size
    n = Image.effect_noise(size, amount).convert("L")
    return n.filter(ImageFilter.GaussianBlur(0.6))


def paste_masked(base, layer, mask_poly=None, mask=None):
    if mask is None:
        mask = Image.new("L", base.size, 0)
        ImageDraw.Draw(mask).polygon(mask_poly, fill=255)
    base.alpha_composite(Image.composite(layer, Image.new("RGBA", base.size, (0, 0, 0, 0)), mask))
    return mask


def shade(base, mask, strength=60):
    """Grain texture: darken/lighten within mask using noise."""
    n = noise(base.size, 40)
    dark = Image.new("RGBA", base.size, (0, 0, 0, 0))
    a = n.point(lambda v: max(0, 128 - v) * strength // 128)
    a = ImageChops.multiply(a, mask)
    dark.putalpha(a)
    base.alpha_composite(dark)


def gold_fill(size, box, vertical=True):
    x0, y0, x1, y1 = box
    stops = [(0.0, (120, 72, 18)), (0.25, (255, 222, 120)), (0.45, (230, 170, 50)),
             (0.7, (150, 92, 22)), (1.0, (90, 52, 12))]
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    span = (x1 - x0) if not vertical else (y1 - y0)
    for i in range(span + 1):
        t = i / max(1, span)
        for j in range(len(stops) - 1):
            if stops[j][0] <= t <= stops[j + 1][0]:
                tt = (t - stops[j][0]) / (stops[j + 1][0] - stops[j][0])
                c = lerp(stops[j][1], stops[j + 1][1], tt) + (255,)
                break
        if vertical:
            d.line([(x0, y0 + i), (x1, y0 + i)], fill=c)
        else:
            d.line([(x0 + i, y0), (x0 + i, y1)], fill=c)
    return img


def draw_icon():
    img = radial((S, S), (256, 200), 380, (70, 40, 70, 255), (8, 5, 12, 255))

    # Light burst behind the chest
    rays = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    cx, cy = 256, 230
    for k in range(14):
        a0 = math.radians(-170 + k * (160 / 13))
        a1 = a0 + math.radians(5)
        rd.polygon([(cx, cy), (cx + 600 * math.cos(a0), cy + 600 * math.sin(a0)),
                    (cx + 600 * math.cos(a1), cy + 600 * math.sin(a1))], fill=(255, 220, 120, 70))
    rays = rays.filter(ImageFilter.GaussianBlur(6))
    img.alpha_composite(rays)
    glow = radial((S, S), (256, 235), 230, (255, 230, 140, 230), (255, 180, 60, 0))
    img.alpha_composite(glow)

    # --- Lid (open, tilted back) ---
    lid_back = [(110, 120), (402, 120), (424, 232), (88, 232)]
    lid = vgrad((S, S), (92, 52, 28, 255), (58, 30, 16, 255))
    m = paste_masked(img, lid, lid_back)
    shade(img, m, 70)
    # lid inner dark edge
    d = ImageDraw.Draw(img)
    for x in (180, 256, 332):
        d.line([(x, 122), (x + (x - 256) * 0.12, 230)], fill=(40, 20, 10, 200), width=3)
    lb = gold_fill((S, S), (96, 214, 416, 238))
    paste_masked(img, lb, [(92, 214), (420, 214), (424, 236), (88, 236)])
    for bx in (150, 330):
        band = gold_fill((S, S), (bx, 120, bx + 32, 232), vertical=False)
        paste_masked(img, band, [(bx - 6, 120), (bx + 26, 120), (bx + 34, 232), (bx - 2, 232)])

    # --- Interior opening (glowing gold) ---
    inner = radial((S, S), (256, 258), 170, (255, 250, 200, 255), (220, 140, 40, 255))
    paste_masked(img, inner, [(88, 236), (424, 236), (412, 280), (100, 280)])
    # coins heaped
    cd = ImageDraw.Draw(img)
    for _ in range(60):
        x = random.randint(110, 400)
        y = random.randint(240, 278)
        r = random.randint(9, 15)
        cd.ellipse([x - r, y - r * 0.55, x + r, y + r * 0.55], fill=(196, 128, 26, 255))
        cd.ellipse([x - r + 2, y - r * 0.55 + 1, x + r - 2, y + r * 0.55 - 3], fill=(255, 214, 92, 255))
        cd.ellipse([x - r * 0.4, y - r * 0.3, x + r * 0.1, y - r * 0.05], fill=(255, 248, 200, 255))

    # --- Body ---
    body = [(100, 280), (412, 280), (404, 446), (108, 446)]
    wood = vgrad((S, S), (128, 74, 38, 255), (62, 32, 16, 255))
    m = paste_masked(img, wood, body)
    shade(img, m, 80)
    d = ImageDraw.Draw(img)
    for y in (322, 364, 406):
        d.line([(104, y), (408, y)], fill=(38, 18, 8, 230), width=4)
        d.line([(104, y + 3), (408, y + 3)], fill=(150, 96, 52, 120), width=2)
    # rim band
    rim = gold_fill((S, S), (96, 276, 416, 300))
    paste_masked(img, rim, [(96, 276), (416, 276), (414, 300), (98, 300)])
    # bottom band
    bot = gold_fill((S, S), (104, 430, 408, 452))
    paste_masked(img, bot, [(106, 430), (406, 430), (404, 452), (108, 452)])
    # vertical straps
    for bx in (146, 334):
        strap = gold_fill((S, S), (bx, 296, bx + 32, 434), vertical=False)
        paste_masked(img, strap, [(bx, 296), (bx + 32, 296), (bx + 32, 434), (bx, 434)])
        for ry in (318, 372, 420):
            d.ellipse([bx + 10, ry - 6, bx + 22, ry + 6], fill=(90, 52, 12, 255))
            d.ellipse([bx + 11, ry - 6, bx + 19, ry + 2], fill=(255, 236, 160, 255))

    # lock plate
    lp = gold_fill((S, S), (222, 298, 290, 378), vertical=False)
    paste_masked(img, lp, [(222, 298), (290, 298), (290, 360), (256, 384), (222, 360)])
    d.polygon([(222, 298), (290, 298), (290, 360), (256, 384), (222, 360)], outline=(70, 40, 10, 255), width=3)
    d.ellipse([247, 318, 265, 336], fill=(20, 10, 5, 255))
    d.polygon([(250, 330), (262, 330), (266, 360), (246, 360)], fill=(20, 10, 5, 255))

    # outline everything chest-like
    outline = Image.new("L", (S, S), 0)
    od = ImageDraw.Draw(outline)
    od.polygon(lid_back, outline=255, width=5)
    od.polygon(body, outline=255, width=5)
    ol = Image.new("RGBA", (S, S), (25, 12, 5, 255))
    ol.putalpha(outline)
    img.alpha_composite(ol)

    # sparkles
    sp = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sp)
    for (x, y, r) in [(170, 170, 26), (360, 150, 20), (275, 105, 34), (110, 250, 14), (420, 255, 16)]:
        sd.polygon([(x, y - r), (x + r * 0.18, y - r * 0.18), (x + r, y), (x + r * 0.18, y + r * 0.18),
                    (x, y + r), (x - r * 0.18, y + r * 0.18), (x - r, y), (x - r * 0.18, y - r * 0.18)],
                   fill=(255, 250, 220, 255))
    img.alpha_composite(sp.filter(ImageFilter.GaussianBlur(3)))
    img.alpha_composite(sp)

    # vignette
    vig = radial((S, S), (256, 256), 370, (0, 0, 0, 0), (0, 0, 0, 200))
    img.alpha_composite(vig)
    return img


icon_hi = draw_icon()
icon_hi.save(os.path.join(OUT, "icon_512.png"))
icon64 = icon_hi.resize((64, 64), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1, 60, 1))
icon64.save(os.path.join(OUT, "icon_64.png"))

# ---------------- Logo / banner ----------------
W, H = 1280, 640
logo = radial((W, H), (W // 2, H // 2), 800, (48, 30, 22, 255), (10, 6, 6, 255))
tex = noise((W, H), 60)
dk = Image.new("RGBA", (W, H), (0, 0, 0, 0))
dk.putalpha(tex.point(lambda v: abs(v - 128) // 3))
logo.alpha_composite(dk)

# medallion: gold ring with the icon inside (circle mask like the in-game portrait)
R = 210
cx, cy = 330, 320
ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
rmask = Image.new("L", (W, H), 0)
ImageDraw.Draw(rmask).ellipse([cx - R - 22, cy - R - 22, cx + R + 22, cy + R + 22], fill=255)
ring.alpha_composite(gold_fill((W, H), (cx - R - 22, cy - R - 22, cx + R + 22, cy + R + 22)))
shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(shadow).ellipse([cx - R - 30, cy - R - 18, cx + R + 30, cy + R + 42], fill=(0, 0, 0, 200))
logo.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
logo.alpha_composite(Image.composite(ring, Image.new("RGBA", (W, H)), rmask))
ImageDraw.Draw(logo).ellipse([cx - R - 6, cy - R - 6, cx + R + 6, cy + R + 6], fill=(40, 22, 8, 255))
ic = icon_hi.resize((2 * R, 2 * R), Image.LANCZOS)
cm = Image.new("L", (2 * R, 2 * R), 0)
ImageDraw.Draw(cm).ellipse([0, 0, 2 * R - 1, 2 * R - 1], fill=255)
logo.paste(ic, (cx - R, cy - R), cm)

FONTS = "C:/Windows/Fonts/"


def gold_text(base, xy, text, font, spacing=0):
    x, y = xy
    tmp = Image.new("L", base.size, 0)
    td = ImageDraw.Draw(tmp)
    cur = x
    for ch in text:
        td.text((cur, y), ch, font=font, fill=255)
        cur += font.getlength(ch) + spacing
    bbox = tmp.getbbox()
    # shadow + dark outline
    sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sh.putalpha(tmp.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(6)))
    base.alpha_composite(ImageChops.offset(sh, 4, 6))
    ol = Image.new("RGBA", base.size, (30, 14, 4, 255))
    ol.putalpha(tmp.filter(ImageFilter.MaxFilter(7)))
    base.alpha_composite(ol)
    g = gold_fill(base.size, bbox)
    base.alpha_composite(Image.composite(g, Image.new("RGBA", base.size), tmp))


title = ImageFont.truetype(FONTS + "palab.ttf", 150)
sub = ImageFont.truetype(FONTS + "palab.ttf", 56)
gold_text(logo, (600, 170), "OpenMe", title)
gold_text(logo, (612, 350), "FOREVER", sub, spacing=18)
d = ImageDraw.Draw(logo)
d.line([(606, 440), (1180, 440)], fill=(170, 120, 40, 255), width=3)
# Tagline on two lines, shrunk if needed so it never runs past the divider line.
TAG_LINES = ["Every box, bag and quest item,", "one click away"]
TAG_MAX_W = 1180 - 608
size = 38
while size > 16:
    tag = ImageFont.truetype(FONTS + "pala.ttf", size)
    if max(tag.getlength(t) for t in TAG_LINES) <= TAG_MAX_W:
        break
    size -= 1
for i, line in enumerate(TAG_LINES):
    d.text((608, 458 + i * int(size * 1.3)), line, font=tag, fill=(225, 205, 160, 255))
logo.save(os.path.join(OUT, "logo.png"))

# In-game icon: 64x64 32-bit TGA (WoW-compatible)
icon64.save(os.path.join(OUT, "..", "Icon.tga"))
print("done")

# ---------------- CurseForge project avatar ----------------
# CurseForge requires a 400x400 avatar (not a solid colour; avoid WebP), so this is PNG.
A = 1600  # draw at 4x, then downscale
av = radial((A, A), (A // 2, A // 2), A * 0.75, (58, 36, 26, 255), (10, 6, 6, 255))
tex = noise((A, A), 60)
dk = Image.new("RGBA", (A, A), (0, 0, 0, 0))
dk.putalpha(tex.point(lambda v: abs(v - 128) // 3))
av.alpha_composite(dk)
c, R, B = A // 2, 640, 70  # centre, icon radius, ring width
sh = Image.new("RGBA", (A, A), (0, 0, 0, 0))
ImageDraw.Draw(sh).ellipse([c - R - B - 10, c - R - B + 20, c + R + B + 10, c + R + B + 60], fill=(0, 0, 0, 220))
av.alpha_composite(sh.filter(ImageFilter.GaussianBlur(40)))
rmask = Image.new("L", (A, A), 0)
ImageDraw.Draw(rmask).ellipse([c - R - B, c - R - B, c + R + B, c + R + B], fill=255)
av.alpha_composite(Image.composite(gold_fill((A, A), (c - R - B, c - R - B, c + R + B, c + R + B)), Image.new("RGBA", (A, A)), rmask))
ImageDraw.Draw(av).ellipse([c - R - 18, c - R - 18, c + R + 18, c + R + 18], fill=(40, 22, 8, 255))
ic = icon_hi.resize((2 * R, 2 * R), Image.LANCZOS)
cm = Image.new("L", (2 * R, 2 * R), 0)
ImageDraw.Draw(cm).ellipse([0, 0, 2 * R - 1, 2 * R - 1], fill=255)
av.paste(ic, (c - R, c - R), cm)
av = av.resize((400, 400), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1, 50, 1))
av.convert("RGB").save(os.path.join(OUT, "curseforge_avatar_400.png"))
print("avatar done")
