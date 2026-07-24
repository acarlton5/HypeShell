package themes

import (
	"fmt"
	"net"

	"github.com/acarlton5/HypeShell/core/internal/server/models"
	"github.com/acarlton5/HypeShell/core/internal/themes"
)

type installProgressResult struct {
	Progress bool   `json:"progress"`
	ThemeID  string `json:"themeId"`
	Stage    string `json:"stage"`
	Detail   string `json:"detail"`
}

func HandleInstall(conn net.Conn, req models.Request) {
	idOrName, ok := models.Get[string](req, "name")
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'name' parameter")
		return
	}
	respondProgress := func(stage, detail string) {
		models.Respond(conn, req.ID, installProgressResult{
			Progress: true,
			ThemeID:  idOrName,
			Stage:    stage,
			Detail:   detail,
		})
	}

	respondProgress("registry", "Checking the theme registry")
	registry, err := themes.NewRegistry()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to create registry: %v", err))
		return
	}

	themeList, err := registry.List()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to list themes: %v", err))
		return
	}

	theme := themes.FindByIDOrName(idOrName, themeList)
	if theme == nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("theme not found: %s", idOrName))
		return
	}

	manager, err := themes.NewManager()
	if err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to create manager: %v", err))
		return
	}

	registryThemeDir := registry.GetThemeDir(theme.SourceDir)
	if err := manager.InstallRegistryThemeWithProgress(*theme, registryThemeDir, respondProgress); err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to install theme: %v", err))
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{
		Success: true,
		Message: fmt.Sprintf("theme installed: %s", theme.Name),
	})
}
