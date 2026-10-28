"""Gera o ícone do Aqua Caos (parque aquático colorido) em SVG e PNG.

Uso: python3 tools/art/make_icon.py
Precisa de: pip install cairosvg pillow

Saídas:
- icon.svg / icon.png (ícone do projeto e do app);
- assets/icon/splash.png (tela de abertura);
- assets/icon/*.png (ícone adaptativo do Android);
- store/icon_512.png (ícone da Play Store).
"""
import io
import math
import os

import cairosvg
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUTLINE = "#13294b"


def sunburst(cx, cy, rays=16, radius=1400):
    parts = []
    for i in range(rays):
        a0 = (i / rays) * math.tau
        a1 = ((i + 0.5) / rays) * math.tau
        x0, y0 = cx + math.cos(a0) * radius, cy + math.sin(a0) * radius
        x1, y1 = cx + math.cos(a1) * radius, cy + math.sin(a1) * radius
        parts.append(f'<path d="M{cx} {cy} L{x0:.1f} {y0:.1f} L{x1:.1f} {y1:.1f} Z"/>')
    return "\n".join(parts)


def tube(path, base, stripe, width, dash=70):
    """Tobogã em tubo: contorno escuro, cor base e listras transversais."""
    return f"""
    <path d="{path}" fill="none" stroke="{OUTLINE}" stroke-width="{width + 22}" stroke-linecap="round"/>
    <path d="{path}" fill="none" stroke="{base}" stroke-width="{width}" stroke-linecap="round"/>
    <path d="{path}" fill="none" stroke="{stripe}" stroke-width="{width}" stroke-dasharray="{dash} {dash}"/>
    <path d="{path}" fill="none" stroke="#ffffff" stroke-opacity="0.35" stroke-width="{width * 0.18:.0f}"
          stroke-linecap="round" transform="translate(-{width * 0.22:.0f} -{width * 0.22:.0f})"/>
    """


def background():
    """Céu com raios de sol, nuvens e tobogãs coloridos."""
    return f"""
    <defs>
      <radialGradient id="sky" cx="0.5" cy="0.38" r="0.75">
        <stop offset="0" stop-color="#7fe0ff"/>
        <stop offset="0.6" stop-color="#29b6f6"/>
        <stop offset="1" stop-color="#1678d1"/>
      </radialGradient>
      <linearGradient id="water" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#4dd0e1"/>
        <stop offset="1" stop-color="#0277bd"/>
      </linearGradient>
    </defs>
    <rect width="1024" height="1024" fill="url(#sky)"/>
    <g fill="#ffffff" fill-opacity="0.13">{sunburst(512, 420)}</g>
    <circle cx="860" cy="150" r="95" fill="#ffee58" stroke="#ffb300" stroke-width="14"/>
    <g fill="#ffffff">
      <ellipse cx="170" cy="250" rx="110" ry="52"/><ellipse cx="240" cy="220" rx="80" ry="62"/>
      <ellipse cx="850" cy="300" rx="100" ry="46"/><ellipse cx="800" cy="275" rx="70" ry="52"/>
    </g>
    <!-- Pilares dos tobogãs -->
    <g stroke="{OUTLINE}" stroke-width="10" fill="#eceff1">
      <rect x="128" y="560" width="34" height="400" rx="8"/>
      <rect x="862" y="560" width="34" height="400" rx="8"/>
    </g>
    <!-- Tobogãs em arco (de trás para a frente) -->
    {tube("M 40 1060 C 40 330, 250 120, 512 120 C 774 120, 984 330, 984 1060", "#ffca28", "#ff7043", 92)}
    {tube("M 150 1060 C 150 430, 320 255, 512 255 C 704 255, 874 430, 874 1060", "#66bb6a", "#ffffff", 80, 60)}
    {palm(105, 520, 1.0)}
    <!-- Água da piscina -->
    <path d="M0 790 Q 64 755 128 790 T 256 790 T 384 790 T 512 790 T 640 790 T 768 790 T 896 790 T 1024 790 V1024 H0 Z"
          fill="url(#water)" stroke="{OUTLINE}" stroke-width="12"/>
    <path d="M0 835 Q 64 810 128 835 T 256 835 T 384 835 T 512 835 T 640 835 T 768 835 T 896 835 T 1024 835"
          fill="none" stroke="#ffffff" stroke-opacity="0.45" stroke-width="10"/>
    """


def bean(cx, cy, s):
    """Personagem do jogo (feijãozinho de boné), pulando com os braços para cima."""
    def p(x, y):
        return f"{cx + x * s:.1f} {cy + y * s:.1f}"

    o = OUTLINE
    w = 7 * s
    return f"""
    <g stroke="{o}" stroke-width="{w:.1f}" stroke-linejoin="round" stroke-linecap="round">
      <!-- Braços para cima -->
      <path d="M {p(-22, -2)} Q {p(-46, -20)} {p(-50, -52)}" fill="none" stroke-width="{w * 3.4:.1f}"/>
      <path d="M {p(-22, -2)} Q {p(-46, -20)} {p(-50, -52)}" fill="none" stroke="#ff7043" stroke-width="{w * 1.9:.1f}"/>
      <path d="M {p(22, -2)} Q {p(46, -20)} {p(50, -52)}" fill="none" stroke-width="{w * 3.4:.1f}"/>
      <path d="M {p(22, -2)} Q {p(46, -20)} {p(50, -52)}" fill="none" stroke="#ff7043" stroke-width="{w * 1.9:.1f}"/>
      <circle cx="{cx - 50 * s:.1f}" cy="{cy - 56 * s:.1f}" r="{9 * s:.1f}" fill="#ffffff"/>
      <circle cx="{cx + 50 * s:.1f}" cy="{cy - 56 * s:.1f}" r="{9 * s:.1f}" fill="#ffffff"/>
      <!-- Corpo -->
      <rect x="{cx - 30 * s:.1f}" y="{cy - 46 * s:.1f}" width="{60 * s:.1f}" height="{100 * s:.1f}" rx="{30 * s:.1f}" fill="#ff7043"/>
    </g>
    <path d="M {p(14, -40)} Q {p(28, -20)} {p(26, 30)}" fill="none" stroke="#e64a19" stroke-opacity="0.5" stroke-width="{8 * s:.1f}" stroke-linecap="round"/>
    <ellipse cx="{cx:.1f}" cy="{cy + 18 * s:.1f}" rx="{19 * s:.1f}" ry="{20 * s:.1f}" fill="#fff3e0"/>
    <!-- Olhos -->
    <g stroke="{o}" stroke-width="{w * 0.8:.1f}">
      <ellipse cx="{cx - 11 * s:.1f}" cy="{cy - 20 * s:.1f}" rx="{9 * s:.1f}" ry="{10.5 * s:.1f}" fill="#ffffff"/>
      <ellipse cx="{cx + 11 * s:.1f}" cy="{cy - 20 * s:.1f}" rx="{9 * s:.1f}" ry="{10.5 * s:.1f}" fill="#ffffff"/>
    </g>
    <circle cx="{cx - 9 * s:.1f}" cy="{cy - 22 * s:.1f}" r="{4.6 * s:.1f}" fill="{o}"/>
    <circle cx="{cx + 13 * s:.1f}" cy="{cy - 22 * s:.1f}" r="{4.6 * s:.1f}" fill="{o}"/>
    <circle cx="{cx - 7.5 * s:.1f}" cy="{cy - 24 * s:.1f}" r="{1.6 * s:.1f}" fill="#ffffff"/>
    <circle cx="{cx + 14.5 * s:.1f}" cy="{cy - 24 * s:.1f}" r="{1.6 * s:.1f}" fill="#ffffff"/>
    <!-- Boca aberta e feliz -->
    <path d="M {p(-10, -4)} Q {p(0, -2)} {p(10, -4)} Q {p(9, 10)} {p(0, 11)} Q {p(-9, 10)} {p(-10, -4)} Z"
          fill="#b71c1c" stroke="{o}" stroke-width="{w * 0.7:.1f}" stroke-linejoin="round"/>
    <ellipse cx="{cx:.1f}" cy="{cy + 7 * s:.1f}" rx="{5 * s:.1f}" ry="{3 * s:.1f}" fill="#ff8a80"/>
    <!-- Bochechas -->
    <ellipse cx="{cx - 21 * s:.1f}" cy="{cy - 5 * s:.1f}" rx="{5 * s:.1f}" ry="{3.2 * s:.1f}" fill="#ff8a65"/>
    <ellipse cx="{cx + 21 * s:.1f}" cy="{cy - 5 * s:.1f}" rx="{5 * s:.1f}" ry="{3.2 * s:.1f}" fill="#ff8a65"/>
    <!-- Boné -->
    <g stroke="{o}" stroke-width="{w * 0.8:.1f}" stroke-linejoin="round">
      <path d="M {p(12, -38)} Q {p(40, -40)} {p(44, -32)} Q {p(30, -28)} {p(10, -31)} Z" fill="#1565c0"/>
      <path d="M {p(-29, -33)} Q {p(-28, -60)} {p(0, -61)} Q {p(28, -60)} {p(29, -33)} Q {p(0, -38)} {p(-29, -33)} Z" fill="#1e88e5"/>
    </g>
    <circle cx="{cx:.1f}" cy="{cy - 61 * s:.1f}" r="{4 * s:.1f}" fill="#ffffff" stroke="{o}" stroke-width="{w * 0.6:.1f}"/>
    <path d="M {p(-18, -48)} Q {p(-12, -56)} {p(-2, -57)}" fill="none" stroke="#ffffff" stroke-opacity="0.6" stroke-width="{3.5 * s:.1f}" stroke-linecap="round"/>
    """


def splash(cx, cy, k):
    """Respingo em volta do personagem e gotas voando (k = escala)."""
    o = OUTLINE

    def P(x, y):
        return f"{cx + x * k:.1f} {cy + y * k:.1f}"

    crown = (f"M {P(-230, 40)} Q {P(-235, -30)} {P(-190, -70)} Q {P(-180, -20)} {P(-150, -25)} "
             f"Q {P(-150, -110)} {P(-110, -125)} Q {P(-100, -55)} {P(-80, -50)} "
             f"L {P(80, -50)} Q {P(100, -55)} {P(110, -125)} Q {P(150, -110)} {P(150, -25)} "
             f"Q {P(180, -20)} {P(190, -70)} Q {P(235, -30)} {P(230, 40)} "
             f"Q {P(0, 95)} {P(-230, 40)} Z")
    drops = ""
    for x, y, r, rot in [(-215, -150, 20, -30), (215, -165, 18, 30), (-280, -60, 15, -50),
                         (285, -75, 16, 50), (-160, -215, 13, -15), (170, -230, 12, 15)]:
        X, Y, R = cx + x * k, cy + y * k, r * k
        drops += (f'<path d="M {X:.1f} {Y - R * 1.9:.1f} Q {X + R:.1f} {Y - R * 0.3:.1f} {X + R:.1f} {Y + R * 0.2:.1f} '
                  f'A {R:.1f} {R:.1f} 0 0 1 {X - R:.1f} {Y + R * 0.2:.1f} Q {X - R:.1f} {Y - R * 0.3:.1f} {X:.1f} {Y - R * 1.9:.1f} Z" '
                  f'transform="rotate({rot} {X:.1f} {Y:.1f})" fill="#e1f5fe" stroke="{o}" stroke-width="{7 * k:.1f}"/>')
    return f"""
    <path d="{crown}" fill="#e1f5fe" stroke="{o}" stroke-width="{10 * k:.1f}" stroke-linejoin="round"/>
    <path d="M {P(-120, -20)} Q {P(0, 10)} {P(120, -20)}" fill="none" stroke="#81d4fa" stroke-width="{16 * k:.1f}" stroke-linecap="round"/>
    <ellipse cx="{cx:.1f}" cy="{cy + 35 * k:.1f}" rx="{170 * k:.1f}" ry="{20 * k:.1f}" fill="#81d4fa"/>
    {drops}
    """


def palm(x, y, k):
    """Coqueiro."""
    o = OUTLINE
    leaves = ""
    for ang, ln in [(-150, 150), (-110, 130), (-60, 140), (-20, 150), (-85, 110)]:
        a = math.radians(ang)
        ex, ey = x + math.cos(a) * ln * k, y + math.sin(a) * ln * k + 45 * k
        mx, my = x + math.cos(a) * ln * 0.5 * k, y + math.sin(a) * ln * 0.5 * k - 35 * k
        leaves += (f'<path d="M {x} {y} Q {mx:.1f} {my - 25 * k:.1f} {ex:.1f} {ey:.1f} '
                   f'Q {mx:.1f} {my + 25 * k:.1f} {x} {y} Z" fill="#43a047" stroke="{o}" stroke-width="{8 * k:.1f}" stroke-linejoin="round"/>')
    return f"""
    <path d="M {x - 14 * k:.1f} {y + 330 * k:.1f} Q {x - 40 * k:.1f} {y + 160 * k:.1f} {x - 8 * k:.1f} {y} L {x + 10 * k:.1f} {y}
             Q {x - 16 * k:.1f} {y + 160 * k:.1f} {x + 16 * k:.1f} {y + 330 * k:.1f} Z" fill="#a1683a" stroke="{o}" stroke-width="{8 * k:.1f}"/>
    {leaves}
    <circle cx="{x - 10 * k:.1f}" cy="{y + 8 * k:.1f}" r="{11 * k:.1f}" fill="#795548" stroke="{o}" stroke-width="{6 * k:.1f}"/>
    <circle cx="{x + 12 * k:.1f}" cy="{y + 10 * k:.1f}" r="{11 * k:.1f}" fill="#795548" stroke="{o}" stroke-width="{6 * k:.1f}"/>
    """


def ring(cx, cy, r):
    """Boia listrada flutuando."""
    o = OUTLINE
    segs = ""
    for i in range(8):
        a0, a1 = i * math.tau / 8, (i + 1) * math.tau / 8
        color = "#ef5350" if i % 2 == 0 else "#ffffff"
        x0, y0 = cx + math.cos(a0) * r, cy + math.sin(a0) * r * 0.42
        x1, y1 = cx + math.cos(a1) * r, cy + math.sin(a1) * r * 0.42
        segs += f'<path d="M {cx} {cy} L {x0:.1f} {y0:.1f} A {r} {r * 0.42:.1f} 0 0 1 {x1:.1f} {y1:.1f} Z" fill="{color}"/>'
    return f"""
    <g>
      <clipPath id="ringclip"><ellipse cx="{cx}" cy="{cy}" rx="{r}" ry="{r * 0.42:.1f}"/></clipPath>
      <g clip-path="url(#ringclip)">{segs}</g>
      <ellipse cx="{cx}" cy="{cy}" rx="{r}" ry="{r * 0.42:.1f}" fill="none" stroke="{o}" stroke-width="10"/>
      <ellipse cx="{cx}" cy="{cy - 2}" rx="{r * 0.45:.1f}" ry="{r * 0.17:.1f}" fill="#29b6f6" stroke="{o}" stroke-width="8"/>
    </g>
    """


def foreground():
    return f"""
    {ring(830, 905, 115)}
    {bean(512, 545, 5.3)}
    {splash(512, 815, 1.15)}
    """


def svg(content, size=1024, rounded=False):
    clip = '<clipPath id="r"><rect width="1024" height="1024" rx="190"/></clipPath>' if rounded else ""
    body = f'<g clip-path="url(#r)">{content}</g>' if rounded else content
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 1024 1024">'
            f"<defs>{clip}</defs>{body}</svg>")


def render(svg_text, size):
    png = cairosvg.svg2png(bytestring=svg_text.encode(), output_width=size, output_height=size)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def main():
    os.makedirs(os.path.join(ROOT, "assets", "icon"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "store"), exist_ok=True)
    full = background() + foreground()

    # Ícone do projeto (cantos arredondados) e PNG grande.
    with open(os.path.join(ROOT, "icon.svg"), "w") as f:
        f.write(svg(full, 256, rounded=True))
    render(svg(full, rounded=True), 512).save(os.path.join(ROOT, "icon.png"))
    # Tela de abertura do app (boot splash).
    render(svg(full, rounded=True), 1024).save(os.path.join(ROOT, "assets", "icon", "splash.png"))

    # Play Store: 512x512 quadrado, sem transparência (a loja arredonda sozinha).
    render(svg(full), 512).convert("RGB").save(os.path.join(ROOT, "store", "icon_512.png"))

    # Android: ícone principal 192 e ícone adaptativo 432 (fundo + frente).
    render(svg(full), 192).save(os.path.join(ROOT, "assets", "icon", "main_192.png"))
    # No ícone adaptativo só o círculo central (~66%) aparece com certeza:
    # o desenho é reduzido para caber nessa área.
    bg = render(svg(background()), 432)
    bg.save(os.path.join(ROOT, "assets", "icon", "adaptive_background_432.png"))
    fg_svg = svg(f'<g transform="translate(512 512) scale(0.66) translate(-512 -585)">{foreground()}</g>')
    render(fg_svg, 432).save(os.path.join(ROOT, "assets", "icon", "adaptive_foreground_432.png"))
    # Monocromático (ícones temáticos do Android 13+): silhueta do personagem.
    mono = render(fg_svg, 432)
    alpha = mono.getchannel("A")
    white = Image.new("RGBA", mono.size, (255, 255, 255, 0))
    white.putalpha(alpha)
    white.save(os.path.join(ROOT, "assets", "icon", "adaptive_monochrome_432.png"))
    print("ícones gerados")


if __name__ == "__main__":
    main()
