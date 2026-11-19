from PIL import Image, ImageDraw, ImageFilter
S=4096
def s(v): return int(v*S/1024)
img=Image.new("RGB",(S,S)); d=ImageDraw.Draw(img)
top,bot=(44,90,74),(20,44,37)
for y in range(S):
    t=y/(S-1); d.line([(0,y),(S,y)],fill=tuple(int(top[i]+(bot[i]-top[i])*t) for i in range(3)))
# faint day grid
grid=Image.new("L",(S,S),0); gd=ImageDraw.Draw(grid)
for x in range(140,1000,124):
    gd.rectangle([s(x),s(150),s(x)+s(6),s(880)],fill=40)
img.paste((255,255,255),(0,0),grid)
WHITE=(250,248,240); OR=(240,96,20); ORD=(196,70,8)
def bar(x0,y0,x1,y1,col,shade):
    sh=Image.new("L",(S,S),0); ImageDraw.Draw(sh).rounded_rectangle([s(x0),s(y0+14),s(x1),s(y1+14)],radius=s(56),fill=120)
    sh=sh.filter(ImageFilter.GaussianBlur(s(14))); img.paste((8,22,18),(0,0),sh)
    dd=ImageDraw.Draw(img); dd.rounded_rectangle([s(x0),s(y0),s(x1),s(y1)],radius=s(56),fill=col)
bar(130,230,560,350,WHITE,None)
bar(330,452,760,572,OR,None)
bar(560,674,900,794,WHITE,None)
d=ImageDraw.Draw(img)
# shift chevrons after orange bar? place small double chevron right of orange bar
def chev(cx,cy,sz,col):
    w=s(30)
    d.line([(s(cx-sz/2),s(cy-sz)),(s(cx+sz/2),s(cy)),(s(cx-sz/2),s(cy+sz))],fill=col,width=w,joint="curve")
    for px,py in [(cx-sz/2,cy-sz),(cx+sz/2,cy),(cx-sz/2,cy+sz)]:
        d.ellipse([s(px)-w//2,s(py)-w//2,s(px)+w//2,s(py)+w//2],fill=col)
chev(820,512,40,OR); chev(890,512,40,OR)
# rain drop top right
cx,cy,r=830,250,62
drop=[(s(cx),s(cy-r*2.0))]
d.polygon([(s(cx),s(cy-r*1.9)),(s(cx-r*0.85),s(cy-r*0.526)),(s(cx+r*0.85),s(cy-r*0.526))],fill=(120,190,240))
d.ellipse([s(cx-r),s(cy-r),s(cx+r),s(cy+r)],fill=(120,190,240))
out=img.resize((1024,1024),Image.LANCZOS)
out.save("/workspace/koutei/icon/app_icon.png")
