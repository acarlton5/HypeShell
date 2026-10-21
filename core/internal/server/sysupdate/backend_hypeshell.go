package sysupdate

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

const (
	hypeShellRepoURL = "https://github.com/acarlton5/HypeShell.git"
)

func init() {
	RegisterOverlayBackend(func() Backend { return &hypeShellBackend{} })
}

type hypeShellBackend struct{}

func (hypeShellBackend) ID() string          { return "hypeshell" }
func (hypeShellBackend) DisplayName() string { return "HypeShell" }
func (hypeShellBackend) Repo() RepoKind      { return RepoHypeShell }
func (hypeShellBackend) NeedsAuth() bool     { return false }
func (hypeShellBackend) RunsInTerminal() bool {
	return false
}
func (hypeShellBackend) IsAvailable(ctx context.Context) bool {
	return commandExists("git") && (commandExists("hype") || installedHypeShellCommit() != "")
}

func (hypeShellBackend) CheckUpdates(ctx context.Context) ([]Package, error) {
	latest, err := latestHypeShellCommit(ctx)
	if err != nil || latest == "" {
		return nil, nil
	}

	installed := installedHypeShellCommit()
	if installed != "" && shortCommit(installed) == shortCommit(latest) {
		return nil, nil
	}

	from := shortCommit(installed)
	if from == "" {
		from = "unknown"
	}

	return []Package{{
		Name:         "HypeShell",
		Repo:         RepoHypeShell,
		Backend:      "hypeshell",
		FromVersion:  from,
		ToVersion:    shortCommit(latest),
		Ref:          "main",
		ChangelogURL: "https://github.com/acarlton5/HypeShell/commits/main",
	}}, nil
}

func (b hypeShellBackend) Upgrade(ctx context.Context, opts UpgradeOptions, onLine func(string)) error {
	realUID := fmt.Sprintf("%d", os.Getuid())
	realUser := os.Getenv("USER")
	realHome := os.Getenv("HOME")
	realXdg := os.Getenv("XDG_RUNTIME_DIR")
	realDbus := os.Getenv("DBUS_SESSION_BUS_ADDRESS")
	cmd := hypeShellSelfUpdateScript(realUID, realUser, realHome, realXdg, realDbus)
	if onLine != nil {
		onLine("$ hype update install")
		onLine("Updating HypeShell from GitHub main")
	}
	if opts.AttachStdio {
		return Run(ctx, []string{"sudo", "bash", "-c", cmd}, RunOptions{OnLine: onLine, AttachStdio: true})
	}

	if opts.Password != "" {
		sudoArgv := []string{"sudo", "-S", "bash", "-c", cmd}
		return Run(ctx, sudoArgv, RunOptions{
			OnLine: onLine,
			Stdin:  opts.Password + "\n",
		})
	}

	bashPath, err := exec.LookPath("bash")
	if err != nil {
		bashPath = "/usr/bin/bash"
	}

	priv := privescBin(opts.UseSudo)
	if priv == "sudo" {
		return Run(ctx, []string{"sudo", "-n", bashPath, "-c", cmd}, RunOptions{OnLine: onLine})
	}

	return Run(ctx, []string{"pkexec", bashPath, "-c", cmd}, RunOptions{OnLine: onLine})
}

func hypeShellSelfUpdateScript(realUID, realUser, realHome, realXdg, realDbus string) string {
	userPath := os.Getenv("PATH")
	if userPath == "" {
		userPath = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
	}
	return fmt.Sprintf(`set -euo pipefail
export PATH=%s:"$PATH"
export GOGC=30
export GOMAXPROCS=1
export GOMEMLIMIT=768MiB

invoking_uid="${SUDO_UID:-${PKEXEC_UID:-%s}}"
if [ -n "$invoking_uid" ] && [ "$invoking_uid" != "0" ]; then
    update_user=$(id -un "$invoking_uid")
    update_home=$(getent passwd "$invoking_uid" | cut -d: -f6)
else
    update_user="%s"
    update_home="%s"
    invoking_uid="%s"
fi

cache_dir="$update_home/.cache/hypeshell-update"
mkdir -p "$cache_dir"
tmp="$(mktemp -d "$cache_dir/hypeshell-self-update-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# Fallback values for XDG and DBus runtime if they need to be populated in the reload block
xdg_runtime="%s"
dbus_bus="%s"
if [ -z "$xdg_runtime" ]; then
    xdg_runtime="/run/user/$invoking_uid"
fi
if [ -z "$dbus_bus" ]; then
    dbus_bus="unix:path=/run/user/$invoking_uid/bus"
fi

# Pre-locate and resolve invoking user's Go compiler path if not in default elevated PATH
user_go=""
if [ -n "$invoking_uid" ]; then
    user_go="$(runuser -u "$update_user" -- env HOME="$update_home" bash -lc "command -v go" 2>/dev/null | grep -E '^/' | tail -n1 || true)"
fi
if [ -z "$user_go" ]; then
    user_go="$(command -v go 2>/dev/null || true)"
fi
if [ -n "$user_go" ]; then
    go_dir="$(dirname "$user_go")"
    export PATH="$go_dir:$PATH"
fi

echo "Cloning HypeShell main..."
git clone --depth 1 --branch main %s "$tmp/source"
commit="$(git -C "$tmp/source" rev-parse HEAD)"

echo "Tidying Go modules..."
(cd "$tmp/source/core" && go mod tidy || true)

echo "Building HypeShell ${commit:0:12}..."
make -C "$tmp/source" build

cat > "$tmp/install-fingerprint" <<EOF
status=success
installed_at=$(date -u +%%Y-%%m-%%dT%%H:%%M:%%SZ)
source_remote=%s
source_branch=main
source_commit=$commit
installer_build=hype-shade-self-update-v2
EOF

echo "Installing HypeShell..."
make -C "$tmp/source" PREFIX="/usr/local" install
install -D -m 755 "$tmp/source/quickshell/Modules/Greetd/assets/hype-greeter" /usr/local/bin/hype-greeter
install -D -m 755 "$tmp/source/quickshell/Modules/Greetd/assets/hype-greeter" /usr/bin/hype-greeter
install -D -m 755 "$tmp/source/assets/sessions/hypeshell-hyprland-session" /usr/local/bin/hypeshell-hyprland-session
if ! cmp -s "$tmp/source/quickshell/Modules/Greetd/assets/hype-greeter" /usr/local/bin/hype-greeter || ! cmp -s "$tmp/source/quickshell/Modules/Greetd/assets/hype-greeter" /usr/bin/hype-greeter || ! cmp -s "$tmp/source/assets/sessions/hypeshell-hyprland-session" /usr/local/bin/hypeshell-hyprland-session; then
    echo "Error: HypeShell asset installation verification failed." >&2
    echo "The binary may be updated, but the greeter/session scripts were not replaced." >&2
    exit 1
fi
install -D -m 644 "$tmp/install-fingerprint" "/usr/local/share/hypeshell/install-fingerprint"

hardware_profile="generic"
hardware_arch="$(uname -m)"
dmi_product=""
if [ -r /sys/devices/virtual/dmi/id/product_name ]; then
    dmi_product="$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || true)"
elif [ -r /sys/class/dmi/id/product_name ]; then
    dmi_product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
fi

if { [ "$hardware_arch" = "aarch64" ] || [ "$hardware_arch" = "arm64" ]; } && { { [ -r /proc/device-tree/compatible ] && tr '\0' '\n' </proc/device-tree/compatible 2>/dev/null | grep -qi '^apple,'; } || { [ -r /proc/device-tree/model ] && grep -aqi 'Apple' /proc/device-tree/model; }; }; then
    hardware_profile="apple-silicon"
elif echo "$dmi_product" | grep -E -iq 'Jupiter|Galileo'; then
    hardware_profile="steamdeck"
fi

echo "Applying HypeShell hardware profile: $hardware_profile"
user_group="$(id -gn "$update_user")"
user_hardware_dir="$update_home/.config/hypr/hype"
user_hardware_file="$user_hardware_dir/hardware.lua"
shared_hardware_file="/usr/local/share/hypeshell/hyprland/hype/hardware.lua"
install -d -o "$update_user" -g "$user_group" "$user_hardware_dir"
if [ "$hardware_profile" = "apple-silicon" ]; then
    hardware_source="$tmp/source/assets/hardware/apple-silicon/hypr-hardware.lua"
    install -D -m 644 "$hardware_source" "$shared_hardware_file"
    install -o "$update_user" -g "$user_group" -m 644 "$hardware_source" "$user_hardware_file"
elif [ "$hardware_profile" = "steamdeck" ]; then
    hardware_source="$tmp/source/assets/hardware/steamdeck/hypr-hardware.lua"
    install -D -m 644 "$hardware_source" "$shared_hardware_file"
    install -o "$update_user" -g "$user_group" -m 644 "$hardware_source" "$user_hardware_file"
    # Auto-update Anvil gaming session and application desktop entries
    anvil_plugin_dir="$update_home/.config/HypeShell/plugins/hypeAnvil"
    anvil_repo="https://github.com/acarlton5/Anvil.git"
    if [ ! -d "$anvil_plugin_dir" ]; then
        echo "Installing Anvil console plugin..."
        runuser -u "$update_user" -- git clone "$anvil_repo" "$anvil_plugin_dir" || true
    elif [ -d "$anvil_plugin_dir/.git" ]; then
        echo "Updating Anvil console from git..."
        runuser -u "$update_user" -- git -C "$anvil_plugin_dir" pull origin main || true
    fi
    if [ -f "$anvil_plugin_dir/scripts/install-session" ]; then
        echo "Refreshing Anvil session files..."
        bash "$anvil_plugin_dir/scripts/install-session" "$anvil_plugin_dir" || true
    elif [ -f "$anvil_plugin_dir/plugins/hypeAnvil/scripts/install-session" ]; then
        echo "Refreshing Anvil session files..."
        bash "$anvil_plugin_dir/plugins/hypeAnvil/scripts/install-session" "$anvil_plugin_dir" || true
    fi

    # Configure Steam Deck bootloader rotation, hide sideways GRUB, and early KMS
    fbcon_rot="3"
    if echo "$dmi_product" | grep -iq 'Galileo'; then
        fbcon_rot="1"
    fi
    deck_params="pci=noaer usbcore.autosuspend=-1 fbcon=rotate:$fbcon_rot quiet loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0"

    if [ -f /etc/default/grub ]; then
        echo "Configuring GRUB to hide sideways menu and rotate console..."
        sed -i 's/ amdgpu\.dcfeaturemask=[^ "]*//g' /etc/default/grub 2>/dev/null || true
        sed -i -E 's/^GRUB_TIMEOUT=[0-9]+/GRUB_TIMEOUT=0/' /etc/default/grub 2>/dev/null || true
        if ! grep -q '^GRUB_TIMEOUT_STYLE=' /etc/default/grub; then
            echo 'GRUB_TIMEOUT_STYLE=hidden' >> /etc/default/grub
        else
            sed -i -E 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub 2>/dev/null || true
        fi
        if ! grep -q '^GRUB_RECORDFAIL_TIMEOUT=' /etc/default/grub; then
            echo 'GRUB_RECORDFAIL_TIMEOUT=0' >> /etc/default/grub
        fi
        if ! grep -q 'pci=noaer' /etc/default/grub; then
            sed -i.bak -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 $deck_params\"/" /etc/default/grub
        fi
        if command -v grub-mkconfig >/dev/null 2>&1; then
            if [ -d /boot/grub ]; then
                grub-mkconfig -o /boot/grub/grub.cfg || true
            elif [ -d /boot/grub2 ]; then
                grub-mkconfig -o /boot/grub2/grub.cfg || true
            fi
        fi
    fi

    for entry_dir in /boot/loader/entries /efi/loader/entries /boot/efi/loader/entries; do
        if [ -d "$entry_dir" ]; then
            for conf in "$entry_dir"/*.conf; do
                [ -f "$conf" ] || continue
                sed -i 's/ amdgpu\.dcfeaturemask=[^ ]*//g' "$conf" 2>/dev/null || true
                if grep -q '^options' "$conf"; then
                    if ! grep -q 'pci=noaer' "$conf"; then
                        sed -i "/^options/ s/$/ $deck_params/" "$conf"
                    fi
                fi
            done
        fi
    done
else
    install -D -m 644 /dev/null "$shared_hardware_file"
    install -o "$update_user" -g "$user_group" -m 644 /dev/null "$user_hardware_file"
fi

# Passwordless sudo and polkit rules for universal SteamOS-style background updating
if [ -d /etc/sudoers.d ]; then
    sudoers_target="/etc/sudoers.d/99-hypeshell-updates"
    echo "%%%%wheel ALL=(ALL) NOPASSWD: /usr/bin/true, /usr/local/bin/hype update *, /usr/bin/pacman -Syu --noconfirm, /usr/bin/pacman -S --needed --noconfirm *, /usr/bin/pacman -S *" > "$sudoers_target"
    chmod 0440 "$sudoers_target" || true
fi

if [ -d /etc/polkit-1/rules.d ]; then
    cat << 'POLKIT_EOF' > /etc/polkit-1/rules.d/99-hypeshell-updates.rules
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        (action.lookup("program") == "/usr/bin/pacman" || action.lookup("program") == "/usr/local/bin/hype") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
POLKIT_EOF
    chmod 0644 /etc/polkit-1/rules.d/99-hypeshell-updates.rules || true
fi

user_hypr_config="$update_home/.config/hypr/hyprland.lua"
hardware_source_line='require("hype.hardware")'
if [ -f "$user_hypr_config" ] && ! grep -Fqx "$hardware_source_line" "$user_hypr_config"; then
    runuser -u "$update_user" -- sh -c 'printf "\n%%s\n" "$1" >> "$2"' sh "$hardware_source_line" "$user_hypr_config"
fi


echo "HypeShell self-update complete. Reloading service in 2 seconds..."
if [ -n "$invoking_uid" ]; then
    runuser -u "$update_user" -- env HOME="$update_home" XDG_RUNTIME_DIR="$xdg_runtime" DBUS_SESSION_BUS_ADDRESS="$dbus_bus" systemctl --user daemon-reload || true
    runuser -u "$update_user" -- env HOME="$update_home" XDG_RUNTIME_DIR="$xdg_runtime" DBUS_SESSION_BUS_ADDRESS="$dbus_bus" systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS || true
    if ! runuser -u "$update_user" -- env HOME="$update_home" XDG_RUNTIME_DIR="$xdg_runtime" DBUS_SESSION_BUS_ADDRESS="$dbus_bus" systemd-run --user --collect --on-active=2s /usr/bin/systemctl --user restart hype.service >/dev/null; then
        echo "Warning: could not schedule the HypeShell service restart; run hype restart." >&2
    fi
else
    systemctl --user daemon-reload || true
    systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS || true
    if ! systemd-run --user --collect --on-active=2s /usr/bin/systemctl --user restart hype.service >/dev/null; then
        echo "Warning: could not schedule the HypeShell service restart; run hype restart." >&2
    fi
fi
`,
		shellQuote(userPath),
		shellQuote(realUID),
		shellQuote(realUser),
		shellQuote(realHome),
		shellQuote(realUID),
		shellQuote(realXdg),
		shellQuote(realDbus),
		shellQuote(hypeShellRepoURL),
		shellQuote(hypeShellRepoURL),
	)
}

func shellQuote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'"
}

func latestHypeShellCommit(ctx context.Context) (string, error) {
	out, err := Capture(ctx, []string{"git", "ls-remote", hypeShellRepoURL, "refs/heads/main"})
	if err != nil {
		return "", err
	}
	fields := strings.Fields(out)
	if len(fields) == 0 {
		return "", nil
	}
	return fields[0], nil
}

func installedHypeShellCommit() string {
	for _, path := range []string{
		"/usr/local/share/hypeshell/install-fingerprint",
		"/usr/share/hypeshell/install-fingerprint",
	} {
		commit := readFingerprintCommit(path)
		if commit != "" {
			return commit
		}
	}
	return ""
}

func readFingerprintCommit(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		value, ok := strings.CutPrefix(line, "source_commit=")
		if !ok {
			continue
		}
		value = strings.TrimSpace(value)
		if value == "" || value == "unknown" || strings.HasPrefix(value, "failed:") {
			return ""
		}
		return value
	}
	return ""
}

func shortCommit(commit string) string {
	commit = strings.TrimSpace(commit)
	if len(commit) > 12 {
		return commit[:12]
	}
	return commit
}
