local http = require "resty.http"
local openidc = require "resty.openidc"
local cjson = require "cjson"
local pl_stringx = require "pl.stringx"

local kong = kong
local ngx = ngx
local string = string

-- Implementation for Kong 3.x OIDC plugin
local OidcHandler = {
  PRIORITY = 1000,
  VERSION = "1.0.0",
}

-- This function is executed when the plugin is loaded
function OidcHandler:init_worker()
  kong.log.debug("Initializing OIDC plugin")
end

-- Build an OIDC config from plugin config
local function make_oidc_config(conf)
  local session_opts = {
    logout_path = conf.logout_path,
    name = conf.session_name or "oidc_session",
    storage = conf.session_storage,
    rolling_expiration = conf.session_rolling_expiration,
    lifetime = conf.session_lifetime,
    cookie_secure = conf.cookie_secure,
    cookie_samesite = conf.cookie_samesite,
    cookie_domain = conf.cookie_domain,
    cookie_httponly = conf.cookie_httponly,
  }

  -- For encrypted sessions when shared secret is defined
  if conf.session_secret then
    session_opts.secret = conf.session_secret
  end

  local oidc_config = {
    client_id = conf.client_id,
    client_secret = conf.client_secret,
    discovery = conf.discovery,
    introspection_endpoint = conf.introspection_endpoint,
    introspection_endpoint_auth_method = conf.introspection_endpoint_auth_method,
    bearer_only = conf.bearer_only,
    realm = conf.realm,
    redirect_uri_path = conf.redirect_uri_path,
    scope = conf.scope,
    response_type = conf.response_type,
    ssl_verify = conf.ssl_verify,
    token_endpoint_auth_method = conf.token_endpoint_auth_method,
    recovery_page_path = conf.recovery_page_path,
    logout_path = conf.logout_path,
    redirect_after_logout_uri = conf.redirect_after_logout_uri,
    filters = conf.filters,
    unauth_action = conf.unauth_action,
    renew_access_token_on_expiry = true,
    redirect_uri = conf.redirect_uri,
    post_logout_redirect_uri = conf.post_logout_redirect_uri,
    session = session_opts,
    access_token_in_authorization_header = true,
    disable_userinfo_endpoint = conf.disable_userinfo_endpoint,
    userinfo_header_name = "X-USERINFO",
    access_token_header_name = "Authorization",
    force_reauthorize = conf.force_reauthorize,
    revoke_tokens_on_logout = conf.revoke_tokens_on_logout,
  }

  return oidc_config
end

-- Handle response to client after OIDC processing
local function handle_response(status_code, body, headers)
  ngx.status = status_code
  if headers then
    for k, v in pairs(headers) do
      ngx.header[k] = v
    end
  end
  if body then
    ngx.say(body)
  end
  return ngx.exit(status_code)
end

-- Function to set user info headers
local function set_headers(conf, userinfo)
  if userinfo.access_token then
    kong.service.request.set_header("Authorization", "Bearer " .. userinfo.access_token)
  end
  
  if userinfo.id_token then
    kong.service.request.set_header("X-ID-Token", userinfo.id_token)
  end
  
  if userinfo.id_token_claims then
    local user_id = userinfo.id_token_claims.sub
    if user_id then
      kong.service.request.set_header("X-User-ID", user_id)
    end
    
    if userinfo.id_token_claims.email then
      kong.service.request.set_header("X-User-Email", userinfo.id_token_claims.email)
    end
    
    if userinfo.id_token_claims.name then
      kong.service.request.set_header("X-User-Name", userinfo.id_token_claims.name)
    end
    
    -- Add preferred_username if available
    if userinfo.id_token_claims.preferred_username then
      kong.service.request.set_header("X-User-Username", userinfo.id_token_claims.preferred_username)
    end
    
    -- Add roles if available
    if userinfo.id_token_claims.realm_access and userinfo.id_token_claims.realm_access.roles then
      local roles = table.concat(userinfo.id_token_claims.realm_access.roles, ",")
      kong.service.request.set_header("X-User-Roles", roles)
    end
  end
  
  -- Set userinfo as a header
  if userinfo.user and conf.pass_userinfo then
    local userinfo_json = cjson.encode(userinfo.user)
    kong.service.request.set_header("X-Userinfo", ngx.encode_base64(userinfo_json))
  end
end

-- Main function executed during the access phase
function OidcHandler:access(conf)
  -- Skip the plugin if disabled
  if not conf.enabled then
    return
  end

  -- Generate OIDC config
  local oidc_config = make_oidc_config(conf)
  
  -- If bearer_only mode is enabled, just check the token
  if conf.bearer_only then
    -- Just check if the token is valid, don't redirect to login
    kong.log.debug("OIDC: Bearer only mode, checking token...")
    
    local res, err = openidc.bearer_jwt_verify(oidc_config)
    
    if err then
      kong.log.err("OIDC bearer verification failed: ", err)
      return handle_response(401, "Unauthorized", {["WWW-Authenticate"] = 'Bearer realm="' .. (conf.realm or "kong") .. '"'})
    end
    
    if res then
      kong.log.debug("OIDC bearer verification succeeded")
      set_headers(conf, res)
    end
    
    return
  end
  
  -- Handle full OIDC flow
  local res, err = openidc.authenticate(oidc_config)
  
  if err then
    kong.log.err("OIDC authentication failed: ", err)
    return handle_response(500, "Authentication failed: " .. err)
  end
  
  -- Set headers for authentication info
  if res and conf.pass_credentials then
    set_headers(conf, res)
  end
end

-- Return the plugin handler
return OidcHandler 