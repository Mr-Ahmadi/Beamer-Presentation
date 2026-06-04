#!/usr/bin/env python3
"""Generate Beamer Presentation app icons - 4 concepts with light/dark variants."""
import os, subprocess, shutil, textwrap

OUT = "/tmp/beamer_icons"
MAC_ICON_DIR = "/Users/aliahmadi/Documents/Projects/Beamer/BeamerPresenter/BeamerPresenter/Assets.xcassets/AppIcon.appiconset"
IOS_ICON_DIR = "/Users/aliahmadi/Documents/Projects/Beamer/BeamerRemote/BeamerRemote/Assets.xcassets/AppIcon.appiconset"

os.makedirs(f"{OUT}/svg", exist_ok=True)
os.makedirs(f"{OUT}/png", exist_ok=True)

def svg2png(svg_path, png_path, size=1024):
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), "-o", png_path, svg_path], check=True)

def resize_png(src, dst, size):
    subprocess.run(["magick", src, "-resize", f"{size}x{size}", dst], check=True)

def make_icon(design_name, variant, svg_content):
    svg_path = f"{OUT}/svg/{design_name}_{variant}.svg"
    png1024 = f"{OUT}/png/{design_name}_{variant}_1024.png"
    with open(svg_path, "w") as f:
        f.write(svg_content)
    svg2png(svg_path, png1024, 1024)
    print(f"  Created {design_name}_{variant}")
    return png1024

def install_mac(png1024, prefix=""):
    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    for name, size in sizes:
        dst = f"{MAC_ICON_DIR}/{name}"
        resize_png(png1024, dst, size)
    print(f"  Installed macOS icons")

def install_ios(png1024):
    shutil.copy2(png1024, f"{IOS_ICON_DIR}/icon_1024.png")
    print(f"  Installed iOS icon")

# ======================================================================
# DESIGN 1: "Slide B" (Main Concept)
# Deep indigo/violet background, white slide with header, bold B monogram
# ======================================================================
def design_slide_b(variant):
    if variant == "dark":
        bg_stops = '<stop offset="0%" stop-color="#110B2C"/><stop offset="50%" stop-color="#2D1B69"/><stop offset="100%" stop-color="#1A1040"/>'
        b_fill = "url(#bgGrad)"
        slide_bg = "#FFFFFF"
        header_bg = "#F0F2F5"
        dot_color = "#D0D5DD"
        glass_opacity = "0.12"
        border_stroke = "rgba(255,255,255,0.08)"
    else:
        bg_stops = '<stop offset="0%" stop-color="#F2F4F7"/><stop offset="50%" stop-color="#E4E7EC"/><stop offset="100%" stop-color="#D0D5DD"/>'
        b_fill = "#2D1B69"
        slide_bg = "#FFFFFF"
        header_bg = "#F0F2F5"
        dot_color = "#C4C8CE"
        glass_opacity = "0"
        border_stroke = "rgba(0,0,0,0.04)"

    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bgGrad" x1="0" y1="0" x2="1" y2="1">{bg_stops}</linearGradient>
    <linearGradient id="glass" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="rgba(255,255,255,{glass_opacity})"/>
      <stop offset="100%" stop-color="rgba(255,255,255,0)"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="224" fill="url(#bgGrad)"/>
  <rect x="1.5" y="1.5" width="1021" height="1021" rx="222.5" fill="none" stroke="{border_stroke}" stroke-width="3"/>
  <rect x="214" y="248" width="600" height="455" rx="28" fill="rgba(0,0,0,0.15)"/>
  <rect x="212" y="242" width="600" height="455" rx="24" fill="{slide_bg}"/>
  <rect x="212" y="242" width="600" height="76" rx="24" fill="{header_bg}"/>
  <rect x="212" y="280" width="600" height="38" fill="{header_bg}"/>
  <circle cx="252" cy="282" r="7" fill="{dot_color}"/>
  <circle cx="284" cy="282" r="7" fill="{dot_color}"/>
  <circle cx="316" cy="282" r="7" fill="{dot_color}"/>
  <rect x="370" y="274" width="200" height="4" rx="2" fill="{dot_color}" opacity="0.7"/>
  <rect x="370" y="286" width="120" height="4" rx="2" fill="{dot_color}" opacity="0.5"/>
  <g fill="{b_fill}">
    <rect x="445" y="365" width="55" height="275" rx="27.5"/>
    <rect x="490" y="367" width="110" height="110" rx="55"/>
    <rect x="490" y="528" width="110" height="110" rx="55"/>
  </g>
  <rect x="0" y="0" width="1024" height="400" rx="224" fill="url(#glass)"/>
</svg>'''

# ======================================================================
# DESIGN 2: "Slide Stack" (Alternative 1)
# Three overlapping slides creating depth
# ======================================================================
def design_slide_stack(variant):
    if variant == "dark":
        bg_stops = '<stop offset="0%" stop-color="#0F172A"/><stop offset="100%" stop-color="#1E293B"/>'
        slide_fills = ["#FFFFFF", "rgba(255,255,255,0.6)", "rgba(255,255,255,0.3)"]
        offsets = [(0,0), (-16,12), (-32,24)]
        ruler_color = "rgba(0,0,0,0.08)"
    else:
        bg_stops = '<stop offset="0%" stop-color="#E2E8F0"/><stop offset="100%" stop-color="#CBD5E1"/>'
        slide_fills = ["#FFFFFF", "rgba(255,255,255,0.7)", "rgba(255,255,255,0.4)"]
        offsets = [(0,0), (-16,12), (-32,24)]
        ruler_color = "rgba(0,0,0,0.06)"

    slides = ""
    for i in range(3):
        ox, oy = offsets[i]
        x = 262 + ox
        y = 242 + oy
        slides += f'''
  <rect x="{x}" y="{y}" width="500" height="380" rx="20" fill="{slide_fills[i]}"/>'''
        if i == 0:
            slides += f'''
  <rect x="{x}" y="{y}" width="500" height="64" rx="20" fill="rgba(0,0,0,0.03)"/>
  <rect x="{x}" y="{y+30}" width="500" height="34" fill="rgba(0,0,0,0.03)"/>
  <circle cx="{x+40}" cy="{y+32}" r="6" fill="{ruler_color}"/>
  <circle cx="{x+68}" cy="{y+32}" r="6" fill="{ruler_color}"/>
  <circle cx="{x+96}" cy="{y+32}" r="6" fill="{ruler_color}"/>
  <rect x="{x+140}" y="{y+26}" width="160" height="4" rx="2" fill="{ruler_color}" opacity="0.6"/>
  <rect x="{x+140}" y="{y+36}" width="100" height="4" rx="2" fill="{ruler_color}" opacity="0.4"/>
  <!-- PDF/toolbar icon hint -->
  <rect x="{x+420}" y="{y+26}" width="48" height="18" rx="4" fill="{ruler_color}" opacity="0.3"/>'''

    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bgGrad" x1="0" y1="0" x2="1" y2="1">{bg_stops}</linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="224" fill="url(#bgGrad)"/>
  <rect x="1.5" y="1.5" width="1021" height="1021" rx="222.5" fill="none" stroke="rgba(255,255,255,0.06)" stroke-width="3"/>
  {slides}
  <!-- Play/forward icon on top slide -->
  <g transform="translate(512,470)">
    <polygon points="-28,-32 28,0 -28,32" fill="rgba(45,27,105,0.7)"/>
  </g>
</svg>'''

# ======================================================================
# DESIGN 3: "The Beam" (Alternative 2)
# Abstract light beam/projector metaphor
# ======================================================================
def design_beam(variant):
    if variant == "dark":
        bg_stops = '<stop offset="0%" stop-color="#05050A"/><stop offset="50%" stop-color="#0D0D1A"/><stop offset="100%" stop-color="#1A1040"/>'
        beam_grad = ('<linearGradient id="beamGrad" x1="0" y1="1" x2="0" y2="0">'
                     '<stop offset="0%" stop-color="rgba(255,255,255,0)"/>'
                     '<stop offset="100%" stop-color="rgba(255,255,255,0.12)"/></linearGradient>')
        slide_bg = "#FFFFFF"
        b_fill = "#1A1040"
    else:
        bg_stops = '<stop offset="0%" stop-color="#F8F9FA"/><stop offset="50%" stop-color="#E9ECEF"/><stop offset="100%" stop-color="#DEE2E6"/>'
        beam_grad = ('<linearGradient id="beamGrad" x1="0" y1="1" x2="0" y2="0">'
                     '<stop offset="0%" stop-color="rgba(45,27,105,0)"/>'
                     '<stop offset="100%" stop-color="rgba(45,27,105,0.06)"/></linearGradient>')
        slide_bg = "#FFFFFF"
        b_fill = "#2D1B69"

    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bgGrad" x1="0" y1="0" x2="1" y2="1">{bg_stops}</linearGradient>
    {beam_grad}
  </defs>
  <rect width="1024" height="1024" rx="224" fill="url(#bgGrad)"/>
  <rect x="1.5" y="1.5" width="1021" height="1021" rx="222.5" fill="none" stroke="rgba(255,255,255,0.05)" stroke-width="3"/>
  <!-- Light beam triangle -->
  <polygon points="512,720 282,260 742,260" fill="url(#beamGrad)"/>
  <polygon points="512,680 312,280 712,280" fill="rgba(255,255,255,0.03)"/>
  <!-- Small slide at top of beam -->
  <rect x="362" y="190" width="300" height="220" rx="16" fill="{slide_bg}"/>
  <rect x="362" y="190" width="300" height="44" rx="16" fill="rgba(0,0,0,0.03)"/>
  <rect x="362" y="220" width="300" height="14" fill="rgba(0,0,0,0.03)"/>
  <circle cx="390" cy="212" r="5" fill="rgba(0,0,0,0.08)"/>
  <circle cx="410" cy="212" r="5" fill="rgba(0,0,0,0.08)"/>
  <circle cx="430" cy="212" r="5" fill="rgba(0,0,0,0.08)"/>
  <g fill="{b_fill}">
    <rect x="475" y="272" width="34" height="100" rx="17"/>
    <rect x="505" y="274" width="62" height="48" rx="24"/>
    <rect x="505" y="330" width="62" height="48" rx="24"/>
  </g>
</svg>'''

# ======================================================================
# DESIGN 4: "Big B" (Alternative 3)
# Bold typographic B monogram with slide frame hint
# ======================================================================
def design_big_b(variant):
    if variant == "dark":
        bg_stops = '<stop offset="0%" stop-color="#1E1E24"/><stop offset="50%" stop-color="#2D2D35"/><stop offset="100%" stop-color="#3A3A45"/>'
        b_fill = "#FFFFFF"
        accent_stroke = "rgba(255,255,255,0.1)"
        inner_b = "#2D2D35"
    else:
        bg_stops = '<stop offset="0%" stop-color="#E8E8ED"/><stop offset="50%" stop-color="#F2F2F7"/><stop offset="100%" stop-color="#FFFFFF"/>'
        b_fill = "#2D1B69"
        accent_stroke = "rgba(0,0,0,0.06)"
        inner_b = "#FFFFFF"

    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bgGrad" x1="0" y1="0" x2="1" y2="1">{bg_stops}</linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="224" fill="url(#bgGrad)"/>
  <rect x="1.5" y="1.5" width="1021" height="1021" rx="222.5" fill="none" stroke="{accent_stroke}" stroke-width="3"/>
  <!-- Slide frame outline -->
  <rect x="152" y="172" width="720" height="560" rx="32" fill="none" stroke="{b_fill}" stroke-width="8" opacity="0.15"/>
  <rect x="152" y="172" width="720" height="90" rx="32" fill="none" stroke="{b_fill}" stroke-width="8" opacity="0.15"/>
  <rect x="152" y="222" width="720" height="40" fill="none" stroke="{b_fill}" stroke-width="8" opacity="0.15"/>
  <!-- Window dots on frame -->
  <circle cx="208" cy="217" r="10" fill="{b_fill}" opacity="0.12"/>
  <circle cx="248" cy="217" r="10" fill="{b_fill}" opacity="0.12"/>
  <circle cx="288" cy="217" r="10" fill="{b_fill}" opacity="0.12"/>
  <!-- Big B letterform -->
  <g fill="{b_fill}">
    <rect x="355" y="262" width="80" height="420" rx="40"/>
    <rect x="420" y="265" width="170" height="175" rx="85"/>
    <rect x="420" y="505" width="170" height="175" rx="85"/>
  </g>
  <!-- Subtle highlight on B -->
  <g fill="{inner_b}" opacity="0.3">
    <rect x="365" y="272" width="20" height="100" rx="10"/>
    <rect x="430" y="278" width="60" height="50" rx="25"/>
    <rect x="430" y="518" width="60" height="50" rx="25"/>
  </g>
</svg>'''

# ======================================================================
# GENERATE ALL
# ======================================================================
designs = {
    "01_SlideB": design_slide_b,
    "02_SlideStack": design_slide_stack,
    "03_Beam": design_beam,
    "04_BigB": design_big_b,
}

variants = ["dark", "light"]

print("Generating icons...")
for dname, dfunc in designs.items():
    for v in variants:
        svg = dfunc(v)
        make_icon(dname, v, svg)

print("\nAll SVGs generated. Installing icons...")

# Install main design (Slide B) - dark variant for main icons
main_png = f"{OUT}/png/01_SlideB_dark_1024.png"
install_mac(main_png)
install_ios(main_png)
print(f"\nMain icon (Slide B Dark) installed to both targets.")

# Also install iOS dark/light variants for reference
for v in variants:
    src = f"{OUT}/png/01_SlideB_{v}_1024.png"
    dst = f"{OUT}/png/beamer_icon_{v}.png"
    shutil.copy2(src, dst)

print("Done! Available designs in /tmp/beamer_icons/png/:")
for f in sorted(os.listdir(f"{OUT}/png/")):
    if f.endswith(".png"):
        sz = os.path.getsize(f"{OUT}/png/{f}")
        print(f"  {f}: {sz/1024:.1f} KB")
