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

# ── Couleurs par rareté (mêmes constantes que Roblox) ─────────────────────────
# On associe chaque rareté à son pourcentage et sa couleur
RARITY_CONFIG = {
    "NORMAL":    {"perc": 60, "color": (163, 162, 165)},
    "RARE":      {"perc": 20, "color": (  0, 162, 255)},
    "MYTHIC":    {"perc": 10, "color": (170,   0, 255)},
    "LEGENDARY": {"perc":  8, "color": (255, 170,   0)},
    "ULTRA":     {"perc":  2, "color": (255,   0, 127)},
}

SEGMENT_DATA = [
    ("Son Bruh",            "NORMAL"),
    ("Tête de Noob",        "NORMAL"),
    ("Pizza Froide",        "NORMAL"),
    ("Emoji Mewing",        "RARE"),
    ("Cravate Bleue",       "RARE"),
    ("Sourire Sigma",       "RARE"),
    ("Mâchoire Gigachad",   "MYTHIC"),
    ("Tour de Pizza",       "MYTHIC"),
    ("Tête Skibidi",        "LEGENDARY"),
    ("Sigma d'Or",          "LEGENDARY"),
    ("Sigma Galactique",    "ULTRA"),
    ("Skibidi Diamant",     "ULTRA"),
]

N   = len(SEGMENT_DATA)
SEG = 360.0 / N          # 30° par part

# ── Polices ──────────────────────────────────────────────────────────────────
# Chemins Windows ou défaut
FONTS = [
    "C:/Windows/Fonts/arialbd.ttf",
    "C:/Windows/Fonts/segoeuib.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
]

def load_font(size):
    for f in FONTS:
        try: return ImageFont.truetype(f, size)
        except: continue
    return ImageFont.load_default()

font_label  = load_font(18)
font_center = load_font(24)

# ── Création de l'image principale ──────────────────────────────────────────
main = Image.new("RGBA", (SIZE, SIZE), (25, 25, 25, 255))
draw = ImageDraw.Draw(main)

# Fond sombre dans le disque
draw.ellipse(
    [CX - RING_R, CY - RING_R, CX + RING_R, CY + RING_R],
    fill=(15, 15, 15)
)

# ── Parts de camembert ───────────────────────────────────────────────────────
for i, (name, rarity) in enumerate(SEGMENT_DATA):
    color = RARITY_CONFIG[rarity]["color"]
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
for i, (name, rarity) in enumerate(SEGMENT_DATA):
    mid_deg = i * SEG + SEG / 2 - 90   # angle du milieu du segment (PIL)
    
    perc = RARITY_CONFIG[rarity]["perc"]
    full_name = f"{name} ({perc}%)"

    # Image temporaire pour le texte (fond transparent)
    TW, TH = 240, 40
    txt_img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    td = ImageDraw.Draw(txt_img)
    
    # Rotation logic for readability
    # On normalise l'angle pour savoir si on est en bas
    norm_ang = (mid_deg + 90) % 360
    text_angle = -mid_deg
    
    if 90 < norm_ang < 270:
        text_angle += 180
    
    # Ombre légère pour lisibilité
    td.text((TW // 2 + 1, TH // 2 + 1), full_name,
            fill=(0, 0, 0, 200), font=font_label, anchor="mm")
    td.text((TW // 2, TH // 2), full_name,
            fill=(255, 255, 255, 255), font=font_label, anchor="mm")

    # Rotation du texte
    txt_rot = txt_img.rotate(text_angle, expand=True, resample=Image.BICUBIC)

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

# ── FLÈCHE INDICATRICE (EN HAUT) ──────────────────────────────────────────────
# Un triangle rouge pointant vers le bas au sommet de la roue
ARROW_W = 40
ARROW_H = 35
pts = [
    (CX - ARROW_W//2, CY - OUTER_R - 10), # Gauche haut
    (CX + ARROW_W//2, CY - OUTER_R - 10), # Droite haut
    (CX, CY - OUTER_R + ARROW_H - 10)     # Pointe bas (touche l'anneau)
]
draw.polygon(pts, fill=(220, 20, 20), outline=(255, 255, 255))

# ── Sauvegarde ────────────────────────────────────────────────────────────────
import os
out = os.path.join(os.getcwd(), "wheel_preview.png")
main.save(out)
print(f"Image sauvegardée : {out}")
