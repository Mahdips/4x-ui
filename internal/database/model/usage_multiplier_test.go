package model

import "testing"

func TestNormalizeUsageMultiplier(t *testing.T) {
	cases := []struct {
		name string
		in   float64
		want float64
	}{
		{"zero means real usage", 0, 1},
		{"negative means real usage", -2, 1},
		{"one stays one", 1, 1},
		{"above one passes through", 2.5, 2.5},
		{"below one passes through", 0.5, 0.5},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := NormalizeUsageMultiplier(tc.in)
			if got != tc.want {
				t.Fatalf("NormalizeUsageMultiplier(%v) = %v, want %v", tc.in, got, tc.want)
			}
		})
	}
}

func TestApplyUsageMultiplier(t *testing.T) {
	t.Run("multiplier of one is a passthrough", func(t *testing.T) {
		ib := &Inbound{UsageMultiplier: 1}
		up, down := ib.ApplyUsageMultiplier(1000, 2000)
		if up != 1000 || down != 2000 {
			t.Fatalf("passthrough = (%d,%d), want (1000,2000)", up, down)
		}
	})

	t.Run("zero multiplier falls back to real usage", func(t *testing.T) {
		ib := &Inbound{UsageMultiplier: 0}
		up, down := ib.ApplyUsageMultiplier(1000, 2000)
		if up != 1000 || down != 2000 {
			t.Fatalf("zero multiplier = (%d,%d), want (1000,2000)", up, down)
		}
	})

	t.Run("double multiplier doubles both directions", func(t *testing.T) {
		ib := &Inbound{UsageMultiplier: 2}
		up, down := ib.ApplyUsageMultiplier(1000, 2000)
		if up != 2000 || down != 4000 {
			t.Fatalf("x2 = (%d,%d), want (2000,4000)", up, down)
		}
	})

	t.Run("half multiplier rounds to nearest byte", func(t *testing.T) {
		ib := &Inbound{UsageMultiplier: 0.5}
		up, down := ib.ApplyUsageMultiplier(1001, 1003)
		if up != 501 || down != 502 {
			t.Fatalf("x0.5 of (1001,1003) = (%d,%d), want (501,502)", up, down)
		}
	})

	t.Run("negative bytes clamp to zero", func(t *testing.T) {
		ib := &Inbound{UsageMultiplier: 2}
		up, down := ib.ApplyUsageMultiplier(-100, 0)
		if up != 0 || down != 0 {
			t.Fatalf("clamped = (%d,%d), want (0,0)", up, down)
		}
	})
}

func TestIsAdmin(t *testing.T) {
	t.Run("admin role is admin", func(t *testing.T) {
		if !(&User{Id: 2, Role: UserRoleAdmin}).IsAdmin() {
			t.Fatal("role=admin must be a full admin")
		}
	})
	t.Run("limited role is not admin", func(t *testing.T) {
		if (&User{Id: 2, Role: UserRoleLimited}).IsAdmin() {
			t.Fatal("role=limited must not be a full admin")
		}
	})
	t.Run("empty role is not admin", func(t *testing.T) {
		if (&User{Id: 2, Role: ""}).IsAdmin() {
			t.Fatal("an empty role must not be a full admin")
		}
	})
	t.Run("the first user is the owner regardless of role", func(t *testing.T) {
		if !(&User{Id: 1, Role: UserRoleLimited}).IsAdmin() {
			t.Fatal("user id 1 is the owner and must stay a full admin")
		}
	})
}
