package sysupdate

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"
)

const (
	hypeShellRepoURL = "https://github.com/acarlton5/HypeShell.git"
)

func init() {
	RegisterOverlayBackend(func() Backend { return &hypeShellBackend{} })
}

type hypeShellBackend struct{}

func (hypeShellBackend) ID() string             { return "hypeshell" }
func (hypeShellBackend) DisplayName() string    { return "HypeShell" }
func (hypeShellBackend) Repo() RepoKind         { return RepoHypeShell }
func (hypeShellBackend) NeedsAuth() bool        { return true }
func (hypeShellBackend) RunsInTerminal() bool   { return false }
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
		Name:        "HypeShell",
		Repo:        RepoHypeShell,
		Backend:     "hypeshell",
		FromVersion: from,
		ToVersion:   shortCommit(latest),
		Ref:         "main",
	}}, nil
}

func (hypeShellBackend) Upgrade(ctx context.Context, opts UpgradeOptions, onLine func(string)) error {
	cmd := hypeShellSelfUpdateScript()
	if onLine != nil {
		onLine("$ hype update --self")
		onLine("Updating HypeShell from GitHub main")
	}
	return Run(ctx, hypeShellUpdateArgv(cmd), RunOptions{OnLine: onLine})
}

func hypeShellUpdateArgv(shellCmd string) []string {
	argv := []string{"bash", "-lc", shellCmd}
	if !commandExists("systemd-run") {
		return argv
	}
	scoped := []string{
		"systemd-run",
		"--user",
		"--scope",
		"--collect",
		"--unit",
		fmt.Sprintf("hypeshell-self-update-%d", os.Getpid()),
		"--",
	}
	return append(scoped, argv...)
}

func hypeShellSelfUpdateScript() string {
	return fmt.Sprintf(`set -euo pipefail
tmp="$(mktemp -d "${TMPDIR:-/tmp}/hypeshell-self-update-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

echo "Cloning HypeShell main..."
git clone --depth 1 --branch main %s "$tmp/source"
commit="$(git -C "$tmp/source" rev-parse HEAD)"
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

update_user="${USER:-$(id -un)}"
update_home="${HOME:-}"
echo "Installing HypeShell. One authentication prompt may appear..."
pkexec env SUDO_USER="$update_user" HOME="$update_home" sh -c 'make -C "$1" PREFIX="/usr/local" install && install -D -m 644 "$2" "/usr/local/share/hypeshell/install-fingerprint"' sh "$tmp/source" "$tmp/install-fingerprint"

echo "Restarting HypeShell service..."
systemctl --user daemon-reload || true
systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS || true
if ! systemctl --user restart hype.service && ! systemctl --user start hype.service; then
    nohup /usr/local/bin/hype run --session >/tmp/hypeshell-update-restart.log 2>&1 &
fi
echo "HypeShell self-update complete."
`, shellQuote(hypeShellRepoURL), shellQuote(hypeShellRepoURL))
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
