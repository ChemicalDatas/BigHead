#!/usr/bin/env python3
"""Makes the grayscale UNACHIEVED icons from the ACHIEVED ones that
tools/achievement_icons.tscn renders, and checks every icon is 256x256.

    python3 tools/finish_icons.py
"""
import glob
import os
from PIL import Image, ImageEnhance, ImageOps

DIR = os.path.join(os.path.dirname(__file__), "..", "steam", "achievements")

made = 0
for path in sorted(glob.glob(os.path.join(DIR, "*_ACHIEVED.png"))):
    icon = Image.open(path).convert("RGB")
    assert icon.size == (256, 256), f"{path} is {icon.size}, expected 256x256"
    gray = ImageOps.grayscale(icon).convert("RGB")
    gray = ImageEnhance.Brightness(gray).enhance(0.7)
    gray = ImageEnhance.Contrast(gray).enhance(0.8)
    gray.save(path.replace("_ACHIEVED.png", "_UNACHIEVED.png"))
    made += 1
print(f"Made {made} unachieved icons in {os.path.normpath(DIR)}")
