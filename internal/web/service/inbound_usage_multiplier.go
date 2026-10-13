package service

import (
	"github.com/mhsanaei/3x-ui/v3/internal/database/model"
	"github.com/mhsanaei/3x-ui/v3/internal/xray"

	"gorm.io/gorm"
)

// scaleClientTrafficByEmail applies each inbound's UsageMultiplier to this poll's
// per-email deltas. Xray reports one total per email, so the email→inbound link is
// resolved through client_inbounds; when an email sits on several inbounds the one
// carrying the client's quota row wins, since that is the inbound the quota is
// billed against. A nil map means "apply raw traffic".
func (s *InboundService) scaleClientTrafficByEmail(tx *gorm.DB, traffics []*xray.ClientTraffic) (map[string]*xray.ClientTraffic, error) {
	if len(traffics) == 0 {
		return nil, nil
	}
	emails := make([]string, 0, len(traffics))
	seen := make(map[string]struct{}, len(traffics))
	for _, t := range traffics {
		if t == nil || t.Email == "" {
			continue
		}
		if _, ok := seen[t.Email]; ok {
			continue
		}
		seen[t.Email] = struct{}{}
		emails = append(emails, t.Email)
	}
	if len(emails) == 0 {
		return nil, nil
	}

	multiplierByEmail, err := s.usageMultiplierByEmails(tx, emails)
	if err != nil {
		return nil, err
	}
	if len(multiplierByEmail) == 0 {
		return nil, nil
	}

	out := make(map[string]*xray.ClientTraffic, len(multiplierByEmail))
	for _, t := range traffics {
		if t == nil || t.Email == "" || (t.Up == 0 && t.Down == 0) {
			continue
		}
		inbound, ok := multiplierByEmail[t.Email]
		if !ok {
			continue
		}
		up, down := inbound.ApplyUsageMultiplier(t.Up, t.Down)
		entry := out[t.Email]
		if entry == nil {
			entry = &xray.ClientTraffic{Email: t.Email}
			out[t.Email] = entry
		}
		entry.Up += up
		entry.Down += down
	}
	return out, nil
}

// usageMultiplierByEmails resolves, per email, the inbound whose multiplier
// applies to it. Only inbounds with a multiplier other than 1.00 are returned,
// so everything else keeps the raw delta (no map entry).
func (s *InboundService) usageMultiplierByEmails(tx *gorm.DB, emails []string) (map[string]*model.Inbound, error) {
	type row struct {
		Email           string  `gorm:"column:email"`
		InboundID       int     `gorm:"column:inbound_id"`
		UsageMultiplier float64 `gorm:"column:usage_multiplier"`
		Total           int64   `gorm:"column:total"`
	}
	var rows []row
	err := tx.Table("client_inbounds").
		Select(`clients.email AS email,
		        client_inbounds.inbound_id AS inbound_id,
		        inbounds.usage_multiplier AS usage_multiplier,
		        client_traffics.total AS total`).
		Joins("JOIN clients ON clients.id = client_inbounds.client_id").
		Joins("JOIN inbounds ON inbounds.id = client_inbounds.inbound_id").
		Joins("LEFT JOIN client_traffics ON client_traffics.email = clients.email").
		Where("clients.email IN ?", emails).
		Where("inbounds.node_id IS NULL").
		Where("inbounds.usage_multiplier IS NOT NULL AND inbounds.usage_multiplier <> 1").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}

	// One email may be attached to several multiplier-bearing inbounds; keep the
	// one holding the client's quota row, then fall back to the highest id.
	best := make(map[string]*row, len(rows))
	for i := range rows {
		r := &rows[i]
		cur, ok := best[r.Email]
		if !ok {
			best[r.Email] = r
			continue
		}
		if r.Total > cur.Total || (r.Total == cur.Total && r.InboundID > cur.InboundID) {
			best[r.Email] = r
		}
	}

	out := make(map[string]*model.Inbound, len(best))
	for email, r := range best {
		out[email] = &model.Inbound{Id: r.InboundID, UsageMultiplier: r.UsageMultiplier}
	}
	return out, nil
}
