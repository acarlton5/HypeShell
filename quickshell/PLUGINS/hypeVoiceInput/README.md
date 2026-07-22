# HypeShell Voice Input

Private, local speech-to-text for Hyprland. Record from the current PipeWire
microphone, transcribe with whisper.cpp, and type the result into the currently
focused application.

## Dependencies

- `pipewire` (`pw-record`)
- `whisper.cpp` (`whisper-cli`)
- A whisper.cpp GGML model such as `ggml-base.en.bin`
- `wtype`, or `wl-clipboard` plus `hyprctl`

Audio and transcripts remain on the local machine. Temporary recordings are
stored below `$XDG_RUNTIME_DIR/hype-voice-input`.
