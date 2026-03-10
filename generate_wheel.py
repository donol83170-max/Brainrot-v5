"""
generate_wheel.py
Génère des images de roues pour "Wheel a Brainrot"
Supporte plusieurs roues (Noob, Sigma, Ultra) avec couleurs par rareté.
"""

from PIL import Image, ImageDraw, ImageFont
import math
import os

# ── Dimensions ──────────────────────────────────────────────────────────────
SIZE     = 1024
CX, CY   = SIZE // 2, SIZE // 2
OUTER_R  = 480   # Bord extérieur
RING_R   = 440   # Bord intérieur (rayon du disque)
TEXT_R   = 300   # Rayon pour le texte
CENTER_R = 100   # Rayon du moyeu central

# ── Configuration des Raretés (Couleurs Roblox) ──────────────────────────────
RARITY_CONFIG = {
    "NORMAL":    {"perc": 60, "color": (163, 162, 165)},
    "RARE":      {"perc": 20, "color": (  0, 162, 255)},
    "MYTHIC":    {"perc": 10, "color": (170,   0, 255)},
    "LEGENDARY": {"perc":  8, "color": (255, 170,   0)},
    "ULTRA":     {"perc":  2, "color": (255,   0, 127)},
}

# ── Données des Roues (Synchronisées avec LootTables.lua) ────────────────────
WHEELS_DATA = {
    "wheel_noob": [
        ("Son Bruh", "NORMAL"), ("Tête de Noob", "NORMAL"), ("Pizza Froide", "NORMAL"),
        ("Emoji Mewing", "RARE"), ("Cravate Bleue", "RARE"), ("Sourire Sigma", "RARE"),
        ("Mâchoire Gigachad", "MYTHIC"), ("Tour de Pizza", "MYTHIC"),
        ("Tête Skibidi", "LEGENDARY"), ("Sigma d'Or", "LEGENDARY"),
        ("Sigma Galactique", "ULTRA"), ("Skibidi Diamant", "ULTRA")
    ],
    "wheel_sigma": [
        ("Cookie", "NORMAL"), ("Rizzler Basique", "NORMAL"), ("Tête de PNJ", "NORMAL"),
        ("Grind Sigma", "RARE"), ("Rizzler 500", "RARE"), ("Brainrot Wave", "RARE"),
        ("Roi Sigma", "MYTHIC"), ("Gobelin Glizzy", "MYTHIC"),
        ("Rizzler Ultra", "LEGENDARY"), ("Sigma Chad", "LEGENDARY"),
        ("Omega Sigma", "ULTRA"), ("Rizzler Divin", "ULTRA")
    ],
    "wheel_ultra": [
        ("Noob Cosmique", "NORMAL"), ("Pizza du Vide", "NORMAL"), ("Bruh Nébuleux", "NORMAL"),
        ("Sigma Stellaire", "RARE"), ("Skibidi Lunaire", "RARE"), ("Mewing Galactique", "RARE"),
        ("Nova Sigma", "MYTHIC"), ("Rizz Trou Noir", "MYTHIC"),
        ("Chad Univers", "LEGENDARY"), ("Skibidi Cosmique", "LEGENDARY"),
        ("Gigachad Absolu", "ULTRA"), ("Vrai Omega Sigma", "ULTRA")
    ]
}

# ── Polices ──────────────────────────────────────────────────────────────────
FONTS = [
    "C:/Windows/Fonts/arialbd.ttf",
    "C:/Windows/Fonts/segoeuib.ttf",
    "C:/Windows/Fonts/bahnschrift.ttf"
]

def load_font(size):
    for f in FONTS:
        if os.path.exists(f):
            try: return ImageFont.truetype(f, size)
            except: continue
    return ImageFont.load_default()

font_label  = load_font(28)
font_center = load_font(40)

def generate_wheel_image(filename, segments):
    N = len(segments)
    SEG = 360.0 / N

    main = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(main)

    # 1. Parts de camembert
    for i, (name, rarity) in enumerate(segments):
        color = RARITY_CONFIG[rarity]["color"]
        start = i * SEG - 90
        end   = start + SEG
        draw.pieslice([CX - RING_R, CY - RING_R, CX + RING_R, CY + RING_R],
                      start=start, end=end, fill=color)

    # 2. Séparateurs
    for i in range(N):
        angle = math.radians(i * SEG - 90)
        x = CX + RING_R * math.cos(angle)
        y = CY + RING_R * math.sin(angle)
        draw.line([(CX, CY), (int(x), int(y))], fill=(255, 255, 255), width=4)

    # 3. Textes
    for i, (name, rarity) in enumerate(segments):
        mid_deg = i * SEG + SEG / 2 - 90
        perc = RARITY_CONFIG[rarity]["perc"]
        full_name = f"{name}\n({perc}%)"

        # Image temporaire pour rotation
        TW, TH = 400, 100
        txt_img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
        td = ImageDraw.Draw(txt_img)
        
        norm_ang = (mid_deg + 90) % 360
        text_angle = -mid_deg
        if 90 < norm_ang < 270:
            text_angle += 180

        # Ombre et Texte
        td.text((TW // 2 + 2, TH // 2 + 2), full_name, fill=(0, 0, 0, 180), font=font_label, anchor="mm", align="center")
        td.text((TW // 2, TH // 2), full_name, fill=(255, 255, 255, 255), font=font_label, anchor="mm", align="center")

        txt_rot = txt_img.rotate(text_angle, expand=True, resample=Image.BICUBIC)
        
        angle_rad = math.radians(mid_deg)
        tx = int(CX + TEXT_R * math.cos(angle_rad))
        ty = int(CY + TEXT_R * math.sin(angle_rad))
        rw, rh = txt_rot.size
        main.paste(txt_rot, (tx - rw // 2, ty - rh // 2), txt_rot)

    # 4. Anneau extérieur
    draw.ellipse([CX - OUTER_R, CY - OUTER_R, CX + OUTER_R, CY + OUTER_R], outline=(40, 160, 50), width=15)
    
    # 5. Moyeu "SPIN!"
    draw.ellipse([CX - CENTER_R, CY - CENTER_R, CX + CENTER_R, CY + CENTER_R], fill=(255, 255, 255), outline=(200, 200, 200), width=5)
    draw.text((CX, CY), "SPIN!", fill=(180, 20, 20), font=font_center, anchor="mm")

    # 6. Sauvegarde
    out_path = os.path.join(os.getcwd(), f"{filename}.png")
    main.save(out_path)
    print(f"✅ Image générée : {out_path}")

# ── Exécution ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    for name, segments in WHEELS_DATA.items():
        generate_wheel_image(name, segments)

