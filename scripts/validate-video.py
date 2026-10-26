#!/usr/bin/env python3
"""Inspect real Android encoder output independently with FFmpeg and stdlib."""
import array
import fractions
import json
import math
import pathlib
import subprocess
import sys
import wave
import numpy as np

video=pathlib.Path(sys.argv[1])
wav=pathlib.Path(sys.argv[2])
report_path=pathlib.Path(sys.argv[3])
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-of','json',str(video)]))
v=next(s for s in probe['streams'] if s['codec_type']=='video')
a=next(s for s in probe['streams'] if s['codec_type']=='audio')
assert v['codec_name']=='h264' and a['codec_name']=='aac'
expected_width=int(sys.argv[4]) if len(sys.argv)>4 else 1080
assert (v['width'],v['height'])==(expected_width,expected_width*5//4)
expected_fps=int(sys.argv[5]) if len(sys.argv)>5 else 30
assert expected_fps in (30,60)
assert abs(float(fractions.Fraction(v['avg_frame_rate']))-expected_fps)<.01
assert a['sample_rate']=='44100' and a['channels']==1
vd,ad=float(v['duration']),float(a['duration'])
assert abs(vd-ad)<=1/expected_fps+.002,(vd,ad)
with wave.open(str(wav)) as w:
    assert (w.getframerate(),w.getnchannels(),w.getsampwidth())==(44100,1,2)
    expected_duration=w.getnframes()/w.getframerate()
    loop_seconds=expected_duration-1.25
    reference=array.array('h',w.readframes(w.getnframes()))
assert expected_duration-.01<=ad<=expected_duration+.15,(ad,expected_duration)
decoded=array.array('h',subprocess.check_output(['ffmpeg','-v','error','-i',str(video),'-map','0:a:0','-ac','1','-ar','44100','-f','s16le','pipe:1']))
assert math.sqrt(sum(x*x for x in decoded)/len(decoded))>100
# Sample-precision FFT correlation avoids pitch-period aliases and coarse
# downsampling phase errors. Both signals include the full onset/release envelope.
ref=np.asarray(reference,dtype=np.float64);out=np.asarray(decoded,dtype=np.float64)
size=1 << (len(ref)+len(out)-2).bit_length()
cross=np.fft.irfft(np.fft.rfft(out,size)*np.conj(np.fft.rfft(ref,size)),size)
limit=round(.05*44100)
lags=np.arange(-limit,limit+1)
norm=np.sqrt(np.dot(ref,ref)*np.dot(out,out))
correlations=cross[lags % size]/norm
index=int(np.argmax(correlations))
best=(float(correlations[index]),float(lags[index]*1000/44100))
assert best[0]>.75,best
assert abs(best[1])<=1000/expected_fps,best
cursor_checks=[]
paper_checks=[]
style_checks=[]
project_path=video.parent/'ui-project.json'
project=json.loads(project_path.read_text()) if video.name=='ui-export-video.mp4' and project_path.exists() else None
if project is not None:
    if project.get('paper'):
        paper=project['paper'];assert paper['kind']=='solid'
        argb=paper['colors'][0];alpha=round(((argb>>24)&255)*paper['opacity'])
    else:
        argb=project['background'];alpha=(argb>>24)&255
    paper_rgb=[(((argb>>shift)&255)*alpha+255*(255-alpha)+127)//255 for shift in (16,8,0)]
for time in (loop_seconds*.25,loop_seconds*.75):
    pixels=subprocess.check_output(['ffmpeg','-v','error','-ss',str(time),'-i',str(video),'-frames:v','1','-f','rawvideo','-pix_fmt','rgb24','pipe:1'])
    width,height=v['width'],v['height'];expected=round(time/loop_seconds*width)
    if project is not None:
        # The synthetic UI fixture has no marks in this bottom-right patch.
        at=((height-6)*width+(width-6))*3
        observed=list(pixels[at:at+3])
        assert all(abs(a-b)<=4 for a,b in zip(observed,paper_rgb)),(observed,paper_rgb)
        paper_checks.append({'seconds':time,'observed_rgb':observed,'expected_rgb':paper_rgb})
    if project is not None and project.get('style','smooth')=='pixel':
        # The UI fixture includes an isolated tap. A filled cell must cover its
        # interior; an unchanged smooth dot cannot pass this area check.
        dot=next(s for s in reversed(project['strokes']) if len(s['points'])==1)
        u,vv=dot['points'][0][:2]
        cx=min(39,int(u*40));cy=min(49,int(vv*50))
        color={'keys':(121,97,198),'mallet':(164,107,22),'bell':(40,126,97)}[dot['instrument']]
        matched=total=0
        for yy in range(int(cy*height/50)+3,int((cy+1)*height/50)-3):
            for xx in range(int(cx*width/40)+3,int((cx+1)*width/40)-3):
                at=(yy*width+xx)*3;sample=pixels[at:at+3];total+=1
                if all(abs(a-b)<=16 for a,b in zip(sample,color)):matched+=1
        assert total>0 and matched/total>.8,(matched,total,color)
        style_checks.append({'seconds':time,'style':'pixel','matched_interior_pixels':matched,'interior_pixels':total})
    candidates=[]
    for x in range(expected-12,expected+13):
        count=0
        for y in range(20,height-20):
            at=(y*width+x)*3;r,g,b=pixels[at:at+3]
            if r<30 and 85<g<160 and 75<b<155:count+=1
        candidates.append((count,x))
    count,x=max(candidates)
    assert count>height*.7,(time,count,x)
    assert abs(x-expected)<=width/120,(time,x,expected)
    cursor_checks.append({'seconds':time,'x':x,'expected_x':expected,'matching_rows':count})
report={'video':{'codec':v['codec_name'],'width':v['width'],'height':v['height'],'fps':v['avg_frame_rate'],'duration':vd},'audio':{'codec':a['codec_name'],'rate':a['sample_rate'],'channels':a['channels'],'duration':ad},'av_duration_difference_seconds':abs(vd-ad),'audio_correlation':best[0],'audio_offset_ms':best[1],'cursor':cursor_checks,'paper':paper_checks,'style':style_checks}
report_path.parent.mkdir(parents=True,exist_ok=True)
report_path.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
