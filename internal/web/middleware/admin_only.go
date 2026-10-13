package middleware

import (
	"net/http"

	"github.com/mhsanaei/3x-ui/v3/internal/logger"
	"github.com/mhsanaei/3x-ui/v3/internal/web/session"

	"github.com/gin-gonic/gin"
)

// AdminOnly rejects requests from a limited admin (a user whose Role is not
// "admin"). Session-login users and admin-scoped API tokens pass through; the
// shared node-sync and monitor token scopes are enforced separately by the API
// controller's own allowlists.
func AdminOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		if session.IsAdmin(c) {
			c.Next()
			return
		}
		user := session.GetLoginUser(c)
		if user != nil {
			logger.Warningf("limited admin %q attempted a restricted endpoint: %s %s", user.Username, c.Request.Method, c.Request.URL.Path)
		}
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
			"success": false,
			"msg":     "this action requires a full admin account",
		})
	}
}
