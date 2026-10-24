#!/usr/bin/env python3
"""Parse the actual UI-exported MIDI independently from its writer."""
import json,pathlib,mido
root=pathlib.Path('work/runtime-output')
document=json.loads((root/'ui-project.json').read_text())
midi=mido.MidiFile(root/'ui-export-notes.mid')
assert midi.type==0 and midi.ticks_per_beat==480
active={};tick=0;count=0;tempo=None
for event in midi.tracks[0]:
    tick+=event.time
    if event.type=='set_tempo':tempo=event.tempo
    if event.type=='note_on' and event.velocity:
        assert (event.channel,event.note) not in active
        active[event.channel,event.note]=tick;count+=1
    if event.type=='note_off' or (event.type=='note_on' and not event.velocity):
        assert active.pop((event.channel,event.note))<tick
assert not active and count>0 and tick==3840
assert abs(tempo-60000000/document['tempo'])<1
assert abs(midi.length-480/document['tempo'])<.00001
report={'type':midi.type,'ppq':midi.ticks_per_beat,'notes':count,'tempo_bpm':document['tempo'],'end_tick':tick,'duration_seconds':midi.length,'project_id':document['id'],'revision':document['revision']}
(root/'midi-inspection.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
