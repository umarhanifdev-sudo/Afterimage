"""Reproducible CC0 MakeHuman -> compact skinned glTF. No Blender dependency.
Source mesh/weights are retained in licenses/MakeHuman. No MakeHuman program code.
Coordinates are metres, +Z is forward. Animation lives in scripts/human_rig.gd.
"""
from pathlib import Path
import json,struct,numpy as np
ROOT=Path(__file__).resolve().parents[1];SRC=ROOT/'licenses/MakeHuman';OUT=ROOT/'assets/characters';OUT.mkdir(exist_ok=True)
v=[];uv=[];faces=[];group=''
for line in (SRC/'base.obj').read_text().splitlines():
 p=line.split()
 if not p:continue
 if p[0]=='v':v.append(list(map(float,p[1:4])))
 elif p[0]=='vt':uv.append(list(map(float,p[1:3])))
 elif p[0]=='g':group=p[1]
 elif p[0]=='f' and group=='body':
  f=[tuple(int(i)-1 for i in a.split('/')[:2]) for a in p[1:]]
  for i in range(1,len(f)-1):faces.append([f[0],f[i],f[i+1]])
v=np.array(v)*.1;v[:,1]+=.825;uv=np.array(uv);uv[:,1]=1-uv[:,1]
d=json.loads((SRC/'default.mhskel').read_text());weights=json.loads((SRC/'default_weights.mhw').read_text())['weights']
keep=['root','spine05','spine03','spine01','neck01','head']
for side in ['L','R']:
 keep += [s+'.'+side for s in ['clavicle','upperarm01','lowerarm01','wrist','upperleg01','lowerleg01','foot']]
 keep += [f'finger{f}-{i}.{side}' for f in range(1,6) for i in range(1,4)]
def ancestor(n):
 while n and n not in keep:n=d['bones'][n]['parent']
 return n
heads={n:v[d['joints'][d['bones'][n]['head']]].mean(0) for n in keep}
parents={n:ancestor(d['bones'][n]['parent']) for n in keep}
ordered=[]
def add(n):
 if n in ordered:return
 if parents[n]:add(parents[n])
 ordered.append(n)
for n in keep:add(n)
keep=ordered;ix={n:i for i,n in enumerate(keep)}
w=[{} for _ in v]
for n,entries in weights.items():
 a=ancestor(n)
 if not a:continue
 for i,x in entries:w[i][ix[a]]=w[i].get(ix[a],0)+x
joints=[];ws=[]
for row in w:
 values=sorted(row.items(),key=lambda r:-r[1])[:4] or [(0,1)]
 s=sum(x for _,x in values);joints.append([i for i,_ in values]+[0]*(4-len(values)));ws.append([x/s for _,x in values]+[0]*(4-len(values)))
joints=np.array(joints,dtype=np.uint16);ws=np.array(ws,dtype=np.float32)
# Smooth anatomically detailed hands and face; cloth follows the weighted body.
normals=np.zeros_like(v)
for f in faces:
 a,b,c=[i for i,t in f];n=np.cross(v[b]-v[a],v[c]-v[a]);normals[[a,b,c]]+=n
normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-8)
# Slight cloth inflation + fine seam folds. Hands and head remain exposed.
clothed=v.copy()
for i,p in enumerate(v):
 hand=abs(p[0])>.395 and p[1]>1.0
 face=p[1]>1.39
 if not hand and not face:
  amount=.014+.003*np.sin(p[1]*180+p[0]*45)
  clothed[i]+=normals[i]*amount
  # Opaque clothing bridges body contours at pelvis and chest.
  if .75<p[1]<1.35 and abs(p[0])<.18:
   clothed[i,2]=max(clothed[i,2],.105) if p[2]>.02 else min(clothed[i,2],-.10)
 def_unused=0

# Transfer original barycentric garment weights to the compact rig.
import re,shutil
clothes=[];hidden=set()
for outfit in ['male_casualsuit01','shoes04']:
 folder=SRC/'system/clothes'/outfit
 raw=(folder/(outfit+'.mhclo')).read_text()
 mapping=raw.split('verts 0',1)[1].split('delete_verts')[0].strip().splitlines()
 cv=[];cj=[];cw=[]
 for line in mapping:
  fields=line.split()
  if not fields or fields[0].startswith('#'):continue
  if len(fields)==1:
   ids=[int(fields[0])];factors=[1.];offset=np.zeros(3)
  else:
   ids=list(map(int,fields[:3]));factors=list(map(float,fields[3:6]));offset=np.array(list(map(float,fields[6:9])))*.1
  cv.append(sum(v[i]*a for i,a in zip(ids,factors))+offset)
  row={}
  for i,a in zip(ids,factors):
   for bone,weight in w[i].items():row[bone]=row.get(bone,0)+weight*a
  values=sorted([(k,max(0,x)) for k,x in row.items()],key=lambda p:-p[1])[:4] or [(0,1)]
  total=sum(x for _,x in values) or 1
  cj.append([k for k,_ in values]+[0]*(4-len(values)));cw.append([x/total for _,x in values]+[0]*(4-len(values)))
 cu=[];cf=[]
 for line in (folder/(outfit+'.obj')).read_text().splitlines():
  parts=line.split()
  if not parts:continue
  if parts[0]=='vt':cu.append([float(parts[1]),1-float(parts[2])])
  if parts[0]=='f':
   face=[tuple(int(j)-1 for j in p.split('/')[:2]) for p in parts[1:]]
   for k in range(1,len(face)-1):cf.append([face[0],face[k],face[k+1]])
 cv=np.array(cv);cn=np.zeros_like(cv)
 for face in cf:
  a,b,c=[i for i,t in face];normal=np.cross(cv[b]-cv[a],cv[c]-cv[a]);cn[[a,b,c]]+=normal
 cn/=np.maximum(np.linalg.norm(cn,axis=1)[:,None],1e-8)
 clothes.append((outfit,cv,cn,np.array(cu),np.array(cj),np.array(cw),cf))
 if 'delete_verts' in raw:
  tokens=re.findall(r'\d+|-',raw.split('delete_verts',1)[1]);i=0
  while i<len(tokens):
   if i+2<len(tokens) and tokens[i+1]=='-':hidden.update(range(int(tokens[i]),int(tokens[i+2])+1));i+=3
   else:hidden.add(int(tokens[i]));i+=1
 for suffix in ['diffuse','normal']:
  shutil.copy2(folder/(outfit+'_'+suffix+'.png'),OUT/(outfit+'_'+suffix+'.png'))
shutil.copy2(SRC/'system/skins/old_caucasian_male/old_lightskinned_male_diffuse.png',OUT/'skin.png')

def export(name,filter_face):
 blob=bytearray();g={'asset':{'version':'2.0','generator':'AFTERIMAGE CC0 character pipeline'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'name':'Character','children':[1,len(keep)+1]}],'meshes':[],'materials':[], 'bufferViews':[],'accessors':[]}
 for n in keep:
  parent=parents[n];node={'name':n.replace('.','_'),'translation':(heads[n]-(heads[parent] if parent else 0)).tolist()}
  children=[ix[c]+1 for c in keep if parents[c]==n]
  if children:node['children']=children
  g['nodes'].append(node)
 g['nodes'].append({'name':'Anatomy','mesh':0,'skin':0})
 def acc(a,typ,component=5126,bounds=False):
  nonlocal blob
  a=np.asarray(a,dtype={5126:'<f4',5123:'<u2',5125:'<u4'}[component]);blob+=b'\0'*((-len(blob))%4);start=len(blob);blob+=a.tobytes();view=len(g['bufferViews']);g['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':a.nbytes})
  ob={'bufferView':view,'componentType':component,'count':len(a),'type':typ}
  if bounds:ob.update(min=a.min(0).tolist(),max=a.max(0).tolist())
  g['accessors'].append(ob);return len(g['accessors'])-1
 mats=[('Uniform',[.115,.126,.105,1],.95),('Skin',[.39,.28,.21,1],.9),('Boots',[.038,.034,.029,1],.72)]
 for n,col,r in mats:g['materials'].append({'name':n,'doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':col,'roughnessFactor':r,'metallicFactor':0}})
 prim=[]
 for material in range(3):
  verts=[];ns=[];tex=[];js=[];wts=[];indices=[];seen={}
  for face in faces:
   ids=[i for i,t in face];center=v[ids].mean(0)
   if not filter_face(center) or any(i in hidden for i in ids):continue
   mat=1 if center[1]>.17 else 2
   if mat!=material:continue
   for i,t in face:
    key=(i,t)
    if key not in seen:
     seen[key]=len(verts);verts.append((v if mat==1 else clothed)[i]);ns.append(normals[i]);tex.append(uv[t]);js.append(joints[i]);wts.append(ws[i])
    indices.append(seen[key])
  if not verts:continue
  prim.append({'attributes':{'POSITION':acc(verts,'VEC3',bounds=True),'NORMAL':acc(ns,'VEC3'),'TEXCOORD_0':acc(tex,'VEC2'),'JOINTS_0':acc(js,'VEC4',5123),'WEIGHTS_0':acc(wts,'VEC4')},'indices':acc(indices,'SCALAR',5125),'material':material})
 # Textured garments use the same fifty-joint skin.
 g['images']=[{'uri':'skin.png'}];g['textures']=[{'source':0}]
 g['materials'][1]['pbrMetallicRoughness']['baseColorFactor']=[.8,.8,.8,1]
 g['materials'][1]['pbrMetallicRoughness']['baseColorTexture']={'index':0}
 for outfit,cv,cn,cu,cj,cw,cf in clothes:
  start=len(g['textures'])
  for suffix in ['diffuse','normal']:
   g['images'].append({'uri':outfit+'_'+suffix+'.png'});g['textures'].append({'source':len(g['images'])-1})
  mi=len(g['materials'])
  g['materials'].append({'name':outfit,'doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':[.52,.53,.44,1],'baseColorTexture':{'index':start},'roughnessFactor':.92},'normalTexture':{'index':start+1,'scale':.5}})
  verts=[];ns=[];tex=[];js=[];wts=[];indices=[];seen={}
  for face in cf:
   if not filter_face(cv[[i for i,t in face]].mean(0)):continue
   for i,t in face:
    key=(i,t)
    if key not in seen:
     seen[key]=len(verts);verts.append(cv[i]);ns.append(cn[i]);tex.append(cu[t]);js.append(cj[i]);wts.append(cw[i])
    indices.append(seen[key])
  if verts:prim.append({'attributes':{'POSITION':acc(verts,'VEC3',bounds=True),'NORMAL':acc(ns,'VEC3'),'TEXCOORD_0':acc(tex,'VEC2'),'JOINTS_0':acc(js,'VEC4',5123),'WEIGHTS_0':acc(wts,'VEC4')},'indices':acc(indices,'SCALAR',5125),'material':mi})
 g['meshes']=[{'name':name,'primitives':prim}]
 inverse=[]
 for n in keep:
  m=np.eye(4);m[:3,3]=-heads[n];inverse.append(m.T.flatten())
 g['skins']=[{'name':'HumanRig','joints':list(range(1,len(keep)+1)),'skeleton':1,'inverseBindMatrices':acc(inverse,'MAT4')}]
 g['buffers']=[{'byteLength':len(blob)}];b=json.dumps(g,separators=(',',':')).encode();b+=b' '*((-len(b))%4);blob+=b'\0'*((-len(blob))%4)
 data=struct.pack('<III',0x46546c67,2,12+8+len(b)+8+len(blob))+struct.pack('<II',len(b),0x4e4f534a)+b+struct.pack('<II',len(blob),0x004e4942)+blob
 (OUT/(name+'.glb')).write_bytes(data);print(name,len(data),'bones',len(keep))
export('human',lambda p:True)
export('elder',lambda p:p[1]>1.13 or (abs(p[0])>.26 and p[1]>.90))
export('arms',lambda p: abs(p[0])>.24 and p[1]>.90)
export('body',lambda p:p[1]<1.43 and (abs(p[0])<.23 or p[1]<.90))
(OUT/'rig.json').write_text(json.dumps({'heads':{n.replace('.','_'):heads[n].tolist() for n in keep},'parents':{n.replace('.','_'):(parents[n].replace('.','_') if parents[n] else '') for n in keep}},indent=2))
