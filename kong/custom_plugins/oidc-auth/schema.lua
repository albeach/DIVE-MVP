local typedefs = require "kong.db.schema.typedefs"

return {
  name = "oidc-auth",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { enabled = { type = "boolean", default = true } },
          
          -- Client credentials
          { client_id = { type = "string", required = true } },
          { client_secret = { type = "string", required = true } },
          
          -- Discovery and endpoints
          { discovery = { type = "string", required = true } },
          { introspection_endpoint = { type = "string" } },
          { introspection_endpoint_auth_method = { type = "string", default = "client_secret_basic" } },
          { token_endpoint_auth_method = { type = "string", default = "client_secret_basic" } },
          { disable_userinfo_endpoint = { type = "boolean", default = false } },
          
          -- Behavior options
          { bearer_only = { type = "boolean", default = false } },
          { realm = { type = "string", default = "kong" } },
          { unauth_action = { type = "string", default = "auth", one_of = { "auth", "deny", "pass" } } },
          { pass_credentials = { type = "boolean", default = true } },
          { pass_userinfo = { type = "boolean", default = false } },
          { force_reauthorize = { type = "boolean", default = false } },
          
          -- URI paths
          { redirect_uri_path = { type = "string", default = "/callback" } },
          { logout_path = { type = "string", default = "/logout" } },
          { redirect_after_logout_uri = { type = "string" } },
          { redirect_uri = { type = "string" } },
          { post_logout_redirect_uri = { type = "string" } },
          { recovery_page_path = { type = "string" } },
          
          -- Session configuration
          { session_secret = { type = "string" } },
          { session_name = { type = "string", default = "oidc_session" } },
          { session_lifetime = { type = "number", default = 3600 } },
          { session_storage = { type = "string", default = "cookie", one_of = { "cookie", "redis" } } },
          { session_rolling_expiration = { type = "boolean", default = true } },
          
          -- Cookie options
          { cookie_secure = { type = "boolean", default = true } },
          { cookie_httponly = { type = "boolean", default = true } },
          { cookie_domain = { type = "string" } },
          { cookie_samesite = { type = "string", default = "Lax", one_of = { "Strict", "Lax", "None" } } },
          
          -- SSL options
          { ssl_verify = { type = "boolean", default = false } },
          
          -- Token handling
          { scope = { type = "string", default = "openid" } },
          { response_type = { type = "string", default = "code" } },
          { revoke_tokens_on_logout = { type = "boolean", default = true } },
          
          -- Filters
          { filters = { type = "array", elements = { type = "string" }, default = {} } },
        },
      },
    },
  },
} 