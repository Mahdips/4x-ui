package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/mhsanaei/3x-ui/v3/internal/database/model"
	"github.com/mhsanaei/3x-ui/v3/internal/web/session"

	"github.com/gin-contrib/sessions"
	"github.com/gin-contrib/sessions/cookie"
	"github.com/gin-gonic/gin"
)

func newTestEngine(t *testing.T) *gin.Engine {
	t.Helper()
	gin.SetMode(gin.TestMode)
	r := gin.New()
	store := cookie.NewStore([]byte("test-secret"))
	r.Use(sessions.Sessions("3x-ui", store))
	return r
}

// withUser stamps the account into the request context the same way API-token
// auth does. That path does not touch the database, so the guard can be tested
// without a live DB; the session middleware resolves it to the same user.
func withUser(user *model.User) gin.HandlerFunc {
	return func(c *gin.Context) {
		session.SetAPIAuthUser(c, user)
		c.Next()
	}
}

func doRequest(r *gin.Engine, path string) *httptest.ResponseRecorder {
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, path, nil))
	return w
}

func TestAdminOnlyAllowsFullAdmin(t *testing.T) {
	r := newTestEngine(t)
	r.GET("/guarded", withUser(&model.User{Id: 2, Role: model.UserRoleAdmin}), AdminOnly(), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"success": true})
	})

	w := doRequest(r, "/guarded")
	if w.Code != http.StatusOK {
		t.Fatalf("full admin got %d, want 200 (body %s)", w.Code, w.Body.String())
	}
}

func TestAdminOnlyRejectsLimitedAdmin(t *testing.T) {
	r := newTestEngine(t)
	r.GET("/guarded", withUser(&model.User{Id: 2, Role: model.UserRoleLimited}), AdminOnly(), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"success": true})
	})

	w := doRequest(r, "/guarded")
	if w.Code != http.StatusForbidden {
		t.Fatalf("limited admin got %d, want 403 (body %s)", w.Code, w.Body.String())
	}
}

func TestAdminOnlyRejectsAnonymous(t *testing.T) {
	r := newTestEngine(t)
	r.GET("/guarded", AdminOnly(), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"success": true})
	})

	w := doRequest(r, "/guarded")
	if w.Code != http.StatusForbidden {
		t.Fatalf("anonymous got %d, want 403", w.Code)
	}
}

// The first user is the owner: even if its stored role is blank (an upgraded
// database), the guard must let it through so the panel is never locked out.
func TestAdminOnlyAllowsTheFirstUser(t *testing.T) {
	r := newTestEngine(t)
	r.GET("/guarded", withUser(&model.User{Id: 1, Role: ""}), AdminOnly(), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"success": true})
	})

	w := doRequest(r, "/guarded")
	if w.Code != http.StatusOK {
		t.Fatalf("owner got %d, want 200", w.Code)
	}
}
