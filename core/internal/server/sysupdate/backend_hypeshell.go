package sysupdate

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"
)

const (
	hypeShellRepoURL    = "https://github.com/acarlton5/HypeShell.git"
	hypeShellRawInstall = "https://raw.githubusercontent.com/acarlton5/HypeShell/main/install.sh"
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
	cmd := fmt.Sprintf(`curl -fsSL "%s?cache=$(date +%%s)" | bash -s -- --update --reboot-if-needed`, hypeShellRawInstall)
	if onLine != nil {
		onLine("$ " + cmd)
		onLine("Streaming HypeShell update in the Hype updater shade")
	}
	return Run(ctx, hypeShellUpdateArgv(cmd), RunOptions{OnLine: onLine})
}

func hypeShellUpdateArgv(shellCmd string) []string {
	argv := []string{"sh", "-c", "export HYPESHELL_INSTALL_PRIVESC=pkexec; " + shellCmd}
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
