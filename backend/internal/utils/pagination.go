package utils

import (
	"strconv"

	"github.com/gin-gonic/gin"
)

// ParsePageLimit reads and clamps the standard `page`/`limit` query
// parameters, centralizing a pattern that was previously reimplemented with
// slightly different caps in every list handler. page always comes back
// >= 1; limit always comes back in [1, maxLimit]. Returns page, limit, and
// the computed offset for a LIMIT/OFFSET query.
func ParsePageLimit(c *gin.Context, defaultLimit, maxLimit int) (page, limit, offset int) {
	page, err := strconv.Atoi(c.DefaultQuery("page", "1"))
	if err != nil || page <= 0 {
		page = 1
	}

	limit, err = strconv.Atoi(c.DefaultQuery("limit", strconv.Itoa(defaultLimit)))
	if err != nil || limit <= 0 || limit > maxLimit {
		limit = defaultLimit
	}

	offset = (page - 1) * limit
	return page, limit, offset
}
