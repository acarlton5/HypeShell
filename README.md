# HypeShell

<div align="center">
  <a href="https://github.com/acarlton5/HypeShell">
    <img src="assets/hypeshell-logo.png" alt="HypeShell" width="200">
  </a>

### A theme-aware desktop shell built for Hyprland

Independent, community-developed software built with [Quickshell](https://quickshell.org/) and [Go](https://go.dev/)

[![Documentation](https://img.shields.io/badge/docs-HypeShell-9ccbfb?style=for-the-badge&labelColor=101418)](https://github.com/acarlton5/HypeShell)
[![GitHub stars](https://img.shields.io/github/stars/acarlton5/HypeShell?style=for-the-badge&labelColor=101418&color=ffd700)](https://github.com/acarlton5/HypeShell/stargazers)
[![GitHub License](https://img.shields.io/github/license/acarlton5/HypeShell?style=for-the-badge&labelColor=101418&color=b9c8da)](https://github.com/acarlton5/HypeShell/blob/main/LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/acarlton5/HypeShell?style=for-the-badge&labelColor=101418&color=9ccbfb)](https://github.com/acarlton5/HypeShell/releases)
[![GitHub](https://img.shields.io/badge/source-GitHub-9ccbfb?style=for-the-badge&logo=github&logoColor=ffffff&labelColor=101418)](https://github.com/acarlton5/HypeShell)

</div>

HypeShell is an independent desktop shell and Hyprland session. It provides a panel, launcher, control center, notifications, dynamic system-wide theming, plugins, and a single `hype` command-line interface. It is designed for ordinary x86-64 Linux computers as well as Arch Linux ARM on Apple Silicon. HypeShell is not a Dank Linux distribution or package.

## Repository Structure

This is a monorepo containing both the shell interface and the core backend services:

```
HypeShell/
├── quickshell/         # QML-based shell interface
│   ├── Modules/        # UI components (panels, widgets, overlays)
│   ├── Services/       # System integration (audio, network, bluetooth)
│   ├── Widgets/        # Reusable UI controls
│   └── Common/         # Shared resources and themes
├── core/               # Go backend and CLI
│   ├── cmd/            # hype CLI and hypeinstall binaries
│   ├── internal/       # System integration, IPC, distro support
│   └── pkg/            # Shared packages
├── distro/             # Distribution packaging
│   ├── fedora/         # Fedora packaging work
│   ├── ubuntu/         # Debian/Ubuntu packaging work
│   └── nix/            # Nix packaging and modules
└── flake.nix           # Nix flake for declarative installation
```

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/acarlton5/HypeShell/main/install.sh | bash
```

The installer builds HypeShell from this repository, installs its Hyprland session and user service, and configures the HypeShell greeter through `greetd`. It installs required build/runtime dependencies when they are missing. Existing display managers are only replaced as part of the greeter setup.

Hardware detection defaults to `auto`. Apple Silicon machines receive the bundled Arch Linux ARM/Asahi Hyprland configuration; other computers use the generic profile. You can override detection with `--hardware-profile apple-silicon` or `--hardware-profile generic`. The GTK setup also migrates older `dank-colors.css` files to HypeShell's `hype-colors.css` naming.

To repair or update an existing install:

```bash
curl -fsSL https://raw.githubusercontent.com/acarlton5/HypeShell/main/install.sh | bash -s -- --update
```

Install from a local checkout:

```bash
git clone https://github.com/acarlton5/HypeShell.git
cd HypeShell
./install.sh
```

Review all installer and recovery options with `./install.sh --help`. Use `--dry-run` to preview system changes.

## Features

**Dynamic Theming**
Wallpaper-based color schemes that automatically theme GTK, Qt, terminals, editors (vscode, vscodium), and more using [matugen](https://github.com/InioX/matugen) and hype16.

**System Monitoring**
Real-time CPU, RAM, GPU metrics and temperatures with [dgop](https://github.com/AvengeMedia/dgop). Process list with search and management.

**Powerful Launcher**
Spotlight-style search for applications, files, emojis, running windows, calculations, and commands. The launcher is extensible through HypeShell plugins.

**Control Center**
Unified interface for network, Bluetooth, audio devices, display settings, and night mode.

**Smart Notifications**
Notification center with grouping, rich text support, and keyboard navigation.

**Media Integration**
MPRIS player controls, calendar sync, weather widgets, and clipboard history with image previews.

**Session Management**
Lock screen, idle detection, auto-lock/suspend with separate AC/battery settings, and greeter support.

**Plugin System**
Extend the panel, launcher, control center, and popouts with installable HypeShell plugins. Bundled integrations include KDE Connect and the configurable AI launcher.

## Supported Compositor

HypeShell targets [Hyprland](https://hyprland.org/) only, with workspace switching, overview integration, monitor management, Hyprland keybind parsing, and a HypeShell Hyprland login session installed from this repository.

[Hyprland configuration guide](https://wiki.hypr.land/Configuring/)

## Command Line Interface

Control the shell from the command line or keybinds:

```bash
hype run                                  # Start the shell
hype restart                              # Restart the running shell
hype ipc spotlight toggle                 # Toggle Spotlight
hype ipc audio setvolume 50                # Set output volume
hype ipc wallpaper set /path/to/image.jpg  # Change wallpaper
hype brightness list                      # List brightness devices
hype plugins browse                       # Browse available plugins
hype doctor                               # Diagnose an installation
```

The `hype` binary is HypeShell's native CLI. Run `hype --help` or `hype ipc --help` for the complete command list.

## Documentation

- **Source:** [github.com/acarlton5/HypeShell](https://github.com/acarlton5/HypeShell)
- **Plugins/Themes:** [github.com/acarlton5/HypeRegistry](https://github.com/acarlton5/HypeRegistry)

## Development

See component-specific documentation:

- **[quickshell/](quickshell/)** - QML shell development, widgets, and modules
- **[core/](core/)** - Go backend, CLI tools, and system integration
- **[distro/](distro/)** - Packaging work for supported distribution formats

### Building from Source

**Core + installer:**

```bash
cd core
make              # Build hype CLI
make hypeinstall  # Build installer
```

**Shell:**

```bash
quickshell -p quickshell/
```

**NixOS:**

```nix
{
  inputs.hypeshell.url = "github:acarlton5/HypeShell";

  # Use in home-manager or NixOS configuration
  imports = [ inputs.hypeshell.homeModules.hypeshell ];
}
```

## Contributing

Contributions welcome. Bug fixes, widgets, features, documentation, and plugins all help.

1. Fork the repository
2. Make your changes
3. Test thoroughly
4. Open a pull request

For documentation contributions, open a pull request in this repository.

## Credits

HypeShell is independently maintained and contains work derived from open-source shell projects. It is not affiliated with or distributed as Dank Linux.

- [quickshell](https://quickshell.org/) - Shell framework
- [Ly-sec](http://github.com/ly-sec) - Wallpaper effects from [Noctalia](https://github.com/noctalia-dev/noctalia-shell)
- [soramanew](https://github.com/soramanew) - [Caelestia](https://github.com/caelestia-dots/shell) inspiration
- [end-4](https://github.com/end-4) - [dots-hyprland](https://github.com/end-4/dots-hyprland) inspiration

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=acarlton5/HypeShell&type=date&legend=top-left)](https://www.star-history.com/#acarlton5/HypeShell&type=date&legend=top-left)

## License

MIT License - See [LICENSE](LICENSE) for details.
