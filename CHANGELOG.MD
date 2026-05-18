This file  is more of a quick reference so I know what to account for before next releases. 
 
# Updater smoke tests 
- 2026-05-18: Added beautiful, borderless kitty and ghostty overlay terminal and kept the popout shade open during execution.
- 2026-05-18: Implemented 100% background privilege escalation via Polkit (`pkexec`) bypass. Redesigned Settings About tab with 4 granular, color-coded service status cards (HypeShell, Pacman, Paru/AUR, Flatpak) and styled scrollable inline update panel in SystemUpdatePopout. Fully resolved Go 1.26 toolchain and missing Go core symbol declarations.
- 2026-05-18: Deployed dynamic invoking-user Go compiler resolution to guarantee successful compilation in stripped systemd/polkit elevated environments.
- 2026-05-18: Switched system updater privilege execution to TTY-less non-login shell (bash -c) and added robust regex filtering on user Go compiler resolution to ignore MOTD shell banners.
- 2026-05-18: Upgraded self-updater to dynamically resolve Go daemon process owner (real UID, home, XDG_RUNTIME_DIR, and DBUS_SESSION_BUS_ADDRESS) directly from the Go context to guarantee foolproof systemd user service restarts.
- 2026-05-18: Polished and finalized background systemd user session handoffs, validating 100% automated self-updates and graphic reload sequences.
- 2026-05-18: Hardened self-update compilation, adding GOGC=50 and GOMAXPROCS=2 thread and memory limits to prevent compilation OOM kills, and automated go mod tidying before make.

# 1.5.0
- Overhauled shadows
- App ID changed to com.hypelinux.hype - breaking for window rules
- Greeter stuff
- Terminal mux
- Locale overrides
- new neovim theming

# 1.4.0

- Overhauled system monitor, graphs, styling
- dbus API for plugins, KDEConnect
- new hype16 algorithm
- launcher actions, customize env, args, name, icon
- launcher v2 - omega stuff, GIF search, supa powerful
- dock on bar
- window rule manager, with IPC - #TODO verify RTL layout (niri only)

# 1.2.0

- Added clipboard and clipboard history integration
- Added swipe to dismiss notification popups and from center
- Added paste from clipboard history view - requires wtype
- Optimize surface damage of OSD & Toast
- Add monitor configurator (niri, Hyprland, MangoWC)
- **BREAKING** ghostty theme changed to ~/.config/ghostty/themes/hypetheme
  - requires intervention and doc update
- Added desktop widget plugins
  - dev guidance available
  - builtin clock & dgop widgets
  - new IPC targets
- Initial RTL support/i18n
- Theme registry
- Notification persistence & history
- **BREAKING** vscode theme needs re-installed
- hype doctor cmd
- niri/hypr/mango gaps/window/border overrides
- settings search
- notification display ops on lock screen
