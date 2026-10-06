package wayland

import (
	"fmt"
	"sync"
	"sync/atomic"

	"github.com/acarlton5/HypeShell/core/internal/proto/hyprland_ctm_control"
	wlclient "github.com/acarlton5/HypeShell/core/pkg/go-wayland/wayland/client"
)

type hyprlandCTMBackend struct {
	registry *wlclient.Registry
	manager  ctmControlManager

	outputsMutex sync.RWMutex
	outputs      map[uint32]*wlclient.Output
	blocked      atomic.Bool
}

type ctmControlManager interface {
	SetCtmForOutput(output *wlclient.Output, mat0, mat1, mat2, mat3, mat4, mat5, mat6, mat7, mat8 float64) error
	Commit() error
	Destroy() error
	IsZombie() bool
}

func newHyprlandCTMBackend(display wlclient.WaylandDisplay) (*hyprlandCTMBackend, error) {
	registry, err := display.GetRegistry()
	if err != nil {
		return nil, fmt.Errorf("get CTM registry: %w", err)
	}

	backend := &hyprlandCTMBackend{
		registry: registry,
		outputs:  make(map[uint32]*wlclient.Output),
	}

	registry.SetGlobalHandler(func(event wlclient.RegistryGlobalEvent) {
		switch event.Interface {
		case "hyprland_ctm_control_manager_v1":
			manager := hyprland_ctm_control.NewHyprlandCtmControlManagerV1(display.Context())
			version := event.Version
			if version > 2 {
				version = 2
			}
			if err := registry.Bind(event.Name, event.Interface, version, manager); err != nil {
				return
			}
			manager.SetBlockedHandler(func(_ hyprland_ctm_control.HyprlandCtmControlManagerV1BlockedEvent) {
				backend.blocked.Store(true)
			})
			backend.manager = manager
		case "wl_output":
			output := wlclient.NewOutput(display.Context())
			version := event.Version
			if version > 3 {
				version = 3
			}
			if err := registry.Bind(event.Name, event.Interface, version, output); err != nil {
				return
			}
			backend.outputsMutex.Lock()
			backend.outputs[event.Name] = output
			backend.outputsMutex.Unlock()
		}
	})

	registry.SetGlobalRemoveHandler(func(event wlclient.RegistryGlobalRemoveEvent) {
		backend.outputsMutex.Lock()
		output := backend.outputs[event.Name]
		delete(backend.outputs, event.Name)
		backend.outputsMutex.Unlock()
		if output != nil && !output.IsZombie() {
			_ = output.Release()
		}
	})

	if err := display.Roundtrip(); err != nil {
		backend.Close()
		return nil, fmt.Errorf("CTM registry roundtrip: %w", err)
	}
	if err := display.Roundtrip(); err != nil {
		backend.Close()
		return nil, fmt.Errorf("CTM event roundtrip: %w", err)
	}
	if backend.manager == nil {
		backend.Close()
		return nil, fmt.Errorf("hyprland CTM protocol unavailable")
	}
	if backend.blocked.Load() {
		backend.Close()
		return nil, fmt.Errorf("hyprland CTM protocol is controlled by another client")
	}

	backend.outputsMutex.RLock()
	hasOutputs := len(backend.outputs) > 0
	backend.outputsMutex.RUnlock()
	if !hasOutputs {
		backend.Close()
		return nil, fmt.Errorf("hyprland CTM protocol has no outputs")
	}

	return backend, nil
}

func (b *hyprlandCTMBackend) Apply(temp int, gamma float64) error {
	if b.blocked.Load() {
		return fmt.Errorf("hyprland CTM protocol is controlled by another client")
	}

	return b.applyMatrix(colorTemperatureMatrix(temp, gamma))
}

func (b *hyprlandCTMBackend) applyMatrix(matrix [9]float64) error {
	b.outputsMutex.RLock()
	outputs := make([]*wlclient.Output, 0, len(b.outputs))
	for _, output := range b.outputs {
		outputs = append(outputs, output)
	}
	b.outputsMutex.RUnlock()

	for _, output := range outputs {
		if output == nil || output.IsZombie() {
			continue
		}
		if err := b.manager.SetCtmForOutput(output,
			matrix[0], matrix[1], matrix[2],
			matrix[3], matrix[4], matrix[5],
			matrix[6], matrix[7], matrix[8],
		); err != nil {
			return fmt.Errorf("set output CTM: %w", err)
		}
	}

	if err := b.manager.Commit(); err != nil {
		return fmt.Errorf("commit output CTM: %w", err)
	}
	return nil
}

func (b *hyprlandCTMBackend) Reset() error {
	if b == nil || b.manager == nil || b.manager.IsZombie() {
		return nil
	}
	if err := b.applyMatrix(identityColorMatrix()); err != nil {
		return fmt.Errorf("reset output CTM: %w", err)
	}
	return nil
}

func (b *hyprlandCTMBackend) Close() {
	if b == nil {
		return
	}
	if b.manager != nil && !b.manager.IsZombie() {
		_ = b.manager.Destroy()
	}
	b.outputsMutex.Lock()
	for id, output := range b.outputs {
		if output != nil && !output.IsZombie() {
			_ = output.Release()
		}
		delete(b.outputs, id)
	}
	b.outputsMutex.Unlock()
	if b.registry != nil && !b.registry.IsZombie() {
		_ = b.registry.Destroy()
	}
}

func colorTemperatureMatrix(temp int, gamma float64) [9]float64 {
	whitepoint := calcWhitepoint(temp)
	return [9]float64{
		whitepoint.r * gamma, 0, 0,
		0, whitepoint.g * gamma, 0,
		0, 0, whitepoint.b * gamma,
	}
}

func identityColorMatrix() [9]float64 {
	return [9]float64{
		1, 0, 0,
		0, 1, 0,
		0, 0, 1,
	}
}
