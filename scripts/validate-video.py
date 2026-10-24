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

video=pathlib.Path(sys.argv[1])
wav=pathlib.Path(sys.argv[2])
report_path=pathlib.Path(sys.argv[3])
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-of','json',str(video)]))
v=next(s for s in probe['streams'] if s['codec_type']=='video')
a=next(s for s in probe['streams'] if s['codec_type']=='audio')
assert v['codec_name']=='h264' and a['codec_name']=='aac'
expected_width=int(sys.argv[4]) if len(sys.argv)>4 else 1080
assert (v['width'],v['height'])==(expected_width,expected_width*5//4)
assert abs(float(fractions.Fraction(v['avg_frame_rate']))-30)<.01
assert a['sample_rate']=='44100' and a['channels']==1
vd,ad=float(v['duration']),float(a['duration'])
assert abs(vd-ad)<=1/30+.002,(vd,ad)
with wave.open(str(wav)) as w:
    assert (w.getframerate(),w.getnchannels(),w.getsampwidth())==(44100,1,2)
    expected_duration=w.getnframes()/w.getframerate()
    loop_seconds=expected_duration-1.25
    reference=array.array('h',w.readframes(w.getnframes()))
assert expected_duration-.01<=ad<=expected_duration+.15,(ad,expected_duration)
decoded=array.array('h',subprocess.check_output(['ffmpeg','-v','error','-i',str(video),'-map','0:a:0','-ac','1','-ar','44100','-f','s16le','pipe:1']))
assert math.sqrt(sum(x*x for x in decoded)/len(decoded))>100
# A bounded correlation search verifies the codec did not shift audio by a frame.
ref=reference[::44];out=decoded[::44]
best=(-2,None)
for lag in range(-50,51):
    pairs=[(ref[i],out[i+lag]) for i in range(max(0,-lag),min(len(ref),len(out)-lag))]
    norm=math.sqrt(sum(x*x for x,y in pairs)*sum(y*y for x,y in pairs))
    correlation=sum(x*y for x,y in pairs)/norm if norm else 0
    if correlation>best[0]:best=(correlation,lag*44/44.1)
assert best[0]>.75,best
assert abs(best[1])<=1000/30,best
cursor_checks=[]
for time in (loop_seconds*.25,loop_seconds*.75):
    pixels=subprocess.check_output(['ffmpeg','-v','error','-ss',str(time),'-i',str(video),'-frames:v','1','-f','rawvideo','-pix_fmt','rgb24','pipe:1'])
    width,height=v['width'],v['height'];expected=round(time/loop_seconds*width)
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
report={'video':{'codec':v['codec_name'],'width':v['width'],'height':v['height'],'fps':v['avg_frame_rate'],'duration':vd},'audio':{'codec':a['codec_name'],'rate':a['sample_rate'],'channels':a['channels'],'duration':ad},'av_duration_difference_seconds':abs(vd-ad),'audio_correlation':best[0],'audio_offset_ms':best[1],'cursor':cursor_checks}
report_path.parent.mkdir(parents=True,exist_ok=True)
report_path.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
