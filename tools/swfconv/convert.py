"""Convert a SWF into a Godot-loadable asset library.

Output (in <out_dir>):
  library.json      symbols: shapes (image + bounds), sprites (timelines), texts, sounds, fonts, bitmaps, classes
  shapes/*.png      rasterised shapes (s<id>), morph shapes at used ratios (m<id>_<ratio>) and static texts (t<id>)
  sounds/<id>.mp3   event sounds
  fonts/<id>.ttf    embedded fonts
  bitmaps/<id>.*    embedded bitmaps

Usage: python convert.py <file.swf> <out_dir> [--scale 2] [--ffdec path/to/ffdec.jar]
"""
import argparse
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from swfparse import SWF, Bits, BLEND_MODES, parse_filters  # noqa: E402
import shapes  # noqa: E402
import framescripts  # noqa: E402

DEFAULT_FFDEC = r'C:\Program Files (x86)\FFDec\ffdec.jar'
SYNTH_ID_START = 20000


def r6(v):
    return round(v, 6)


# ---------------------------------------------------------------- timelines

def placement_key(p):
    out = {'c': p['id']}
    m = p.get('matrix')
    if m and m != [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]:
        out['m'] = [r6(v) for v in m]
    ct = p.get('cxform')
    if ct and ct != [1.0, 1.0, 1.0, 1.0, 0, 0, 0, 0]:
        out['ct'] = [r6(v) for v in ct]
    if p.get('ratio'):
        out['r'] = p['ratio']
    if p.get('name'):
        out['n'] = p['name']
    if p.get('clipDepth'):
        out['cd'] = p['clipDepth']
    if p.get('blend') and p['blend'] != 'normal':
        out['bl'] = p['blend']
    if p.get('filters'):
        out['f'] = p['filters']
    if 'visible' in p and not p['visible']:
        out['v'] = 0
    if p.get('cacheAsBitmap'):
        out['cab'] = 1
    return out


def build_timeline(frames_ops, labels, morph_uses):
    """Flattens SWF control tags into per-frame display lists.

    Returns dict with:
      places: unique placement dicts
      frames: per frame, list of [depth, placeIndex, birthFrame] sorted by depth
      labels: name -> 0-based frame
      sounds: {frame: [soundId, ...]}
    birthFrame identifies the instance: Flash keeps an existing child across a goto only when it is the same
    instance (same depth, same birth frame)."""
    places = []
    index = {}
    state = {}
    frames = []
    sounds = {}
    for fi, ops in enumerate(frames_ops):
        for op in ops:
            if op['op'] == 'remove':
                state.pop(op['depth'], None)
            elif op['op'] == 'sound':
                sounds.setdefault(fi, []).append(op['id'])
            elif op['op'] == 'place':
                d = op['depth']
                if not op['move'] or d not in state:
                    if 'id' not in op:
                        continue
                    cur = {k: v for k, v in op.items() if k not in ('op', 'move', 'depth', 'hasClipActions')}
                    state[d] = [cur, fi]
                else:
                    cur = dict(state[d][0])
                    for k, v in op.items():
                        if k not in ('op', 'move', 'depth', 'hasClipActions'):
                            cur[k] = v
                    if 'id' in op and op['id'] != state[d][0]['id']:
                        state[d] = [cur, fi]
                    else:
                        state[d] = [cur, state[d][1]]
        row = []
        for d in sorted(state):
            p, birth = state[d]
            key = placement_key(p)
            morph_uses.setdefault(key['c'], set()).add(key.get('r', 0))
            sk = json.dumps(key, sort_keys=True)
            if sk not in index:
                index[sk] = len(places)
                places.append(key)
            row.append([d, index[sk], birth])
        frames.append(row)
    out = {'places': places, 'frames': frames, 'labels': labels}
    if sounds:
        out['sounds'] = {str(k): v for k, v in sounds.items()}
    return out


# ---------------------------------------------------------------- other characters

def parse_edit_text(data, pos):
    b = Bits(data, pos)
    cid = b.u16()
    bounds = b.rect()
    has_text = b.ub(1)
    word_wrap = b.ub(1)
    multiline = b.ub(1)
    password = b.ub(1)
    read_only = b.ub(1)
    has_color = b.ub(1)
    has_max = b.ub(1)
    has_font = b.ub(1)
    has_font_class = b.ub(1)
    auto_size = b.ub(1)
    has_layout = b.ub(1)
    no_select = b.ub(1)
    border = b.ub(1)
    was_static = b.ub(1)
    html = b.ub(1)
    use_outlines = b.ub(1)
    e = {'t': 'edittext', 'x': bounds[0] / 20.0, 'y': bounds[2] / 20.0, 'w': (bounds[1] - bounds[0]) / 20.0,
         'h': (bounds[3] - bounds[2]) / 20.0, 'wordWrap': word_wrap, 'multiline': multiline, 'password': password,
         'readOnly': read_only, 'autoSize': auto_size, 'selectable': 0 if no_select else 1, 'border': border,
         'html': html, 'useOutlines': use_outlines, 'wasStatic': was_static}
    if has_font:
        e['font'] = b.u16()
    if has_font_class:
        e['fontClass'] = b.string()
    if has_font or has_font_class:
        e['fontHeight'] = b.u16() / 20.0
    if has_color:
        e['color'] = list(b.bytes(4))
    if has_max:
        e['maxLength'] = b.u16()
    if has_layout:
        e['align'] = ['left', 'right', 'center', 'justify'][b.u8() & 3]
        e['leftMargin'] = b.u16() / 20.0
        e['rightMargin'] = b.u16() / 20.0
        e['indent'] = b.u16() / 20.0
        e['leading'] = b.s16() / 20.0
    e['variable'] = b.string()
    if has_text:
        e['text'] = b.string()
    return cid, e


def parse_button2(data, pos, ln):
    b = Bits(data, pos)
    cid = b.u16()
    b.u8()
    b.u16()  # action offset
    records = []
    while True:
        flags = b.u8()
        if flags == 0:
            break
        rec = {'states': [s for s, bit in (('up', 1), ('over', 2), ('down', 4), ('hit', 8)) if flags & bit]}
        rec['c'] = b.u16()
        rec['depth'] = b.u16()
        rec['m'] = [r6(v) for v in b.matrix()]
        rec['ct'] = [r6(v) for v in b.cxform(True)]
        if flags & 0x10:
            rec['f'] = parse_filters(b)
        if flags & 0x20:
            rec['bl'] = BLEND_MODES.get(b.u8(), 'normal')
        records.append(rec)
    return cid, {'t': 'button', 'records': records}


# ---------------------------------------------------------------- main

def run_ffdec(ffdec, args):
    cmd = ['java', '-jar', ffdec] + args
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)


def build_hitmasks(out_dir, chars, scale):
    """Packs a 1x, 1-bit alpha mask per rasterised image into hitmasks.bin for shape-accurate hitTestPoint.

    Flash hit-tests and masks with the geometry, whatever the fill's alpha: an image whose most opaque pixel is
    below 1 gets 'ma' (that alpha), and its coverage is divided by it."""
    import numpy as np
    from PIL import Image
    blob = bytearray()

    def mask_for(entry):
        path = os.path.join(out_dir, 'shapes', entry['img'] + '.png')
        a = np.asarray(Image.open(path).convert('RGBA'))[:, :, 3].astype(np.float32) / 255.0
        top = float(a.max()) if a.size else 1.0
        entry.pop('ma', None)
        if 0.0 < top < 0.999:
            entry['ma'] = round(top, 4)
            a = np.minimum(a / top, 1.0)
        w = max(1, int(np.ceil(a.shape[1] / scale)))
        h = max(1, int(np.ceil(a.shape[0] / scale)))
        s = int(round(scale))
        padded = np.zeros((h * s, w * s), np.float32)
        padded[:a.shape[0], :a.shape[1]] = a
        cov = padded.reshape(h, s, w, s).mean(axis=(1, 3))
        bits = np.packbits((cov >= 0.5).astype(np.uint8), axis=None, bitorder='little')
        entry['hm'] = [len(blob), w, h]
        blob.extend(bits.tobytes())

    for e in chars.values():
        if e.get('t') == 'shape':
            mask_for(e)
        elif e.get('t') == 'morph':
            for re_ in e['ratios'].values():
                if re_:
                    mask_for(re_)
    with open(os.path.join(out_dir, 'hitmasks.bin'), 'wb') as f:
        f.write(bytes(blob))
    print('hitmasks', len(blob), 'bytes')


def convert(swf_path, out_dir, scale, ffdec, scripts_dir=None):
    s = SWF(swf_path)
    os.makedirs(out_dir, exist_ok=True)
    for sub in ('shapes', 'sounds', 'fonts', 'bitmaps'):
        os.makedirs(os.path.join(out_dir, sub), exist_ok=True)
    lib = {'version': 1, 'width': (s.rect[1] - s.rect[0]) / 20.0, 'height': (s.rect[3] - s.rect[2]) / 20.0,
           'fps': s.frame_rate, 'scale': scale, 'classes': {}, 'chars': {}}
    chars = lib['chars']
    for cid, name in s.symbol_class.items():
        if cid == 0:
            lib['documentClass'] = name
        else:
            lib['classes'][name] = cid
    for cid, name in s.exports.items():
        lib['classes'].setdefault(name, cid)

    morph_uses = {}
    # timelines
    for cid, ch in s.chars.items():
        if ch['type'] == 'sprite':
            frames, labels = s.timeline(cid)
            tl = build_timeline(frames, labels, morph_uses)
            tl['t'] = 'sprite'
            if cid in s.scaling_grids:
                g = s.scaling_grids[cid]
                tl['grid'] = [g[0] / 20.0, g[2] / 20.0, (g[1] - g[0]) / 20.0, (g[3] - g[2]) / 20.0]
            chars[str(cid)] = tl
    frames, labels = s.timeline()
    root = build_timeline(frames, labels, morph_uses)
    if s.scene_labels:
        root['scenes'] = [[off, name] for off, name in s.scene_labels['scenes']]
    lib['root'] = root

    # synthetic shapes: morph ratios + static texts
    synth = []
    next_id = SYNTH_ID_START
    fonts = {}
    for cid, ch in s.chars.items():
        if ch['type'] == 'font' and ch['code'] in (48, 75):
            fonts[cid] = shapes.read_font3(s.data, ch['pos'], ch['code'])
    shape_jobs = {}  # synthetic id -> (char key, image name, bounds)
    for cid, ch in s.chars.items():
        if ch['type'] == 'morph':
            m = shapes.read_morph(s.data, ch['pos'], ch['code'])
            entry = {'t': 'morph', 'ratios': {}}
            for ratio in sorted(morph_uses.get(cid, {0})):
                st = shapes.morph_at(m, ratio)
                synth.append(shapes.tag(83, shapes.write_shape4(next_id, st)))
                img = 'm%d_%d' % (cid, ratio)
                shape_jobs[next_id] = img
                entry['ratios'][str(ratio)] = _img_entry(img, st['bounds'])
                next_id += 1
            chars[str(cid)] = entry
        elif ch['type'] == 'text':
            t = shapes.read_text(s.data, ch['pos'], ch['code'])
            st = shapes.text_to_shape(t, fonts)
            if st is None:
                chars[str(cid)] = {'t': 'empty'}
                continue
            synth.append(shapes.tag(83, shapes.write_shape4(next_id, st)))
            img = 't%d' % cid
            shape_jobs[next_id] = img
            chars[str(cid)] = dict(_img_entry(img, st['bounds']), t='shape')
            next_id += 1
        elif ch['type'] == 'shape':
            chars[str(cid)] = dict(_img_entry('s%d' % cid, ch['bounds']), t='shape')
        elif ch['type'] == 'edittext':
            _, e = parse_edit_text(s.data, ch['pos'])
            chars[str(cid)] = e
        elif ch['type'] == 'button':
            if ch['code'] == 34:
                _, e = parse_button2(s.data, ch['pos'], ch['len'])
                chars[str(cid)] = e
        elif ch['type'] == 'font':
            f = fonts.get(cid)
            chars[str(cid)] = {'t': 'font', 'name': f['name'] if f else '', 'file': 'fonts/%d.ttf' % cid}
        elif ch['type'] == 'sound':
            chars[str(cid)] = {'t': 'sound', 'file': 'sounds/%d.mp3' % cid}
        elif ch['type'] == 'bitmap':
            chars[str(cid)] = {'t': 'bitmap'}
        elif ch['type'] == 'binary':
            chars[str(cid)] = {'t': 'binary', 'file': 'binary/%d.bin' % cid}

    tmp = tempfile.mkdtemp(prefix='swfconv_')
    try:
        # synthetic swf (needs the bitmaps too, for bitmap-filled morphs)
        synth_tags = [shapes.tag(code, s.data[pos:pos + ln]) for code, pos, ln in s.tags
                      if code in (8, 6, 20, 21, 35, 36, 90)]
        synth_swf = os.path.join(tmp, 'synth.swf')
        shapes.write_swf(synth_swf, synth_tags + synth)
        zoom = str(scale)
        run_ffdec(ffdec, ['-format', 'shape:png', '-zoom', zoom, '-export', 'shape', os.path.join(tmp, 'shapes'),
                          swf_path])
        run_ffdec(ffdec, ['-format', 'shape:png', '-zoom', zoom, '-export', 'shape', os.path.join(tmp, 'synth'),
                          synth_swf])
        run_ffdec(ffdec, ['-format', 'sound:mp3_wav', '-export', 'sound', os.path.join(tmp, 'sounds'), swf_path])
        run_ffdec(ffdec, ['-format', 'font:ttf', '-export', 'font', os.path.join(tmp, 'fonts'), swf_path])
        run_ffdec(ffdec, ['-export', 'image', os.path.join(tmp, 'images'), swf_path])
        run_ffdec(ffdec, ['-export', 'binaryData', os.path.join(tmp, 'binary'), swf_path])

        dst = os.path.join(out_dir, 'shapes')
        for f in os.listdir(os.path.join(tmp, 'shapes')):
            cid = int(re.match(r'\d+', f).group())  # FFDec adds _ClassName to a shape with a class
            shutil.move(os.path.join(tmp, 'shapes', f), os.path.join(dst, 's%d.png' % cid))
        for f in os.listdir(os.path.join(tmp, 'synth')):
            sid = int(re.match(r'\d+', f).group())
            if sid in shape_jobs:
                shutil.move(os.path.join(tmp, 'synth', f), os.path.join(dst, shape_jobs[sid] + '.png'))
        _move_prefixed(os.path.join(tmp, 'sounds'), os.path.join(out_dir, 'sounds'), chars, 'sound')
        _move_prefixed(os.path.join(tmp, 'fonts'), os.path.join(out_dir, 'fonts'), chars, 'font')
        _move_prefixed(os.path.join(tmp, 'images'), os.path.join(out_dir, 'bitmaps'), chars, 'bitmap')
        os.makedirs(os.path.join(out_dir, 'binary'), exist_ok=True)
        _move_prefixed(os.path.join(tmp, 'binary'), os.path.join(out_dir, 'binary'), chars, 'binary')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    if scripts_dir:
        fs, warnings = framescripts.extract(scripts_dir)
        for w in warnings:
            print('frame script warning:', w)
        for cls, scripts in fs.items():
            cid = lib['classes'].get(cls)
            if cid is not None and str(cid) in chars:
                chars[str(cid)]['fs'] = {str(k): v for k, v in scripts.items()}

    # drop references to images FFDec did not produce (empty shapes)
    for cid, e in chars.items():
        if e.get('t') == 'shape' and not os.path.exists(os.path.join(out_dir, 'shapes', e['img'] + '.png')):
            chars[cid] = {'t': 'empty'}
        if e.get('t') == 'morph':
            for r, re_ in list(e['ratios'].items()):
                if not os.path.exists(os.path.join(out_dir, 'shapes', re_['img'] + '.png')):
                    e['ratios'][r] = None
    build_hitmasks(out_dir, chars, scale)
    with open(os.path.join(out_dir, 'library.json'), 'w', encoding='utf-8') as f:
        json.dump(lib, f, separators=(',', ':'))
    # Flash hit-tests geometry: masks of shapes with transparent fills are re-derived from opaque renders.
    subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fix_hitmasks.py'),
                    swf_path, out_dir, '--ffdec', ffdec], check=True)
    # FFDec does not anti-alias gradient / bitmap fills: re-render those shapes supersampled.
    subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'supersample.py'),
                    swf_path, out_dir, '--ffdec', ffdec], check=True)
    print('chars', len(chars), 'synthetic shapes', len(shape_jobs))


def _img_entry(img, bounds):
    return {'img': img, 'x': bounds[0] / 20.0, 'y': bounds[2] / 20.0, 'w': (bounds[1] - bounds[0]) / 20.0,
            'h': (bounds[3] - bounds[2]) / 20.0}


def _move_prefixed(src, dst, chars, kind):
    """FFDec names files '<id>_<name>.<ext>' or '<id>.<ext>'; store as '<id>.<ext>'."""
    if not os.path.isdir(src):
        return
    for root, _, files in os.walk(src):
        for f in files:
            m = re.match(r'(-?\d+)', f)
            if not m:
                continue
            cid = m.group(1)
            ext = os.path.splitext(f)[1].lower()
            shutil.move(os.path.join(root, f), os.path.join(dst, cid + ext))
            e = chars.get(cid)
            if e is not None and e.get('t') == kind:
                e['file'] = '%s/%s%s' % (os.path.basename(dst), cid, ext)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('swf')
    ap.add_argument('out')
    ap.add_argument('--scale', type=float, default=2)
    ap.add_argument('--ffdec', default=DEFAULT_FFDEC)
    ap.add_argument('--scripts', help='FFDec-decompiled AS3 folder, for timeline frame scripts')
    a = ap.parse_args()
    convert(a.swf, a.out, int(a.scale) if a.scale == int(a.scale) else a.scale, a.ffdec, a.scripts)
