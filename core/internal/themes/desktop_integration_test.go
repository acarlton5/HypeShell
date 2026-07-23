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
