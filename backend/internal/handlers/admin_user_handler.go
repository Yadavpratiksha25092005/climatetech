package handlers

import (
	"errors"
	"net/http"
	"strconv"
	"time"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// errLastActiveAdmin is a sentinel used to bail out of the transactions in
// UpdateUserRole/UpdateUserStatus with a specific 409, distinguishing "the
// last-admin guard rejected this" from an actual DB error.
var errLastActiveAdmin = errors.New("would remove the last active admin")

type AdminUserHandler struct{}

func NewAdminUserHandler() *AdminUserHandler {
	return &AdminUserHandler{}
}

const adminUsersPageSize = 20

type adminUserRow struct {
	ID        uuid.UUID   `json:"id"`
	Name      string      `json:"name"`
	Email     string      `json:"email"`
	Role      models.Role `json:"role"`
	IsActive  bool        `json:"is_active"`
	CreatedAt time.Time   `json:"created_at"`
}

// ListUsers returns a paginated list of every user for admin management —
// exactly 2 queries regardless of page size: one page of rows, one count.
// GET /api/v1/admin/users?page=1
func (h *AdminUserHandler) ListUsers(c *gin.Context) {
	page, err := strconv.Atoi(c.DefaultQuery("page", "1"))
	if err != nil || page <= 0 {
		page = 1
	}
	offset := (page - 1) * adminUsersPageSize

	var users []adminUserRow
	if err := database.DB.Model(&models.User{}).
		Select("id", "name", "email", "role", "is_active", "created_at").
		Order("created_at DESC").
		Limit(adminUsersPageSize).
		Offset(offset).
		Scan(&users).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch users", err)
		return
	}

	var total int64
	if err := database.DB.Model(&models.User{}).Count(&total).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count users", err)
		return
	}

	utils.Success(c, http.StatusOK, "users fetched", gin.H{
		"users":     users,
		"page":      page,
		"page_size": adminUsersPageSize,
		"total":     total,
	})
}

var validRoles = map[string]bool{
	string(models.RoleUser):         true,
	string(models.RoleOrganization): true,
	string(models.RoleAdmin):        true,
}

// wouldRemoveLastActiveAdmin reports whether targetID is currently the
// system's only active admin — used to block an action (demotion or
// deactivation) that would leave zero active admins able to manage the
// platform. This isn't scoped to "self" specifically: demoting/deactivating
// the last *other* active admin would strand the system exactly the same
// way, so the same check guards both cases.
//
// Must be called with tx inside the same transaction that performs the
// follow-up update: it row-locks every active admin (FOR UPDATE), so two
// concurrent requests demoting/deactivating two different admins can't both
// read "not last" and both succeed — the second one blocks until the first
// commits, then sees the now-updated count. Postgres doesn't allow FOR
// UPDATE on an aggregate, so this locks and fetches the rows rather than
// locking a COUNT(*).
func wouldRemoveLastActiveAdmin(tx *gorm.DB, targetID uuid.UUID) (bool, error) {
	var target models.User
	if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
		Select("id", "role", "is_active").First(&target, "id = ?", targetID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			// A nonexistent user can't be the one whose demotion/deactivation
			// zeroes out the active-admin count — let the caller's own
			// RowsAffected==0 check surface the real 404 instead of this
			// lookup masking it as a 500.
			return false, nil
		}
		return false, err
	}
	if target.Role != models.RoleAdmin || !target.IsActive {
		// Not currently a counted active admin, so acting on it can't be
		// what zeroes out the active-admin count.
		return false, nil
	}

	var activeAdmins []models.User
	if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
		Select("id").
		Where("role = ? AND is_active = ?", models.RoleAdmin, true).
		Find(&activeAdmins).Error; err != nil {
		return false, err
	}
	return len(activeAdmins) <= 1, nil
}

type updateRoleRequest struct {
	Role string `json:"role" binding:"required"`
}

// UpdateUserRole changes a user's role.
// PUT /api/v1/admin/users/:id/role
func (h *AdminUserHandler) UpdateUserRole(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid user id", err)
		return
	}

	var req updateRoleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}
	if !validRoles[req.Role] {
		utils.Fail(c, http.StatusBadRequest, "invalid role", nil)
		return
	}

	var rowsAffected int64
	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		if req.Role != string(models.RoleAdmin) {
			isLast, err := wouldRemoveLastActiveAdmin(tx, id)
			if err != nil {
				return err
			}
			if isLast {
				return errLastActiveAdmin
			}
		}

		result := tx.Model(&models.User{}).Where("id = ?", id).Update("role", req.Role)
		if result.Error != nil {
			return result.Error
		}
		rowsAffected = result.RowsAffected
		return nil
	})
	if txErr != nil {
		if errors.Is(txErr, errLastActiveAdmin) {
			utils.Fail(c, http.StatusConflict, "cannot demote the last active admin", nil)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to update role", txErr)
		return
	}
	if rowsAffected == 0 {
		utils.Fail(c, http.StatusNotFound, "user not found", nil)
		return
	}

	utils.Success(c, http.StatusOK, "role updated", nil)
}

// updateStatusRequest uses *bool (not bool) so an explicit {"is_active":
// false} payload can be told apart from the field being omitted entirely —
// binding:"required" on a bool would incorrectly reject `false` itself,
// since false is bool's zero value.
type updateStatusRequest struct {
	IsActive *bool `json:"is_active" binding:"required"`
}

// UpdateUserStatus activates/deactivates a user account.
// PUT /api/v1/admin/users/:id/status
func (h *AdminUserHandler) UpdateUserStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid user id", err)
		return
	}

	var req updateStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	var rowsAffected int64
	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		if !*req.IsActive {
			isLast, err := wouldRemoveLastActiveAdmin(tx, id)
			if err != nil {
				return err
			}
			if isLast {
				return errLastActiveAdmin
			}
		}

		result := tx.Model(&models.User{}).Where("id = ?", id).Update("is_active", *req.IsActive)
		if result.Error != nil {
			return result.Error
		}
		rowsAffected = result.RowsAffected
		return nil
	})
	if txErr != nil {
		if errors.Is(txErr, errLastActiveAdmin) {
			utils.Fail(c, http.StatusConflict, "cannot deactivate the last active admin", nil)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to update status", txErr)
		return
	}
	if rowsAffected == 0 {
		utils.Fail(c, http.StatusNotFound, "user not found", nil)
		return
	}

	utils.Success(c, http.StatusOK, "status updated", nil)
}
