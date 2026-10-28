"""Gera as imagens da Play Store: banner (1024x500) e capturas com legenda.

Uso:
  python3 tools/art/make_store_art.py banner
  python3 tools/art/make_store_art.py shots <pasta_com_capturas_brutas>

As capturas brutas (1920x1080) vêm de tools/store/store_shot.gd, uma pasta
por idioma (pt_BR, en, es) com os arquivos listados em SHOTS.
Saída em store/<idioma da Play Store>/.
"""
import io
import math
import os
import sys

import cairosvg
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import make_icon as icon  # noqa: E402

ROOT = icon.ROOT
FONT = os.path.join(ROOT, "assets", "fonts", "LilitaOne-Regular.ttf")
NAVY = (19, 41, 75)

# Idioma do jogo -> pasta da Play Store
LANGS = {"pt_BR": "pt-BR", "en": "en-US", "es": "es-419"}

SUBTITLE = {"pt_BR": "DESAFIO MOLHADO", "en": "SPLASH CHALLENGE", "es": "DESAFÍO MOJADO"}

# (arquivo bruto, legenda por idioma)
SHOTS = [
    ("race.png", {"pt_BR": "Corridas de obstáculos na água!", "en": "Splashy obstacle races!",
                  "es": "¡Carreras de obstáculos en el agua!"}),
    ("slide.png", {"pt_BR": "Tobogãs, curvas e muita bagunça", "en": "Slides, curves and lots of chaos",
                   "es": "Toboganes, curvas y mucho caos"}),
    ("rivals.png", {"pt_BR": "Vença os rivais e chegue em 1º", "en": "Beat your rivals and finish 1st",
                    "es": "Vence a tus rivales y llega 1º"}),
    ("map.png", {"pt_BR": "Fases sem fim num mapa de aventuras", "en": "Endless levels on an adventure map",
                 "es": "Niveles sin fin en un mapa de aventuras"}),
    ("shop.png", {"pt_BR": "Skins divertidas para escolher", "en": "Fun skins to choose from",
                  "es": "Skins divertidas para elegir"}),
    ("worlds.png", {"pt_BR": "Mundos coloridos de dia e de noite", "en": "Colorful worlds by day and night",
                    "es": "Mundos coloridos de día y de noche"}),
    ("result.png", {"pt_BR": "Ganhe moedas, estrelas e recordes", "en": "Earn coins, stars and records",
                    "es": "Gana monedas, estrellas y récords"}),
]


def font(size):
    return ImageFont.truetype(FONT, size)


def render_svg(content, w, h, view):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{view}" '
           f'preserveAspectRatio="xMidYMid slice">{content}</svg>')
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=w, output_height=h)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def outlined_text(draw, xy, text, size, fill, outline=NAVY, stroke=None, anchor="la"):
    stroke = stroke if stroke is not None else max(4, size // 9)
    draw.text(xy, text, font=font(size), fill=fill, stroke_width=stroke, stroke_fill=outline, anchor=anchor)


def sky(w, h, cx, cy):
    """Fundo com raios de sol, no estilo do ícone."""
    content = f"""
    <defs><radialGradient id="sky" cx="{cx / w}" cy="{cy / h}" r="0.9">
      <stop offset="0" stop-color="#7fe0ff"/><stop offset="0.6" stop-color="#29b6f6"/>
      <stop offset="1" stop-color="#1678d1"/></radialGradient></defs>
    <rect width="{w}" height="{h}" fill="url(#sky)"/>
    <g fill="#ffffff" fill-opacity="0.12">{icon.sunburst(cx, cy, 20, max(w, h) * 1.5)}</g>
    """
    return render_svg(content, w, h, f"0 0 {w} {h}")


def banner(lang):
    w, h = 1024, 500
    img = sky(w, h, 760, 170)
    # Cena do ícone à direita: tobogãs atrás, água por toda a largura, personagem na frente.
    scene = icon.background().replace('<rect width="1024" height="1024" fill="url(#sky)"/>', "")
    scene = scene.replace(f'<g fill="#ffffff" fill-opacity="0.13">{icon.sunburst(512, 420)}</g>', "")
    scene = scene[:scene.index("<!-- Água da piscina -->")]
    img.alpha_composite(render_svg(scene, 620, 620, "0 0 1024 1024"), (430, -40))
    water_y = int(-40 + 790 * 620 / 1024)
    waves = " ".join(f"T {x} 30" for x in range(160, 1200, 80))
    water = render_svg(
        '<defs><linearGradient id="w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4dd0e1"/>'
        '<stop offset="1" stop-color="#0277bd"/></linearGradient></defs>'
        f'<path d="M-20 30 Q 30 8 80 30 {waves} V200 H-20 Z" fill="url(#w)" stroke="#13294b" stroke-width="7"/>'
        f'<path d="M-20 58 Q 30 40 80 58 ' + " ".join(f"T {x} 58" for x in range(160, 1200, 80)) +
        '" fill="none" stroke="#ffffff" stroke-opacity="0.45" stroke-width="6"/>',
        w, 200, f"0 0 {w} 200")
    img.alpha_composite(water, (0, water_y - 30))
    img.alpha_composite(render_svg(icon.foreground(), 620, 620, "0 0 1024 1024"), (430, -40))
    d = ImageDraw.Draw(img)
    # Logo
    outlined_text(d, (60, 70), "AQUA", 128, (128, 222, 255), stroke=14)
    outlined_text(d, (60, 185), "CAOS", 150, (255, 179, 0), stroke=16)
    # Faixa do subtítulo
    sub = SUBTITLE[lang]
    f = font(40)
    tw = d.textlength(sub, font=f)
    d.rounded_rectangle((60, 350, 60 + tw + 56, 414), 20, fill=NAVY)
    d.text((88, 360), sub, font=f, fill=(255, 255, 255))
    return img.convert("RGB")


def caption_shot(raw_path, caption):
    """Captura com legenda: fundo da marca, legenda grande e a tela do jogo emoldurada."""
    w, h = 1920, 1080
    img = sky(w, h, 960, 0)
    shot = Image.open(raw_path).convert("RGBA").resize((1520, 855), Image.LANCZOS)
    x, y = (w - 1520) // 2, 200
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x - 4, y + 14, x + 1524, y + 869), 40, fill=(10, 30, 60, 140))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
    frame = Image.new("RGBA", (1520 + 24, 855 + 24), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, 1543, 878), 44, fill=(255, 255, 255, 255))
    img.alpha_composite(frame, (x - 12, y - 12))
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 1519, 854), 34, fill=255)
    img.paste(shot, (x, y), mask)
    d = ImageDraw.Draw(img)
    size = 92
    while d.textlength(caption, font=font(size)) > 1700:
        size -= 4
    outlined_text(d, (w // 2, 105), caption, size, (255, 255, 255), stroke=12, anchor="mm")
    return img.convert("RGB")


def main():
    mode = sys.argv[1]
    for lang, folder in LANGS.items():
        out = os.path.join(ROOT, "store", folder)
        os.makedirs(out, exist_ok=True)
        if mode == "banner":
            banner(lang).save(os.path.join(out, "feature_graphic_1024x500.png"))
        elif mode == "shots":
            raw = os.path.join(sys.argv[2], lang)
            for i, (name, captions) in enumerate(SHOTS, 1):
                path = os.path.join(raw, name)
                if os.path.exists(path):
                    caption_shot(path, captions[lang]).save(os.path.join(out, f"screenshot_{i}.png"))
    print("pronto:", mode)


if __name__ == "__main__":
    main()
