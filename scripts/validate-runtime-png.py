#!/usr/bin/env python3
"""Decode the actual UI PNG independently through FFmpeg, not Flutter's painter."""
import json, pathlib, struct, subprocess
root=pathlib.Path('work/runtime-output')
image=root/'ui-export-image.png'
header=image.read_bytes()[:33]
assert header[:8]==b'\x89PNG\r\n\x1a\n' and header[12:16]==b'IHDR'
width,height=struct.unpack('>II',header[16:24])
assert (width,height)==(1080,1350)
pixels=subprocess.check_output(['ffmpeg','-v','error','-i',str(image),'-frames:v','1','-f','rawvideo','-pix_fmt','rgba','pipe:1'])
assert len(pixels)==width*height*4
assert all(pixels[i]==255 for i in range(3,len(pixels),4))
doc=json.loads((root/'ui-project.json').read_text())
paper=doc.get('paper');argb=paper['colors'][0] if paper else doc['background']
alpha=round(((argb>>24)&255)*(paper['opacity'] if paper else 1))
expected=[(((argb>>shift)&255)*alpha+255*(255-alpha)+127)//255 for shift in (16,8,0)]
at=((height-6)*width+(width-6))*4
observed=list(pixels[at:at+3]);assert all(abs(a-b)<=1 for a,b in zip(expected,observed)),(expected,observed)
report={'width':width,'height':height,'opaque':True,'decoded_bytes':len(pixels),'paper_rgb':observed,'source_project':doc['id'],'revision':doc['revision']}
(root/'png-inspection.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
