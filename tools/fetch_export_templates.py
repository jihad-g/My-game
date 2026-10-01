#!/usr/bin/env python3
"""Downloads only the Godot export templates a build needs (Milestone 13).

The official template pack is a 1.2 GB zip; this reads its directory over HTTP
range requests and fetches just the named files into the folder Godot looks in
(~/.local/share/godot/export_templates/<version>/ on Linux).

    python3 tools/fetch_export_templates.py                 # list files
    python3 tools/fetch_export_templates.py windows web     # Windows + web
"""
import urllib.request, struct, zlib, sys, os
URL="https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_export_templates.tpz"
ctx=None
def rng(a,b):
    req=urllib.request.Request(URL,headers={"Range":"bytes=%d-%d"%(a,b)})
    return urllib.request.urlopen(req).read()
size=int(urllib.request.urlopen(urllib.request.Request(URL,method="HEAD")).headers["Content-Length"])
tail=rng(size-70000,size-1)
i=tail.rfind(b"PK\x05\x06")
eocd=tail[i:]
cd_size,cd_off=struct.unpack("<II",eocd[12:20])
if cd_off==0xFFFFFFFF or cd_size==0xFFFFFFFF:
    j=tail.rfind(b"PK\x06\x06")
    z=tail[j:]
    cd_size,cd_off=struct.unpack("<QQ",z[40:56])
cd=rng(cd_off,cd_off+cd_size-1)
p=0; entries={}
while p<len(cd) and cd[p:p+4]==b"PK\x01\x02":
    meth,=struct.unpack("<H",cd[p+10:p+12])
    csz,usz=struct.unpack("<II",cd[p+20:p+28])
    nl,el,cl=struct.unpack("<HHH",cd[p+28:p+34])
    off,=struct.unpack("<I",cd[p+42:p+46])
    name=cd[p+46:p+46+nl].decode()
    extra=cd[p+46+nl:p+46+nl+el]
    q=0
    while q<len(extra):
        hid,hl=struct.unpack("<HH",extra[q:q+4])
        if hid==1:
            vals=extra[q+4:q+4+hl]; k=0
            if usz==0xFFFFFFFF: usz,=struct.unpack("<Q",vals[k:k+8]); k+=8
            if csz==0xFFFFFFFF: csz,=struct.unpack("<Q",vals[k:k+8]); k+=8
            if off==0xFFFFFFFF: off,=struct.unpack("<Q",vals[k:k+8]); k+=8
        q+=4+hl
    entries[name]=(meth,csz,usz,off)
    p+=46+nl+el+cl
GROUPS={"windows":["templates/windows_release_x86_64.exe","templates/windows_debug_x86_64.exe","templates/windows_release_x86_64_console.exe","templates/windows_debug_x86_64_console.exe"],
    "linux":["templates/linux_release.x86_64","templates/linux_debug.x86_64"],
    "web":["templates/web_nothreads_release.zip","templates/web_nothreads_debug.zip"],
    "macos":["templates/macos.zip"]}
if len(sys.argv)<2:
    for n,e in entries.items(): print(n,e[2])
    sys.exit()
wanted=["templates/version.txt"]
for a in sys.argv[1:]:
    wanted+=GROUPS.get(a,[a if a.startswith("templates/") else "templates/"+a])
os.makedirs(os.path.expanduser("~/.local/share/godot/export_templates/4.4.1.stable"),exist_ok=True)
for want in wanted:
    meth,csz,usz,off=entries[want]
    lh=rng(off,off+29)
    nl,el=struct.unpack("<HH",lh[26:30])
    start=off+30+nl+el
    data=rng(start,start+csz-1)
    if meth==8: data=zlib.decompress(data,-15)
    out=os.path.expanduser("~/.local/share/godot/export_templates/4.4.1.stable/"+want.split("/")[-1])
    open(out,"wb").write(data)
    print("wrote",out,len(data))
