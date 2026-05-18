This file  is more of a quick reference so I know what to account for before next releases. 
 
# Updater smoke tests 
- 2026-05-18: Added beautiful, borderless kitty and ghostty overlay terminal and kept the popout shade open during execution.

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
