"""
generate_wheel.py
Génère une image de la roue avec des parts de camembert pleines
colorées par rareté (NORMAL=gris, RARE=bleu, MYTHIC=violet,
LEGENDARY=or, ULTRA=rose vif) + texte blanc rotatif + anneau vert.
"""

from PIL import Image, ImageDraw, ImageFont
import math

# ── Dimensions ──────────────────────────────────────────────────────────────
SIZE     = 720
CX, CY   = SIZE // 2, SIZE // 2
OUTER_R  = 328   # bord extérieur anneau vert
RING_R   = 298   # bord intérieur anneau vert (= rayon du disque)
TEXT_R   = 195   # rayon du point d'ancrage du texte
CENTER_R = 68    # rayon du moyeu "SPIN!"

# ── Couleurs par rareté (même palette que le jeu Roblox) ────────────────────
SEGMENT_DATA = [
    # (Nom,                 couleur RGB)  — même palette que WheelController.lua
    ("Son Bruh",            (255,  45,  45)),   # 1  Rouge vif
    ("Tête de Noob",        ( 55, 175, 255)),   # 2  Bleu ciel
    ("Pizza Froide",        ( 45, 200,  75)),   # 3  Vert
    ("Emoji Mewing",        (255, 200,   0)),   # 4  Jaune or
    ("Cravate Bleue",       (175,  45, 255)),   # 5  Violet
    ("Sourire Sigma",       (255, 115,   0)),   # 6  Orange
    ("Mâchoire Gigachad",   (  0, 210, 210)),   # 7  Turquoise
    ("Tour de Pizza",       (255,  45, 145)),   # 8  Rose vif
    ("Tête Skibidi",        ( 75, 255, 115)),   # 9  Vert lime
    ("Sigma d'Or",          ( 75,  75, 255)),   # 10 Bleu roi
    ("Sigma Galactique",    (255, 155,  25)),   # 11 Ambre
    ("Skibidi Diamant",     (220,  55, 220)),   # 12 Magenta
]

N   = len(SEGMENT_DATA)
SEG = 360.0 / N          # 30° par part

# ── Polices ──────────────────────────────────────────────────────────────────
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_REG  = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

def load_font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except:
        return ImageFont.load_default()

font_label  = load_font(FONT_BOLD, 17)
font_center = load_font(FONT_BOLD, 24)

# ── Création de l'image principale ──────────────────────────────────────────
main = Image.new("RGBA", (SIZE, SIZE), (25, 25, 25, 255))
draw = ImageDraw.Draw(main)

# Fond sombre dans le disque
draw.ellipse(
    [CX - RING_R, CY - RING_R, CX + RING_R, CY + RING_R],
    fill=(15, 15, 15)
)

# ── Parts de camembert ───────────────────────────────────────────────────────
for i, (name, color) in enumerate(SEGMENT_DATA):
    # PIL : angle 0 = droite (3h), donc on décale de -90° pour partir du haut
    start = i * SEG - 90
    end   = start + SEG
    draw.pieslice(
        [CX - RING_R, CY - RING_R, CX + RING_R, CY + RING_R],
        start=start, end=end,
        fill=color
    )

# ── Lignes blanches de séparation ────────────────────────────────────────────
for i in range(N):
    angle = math.radians(i * SEG - 90)
    x = CX + RING_R * math.cos(angle)
    y = CY + RING_R * math.sin(angle)
    draw.line([(CX, CY), (int(x), int(y))], fill=(255, 255, 255), width=3)

# ── Textes rotatifs (chaque label suit son segment) ──────────────────────────
for i, (name, color) in enumerate(SEGMENT_DATA):
    mid_deg = i * SEG + SEG / 2 - 90   # angle du milieu du segment (PIL)

    # Image temporaire pour le texte (fond transparent)
    TW, TH = 210, 32
    txt_img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    td = ImageDraw.Draw(txt_img)
    # Ombre légère pour lisibilité
    td.text((TW // 2 + 1, TH // 2 + 1), name,
            fill=(0, 0, 0, 160), font=font_label, anchor="mm")
    td.text((TW // 2, TH // 2), name,
            fill=(255, 255, 255, 255), font=font_label, anchor="mm")

    # Rotation du texte pour qu'il soit radial
    # PIL rotate : sens antihoraire → on passe -mid_deg pour alignement CW
    txt_rot = txt_img.rotate(-mid_deg, expand=True, resample=Image.BICUBIC)

    # Position sur le disque
    angle_rad = math.radians(mid_deg)
    tx = int(CX + TEXT_R * math.cos(angle_rad))
    ty = int(CY + TEXT_R * math.sin(angle_rad))
    rw, rh = txt_rot.size
    px = tx - rw // 2
    py = ty - rh // 2
    main.paste(txt_rot, (px, py), txt_rot)

# ── Anneau vert extérieur ─────────────────────────────────────────────────────
ring_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
rd = ImageDraw.Draw(ring_layer)

# Remplissage de l'anneau (OUTER_R → RING_R)
rd.ellipse([CX - OUTER_R, CY - OUTER_R, CX + OUTER_R, CY + OUTER_R],
           fill=(40, 160, 50))
# Effacement du centre pour ne garder que l'anneau
rd.ellipse([CX - RING_R, CY - RING_R, CX + RING_R, CY + RING_R],
           fill=(0, 0, 0, 0))
main.paste(ring_layer, (0, 0), ring_layer)
draw = ImageDraw.Draw(main)

# Bord intérieur vert foncé
draw.ellipse([CX - RING_R, CY - RING_R, CX + RING_R, CY + RING_R],
             outline=(30, 130, 40), width=4)
# Bord extérieur vert foncé
draw.ellipse([CX - OUTER_R, CY - OUTER_R, CX + OUTER_R, CY + OUTER_R],
             outline=(30, 110, 35), width=5)

# ── Points blancs sur l'anneau ────────────────────────────────────────────────
DOT_R   = (OUTER_R + RING_R) // 2   # milieu de l'anneau
N_DOTS  = N * 2                      # 24 points (2 par segment)
for i in range(N_DOTS):
    angle = math.radians(i * (360.0 / N_DOTS) - 90)
    dx = int(CX + DOT_R * math.cos(angle))
    dy = int(CY + DOT_R * math.sin(angle))
    draw.ellipse([dx - 6, dy - 6, dx + 6, dy + 6], fill=(255, 255, 255))

# ── Moyeu central "SPIN!" ──────────────────────────────────────────────────────
draw.ellipse([CX - CENTER_R, CY - CENTER_R, CX + CENTER_R, CY + CENTER_R],
             fill=(255, 255, 255))
draw.ellipse([CX - CENTER_R, CY - CENTER_R, CX + CENTER_R, CY + CENTER_R],
             outline=(200, 200, 200), width=3)
draw.text((CX, CY), "SPIN!", fill=(180, 20, 20),
          font=font_center, anchor="mm")

# ── Sauvegarde ────────────────────────────────────────────────────────────────
out = "/home/user/Brainrot-v5/wheel_preview.png"
main.save(out)
print(f"Image sauvegardée : {out}")
