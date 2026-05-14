#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DEFAULT_REPO_URL="https://github.com/acarlton5/Hype.git"

YES=0
PURGE_USER_DATA=0
SKIP_INSTALL=0
SKIP_PACKAGE_REMOVAL=0
REMOVE_DMS_PACKAGES=0
INSTALL_GREETER=0
INSTALL_METHOD="source"
CLEAN_DISPLAY_MANAGER=0
REPO_URL="$DEFAULT_REPO_URL"
BRANCH="main"
PREFIX="/usr/local"
SOURCE_DIR=""
BACKUP_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/Hype/migration-backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
WORK_DIR="${TMPDIR:-/tmp}/hype-migration-$TIMESTAMP"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Remove old HYPESHELL-era files and install the new Hype/DMS system.

Options:
  --yes                 Actually make changes. Without this, dry-run only.
  --purge-user-data     Delete old user config/state/cache instead of backing it up.
  --skip-install        Only uninstall old HYPESHELL artifacts.
  --skip-package-removal
                        Do not ask the distro package manager to remove old packages.
  --remove-dms-packages Remove installed dms/dms-shell packages too. Use this when
                        replacing an upstream Dank package with this source install.
  --install-method MODE Install method for the replacement system:
                        source   build/install this Hype repo from source (default)
                        package  install the distro Dank/DMS package
  --install-greeter     Install/configure DankGreeter via "dms greeter install --yes".
                        This replaces SDDM/GDM/LightDM with greetd.
  --clean               Remove the sddm package after DankGreeter setup succeeds.
  --repo URL            Hype git repository to install from.
                        Default: $DEFAULT_REPO_URL
  --branch NAME         Branch to clone when --source is not used. Default: main.
  --source DIR          Install from an existing local Hype checkout.
  --prefix DIR          Install prefix. Default: /usr/local.
  -h, --help            Show this help.

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME --yes
  $SCRIPT_NAME --yes --source ~/src/Hype
  $SCRIPT_NAME --yes --install-method package --install-greeter
  $SCRIPT_NAME --yes --purge-user-data --skip-install
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --yes)
            YES=1
            ;;
        --purge-user-data)
            PURGE_USER_DATA=1
            ;;
        --skip-install)
            SKIP_INSTALL=1
            ;;
        --skip-package-removal)
            SKIP_PACKAGE_REMOVAL=1
            ;;
        --remove-dms-packages)
            REMOVE_DMS_PACKAGES=1
            ;;
        --install-method)
            INSTALL_METHOD="${2:-}"
            shift
            ;;
        --install-greeter)
            INSTALL_GREETER=1
            ;;
        --clean)
            CLEAN_DISPLAY_MANAGER=1
            ;;
        --remove-sddm-package)
            CLEAN_DISPLAY_MANAGER=1
            ;;
        --repo)
            REPO_URL="${2:-}"
            shift
            ;;
        --branch)
            BRANCH="${2:-}"
            shift
            ;;
        --source)
            SOURCE_DIR="${2:-}"
            shift
            ;;
        --prefix)
            PREFIX="${2:-}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

case "$INSTALL_METHOD" in
    source|package)
        ;;
    *)
        echo "Error: --install-method must be 'source' or 'package'." >&2
        exit 2
        ;;
esac

if [ "$(uname -s)" != "Linux" ]; then
    echo "Error: this migration script is intended for Linux." >&2
    exit 1
fi

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "Error: run as your normal user. The script will use sudo only where needed." >&2
    exit 1
fi

run() {
    if [ "$YES" -eq 1 ]; then
        "$@"
    else
        printf '[dry-run] '
        printf '%q ' "$@"
        printf '\n'
    fi
}

have() {
    command -v "$1" >/dev/null 2>&1
}

sudo_run() {
    if have sudo; then
        run sudo "$@"
    else
        echo "Error: sudo is required for system install/removal steps." >&2
        exit 1
    fi
}

path_exists() {
    [ -e "$1" ] || [ -L "$1" ]
}

backup_or_remove() {
    path="$1"
    if ! path_exists "$path"; then
        return 0
    fi

    if [ "$PURGE_USER_DATA" -eq 1 ]; then
        run rm -rf "$path"
        return 0
    fi

    relative="${path#$HOME/}"
    destination="$BACKUP_DIR/$relative"
    run mkdir -p "$(dirname "$destination")"
    run mv "$path" "$destination"
}

remove_if_exists() {
    path="$1"
    if path_exists "$path"; then
        sudo_run rm -rf "$path"
    fi
}

remove_user_file_if_exists() {
    path="$1"
    if path_exists "$path"; then
        run rm -f "$path"
    fi
}

backup_legacy_children() {
    parent="$1"
    [ -d "$parent" ] || return 0

    for child in "$parent"/HYPE* "$parent"/Hype* "$parent"/hype*; do
        [ -e "$child" ] || [ -L "$child" ] || continue
        backup_or_remove "$child"
    done
}

stop_disable_user_units() {
    if ! have systemctl; then
        return 0
    fi

    units=(
        hypeshell.service
        hype-shell.service
        hype.service
        hype-updater.service
        HYPESHELL.service
        dms.service
    )

    for unit in "${units[@]}"; do
        run systemctl --user stop "$unit" 2>/dev/null || true
        run systemctl --user disable "$unit" 2>/dev/null || true
    done
    run systemctl --user daemon-reload || true
}

kill_legacy_processes() {
    names=(
        hypeshell
        hype-shell
        HYPESHELL
        hypeupdater
        hype-updater
    )

    for name in "${names[@]}"; do
        run pkill -TERM -x "$name" 2>/dev/null || true
    done

    run pkill -TERM -x dms 2>/dev/null || true
    sleep 1
}

remove_legacy_packages() {
    if [ "$SKIP_PACKAGE_REMOVAL" -eq 1 ]; then
        echo "Skipping distro package removal."
        return 0
    fi

    package_candidates=(
        hypeshell
        hype-shell
        hype-shell-git
        hypeupdater
        hype-updater
        hypeshell-git
    )

    if [ "$REMOVE_DMS_PACKAGES" -eq 1 ]; then
        package_candidates+=(
            dms
            dms-cli
            dms-git
            dms-shell
            dms-shell-git
        )
    fi

    if have pacman; then
        installed=()
        for pkg in "${package_candidates[@]}"; do
            if pacman -Q "$pkg" >/dev/null 2>&1; then
                installed+=("$pkg")
            fi
        done
        if [ "${#installed[@]}" -gt 0 ]; then
            sudo_run pacman -Rns --noconfirm "${installed[@]}"
        fi
    elif have rpm; then
        installed=()
        for pkg in "${package_candidates[@]}"; do
            if rpm -q "$pkg" >/dev/null 2>&1; then
                installed+=("$pkg")
            fi
        done
        if [ "${#installed[@]}" -gt 0 ]; then
            if have dnf; then
                sudo_run dnf remove -y "${installed[@]}"
            elif have zypper; then
                sudo_run zypper --non-interactive remove "${installed[@]}"
            else
                sudo_run rpm -e "${installed[@]}"
            fi
        fi
    elif have dpkg-query; then
        installed=()
        for pkg in "${package_candidates[@]}"; do
            if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
                installed+=("$pkg")
            fi
        done
        if [ "${#installed[@]}" -gt 0 ]; then
            sudo_run apt-get remove -y "${installed[@]}"
        fi
    fi
}

remove_legacy_user_artifacts() {
    backup_or_remove "$HOME/.config/quickshell/hype-shell"
    backup_or_remove "$HOME/.config/quickshell/hypeshell"
    backup_or_remove "$HOME/.config/HYPESHELL"
    backup_or_remove "$HOME/.config/HypeShell"
    backup_or_remove "$HOME/.config/hypeshell"
    backup_or_remove "$HOME/.config/hype-shell"
    backup_or_remove "$HOME/.config/HYPESTORE"
    backup_or_remove "$HOME/.config/HypeStore"
    backup_or_remove "$HOME/.config/hypestore"
    backup_or_remove "$HOME/.config/hype-store"
    backup_or_remove "$HOME/.local/share/HYPESHELL"
    backup_or_remove "$HOME/.local/share/HypeShell"
    backup_or_remove "$HOME/.local/share/hypeshell"
    backup_or_remove "$HOME/.local/share/hype-shell"
    backup_or_remove "$HOME/.local/share/HYPESTORE"
    backup_or_remove "$HOME/.local/share/HypeStore"
    backup_or_remove "$HOME/.local/share/hypestore"
    backup_or_remove "$HOME/.local/share/hype-store"
    backup_or_remove "$HOME/.local/state/HYPESHELL"
    backup_or_remove "$HOME/.local/state/HypeShell"
    backup_or_remove "$HOME/.local/state/hypeshell"
    backup_or_remove "$HOME/.local/state/hype-shell"
    backup_or_remove "$HOME/.local/state/HYPESTORE"
    backup_or_remove "$HOME/.local/state/HypeStore"
    backup_or_remove "$HOME/.local/state/hypestore"
    backup_or_remove "$HOME/.local/state/hype-store"
    backup_or_remove "$HOME/.cache/HYPESHELL"
    backup_or_remove "$HOME/.cache/HypeShell"
    backup_or_remove "$HOME/.cache/hypeshell"
    backup_or_remove "$HOME/.cache/hype-shell"
    backup_or_remove "$HOME/.cache/HYPESTORE"
    backup_or_remove "$HOME/.cache/HypeStore"
    backup_or_remove "$HOME/.cache/hypestore"
    backup_or_remove "$HOME/.cache/hype-store"

    remove_user_file_if_exists "$HOME/.config/systemd/user/hypeshell.service"
    remove_user_file_if_exists "$HOME/.config/systemd/user/hype-shell.service"
    remove_user_file_if_exists "$HOME/.config/systemd/user/hype.service"
    remove_user_file_if_exists "$HOME/.config/systemd/user/hype-updater.service"
    remove_user_file_if_exists "$HOME/.local/bin/hypeshell"
    remove_user_file_if_exists "$HOME/.local/bin/hype-shell"
    remove_user_file_if_exists "$HOME/.local/bin/hypeupdater"
    remove_user_file_if_exists "$HOME/.local/bin/hype-updater"
    remove_user_file_if_exists "$HOME/.local/share/applications/hypeshell.desktop"
    remove_user_file_if_exists "$HOME/.local/share/applications/hype-shell.desktop"
    remove_user_file_if_exists "$HOME/.local/share/applications/hype-updater.desktop"
    remove_user_file_if_exists "$HOME/.local/share/applications/hype-store.desktop"

    backup_legacy_children "$HOME/.config/DankMaterialShell/plugins"
    backup_legacy_children "$HOME/.config/DankMaterialShell/themes"
    backup_legacy_children "$HOME/.local/share/DankMaterialShell/plugins"
    backup_legacy_children "$HOME/.local/share/DankMaterialShell/themes"
}

remove_legacy_system_artifacts() {
    remove_if_exists /usr/local/bin/hypeshell
    remove_if_exists /usr/local/bin/hype-shell
    remove_if_exists /usr/local/bin/hypeupdater
    remove_if_exists /usr/local/bin/hype-updater
    remove_if_exists /usr/bin/hypeshell
    remove_if_exists /usr/bin/hype-shell
    remove_if_exists /usr/bin/hypeupdater
    remove_if_exists /usr/bin/hype-updater
    remove_if_exists /usr/local/share/quickshell/hype-shell
    remove_if_exists /usr/local/share/quickshell/hypeshell
    remove_if_exists /usr/local/share/hype-shell
    remove_if_exists /usr/local/share/hypeshell
    remove_if_exists /usr/local/share/hype-store
    remove_if_exists /usr/share/quickshell/hype-shell
    remove_if_exists /usr/share/quickshell/hypeshell
    remove_if_exists /usr/share/hype-shell
    remove_if_exists /usr/share/hypeshell
    remove_if_exists /usr/share/hype-store
    remove_if_exists /etc/xdg/quickshell/hype-shell
    remove_if_exists /etc/xdg/quickshell/hypeshell
    remove_if_exists /etc/systemd/user/hypeshell.service
    remove_if_exists /etc/systemd/user/hype-shell.service
    remove_if_exists /usr/local/share/applications/hypeshell.desktop
    remove_if_exists /usr/local/share/applications/hype-shell.desktop
    remove_if_exists /usr/local/share/applications/hype-store.desktop
    remove_if_exists /usr/share/applications/hypeshell.desktop
    remove_if_exists /usr/share/applications/hype-shell.desktop
    remove_if_exists /usr/share/applications/hype-store.desktop
}

install_package_if_available() {
    package="$1"
    if have pacman; then
        sudo_run pacman -S --needed --noconfirm "$package"
    elif have dnf; then
        sudo_run dnf install -y "$package"
    elif have apt-get; then
        sudo_run apt-get update
        sudo_run apt-get install -y "$package"
    elif have zypper; then
        sudo_run zypper --non-interactive install "$package"
    else
        return 1
    fi
}

install_dms_package() {
    echo "Installing Dank/DMS from distro packages..."

    if have pacman; then
        install_package_if_available dms-shell
    elif have dnf; then
        if [ "$YES" -eq 1 ] && ! sudo dnf repolist 2>/dev/null | grep -q "avengemedia.*dms"; then
            sudo_run dnf copr enable -y avengemedia/dms || true
        elif [ "$YES" -eq 0 ]; then
            run sudo dnf copr enable -y avengemedia/dms
        fi
        install_package_if_available dms
    elif have apt-get; then
        install_package_if_available dms
    elif have zypper; then
        install_package_if_available dms
    else
        echo "Error: no supported package manager found for package install." >&2
        exit 1
    fi
}

prepare_source() {
    if [ -n "$SOURCE_DIR" ]; then
        if have realpath; then
            SOURCE_DIR="$(realpath "$SOURCE_DIR")"
        else
            SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd -P)"
        fi
        if [ ! -f "$SOURCE_DIR/quickshell/shell.qml" ] || [ ! -f "$SOURCE_DIR/core/Makefile" ]; then
            echo "Error: --source does not look like a Hype checkout: $SOURCE_DIR" >&2
            exit 1
        fi
        return 0
    fi

    if ! have git; then
        echo "Error: git is required to clone $REPO_URL." >&2
        exit 1
    fi

    SOURCE_DIR="$WORK_DIR/Hype"
    run mkdir -p "$WORK_DIR"
    run git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$SOURCE_DIR"
}

install_hype() {
    if [ "$SKIP_INSTALL" -eq 1 ]; then
        echo "Skipping Hype install."
        return 0
    fi

    if [ "$INSTALL_METHOD" = "package" ]; then
        install_dms_package
        return 0
    fi

    prepare_source

    if ! have go; then
        echo "Error: Go 1.22+ is required to build Hype from source." >&2
        echo "Install Go, then rerun this script." >&2
        exit 1
    fi
    if ! have make; then
        echo "Error: make is required to build Hype from source." >&2
        exit 1
    fi

    run make -C "$SOURCE_DIR" build
    sudo_run make -C "$SOURCE_DIR" PREFIX="$PREFIX" install
    run systemctl --user daemon-reload || true
}

install_greeter() {
    if [ "$INSTALL_GREETER" -eq 0 ]; then
        return 0
    fi

    if [ "$YES" -eq 0 ]; then
        echo "Would install/configure DankGreeter. This replaces SDDM/GDM/LightDM with greetd."
        run dms greeter install --yes
        run dms greeter sync --yes
        run dms greeter status
        return 0
    fi

    if ! have dms; then
        echo "Error: dms command is not available; cannot install DankGreeter." >&2
        echo "Install Hype/DMS first, then rerun with --skip-install --install-greeter." >&2
        exit 1
    fi

    echo "Installing/configuring DankGreeter. This replaces SDDM/GDM/LightDM with greetd."
    run dms greeter install --yes
    run dms greeter sync --yes
    run dms greeter status || true
}

clean_display_manager() {
    if [ "$CLEAN_DISPLAY_MANAGER" -eq 0 ]; then
        return 0
    fi

    if [ "$INSTALL_GREETER" -eq 0 ]; then
        echo "Error: --clean requires --install-greeter so greetd is configured first." >&2
        exit 1
    fi

    if have pacman && pacman -Q sddm >/dev/null 2>&1; then
        sudo_run pacman -Rns --noconfirm sddm
    elif have rpm && rpm -q sddm >/dev/null 2>&1; then
        if have dnf; then
            sudo_run dnf remove -y sddm
        elif have zypper; then
            sudo_run zypper --non-interactive remove sddm
        else
            sudo_run rpm -e sddm
        fi
    elif have dpkg-query && dpkg-query -W -f='${Status}' sddm 2>/dev/null | grep -q "install ok installed"; then
        sudo_run apt-get remove -y sddm
    else
        echo "sddm package not installed or no supported package manager found."
    fi
}

main() {
    if [ "$YES" -eq 0 ]; then
        cat <<EOF
Dry run only. Re-run with --yes to make changes.

This will:
  - stop/disable legacy HYPESHELL user services
  - remove known old HYPESHELL binaries, service files, desktop files, and shell paths
  - move old user config/state/cache into:
    $BACKUP_DIR
  - build and install Hype from:
    ${SOURCE_DIR:-$REPO_URL}
  - install the new system command as "dms" under:
    $PREFIX/bin/dms
  - install method:
    $INSTALL_METHOD
  - install DankGreeter / replace SDDM with greetd:
    $INSTALL_GREETER
  - remove sddm package after greeter setup:
    $CLEAN_DISPLAY_MANAGER

EOF
    else
        mkdir -p "$BACKUP_DIR"
    fi

    stop_disable_user_units
    kill_legacy_processes
    remove_legacy_packages
    remove_legacy_user_artifacts
    remove_legacy_system_artifacts
    install_hype
    install_greeter
    clean_display_manager

    if [ "$YES" -eq 1 ]; then
        echo
        echo "Migration complete."
        if [ "$PURGE_USER_DATA" -eq 0 ]; then
            echo "Legacy user data backup: $BACKUP_DIR"
        fi
        echo "Start Hype/DMS with:"
        echo "  systemctl --user enable --now dms"
        echo "or:"
        echo "  dms run"
        echo
        echo "Note: Hype currently keeps the upstream DMS command/service names internally."
    else
        echo
        echo "Dry run complete. No changes were made."
    fi
}

main "$@"
