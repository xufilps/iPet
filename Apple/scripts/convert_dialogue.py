#!/usr/bin/env python3
"""Bounded conversion of the original built-in dialogue; not a general LPS interpreter."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
from convert_assets import fields, write_if_changed

FILES=['ClickText.lps','ClickTextv2.lps','ClickTextv3.lps','LowText.lps']
ATTRS=['like','health','level','money','food','drink','feel','strength']
EFFECTS={'money':'money','strength':'strength','strengthfood':'food','strengthdrink':'drink','feeling':'feeling','health':'health','likability':'affection','exp':'experience'}
TOKENS={'name','food','drink','feel','strength','money','level','health','hostname'}
def numeric(f,key,default=0):
    value=float(f.get(key,default))
    if not math.isfinite(value):raise ValueError('Nonfinite dialogue value: '+key)
    return value

def selection_entries(source,records):
    entries=[]
    limits={'money':1000,'strength':1000,'food':1000,'drink':1000,'feeling':100,'health':100,'affection':50,'experience':1000}
    for filename in ['SelectText.lps','SelectTextv2.lps']:
        path=source/'text'/filename
        if not path.exists():continue
        records['text/'+filename]=hashlib.sha256(path.read_bytes()).hexdigest()
        for line_number,line in enumerate(path.read_text(encoding='utf-8-sig').splitlines(),1):
            if not line.strip() or line.startswith('///'):continue
            if line.split(':',1)[0].lower()!='selecttext':raise ValueError('Unknown selection row')
            f={key.lower():value for key,value in fields(line).items()}
            allowed={'choose','text','tag','tags','totags','mode'}|set(EFFECTS)|{a+b for a in ATTRS for b in ['min','max']}
            if set(f)-allowed:raise ValueError('Unknown selection fields: '+str(set(f)-allowed))
            text=f.get('text','').replace('/n','\n');choose=f.get('choose','')
            if not text or not choose or len(text)>5000 or len(choose)>5000:raise ValueError('Invalid selection text')
            if set(re.findall(r'\{([^}]+)\}',text))-TOKENS:raise ValueError('Unsupported selection placeholder')
            if 'mode' in f:numeric(f,'mode') # Original CheckState does not use Mode.
            bounds={a+b:numeric(f,a+b) for a in ATTRS for b in ['min','max'] if a+b in f}
            for a in ATTRS:
                if bounds.get(a+'min',-2147483648 if a=='money' else 0)>bounds.get(a+'max',2147483647):raise ValueError('Inverted selection bounds')
            effects={value:max(-limits[value],min(limits[value],numeric(f,key))) for key,value in EFFECTS.items()}
            if not numeric(f,'exp').is_integer():raise ValueError('Selection experience must be an integer')
            entries.append({'id':f'{filename}:{line_number}','choose':choose,'text':text,'characterTags':f.get('tag','all').split(','),'conversationTags':f['tags'].split(',') if f.get('tags') else [],'toTags':f['totags'].split(',') if f.get('totags') else [],'bounds':bounds,'effects':effects})
    return entries

def convert_dialogue(source,destination):
    entries=[];records={};diagnostics=[]
    config=source/'pet/vup.lps';records['pet/vup.lps']=hashlib.sha256(config.read_bytes()).hexdigest()
    tag=next((fields(line).get('tag') for line in config.read_text(encoding='utf-8-sig').splitlines() if line.startswith('tag#')),None)
    tags=(tag or 'all').split(',')
    for filename in FILES:
        path=source/'text'/filename
        if not path.exists():continue
        records['text/'+filename]=hashlib.sha256(path.read_bytes()).hexdigest()
        for line_number,line in enumerate(path.read_text(encoding='utf-8-sig').splitlines(),1):
            if not line.strip() or line.startswith('///') or line.startswith('tag#'):continue
            if line.startswith(':|'):
                diagnostics.append(f'{filename}:{line_number}: orphan multiline tail excluded');continue
            name=line.split(':',1)[0].lower()
            if name not in ['clicktext','lowfoodtext','lowdrinktext']:raise ValueError('Unknown dialogue row: '+line)
            f={key.lower():value for key,value in fields(line).items()}
            allowed={'text','tag','tags','mode','daytime','state','working','like'}|set(EFFECTS)|{a+b for a in ATTRS for b in ['min','max']}
            if set(f)-allowed:raise ValueError('Unknown dialogue fields: '+str(set(f)-allowed))
            text=f.get('text','').replace('/n','\n')
            if not text:
                diagnostics.append(f'{filename}:{line_number}: malformed multiline text excluded');continue
            if set(re.findall(r'\{([^}]+)\}',text))-TOKENS:raise ValueError('Unsupported placeholder')
            if 'tags' in f:diagnostics.append(f'{filename}:{line_number}: original Tags does not map to Tag; kept original default all')
            kind={'clicktext':'click','lowfoodtext':'food','lowdrinktext':'drink'}[name]
            bounds={a+b:numeric(f,a+b) for a in ATTRS for b in ['min','max'] if a+b in f}
            for a in ATTRS:
                if bounds.get(a+'min',-2147483648 if a=='money' else 0)>bounds.get(a+'max',2147483647):raise ValueError('Inverted bounds')
            effects={value:(numeric(f,key) if kind=='click' else 0) for key,value in EFFECTS.items()}
            entry={'id':f'{filename}:{line_number}','kind':kind,'text':text,'tags':f.get('tag','all').split(','),'mode':int(numeric(f,'mode',7)) if kind=='click' else 7,'dayTime':int(numeric(f,'daytime',15)),'workState':f.get('state','Nomal'),'working':f.get('working'),'bounds':bounds,'effects':effects,'lowMode':f.get('mode','L') if kind!='click' else None,'severity':f.get('strength','S') if kind!='click' else None,'like':{'N':0,'S':1,'M':2,'L':3}[f.get('like','N')]}
            if not 0<=entry['mode']<=15 or not 0<=entry['dayTime']<=15 or entry['workState'] not in ['Nomal','Sleep','Work','Empty','Travel']:raise ValueError('Unsupported dialogue condition')
            if kind!='click' and (entry['lowMode'] not in ['H','L'] or entry['severity'] not in ['L','M','S']):raise ValueError('Invalid low-state condition')
            entries.append(entry)
    selections=selection_entries(source,records)
    write_if_changed(destination/'selection-dialogue.json',(json.dumps({'version':1,'tags':tags,'entries':selections},ensure_ascii=False,indent=2,allow_nan=False)+'\n').encode())
    result={'version':1,'tags':tags,'entries':entries,'diagnostics':diagnostics}
    write_if_changed(destination/'dialogue.json',(json.dumps(result,ensure_ascii=False,indent=2,allow_nan=False)+'\n').encode())
    write_if_changed(destination/'dialogue-sources.sha256.json',(json.dumps(records,sort_keys=True,indent=2)+'\n').encode())
    print(f'Selection dialogue: {len(selections)} rows')
    print(f'Dialogue: {len(entries)} rows, {len(diagnostics)} source diagnostics')
if __name__=='__main__':
    root=Path(__file__).resolve().parents[1]
    parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,default=root.parent/'VPet-Simulator.Windows/mod/0000_core');parser.add_argument('--output',type=Path,default=root/'Resources/PetAssets');args=parser.parse_args();convert_dialogue(args.source,args.output)
