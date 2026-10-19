import numpy as np, json, re, sys
from PIL import Image
from scipy import ndimage
from skimage.graph import route_through_array
mask, scale, posfile = sys.argv[1], float(sys.argv[2]), sys.argv[3]
STEP = int(sys.argv[5]) if len(sys.argv) > 5 else 5
m=np.asarray(Image.open(mask))>127
dt=ndimage.distance_transform_edt(m)
cost=np.where(m, 1+4/(dt+0.5), 1e6)
pos=json.load(open(posfile))
ok=np.argwhere(dt>3)
def near(p):
    x,y=p[0]/scale,p[1]/scale
    i=np.argmin((ok[:,1]-x)**2+(ok[:,0]-y)**2); return tuple(ok[i])
routes={}
names=list(pos)
for a,b in zip(names,names[1:]):
    path,c=route_through_array(cost,near(pos[a]),near(pos[b]),fully_connected=True,geometric=True)
    if c>=1e6: print("NO ROUTE",a,b); continue
    pts=[(int(x*scale),int(y*scale)) for y,x in path[::STEP]]+[(int(near(pos[b])[1]*scale),int(near(pos[b])[0]*scale))]
    routes[a+'>'+b]=pts
json.dump(routes,open(sys.argv[4],'w'))
print(len(routes),"routes")
