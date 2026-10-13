package model

// NormalizeUsageMultiplier maps a stored multiplier to its effective value: 0
// and negative values mean "real usage" (1), matching how the form omits the
// field. Values below one bill less, above one bill more.
func NormalizeUsageMultiplier(m float64) float64 {
	if m <= 0 {
		return 1
	}
	return m
}

// EffectiveUsageMultiplier returns the multiplier actually applied to traffic
// on this inbound.
func (i *Inbound) EffectiveUsageMultiplier() float64 {
	return NormalizeUsageMultiplier(i.UsageMultiplier)
}

// ApplyUsageMultiplier scales real up/down bytes by this inbound's multiplier.
// The result is rounded to whole bytes and clamped at 0.
func (i *Inbound) ApplyUsageMultiplier(up, down int64) (int64, int64) {
	m := i.EffectiveUsageMultiplier()
	if m == 1 {
		return up, down
	}
	return scaleBytes(up, m), scaleBytes(down, m)
}

func scaleBytes(b int64, m float64) int64 {
	if b <= 0 {
		return 0
	}
	scaled := float64(b) * m
	if scaled <= 0 {
		return 0
	}
	return int64(scaled + 0.5)
}
