# Hype Voice2Text

Private, local speech-to-text for Hyprland. Record from the current PipeWire
microphone, transcribe with whisper.cpp, and type the result into the currently
focused application.

The Hypebar button opens the voice shade. Press the orb to begin listening; the
shade then collapses into a floating orb. Press the floating orb to stop and
transcribe, or press its small close button to cancel. The orb remains visible
with an animated processing indicator until the transcript has been inserted.

## Dependencies

- `pipewire` (`pw-record`)
- `whisper.cpp` (`whisper-cli`)
- A whisper.cpp GGML model such as `ggml-base.en.bin`
- `wtype`, or `wl-clipboard` plus `hyprctl`

On Arch Linux, install the runtime tools and an English base model with:

```bash
paru -S --needed wtype wl-clipboard whisper.cpp-git whisper.cpp-model-base.en
```

Some AUR whisper.cpp packages omit `aarch64` from their architecture list even
though whisper.cpp supports ARM. On an ARM machine, review the PKGBUILD and add
`aarch64` to its `arch` array before building when necessary.

The plugin automatically discovers the packaged model at
`/usr/share/whisper.cpp-model-base.en/ggml-base.en.bin`. A different GGML model
can be selected in the plugin settings.

## Installation

Install the plugin from HypeShell's plugin registry. HypeShell opens a setup
terminal that installs the runtime tools and detects the machine architecture.
On x86_64 Arch it first uses the packaged whisper.cpp build; on ARM it builds
whisper.cpp locally under `~/.local` to avoid incompatible AUR architecture
metadata. Then add **Voice Input** to your Hypebar in Settings.

## Privacy

Audio and transcripts remain on the local machine. Temporary recordings are
stored below `$XDG_RUNTIME_DIR/hype-voice-input`.
