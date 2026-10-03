#!/usr/bin/env python3
"""Convert a bounded set of built-in VPet assets. No runtime LPS dependency."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

MODES = ["Happy", "Nomal", "PoorCondition", "Ill"]
ACTIONS = {"idle": "Default", "head": "Touch_Head", "body": "Touch_Body", "raised": "Raise/Raised_Static", "walkLeft": "MOVE/walk.left", "walkRight": "MOVE/walk.right", "sleep": "Sleep"}

def fields(line):
    return {m.group(1): m.group(2) for m in re.finditer(r'(?:^|\|)([^#:\s]+)#([^:|]*):', line)}

def natural(path):
    return [int(s) if s.isdigit() else s.lower() for s in re.split(r'(\d+)', str(path))]

def png_size(path):
    data = path.read_bytes()[:24]
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f"Invalid PNG: {path}")
    return struct.unpack('>II', data[16:24])

def write_if_changed(path, data):
    """Validate actual output bytes; do not rely on timestamps or a cache marker."""
    try:
        if path.read_bytes() == data:
            return
    except FileNotFoundError:
        pass
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def convert(source, destination):
    pet = source / 'pet/vup'
    destination.mkdir(parents=True, exist_ok=True)
    records = {}
    def layer(directory, z):
        frames = []
        for path in sorted(directory.glob('*.png'), key=natural):
            match = re.search(r'(?:^|_)(\d+)\.png$', path.name, re.I)
            if not match or int(match[1]) <= 0:
                raise ValueError(f"Invalid frame name: {path}")
            relative = path.relative_to(pet).as_posix()
            target = destination / 'frames' / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            width, height = png_size(path)
            write_if_changed(target, path.read_bytes())
            records[relative] = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'bytes': path.stat().st_size}
            frames.append({'path': 'frames/' + relative, 'duration': int(match[1]) / 1000, 'width': width, 'height': height})
        if not frames:
            raise ValueError(f"Empty animation: {directory}")
        return {'z': z, 'frames': frames}
    clips = []
    diagnostics = []
    roots = [(action,subtree,subtree.split("/")[-1] if action in ("walkLeft","walkRight") else "raised.static" if action=="raised" else None) for action,subtree in ACTIONS.items()]
    roots += [('pinch','Pinch',None)]
    roots += [('say','Say/'+name,'say.'+name.lower()) for name in ['Self','Serious','Shining','Shy']]
    roots += [('raised','Raise/Raised_Dynamic','raised.dynamic')]
    roots += [(action,'MOVE/'+graph,graph) for action,side in [('walkLeft','left'),('walkRight','right')] for graph in ['walk.'+side+'.faster','walk.'+side+'.slow','crawl.'+side]]
    roots += [('sideHide','SideHide_'+side+'_'+kind,'sidehide.'+side.lower()+('' if kind=='Main' else '.rise')) for side in ['Left','Right'] for kind in ['Main','Rise']]
    roots += [('climb','MOVE/'+graph,graph) for graph in ['climb.left','climb.right','climb.top.left','climb.top.right','fall.left','fall.right']]
    roots += [('fidget',p.relative_to(pet).as_posix(),p.name.lower()) for p in sorted((pet/'IDEL').iterdir(),key=natural) if p.is_dir()] if (pet/'IDEL').exists() else []
    roots += [('specialIdle','State/StateONE','state.one'),('specialIdle','State/StateTWO','state.two')]
    roots += [('stateUp','Switch/Up',None),('stateDown','Switch/Down',None)]
    config_lines=(source/'pet/vup.lps').read_text(encoding='utf-8-sig').splitlines()
    durations=next((fields(line) for line in config_lines if line.startswith('duration:')), {})
    for line in (source/'pet/vup.lps').read_text(encoding='utf-8-sig').splitlines():
        if not line.startswith('work:'): continue
        graph=fields(line)['Graph'].lower()
        matches=[p for p in (pet/'WORK').iterdir() if p.is_dir() and p.name.lower()==graph]
        if len(matches)!=1: raise ValueError(f'Unresolved activity graph: {graph}')
        roots.append(('activity',matches[0].relative_to(pet).as_posix(),graph))
    for action, subtree, graph in roots:
        root = pet / subtree
        # A few distributions only include slow walking variants.
        if not root.exists() and action == 'walkLeft':
            root = pet / 'MOVE/walk.left.slow'
        leaves = sorted({p.parent for p in root.rglob('*.png')}, key=natural)
        for mode in MODES:
            if action=='fidget':
                def tokens(directory):
                    return re.split(r'[/_]',directory.relative_to(pet).as_posix().lower())
                def inferred_mode(directory):
                    parts=tokens(directory)
                    return next((m for m in MODES if m.lower() in parts),'Nomal')
                def phase(directory):
                    parts=tokens(directory)
                    return next((p for p,names in [('start',['a','start']),('loop',['b','loop']),('end',['c','end'])] if any(n in parts for n in names)),'single')
                matching=[p for p in leaves if inferred_mode(p)==mode]
                groups={p:[d for d in matching if phase(d)==p] for p in ['start','loop','end','single']}
                selected=['start','loop','end'] if groups['start'] else ['single'] if groups['single'] else []
                stages=[]
                for p in selected:
                    choices=groups[p]
                    if not choices: continue
                    stage={'phase':'loop' if p=='single' else p,'layers':[layer(choices[0],0)],'foodTrack':[]}
                    if len(choices)>1: stage['variants']=[[layer(d,0)] for d in choices[1:]]
                    stages.append(stage)
                if stages:
                    clip={'action':action,'mood':mode,'graphID':graph,'stages':stages}
                    if groups['start'] and groups['loop']: clip['idleLoopLimit']=int(durations.get(graph,10))
                    clips.append(clip)
                continue
            matching = leaves if action == 'say' and mode == 'Nomal' else [] if action == 'say' else [p for p in leaves if mode.lower() in p.relative_to(root).as_posix().lower()]
            if not matching:
                continue  # Renderer explicitly falls back to Nomal/idle.
            stages = []
            if action in ('idle','stateUp','stateDown') or graph=='raised.dynamic':
                stage = {'phase': 'loop', 'layers': [layer(matching[0], 0)], 'foodTrack': []}
                if (action == 'idle' or graph=='raised.dynamic') and len(matching)>1:
                    stage['variants'] = [[layer(path,0)] for path in matching[1:]]
                stages = [stage]
            else:
                for phase, prefix in [('start', 'a'), ('loop', 'b'), ('end', 'c')]:
                    choices = [p for p in matching if any(part.lower().split('_')[0] == prefix or part.lower().split('_')[-1] == prefix for part in p.relative_to(root).parts)]
                    if choices:
                        stage = {'phase': phase, 'layers': [layer(choices[0], 0)], 'foodTrack': []}
                        if action in ('head','body','fidget','walkLeft','walkRight','climb','sideHide','pinch','specialIdle','raised','say') and len(choices)>1:
                            stage['variants'] = [[layer(path,0)] for path in choices[1:]]
                        stages.append(stage)
            if stages:
                clips.append({'action': action, 'mood': mode, 'stages': stages, **({'graphID': graph} if graph else {}), **({'idleLoopLimit':int(durations.get('state' if action=='specialIdle' else 'sleep',10 if action=='specialIdle' else 20))} if action in ('specialIdle','sleep') else {})})
                if graph and graph!='raised.dynamic' and len(stages)<3: diagnostics.append(f'{graph}/{mode}: available phases '+','.join(x['phase'] for x in stages))
    # FoodAnimation is a sandwich of synchronized back/front frames and an item track.
    for action, subtree in [('eat', 'Eat'), ('drink', 'Drink'), ('gift', 'Gift')]:
        root = pet / subtree
        infos = [(p, line, fields(line)) for p in sorted(root.rglob('info.lps')) for line in p.read_text(encoding='utf-8-sig').splitlines()]
        graph_paths = {(fields(line).get('PNGAnimation'), fields(line).get('mode', '').lower()): (p.parent / fields(line)['path'].replace('\\', '/')) for p, line, f in infos if line.startswith('PNGAnimation#') and 'path' in fields(line)}
        for mode in MODES:
            entries = [(p, f) for p, line, f in infos if line.startswith('FoodAnimation#') and f.get('mode', '').lower() == mode.lower()]
            if not entries:
                continue
            p, f = entries[0]
            back = graph_paths.get((f.get('back_lay'), mode.lower())) or graph_paths.get((f.get('back_lay'), 'nomal'))
            front = graph_paths.get((f.get('front_lay'), mode.lower())) or graph_paths.get((f.get('front_lay'), 'nomal'))
            if back is None or front is None:
                raise ValueError(f"Unresolved food layers: {action}/{mode}")
            track = []
            i = 0
            previous = {'x': 0, 'y': 0, 'width': 0, 'rotation': 0, 'opacity': 1, 'visible': False}
            while f'a{i}' in f:
                values = [float(v) for v in f[f'a{i}'].split(',')]
                frame = dict(previous, duration=values[0] / 1000)
                if len(values) >= 4:
                    frame.update(x=values[1], y=values[2], width=values[3], rotation=values[4] if len(values) > 4 else 0, opacity=values[5] if len(values) > 5 else 1, visible=True)
                else:
                    frame['visible'] = False
                if not 0 <= frame['opacity'] <= 1:
                    diagnostics.append(f'{action}/{mode}/a{i}: invalid source opacity {frame["opacity"]}, clamped to 0...1')
                    frame['opacity']=max(0,min(1,frame['opacity']))
                track.append(frame); previous = frame; i += 1
            clips.append({'action': action, 'mood': mode, 'stages': [{'phase': 'loop', 'layers': [layer(back, 0), layer(front, 2)], 'foodTrack': track}]})
    config = (source / 'pet/vup.lps').read_text(encoding='utf-8-sig')
    regions = {}
    raise_anchors = {}
    for line in config.splitlines():
        if line.startswith(('touchhead:', 'touchbody:','pinch:')):
            f = fields(line)
            regions['head' if line.startswith('touchhead') else 'pinch' if line.startswith('pinch') else 'body'] = {'x': float(f['px']), 'y': float(f['py']), 'width': float(f['sw']), 'height': float(f['sh'])}
        if line.startswith('raisepoint:'):
            f = fields(line)
            for mode in MODES:
                x, y = float(f[mode.lower()+'_x']), float(f[mode.lower()+'_y'])
                if not (0 <= x <= 500 and 0 <= y <= 500):
                    raise ValueError('Invalid raise anchor: '+mode)
                raise_anchors[mode] = {'x': x, 'y': y}
        if line.startswith('touchraised:'):
            f = fields(line)
            for mode in MODES:
                prefix=mode.lower()+'_'
                regions['raised:'+mode]={'x':float(f[prefix+'px']),'y':float(f[prefix+'py']),'width':float(f[prefix+'sw']),'height':float(f[prefix+'sh'])}
    manifest = {'version': 3, 'diagnostics': diagnostics, 'canvasWidth': 500, 'canvasHeight': 500, 'regions': regions, 'clips': clips}
    if raise_anchors: manifest['raiseAnchors'] = raise_anchors
    write_if_changed(destination / 'manifest.json', (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    write_if_changed(destination / 'sources.sha256.json', (json.dumps(records, indent=2, sort_keys=True) + '\n').encode('utf-8'))
    if not any(c['action'] == 'idle' and c['mood'] == 'Nomal' for c in clips):
        raise ValueError('Missing normal idle animation')
    print(f"Converted {len(clips)} clips, {len(records)} frames, {sum(r['bytes'] for r in records.values()) / 1024**2:.1f} MiB")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parents[2] / 'Assets/Upstream/VPet/Core')
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'Resources/PetAssets')
    args = parser.parse_args()
    convert(args.source.resolve(), args.output.resolve())
