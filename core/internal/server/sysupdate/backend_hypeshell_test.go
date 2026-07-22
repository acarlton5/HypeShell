package sysupdate

import (
	"os/exec"
	"strings"
	"testing"
)

func TestHypeShellSelfUpdateScriptHardwareProfile(t *testing.T) {
	script := hypeShellSelfUpdateScript("1001", "testuser", "/home/testuser", "/run/user/1001", "unix:path=/run/user/1001/bus")
	for _, expected := range []string{
		`hardware_profile="apple-silicon"`,
		`assets/hardware/apple-silicon/hypr-hardware.conf`,
		`source = ./hype/hardware.conf`,
		`install -o "$update_user" -g "$user_group" -m 644 /dev/null "$user_hardware_file"`,
	} {
		if !strings.Contains(script, expected) {
			t.Fatalf("self-update script missing %q", expected)
		}
	}

	cmd := exec.Command("bash", "-n")
	cmd.Stdin = strings.NewReader(script)
	if output, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("self-update script has invalid shell syntax: %v\n%s", err, output)
	}
}
