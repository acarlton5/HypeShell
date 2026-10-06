package wayland

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestColorTemperatureMatrix(t *testing.T) {
	identity := colorTemperatureMatrix(6500, 1)
	assert.Equal(t, [9]float64{1, 0, 0, 0, 1, 0, 0, 0, 1}, identity)

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
