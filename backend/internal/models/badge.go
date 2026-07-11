package models

// GetBadges returns every badge threshold a user's points have crossed, in
// ascending order (so higher badges appear after the ones they imply).
func GetBadges(points int) []string {
	badges := []string{}
	if points >= 50 {
		badges = append(badges, "Eco Starter")
	}
	if points >= 200 {
		badges = append(badges, "Eco Warrior")
	}
	if points >= 500 {
		badges = append(badges, "Green Champion")
	}
	if points >= 1000 {
		badges = append(badges, "Climate Hero")
	}
	return badges
}
