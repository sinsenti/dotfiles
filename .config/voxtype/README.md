# Spoken stop commands

While recording, pause briefly, say one of these phrases, then pause again:

- `stop recording`
- `end dictation`
- `finish recording`
- `конец записи`

Say the command as a separate utterance. A single word such as `finish` does
not stop recording. The listener waits for the end of the utterance; it does
not act on partial recognition. The hotkey continues to work normally.

The helper uses local Vosk English and Russian models and the default
PulseAudio/PipeWire microphone. It opens its audio stream only while Voxtype
is recording, saves no audio or transcripts, and makes no recognition network
requests. An isolated command at the end of dictation is consumed rather than
pasted when the listener stops recording. Manually stopped dictation is not
stripped of these words.

Install the helper dependencies and official models with:

```sh
python3 ~/.config/voxtype/setup_stop_listener.py
```

This requires `uv` and `parec`. Models and a private Python environment live
under `${XDG_DATA_HOME:-~/.local/share}/voxtype/stop-commands/`, outside the
repository. The Voxtype systemd drop-in launches the listener alongside the
status window and stops both when Voxtype stops. After installing or changing
the drop-in, reload systemd and restart Voxtype when no recording is active.

Offline regression checks (no microphone or desktop interaction):

```sh
python3 ~/.config/voxtype/test_stop_commands.py
```
