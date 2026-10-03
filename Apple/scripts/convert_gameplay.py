#!/usr/bin/env python3
"""Convert the bounded built-in economy catalogue; not a general MOD/LPS loader."""
import argparse
import hashlib
import json
import math
from pathlib import Path
from convert_assets import fields, write_if_changed

FILES = ['food.lps', 'moredrink.lps', 'drug.lps', 'gift.lps']

def number(f, key, default=0):
    value = float(f.get(key.lower(), default))
    if not math.isfinite(value): raise ValueError(f'Invalid {key}: {value}')
    return value

def power(value, exponent):
    return math.copysign(abs(value) ** exponent, value) if value else 0

def normalize_work(raw):
    f = {k.lower(): v for k,v in raw.items()}
    kind = f.get('type', 'Work').lower()
    if kind not in ['work','study','play']: raise ValueError('Unknown activity type')
    w = {'kind':kind,'moneyBase':number(f,'MoneyBase'),'strengthFood':number(f,'StrengthFood'), 'strengthDrink':number(f,'StrengthDrink'),'feeling':number(f,'Feeling'),'levelLimit':max(0,int(number(f,'LevelLimit'))),'durationSeconds':max(10,number(f,'Time'))*60,'finishBonus':min(2,max(0,number(f,'FinishBonus')))}
    if kind=='play' and w['feeling']>0: w['feeling'] *= -1
    def spend():
        a,b,c=w['strengthFood'],w['strengthDrink'],w['feeling']
        return (power(a,1.5)/3+power(b,1.5)/4+power(c,1.5)/4+w['levelLimit']/10+power(a+b+c,1.5)/10)*3
    def overloaded():
        x=abs(w['moneyBase'])*(1+w['finishBonus']/2)+1
        gain=power(x if kind=='work' else x/10,1.25)
        cost=spend()
        ratio=gain/cost if cost else (math.inf if gain else math.nan)
        cap=(1.1*w['levelLimit']+10)*(1 if kind=='work' else 10)
        return ratio<0 or abs(w['moneyBase'])>cap or ratio>1.4
    if overloaded():
        cost=spend()
        if cost>0:
            base=2*(1.15*cost**0.8-1)/(2+w['finishBonus'])
            w['moneyBase']=min(round(base*(1 if kind=='work' else 10),1),(1.1*w['levelLimit']+10)*(1 if kind=='work' else 10))
        if overloaded():
            defaults={'work':(8,3.5,2.5,1,.1),'study':(80,2,2,3,.2),'play':(18,1,1.5,-1,.2)}
            for k,v in zip(['moneyBase','strengthFood','strengthDrink','feeling','finishBonus'],defaults[kind]): w[k]=v
            w['levelLimit']=0
    return w

def normalize_package(raw):
    f={k.lower():v for k,v in raw.items()}
    kind=f.get('worktype','Work').lower()
    if kind not in ['work','study']: raise ValueError('Unknown package type')
    raw_days=number(f,'Duration')
    if raw_days != int(raw_days): raise ValueError('Package duration must be an integer')
    days=max(1,int(raw_days))
    price=number(f,'Price');price=1 if price<0 else price
    ratio=number(f,'LevelInNeed');ratio=1.25 if ratio<1 else ratio
    commission=number(f,'Commissions');commission=.2 if commission<0 else commission
    use=power(commission*100-15,1.5)+power(ratio*100-120,1.5)+(price*ratio*100-100)/4
    if use/math.sqrt(days)<10: commission,ratio,price,days=.2,1.25,1,7
    if not (0<=commission<=1 and 0<=price<=1e12 and 1<=ratio<=1e6 and 1<=days<=36500):
        raise ValueError('Package exceeds supported bounds')
    return {'kind':kind,'durationDays':days,'unitPrice':price,'levelRatio':ratio,'commission':commission}

def convert_gameplay(source, destination):
    records={}; diagnostics=[]
    def read(path):
        data=path.read_bytes();records[str(path.relative_to(source))]=hashlib.sha256(data).hexdigest()
        return data.decode('utf-8-sig').splitlines()
    activities=[]
    for line in read(source/'pet/vup.lps'):
        if not line.startswith('work:'): continue
        raw=fields(line); f={k.lower():v for k,v in raw.items()}
        name=f.get('name'); graph=f.get('graph')
        if not name or not graph: raise ValueError('Missing activity name/graph')
        activities.append(dict(normalize_work(raw),id='core.activity.'+name,name=name,graphID=graph.lower(),source=raw))
    items=[]
    for filename in FILES:
        for line in read(source/'food'/filename):
            if not line.startswith('food:'): continue
            f={k.lower():v for k,v in fields(line).items()};name=f.get('name')
            if not name: raise ValueError('Missing item name')
            category=f.get('type','Food').lower()
            if category not in ['food','meal','snack','drink','functional','drug','gift']: raise ValueError('Unknown food category')
            image=f.get('image',name)
            if '/' in image or '\\' in image or image in ['.','..']: raise ValueError('Unsafe item image')
            image_path=None
            candidates=[source/'image/food'/f'{image}.png',source/'image'/f'food_{image}.png',source/'image/food.png']
            for candidate in candidates:
                if candidate.is_file():
                    data=candidate.read_bytes(); digest=hashlib.sha256(data).hexdigest()
                    image_path='items/'+digest+'.png';write_if_changed(destination/image_path,data)
                    records[str(candidate.relative_to(source))]=digest; break
            if image_path is None: diagnostics.append('Missing item image: '+name)
            item={'id':'core.item.'+name,'name':name,'category':category,'description':f.get('desc','').replace('/n','\n'),'imagePath':image_path,'graphID':f.get('graph','eat').lower(),'price':number(f,'Price')}
            for key,original in [('strength','Strength'),('food','StrengthFood'),('drink','StrengthDrink'),('feeling','Feeling'),('health','Health'),('affection','Likability'),('experience','Exp')]:item[key]=number(f,original)
            if item['price']<0: raise ValueError('Negative price')
            items.append(item)
    packages=[]
    for line in read(source/'text/SchedulePackage.lps'):
        if not line.startswith('SchedulePackage:'): continue
        raw=fields(line);f={k.lower():v for k,v in raw.items()};name=f.get('name')
        if not name or len(name)>100: raise ValueError('Missing or long package name')
        package=normalize_package(raw)
        packages.append(dict(package,id='core.package.'+package['kind']+'.'+name,name=name,description=f.get('describe','').replace('/n','\n'),source=raw))
    for group in [activities,items,packages]:
        if len({x['id'] for x in group}) != len(group): raise ValueError('Duplicate catalogue ID')
    result={'version':1,'activities':activities,'items':items,'packages':packages,'diagnostics':diagnostics}
    write_if_changed(destination/'gameplay.json',(json.dumps(result,ensure_ascii=False,indent=2,allow_nan=False)+'\n').encode())
    write_if_changed(destination/'gameplay-sources.sha256.json',(json.dumps(records,ensure_ascii=False,sort_keys=True,indent=2)+'\n').encode())
    print(f'Gameplay: {len(activities)} activities, {len(items)} items, {len(packages)} packages, {len(diagnostics)} missing images')

if __name__=='__main__':
    root=Path(__file__).resolve().parents[1]
    parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,default=root.parent/'Assets/Upstream/VPet/Core');parser.add_argument('--output',type=Path,default=root/'Resources/PetAssets');args=parser.parse_args()
    convert_gameplay(args.source,args.output)
