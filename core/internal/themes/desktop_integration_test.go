package themes

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/spf13/afero"
)

func TestThemeDesktopAssetFixture(t *testing.T) {
	fixture := os.Getenv("HYPE_THEME_FIXTURE")
	if fixture == "" {
		t.Skip("HYPE_THEME_FIXTURE is not set")
	}

	data, err := os.ReadFile(filepath.Join(fixture, "theme.json"))
	if err != nil {
		t.Fatal(err)
	}
	var theme Theme
	if err := json.Unmarshal(data, &theme); err != nil {
		t.Fatal(err)
	}

	destination := t.TempDir()
	manager := &Manager{fs: afero.NewOsFs(), themesDir: t.TempDir()}
	manager.copyThemeAssets(fixture, destination, theme)

	for _, wallpaper := range theme.Wallpapers {
		if wallpaper.Path == "" {
			continue
		}
		if _, err := os.Stat(filepath.Join(destination, wallpaper.Path)); err != nil {
			t.Errorf("wallpaper %q was not installed: %v", wallpaper.Path, err)
		}
	}

	if theme.Desktop == nil {
		return
	}
	for name, asset := range map[string]*ThemeDesktopAsset{
		"cursor": theme.Desktop.Cursor,
		"icons":  theme.Desktop.Icons,
		"gtk":    theme.Desktop.GTK,
	} {
		if asset == nil {
			continue
		}
		expected := filepath.Join(
			destination,
			filepath.Dir(asset.Archive),
			".extracted",
			asset.Root,
		)
		info, err := os.Stat(expected)
		if err != nil {
			t.Errorf("%s asset was not extracted to %q: %v", name, expected, err)
			continue
		}
		if !info.IsDir() {
			t.Errorf("%s asset root %q is not a directory", name, expected)
		}
	}
}

func TestRegistryThemeRepositoryFixture(t *testing.T) {
	repository := os.Getenv("HYPE_THEME_REPOSITORY")
	if repository == "" {
		t.Skip("HYPE_THEME_REPOSITORY is not set")
	}
	themeID := os.Getenv("HYPE_THEME_ID")
	if themeID == "" {
		t.Fatal("HYPE_THEME_ID is not set")
	}

	resolved, sourceDir, cleanup, err := resolveRegistryThemeSource(Theme{
		ID:         themeID,
		Repository: repository,
	}, "")
	if err != nil {
		t.Fatal(err)
	}
	defer cleanup()

	if resolved.ID != themeID {
		t.Fatalf("resolved ID = %q, want %q", resolved.ID, themeID)
	}
	if _, err := os.Stat(filepath.Join(sourceDir, "theme.json")); err != nil {
		t.Fatalf("resolved source does not contain theme.json: %v", err)
	}
	if resolved.Repository != repository {
		t.Fatalf("resolved repository = %q, want %q", resolved.Repository, repository)
	}
}

func TestInstallRegistryThemeReportsProgress(t *testing.T) {
	sourceDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(sourceDir, "theme.json"), []byte(`{"id":"progressTest","name":"Progress Test","version":"1.0.0"}`), 0o644); err != nil {
		t.Fatal(err)
	}

	manager := &Manager{fs: afero.NewOsFs(), themesDir: t.TempDir()}
	var stages []string
	err := manager.InstallRegistryThemeWithProgress(Theme{
		ID:      "progressTest",
		Name:    "Progress Test",
		Version: "1.0.0",
	}, sourceDir, func(stage, _ string) {
		stages = append(stages, stage)
	})
	if err != nil {
		t.Fatal(err)
	}

	for _, expected := range []string{"downloading", "installing", "wallpapers", "desktop", "remote-assets", "extracting", "finishing"} {
		found := false
		for _, stage := range stages {
			if stage == expected {
				found = true
				break
			}
		}
		if !found {
			t.Fatalf("progress stages %v do not contain %q", stages, expected)
		}
	}
}
