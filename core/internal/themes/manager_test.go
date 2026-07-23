package themes

import "testing"

func TestSafeArchiveEntries(t *testing.T) {
	tests := []struct {
		name string
		list string
		want bool
	}{
		{name: "normal tree", list: "MacOS/\nMacOS/index.theme\nMacOS/cursors/default\n", want: true},
		{name: "parent traversal", list: "MacOS/\n../outside\n", want: false},
		{name: "nested traversal", list: "MacOS/../../outside\n", want: false},
		{name: "absolute path", list: "/tmp/outside\n", want: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := safeArchiveEntries(tt.list); got != tt.want {
				t.Fatalf("safeArchiveEntries() = %v, want %v", got, tt.want)
			}
		})
	}
}
