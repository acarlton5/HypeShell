package wayland

import (
	"testing"

	wlclient "github.com/acarlton5/HypeShell/core/pkg/go-wayland/wayland/client"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type recordingCTMManager struct {
	matrices    [][9]float64
	commitCount int
}

func (m *recordingCTMManager) SetCtmForOutput(_ *wlclient.Output, mat0, mat1, mat2, mat3, mat4, mat5, mat6, mat7, mat8 float64) error {
	m.matrices = append(m.matrices, [9]float64{mat0, mat1, mat2, mat3, mat4, mat5, mat6, mat7, mat8})
	return nil
}

func (m *recordingCTMManager) Commit() error {
	m.commitCount++
	return nil
}

func (m *recordingCTMManager) Destroy() error {
	return nil
}

func (m *recordingCTMManager) IsZombie() bool {
	return false
}

func TestColorTemperatureMatrix(t *testing.T) {
	identity := colorTemperatureMatrix(6500, 1)
	assert.Equal(t, identityColorMatrix(), identity)

	warm := colorTemperatureMatrix(2500, 1)
	assert.Equal(t, 1.0, warm[0])
	assert.Less(t, warm[4], warm[0])
	assert.Less(t, warm[8], warm[4])
	for _, index := range []int{1, 2, 3, 5, 6, 7} {
		assert.Zero(t, warm[index])
	}

	dimmed := colorTemperatureMatrix(2500, 0.5)
	for _, index := range []int{0, 4, 8} {
		assert.InDelta(t, warm[index]*0.5, dimmed[index], 0.000001)
	}
}

func TestIdentityColorMatrix(t *testing.T) {
	assert.Equal(t, [9]float64{
		1, 0, 0,
		0, 1, 0,
		0, 0, 1,
	}, identityColorMatrix())
}

func TestCTMResetAppliesIdentityToEveryOutput(t *testing.T) {
	manager := &recordingCTMManager{}
	backend := &hyprlandCTMBackend{
		manager: manager,
		outputs: map[uint32]*wlclient.Output{
			1: {},
			2: {},
		},
	}

	require.NoError(t, backend.Reset())
	assert.Equal(t, 2, len(manager.matrices))
	assert.Equal(t, identityColorMatrix(), manager.matrices[0])
	assert.Equal(t, identityColorMatrix(), manager.matrices[1])
	assert.Equal(t, 1, manager.commitCount)
}
