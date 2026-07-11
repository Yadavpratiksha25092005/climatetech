package handlers

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"climatetech-backend/internal/database"
	"climatetech-backend/internal/models"
	"climatetech-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// escapeLikePattern escapes LIKE/ILIKE wildcard characters in user-supplied
// search text before it's wrapped in "%...%" — without this, a literal "%"
// or "_" typed by the user silently behaves as a wildcard instead of the
// literal character they meant to search for.
func escapeLikePattern(s string) string {
	replacer := strings.NewReplacer(`\`, `\\`, "%", `\%`, "_", `\_`)
	return replacer.Replace(s)
}

type MarketplaceHandler struct{}

func NewMarketplaceHandler() *MarketplaceHandler {
	return &MarketplaceHandler{}
}

// ---------- Seller onboarding ----------

type applySellerRequest struct {
	ShopName      string   `json:"shop_name" binding:"required,max=150"`
	OwnerName     string   `json:"owner_name" binding:"required,max=150"`
	Address       string   `json:"address" binding:"required,max=500"`
	City          string   `json:"city" binding:"required,max=100"`
	ShopCategory  string   `json:"shop_category" binding:"required,max=50"`
	Phone         string   `json:"phone" binding:"required,max=20"`
	Description   string   `json:"description" binding:"omitempty,max=2000"`
	ShopPhotoURLs []string `json:"shop_photo_urls" binding:"omitempty,max=10,dive,url"`
}

// ApplySeller lets an authenticated user apply to become a marketplace
// seller. Only one profile per user is allowed — reapplying isn't supported
// via this endpoint once a profile (pending, approved, or rejected) exists.
// POST /api/v1/marketplace/seller/apply
func (h *MarketplaceHandler) ApplySeller(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	err := database.DB.Where("user_id = ?", userID).First(&models.Seller{}).Error
	if err == nil {
		utils.Fail(c, http.StatusConflict, "you already have a seller profile", nil)
		return
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		utils.Fail(c, http.StatusInternalServerError, "failed to check existing seller profile", err)
		return
	}

	var req applySellerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	seller := models.Seller{
		UserID:        userID,
		ShopName:      req.ShopName,
		OwnerName:     req.OwnerName,
		Address:       req.Address,
		City:          req.City,
		ShopCategory:  req.ShopCategory,
		Description:   req.Description,
		ShopPhotoURLs: models.StringArray(req.ShopPhotoURLs),
		Status:        models.SellerStatusPending,
	}

	// The seller profile and the contact phone number (stored on User, since
	// it's the same phone regardless of how many times a user applies) are
	// written together so a failure on either side can't leave one saved
	// without the other.
	txErr := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&seller).Error; err != nil {
			return err
		}
		if err := tx.Model(&models.User{}).Where("id = ?", userID).Update("phone", req.Phone).Error; err != nil {
			return err
		}
		return nil
	})
	if txErr != nil {
		// Another request may have created this user's seller profile
		// between the check above and this insert; sellers.user_id's unique
		// constraint is the real source of truth for that race, so its
		// violation is translated into the same 409 the pre-check gives in
		// the common case, instead of a 500.
		if utils.IsUniqueViolation(txErr) {
			utils.Fail(c, http.StatusConflict, "you already have a seller profile", nil)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to submit seller application", txErr)
		return
	}

	utils.Success(c, http.StatusCreated, "seller application submitted", seller)
}

// GetMySellerProfile returns the authenticated user's seller profile/status,
// or has_profile=false if they've never applied.
// GET /api/v1/marketplace/seller/me
func (h *MarketplaceHandler) GetMySellerProfile(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var seller models.Seller
	if err := database.DB.Where("user_id = ?", userID).First(&seller).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Success(c, http.StatusOK, "no seller profile", gin.H{"has_profile": false, "seller": nil})
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch seller profile", err)
		return
	}

	utils.Success(c, http.StatusOK, "seller profile fetched", gin.H{"has_profile": true, "seller": seller})
}

// ---------- Admin seller approval ----------

// ListSellersByStatus lists seller applications filtered by status (default
// "pending"). status=all returns every seller regardless of status.
// GET /api/v1/marketplace/admin/sellers?status=pending
func (h *MarketplaceHandler) ListSellersByStatus(c *gin.Context) {
	status := c.DefaultQuery("status", string(models.SellerStatusPending))
	page, limit, offset := utils.ParsePageLimit(c, 20, 100)

	// Built twice (once per query below) rather than reused, so Count's
	// internal Select doesn't carry over into the Find call — same pattern
	// as AdminUserHandler.ListUsers.
	countQuery := database.DB.Model(&models.Seller{})
	if status != "all" {
		countQuery = countQuery.Where("status = ?", status)
	}
	var total int64
	if err := countQuery.Count(&total).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count sellers", err)
		return
	}

	query := database.DB.Model(&models.Seller{})
	if status != "all" {
		query = query.Where("status = ?", status)
	}
	var sellers []models.Seller
	if err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&sellers).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch sellers", err)
		return
	}

	utils.Success(c, http.StatusOK, "sellers fetched", gin.H{
		"sellers": sellers,
		"page":    page,
		"limit":   limit,
		"total":   total,
	})
}

// ApproveSeller marks a seller application as approved.
// PUT /api/v1/marketplace/admin/sellers/:id/approve
func (h *MarketplaceHandler) ApproveSeller(c *gin.Context) {
	h.updateSellerStatus(c, models.SellerStatusApproved)
}

// RejectSeller marks a seller application as rejected.
// PUT /api/v1/marketplace/admin/sellers/:id/reject
func (h *MarketplaceHandler) RejectSeller(c *gin.Context) {
	h.updateSellerStatus(c, models.SellerStatusRejected)
}

func (h *MarketplaceHandler) updateSellerStatus(c *gin.Context, status models.SellerStatus) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid seller id", err)
		return
	}

	var seller models.Seller
	if err := database.DB.First(&seller, "id = ?", id).Error; err != nil {
		utils.Fail(c, http.StatusNotFound, "seller not found", err)
		return
	}

	seller.Status = status
	if err := database.DB.Save(&seller).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to update seller status", err)
		return
	}

	utils.Success(c, http.StatusOK, "seller status updated", seller)
}

// ---------- Listings ----------

type createListingRequest struct {
	Title       string   `json:"title" binding:"required,max=200"`
	Description string   `json:"description" binding:"omitempty,max=5000"`
	Price       float64  `json:"price" binding:"required,gt=0,lte=1000000000"`
	Category    string   `json:"category" binding:"required,max=50"`
	ImageURLs   []string `json:"image_urls" binding:"required,min=1,max=10,dive,required,url"`
	Condition   string   `json:"condition"`
	Location    string   `json:"location" binding:"omitempty,max=150"`
}

// CreateListing lets a user with an approved seller profile post a new listing.
// POST /api/v1/marketplace/listings
func (h *MarketplaceHandler) CreateListing(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var seller models.Seller
	if err := database.DB.Where("user_id = ? AND status = ?", userID, models.SellerStatusApproved).First(&seller).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusForbidden, "you need an approved seller profile to post listings", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to check seller profile", err)
		return
	}

	var req createListingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	condition := models.ConditionUsed
	if req.Condition == string(models.ConditionNew) {
		condition = models.ConditionNew
	}

	listing := models.Listing{
		SellerID:    seller.ID,
		Title:       req.Title,
		Description: req.Description,
		Price:       req.Price,
		Category:    req.Category,
		ImageURLs:   models.StringArray(req.ImageURLs),
		Condition:   condition,
		Location:    req.Location,
		IsActive:    true,
	}
	if err := database.DB.Create(&listing).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to create listing", err)
		return
	}

	utils.Success(c, http.StatusCreated, "listing created", listing)
}

type adminCreateListingRequest struct {
	SellerID    string   `json:"seller_id" binding:"required"`
	Title       string   `json:"title" binding:"required,max=200"`
	Description string   `json:"description" binding:"omitempty,max=5000"`
	Price       float64  `json:"price" binding:"required,gt=0,lte=1000000000"`
	Category    string   `json:"category" binding:"required,max=50"`
	ImageURLs   []string `json:"image_urls" binding:"required,min=1,max=10,dive,required,url"`
	Condition   string   `json:"condition"`
	Location    string   `json:"location" binding:"omitempty,max=150"`
}

// AdminCreateListing lets an admin create a listing directly on behalf of
// any seller (or the admin's own seller profile), bypassing the "seller
// must be approved" check that CreateListing enforces for normal sellers.
// POST /api/v1/marketplace/admin/listings
func (h *MarketplaceHandler) AdminCreateListing(c *gin.Context) {
	var req adminCreateListingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	sellerID, err := uuid.Parse(req.SellerID)
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid seller id", err)
		return
	}

	// There's no DB-level foreign key from listings to sellers, so this
	// check is what stops an admin from accidentally creating a listing
	// against a seller_id that doesn't exist.
	if err := database.DB.Select("id").First(&models.Seller{}, "id = ?", sellerID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "seller not found", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to check seller existence", err)
		return
	}

	condition := models.ConditionUsed
	if req.Condition == string(models.ConditionNew) {
		condition = models.ConditionNew
	}

	listing := models.Listing{
		SellerID:    sellerID,
		Title:       req.Title,
		Description: req.Description,
		Price:       req.Price,
		Category:    req.Category,
		ImageURLs:   models.StringArray(req.ImageURLs),
		Condition:   condition,
		Location:    req.Location,
		IsActive:    true,
	}
	if err := database.DB.Create(&listing).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to create listing", err)
		return
	}

	utils.Success(c, http.StatusCreated, "listing created", listing)
}

// listingWithSeller decorates a listing with the minimal seller info the
// browse/detail views need, without exposing the seller's full application.
type listingWithSeller struct {
	models.Listing
	ShopName string `json:"shop_name"`
	Verified bool   `json:"verified"`
}

// BrowseListings lists active listings with optional category/search filters.
// GET /api/v1/marketplace/listings?category=&search=&limit=20
func (h *MarketplaceHandler) BrowseListings(c *gin.Context) {
	limit, err := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if err != nil || limit <= 0 || limit > 100 {
		limit = 20
	}

	query := database.DB.Model(&models.Listing{}).Where("is_active = ?", true)
	if category := c.Query("category"); category != "" {
		query = query.Where("category = ?", category)
	}
	if search := c.Query("search"); search != "" {
		if len(search) > 200 {
			search = search[:200]
		}
		like := "%" + escapeLikePattern(search) + "%"
		query = query.Where("title ILIKE ? ESCAPE '\\' OR description ILIKE ? ESCAPE '\\'", like, like)
	}

	var listings []models.Listing
	if err := query.Order("created_at DESC").Limit(limit).Find(&listings).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch listings", err)
		return
	}

	results, err := h.attachSellerInfo(listings)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to load seller info", err)
		return
	}

	utils.Success(c, http.StatusOK, "listings fetched", results)
}

// attachSellerInfo batches a single query for every seller referenced across
// the given listings, so browsing N listings never costs N seller lookups.
func (h *MarketplaceHandler) attachSellerInfo(listings []models.Listing) ([]listingWithSeller, error) {
	results := make([]listingWithSeller, 0, len(listings))
	if len(listings) == 0 {
		return results, nil
	}

	sellerIDSet := make(map[uuid.UUID]struct{}, len(listings))
	for _, l := range listings {
		sellerIDSet[l.SellerID] = struct{}{}
	}
	sellerIDs := make([]uuid.UUID, 0, len(sellerIDSet))
	for id := range sellerIDSet {
		sellerIDs = append(sellerIDs, id)
	}

	var sellers []models.Seller
	if err := database.DB.Where("id IN ?", sellerIDs).Find(&sellers).Error; err != nil {
		return nil, err
	}
	sellerByID := make(map[uuid.UUID]models.Seller, len(sellers))
	for _, s := range sellers {
		sellerByID[s.ID] = s
	}

	for _, l := range listings {
		seller := sellerByID[l.SellerID]
		results = append(results, listingWithSeller{
			Listing:  l,
			ShopName: seller.ShopName,
			Verified: seller.Status == models.SellerStatusApproved,
		})
	}
	return results, nil
}

// GetListingDetail returns a single listing plus enough seller/contact info
// for the Call/WhatsApp actions (name, email, and phone — phone may be empty
// for sellers who applied before the phone field existed).
// GET /api/v1/marketplace/listings/:id
func (h *MarketplaceHandler) GetListingDetail(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid listing id", err)
		return
	}

	var listing models.Listing
	if err := database.DB.Where("is_active = ?", true).First(&listing, "id = ?", id).Error; err != nil {
		utils.Fail(c, http.StatusNotFound, "listing not found", err)
		return
	}

	var seller models.Seller
	if err := database.DB.First(&seller, "id = ?", listing.SellerID).Error; err != nil {
		// There's no DB-level foreign key from listings to sellers, so a
		// missing seller row here means an orphaned/inconsistent listing
		// rather than a transient failure — treated as "not found" from
		// the caller's perspective instead of a hard 500, since there's
		// nothing usable to return either way. A genuine DB error (not
		// simply "no such seller row") still surfaces as 500.
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusNotFound, "listing not found", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to load seller info", err)
		return
	}

	var user models.User
	if err := database.DB.Select("name", "email", "phone").First(&user, "id = ?", seller.UserID).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to load seller contact info", err)
		return
	}

	utils.Success(c, http.StatusOK, "listing fetched", gin.H{
		"listing": listing,
		"seller": gin.H{
			"shop_name":  seller.ShopName,
			"owner_name": seller.OwnerName,
			"city":       seller.City,
			"verified":   seller.Status == models.SellerStatusApproved,
		},
		"contact": gin.H{
			"name":  user.Name,
			"email": user.Email,
			"phone": user.Phone,
		},
	})
}

// GetMyListings returns the authenticated user's own listings, via their seller profile.
// GET /api/v1/marketplace/my-listings
func (h *MarketplaceHandler) GetMyListings(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var seller models.Seller
	if err := database.DB.Where("user_id = ?", userID).First(&seller).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Success(c, http.StatusOK, "no listings", []models.Listing{})
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to load seller profile", err)
		return
	}

	var listings []models.Listing
	if err := database.DB.Where("seller_id = ?", seller.ID).Order("created_at DESC").Find(&listings).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch your listings", err)
		return
	}

	utils.Success(c, http.StatusOK, "your listings fetched", listings)
}

// DeleteListing removes a listing, but only if it's owned by the current
// user's seller profile — scoping the delete query by seller_id means a
// mismatched id is indistinguishable from "not found" to the caller.
// DELETE /api/v1/marketplace/listings/:id
func (h *MarketplaceHandler) DeleteListing(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid listing id", err)
		return
	}

	var seller models.Seller
	if err := database.DB.Where("user_id = ?", userID).First(&seller).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.Fail(c, http.StatusForbidden, "you don't have a seller profile", err)
			return
		}
		utils.Fail(c, http.StatusInternalServerError, "failed to check seller profile", err)
		return
	}

	result := database.DB.Where("id = ? AND seller_id = ?", id, seller.ID).Delete(&models.Listing{})
	if result.Error != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to delete listing", result.Error)
		return
	}
	if result.RowsAffected == 0 {
		utils.Fail(c, http.StatusNotFound, "listing not found or not owned by you", nil)
		return
	}

	utils.Success(c, http.StatusOK, "listing deleted", nil)
}

// ---------- Admin listing moderation ----------

// ListAllListingsAdmin returns every listing (active or not, any seller)
// with seller info attached, for admin moderation. Reuses attachSellerInfo
// so this is still a batched 2-query lookup, not one seller query per listing.
// GET /api/v1/marketplace/admin/listings
func (h *MarketplaceHandler) ListAllListingsAdmin(c *gin.Context) {
	page, limit, offset := utils.ParsePageLimit(c, 20, 100)

	var total int64
	if err := database.DB.Model(&models.Listing{}).Count(&total).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to count listings", err)
		return
	}

	var listings []models.Listing
	if err := database.DB.Order("created_at DESC").Limit(limit).Offset(offset).Find(&listings).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to fetch listings", err)
		return
	}

	results, err := h.attachSellerInfo(listings)
	if err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to load seller info", err)
		return
	}

	utils.Success(c, http.StatusOK, "listings fetched", gin.H{
		"listings": results,
		"page":     page,
		"limit":    limit,
		"total":    total,
	})
}

// DeleteListingAdmin removes any listing regardless of ownership — admin
// moderation, separate from the owner-scoped DeleteListing above.
// DELETE /api/v1/marketplace/admin/listings/:id
func (h *MarketplaceHandler) DeleteListingAdmin(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid listing id", err)
		return
	}

	result := database.DB.Delete(&models.Listing{}, "id = ?", id)
	if result.Error != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to delete listing", result.Error)
		return
	}
	if result.RowsAffected == 0 {
		utils.Fail(c, http.StatusNotFound, "listing not found", nil)
		return
	}

	utils.Success(c, http.StatusOK, "listing deleted", nil)
}

// updateListingAdminRequest uses pointers throughout so only fields actually
// present in the request body get applied — omitted fields leave the
// existing column untouched instead of being zeroed out.
type updateListingAdminRequest struct {
	Title       *string  `json:"title" binding:"omitempty,max=200"`
	Description *string  `json:"description" binding:"omitempty,max=5000"`
	Price       *float64 `json:"price" binding:"omitempty,gt=0,lte=1000000000"`
	Category    *string  `json:"category" binding:"omitempty,max=50"`
	IsActive    *bool    `json:"is_active"`
}

// UpdateListingAdmin partially updates a listing — admin moderation
// (e.g. correcting a price/category or deactivating a listing), separate
// from the seller's own listing creation flow.
// PUT /api/v1/marketplace/admin/listings/:id
func (h *MarketplaceHandler) UpdateListingAdmin(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid listing id", err)
		return
	}

	var req updateListingAdminRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Fail(c, http.StatusBadRequest, "invalid request payload", err)
		return
	}

	var listing models.Listing
	if err := database.DB.First(&listing, "id = ?", id).Error; err != nil {
		utils.Fail(c, http.StatusNotFound, "listing not found", err)
		return
	}

	if req.Title != nil {
		listing.Title = *req.Title
	}
	if req.Description != nil {
		listing.Description = *req.Description
	}
	if req.Price != nil {
		listing.Price = *req.Price
	}
	if req.Category != nil {
		listing.Category = *req.Category
	}
	if req.IsActive != nil {
		listing.IsActive = *req.IsActive
	}

	if err := database.DB.Save(&listing).Error; err != nil {
		utils.Fail(c, http.StatusInternalServerError, "failed to update listing", err)
		return
	}

	utils.Success(c, http.StatusOK, "listing updated", listing)
}
