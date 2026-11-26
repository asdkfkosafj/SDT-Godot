"""Pulls in a shape's edge where a shape drawn over it ends on that same edge (a conflation seam).

Two shapes of one picture that end on the same edge are both half transparent there (anti-aliasing), so a little of
the lower one shows through the upper one's soft edge: a thin line of the lower shape's colour along the edge (her
jaw: the lighter skin under the jaw's own skin shape, an L-shaped light line on her cheek with her mouth open).
For each pair in PAIRS, the lower shape's alpha is pulled in by `pull` stage px only along the part of its edge that
lies on the upper shape's edge (for a morph: on any of its frames) inside the pair's area, blending to the drawn edge
past that part. The
upper shape's soft edge then lies over what is under both (the same skin), so no line shows; the rest of the lower
shape stays as drawn. Only the alpha changes. A done shape is marked in library.json ("pulled"), so a second run
leaves it alone.

Usage: shared_edges.py <library dir>
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

# [sprite id, lower shape id, upper shape id (a shape or a morph), pull in stage px, area]: both placed in that sprite
# without a matrix (one space); ids of the game's own SWF (a pair is skipped unless the sprite places both). area:
# [x0, y0, x1, y1] in stage px of that space (None: no limit), so only the edge that shows a line is pulled - where
# a darker shape lies under both (her neck under the jaw's bottom edge), pulling in would show a dark line instead.
PAIRS = [
    # her jaw: its light skin under the jaw's skin shape; only the top edge and the edge beside her mouth, down to
    # the corner at her lip (the L line), not the bottom edge over her neck
    ['1101', '1056', '1057', 1.5, [-1000, -1000, 1000, 50.5]],
]


def _placed(lib_dir, entry, size, origin, scale):
    im = Image.open(os.path.join(lib_dir, 'shapes', entry['img'] + '.png')).convert('RGBA')
    canvas = Image.new('L', size, 0)
    canvas.paste(im.getchannel('A'), (int(round((entry['x'] - origin[0]) * scale)),
                                      int(round((entry['y'] - origin[1]) * scale))))
    return canvas


def _edge_band(alpha, r):
    """Pixels within r px of the shape's edge, inside or out."""
    hi = np.asarray(alpha.filter(ImageFilter.MaxFilter(2 * r + 1)))
    lo = np.asarray(alpha.filter(ImageFilter.MinFilter(2 * r + 1)))
    return (hi > 8) & (lo < 247)


def pull(lib_dir, lower_id, upper_id, amount, area, chars, scale):
    lower = chars[lower_id]
    if lower.get('pulled'):
        return False
    upper = chars[upper_id]
    entries = [e for e in upper['ratios'].values() if e] if upper.get('t') == 'morph' else [upper]
    pad = 8
    origin = (lower['x'] - pad / scale, lower['y'] - pad / scale)
    size = (int(lower['w'] * scale) + 2 * pad + 2, int(lower['h'] * scale) + 2 * pad + 2)
    a_low = _placed(lib_dir, lower, size, origin, scale)
    low_band = _edge_band(a_low, 1)
    shared = np.zeros(low_band.shape, bool)
    for e in entries:
        a_up = _placed(lib_dir, e, size, origin, scale)
        near_up = np.asarray(a_up.filter(ImageFilter.MaxFilter(5))) > 8
        shared |= low_band & _edge_band(a_up, 2) & near_up
    if area:
        ys, xs = np.mgrid[0:size[1], 0:size[0]]
        sx = origin[0] + (xs + 0.5) / scale
        sy = origin[1] + (ys + 0.5) / scale
        shared &= (sx >= area[0]) & (sy >= area[1]) & (sx <= area[2]) & (sy <= area[3])
    r = max(1, int(round(amount * scale)))
    pulled = np.asarray(a_low.filter(ImageFilter.MinFilter(2 * r + 1))).astype(np.float32)
    # weight 1 on the shared part (and r + 1 px round it, where the pulled-in edge lies), fading out past its ends
    w = Image.fromarray((shared * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(2 * (r + 1) + 1))
    w = np.asarray(w.filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255.0
    w = np.clip(w * 2.0, 0.0, 1.0)
    alpha = np.asarray(a_low).astype(np.float32)
    new_alpha = alpha * (1.0 - w) + np.minimum(alpha, pulled) * w
    # back into the shape's own image
    path = os.path.join(lib_dir, 'shapes', lower['img'] + '.png')
    im = Image.open(path).convert('RGBA')
    ox = int(round((lower['x'] - origin[0]) * scale))
    oy = int(round((lower['y'] - origin[1]) * scale))
    rgba = np.asarray(im).copy()
    rgba[..., 3] = np.clip(new_alpha[oy:oy + im.height, ox:ox + im.width] + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(rgba, 'RGBA').save(path)
    lower['pulled'] = [upper_id, amount, area]
    print('pulled s%s under %s: %d edge px shared' % (lower_id, upper_id, int(shared.sum())))
    return True


def main():
    lib_dir = sys.argv[1]
    with open(os.path.join(lib_dir, 'library.json'), encoding='utf-8') as f:
        lib = json.load(f)
    scale = float(lib.get('scale', 2))
    changed = False
    chars = lib['chars']
    for sprite_id, lower_id, upper_id, amount, area in PAIRS:
        places = chars.get(sprite_id, {}).get('places', [])
        plain = {str(p['c']) for p in places if 'm' not in p}
        if lower_id in plain and upper_id in plain:
            changed = pull(lib_dir, lower_id, upper_id, amount, area, chars, scale) or changed
    if changed:
        with open(os.path.join(lib_dir, 'library.json'), 'w', encoding='utf-8') as f:
            json.dump(lib, f, separators=(',', ':'))


if __name__ == '__main__':
    main()
