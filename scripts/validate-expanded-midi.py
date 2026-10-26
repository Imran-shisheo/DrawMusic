#!/usr/bin/env python3
"""Independent new-catalog/mix MIDI and visual-snapshot inspection."""
import json,pathlib,mido,subprocess,struct
root=pathlib.Path('work/runtime-output');doc=json.loads((root/'expanded-project.json').read_text())
assert doc['root']=='fSharp' and doc['scale']=='lydian' and doc['mix']['arpeggio']['enabled']
midi=mido.MidiFile(root/'expanded-notes.mid');assert midi.type==0 and midi.ticks_per_beat==480
active={};notes=[];tick=0;tempo=None
for e in midi.tracks[0]:
    tick+=e.time
    if e.type=='set_tempo':tempo=e.tempo
    if e.type=='note_on' and e.velocity:
        key=(e.channel,e.note);assert key not in active,(key,tick)
        active[key]=(tick,e.velocity)
    elif e.type=='note_off' or (e.type=='note_on' and not e.velocity):
        start,velocity=active.pop((e.channel,e.note));assert start<tick
        notes.append((e.channel,e.note,start,tick,velocity))
assert not active and tick==3840 and abs(tempo-60000000/doc['tempo'])<1
bass=[n for n in notes if n[0]==14];arp=[n for n in notes if n[0]==15];drums=[n for n in notes if n[0]==9]
assert len(bass)==4 and all(n[1]==42 and n[4]==40 for n in bass)
assert len(arp)==16 and sorted(n[2] for n in arp)==list(range(0,3840,240))
assert len(drums)==26 and len({(n[1],n[2]) for n in drums})==26
assert all(n[4]==35 for n in drums)
assert {n[1] for n in drums}=={36,38,39,42}
melodic=[n for n in notes if n[0] not in (9,14,15)]
assert melodic and all(48<=n[1]<=84 and (n[1]-48-6)%12 in (0,2,4,6,7,9,11) for n in melodic)
# Compare exported still and actual encoded video background corners. No app
# UI raster or playback cursor can become part of these four source pixels.
png=root/'expanded-image.png';h=png.read_bytes()[:24];assert h[:8]==b'\x89PNG\r\n\x1a\n'
w,hh=struct.unpack('>II',h[16:24]);assert (w,hh)==(1080,1350)
image=subprocess.check_output(['ffmpeg','-v','error','-i',str(png),'-frames:v','1','-f','rawvideo','-pix_fmt','rgb24','pipe:1'])
frame=subprocess.check_output(['ffmpeg','-v','error','-ss','0.5','-i',str(root/'expanded-video.mp4'),'-frames:v','1','-f','rawvideo','-pix_fmt','rgb24','pipe:1'])
assert doc['paper']['kind']=='linear'
visual=[]
for u,v in ((.02,.02),(.98,.02),(.02,.98),(.98,.98)):
    p=(int(v*hh)*w+int(u*w))*3;q=(int(v*800)*640+int(u*640))*3
    a=list(image[p:p+3]);b=list(frame[q:q+3]);assert all(abs(x-y)<=8 for x,y in zip(a,b)),(a,b)
    visual.append({'u':u,'v':v,'png_rgb':a,'video_rgb':b})
assert image[0:3]!=image[-3:] # genuine gradient, not solid fallback
report={'notes':len(notes),'drawing_notes':len(melodic),'bass':len(bass),'arpeggio':len(arp),'percussion':len(drums),'end_tick':tick,'root':doc['root'],'scale':doc['scale'],'visual_parity':visual}
(root/'expanded-inspection.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
