-- Patched version of lua-resty-openidc to work with newer resty.session
-- This file contains fixes for the session:start() method calls

local require = require

local cjson   = require "cjson"
local http    = require "resty.http"
local string  = string
local ipairs  = ipairs
local pairs   = pairs
local type    = type
local ngx     = ngx
local b64     = ngx.encode_base64
local unb64   = ngx.decode_base64

local openidc = {
  _VERSION = "1.7.6"
}
openidc.__index = openidc

-- session object patch for compatibility with newer resty.session
local function ensure_session_started(session)
  -- Check if session has start method
  if type(session.start) == "function" then
    -- Old API - call start directly
    session:start()
  else
    -- New API - session is already started by open
    -- No need to do anything
  end
  return session
end

-- set value in server-wide cache if available
local function openidc_cache_set(type, key, value, exp)
  local dict = ngx.shared[type]
  if dict and (exp > 0) then
    local success, err, forcible = dict:set(key, value, exp)
    ngx.log(ngx.DEBUG, "cache set: success=", success, " err=", err, " forcible=", forcible)
  end
end

-- get value from server-wide cache if available
local function openidc_cache_get(type, key)
  local dict = ngx.shared[type]
  local value
  if dict then
    value = dict:get(key)
    if value then ngx.log(ngx.DEBUG, "cache hit: type=", type, " key=", key) end
  end
  return value
end

-- validate the contents of and id_token
local function openidc_validate_id_token(opts, id_token, nonce)

  -- check issuer
  if opts.discovery.iss ~= id_token.iss then
    ngx.log(ngx.ERR, "issuer \"", id_token.iss, "\" in id_token is not equal to the issuer from the discovery document \"", opts.discovery.iss, "\"")
    return false
  end

  -- check nonce
  if nonce and nonce ~= id_token.nonce then
    ngx.log(ngx.ERR, "nonce \"", id_token.nonce, "\" in id_token is not equal to the nonce that was sent in the request \"", nonce, "\"")
    return false
  end

  -- check issued-at timestamp
  if not id_token.iat then
    ngx.log(ngx.ERR, "no \"iat\" claim found in id_token")
    return false
  end

  local slack=opts.iat_slack and opts.iat_slack or 120
  if id_token.iat > (ngx.time() + slack) then
    ngx.log(ngx.ERR, "id_token not yet valid: id_token.iat=", id_token.iat, ", ngx.time()=", ngx.time(), ", slack=", slack)
    return false
  end

  -- check expiry timestamp
  if not id_token.exp then
    ngx.log(ngx.ERR, "no \"exp\" claim found in id_token")
    return false
  end

  if (id_token.exp + slack) < ngx.time() then
    ngx.log(ngx.ERR, "token expired: id_token.exp=", id_token.exp, ", ngx.time()=", ngx.time())
    return false
  end

  -- check audience (array or string)
  if not id_token.aud then
    ngx.log(ngx.ERR, "no \"aud\" claim found in id_token")
    return false
  end

  if (type(id_token.aud) == "table") then
    for _, value in pairs(id_token.aud) do
      if value == opts.client_id then
        return true
      end
    end
    ngx.log(ngx.ERR, "no match found token audience array: client_id=", opts.client_id )
    return false
  elseif (type(id_token.aud) == "string") then
    if id_token.aud ~= opts.client_id then
      ngx.log(ngx.ERR, "token audience does not match: id_token.aud=", id_token.aud, ", client_id=", opts.client_id )
      return false
    end
  end
  return true
end

-- assemble the redirect_uri
local function openidc_get_redirect_uri(opts)
  -- If a redirect_uri is explicitly configured, use it
  if opts.redirect_uri then
    return opts.redirect_uri
  end
  
  -- Otherwise, generate it from the server name
  local scheme = opts.redirect_uri_scheme or ngx.req.get_headers()["X-Forwarded-Proto"] or ngx.var.scheme
  if not ngx.var.server_name then
    -- if we are behind a reverse proxy, we might have a X-Forwarded-Host header
    -- that would give better information
    ngx.log(ngx.ERR, "no variable 'server_name' found for server name. Check your nginx configuration.")
    return nil
  end
  local host = ngx.var.server_name
  if ngx.var.server_port and ngx.var.server_port ~= 80 and ngx.var.server_port ~= 443 then
    host = host .. ":" .. ngx.var.server_port
  end
  return scheme .. "://" .. host .. opts.redirect_uri_path
end

-- perform base64url decoding
local function openidc_base64_url_decode(input)
  local reminder = #input % 4
  if reminder > 0 then
    local padlen = 4 - reminder
    input = input .. string.rep('=', padlen)
  end
  input = input:gsub('-','+'):gsub('_','/')
  return unb64(input)
end

-- perform base64url encoding
local function openidc_base64_url_encode(input)
  input = b64(input)
  return input:gsub('+','-'):gsub('/','_'):gsub('=','')
end

-- send the browser of to the OP's authorization endpoint
local function openidc_authorize(opts, session, target_url, prompt)
  local resty_random = require "resty.random"
  local resty_string = require "resty.string"

  -- generate state and nonce
  local state = resty_string.to_hex(resty_random.bytes(16))
  local nonce = resty_string.to_hex(resty_random.bytes(16))

  -- assemble the parameters to the authentication request
  local params = {
    client_id=opts.client_id,
    response_type="code",
    scope=opts.scope and opts.scope or "openid email profile",
    redirect_uri=openidc_get_redirect_uri(opts),
    state=state,
    nonce=nonce
  }

  if prompt then
    params.prompt = prompt
  end

  if opts.display then
    params.display = opts.display
  end
  
  -- merge any provided extra parameters
  if opts.authorization_params then
    for k,v in pairs(opts.authorization_params) do params[k] = v end
  end

  -- store state in the session
  ensure_session_started(session)
  session.data.original_url = target_url
  session.data.state = state
  session.data.nonce = nonce
  session.data.last_authenticated = ngx.time()
  session:save()

  -- redirect to the /authorization endpoint
  return ngx.redirect(opts.discovery.authorization_endpoint.."?"..ngx.encode_args(params))
end

-- parse the JSON result from a call to the OP
local function openidc_parse_json_response(response)
  local err
  local res

  -- check the response from the OP
  if response.status ~= 200 then
    err = "response indicates failure, status="..response.status..", body="..response.body
  else
    -- decode the response and extract the JSON object
    res = cjson.decode(response.body)

    if not res then
      err = "JSON decoding failed"
    end
  end

  return res, err
end

-- make a call to the token endpoint
local function openidc_call_token_endpoint(opts, endpoint, body, auth)
  local headers = {
      ["Content-Type"] = "application/x-www-form-urlencoded"
  }
  
  if auth then
    if auth == "client_secret_basic" then
      headers.Authorization = "Basic "..b64( opts.client_id..":"..opts.client_secret)
      ngx.log(ngx.DEBUG,"client_secret_basic: authorization header '"..headers.Authorization.."'")
    end
    if auth == "client_secret_post" then
      body.client_id=opts.client_id
      body.client_secret=opts.client_secret
      ngx.log(ngx.DEBUG, "client_secret_post: client_id and client_secret being sent in POST body")
    end
  end

  ngx.log(ngx.DEBUG, "request body for token endpoint call: ", ngx.encode_args(body))
  
  local httpc = http.new()
  local res, err = httpc:request_uri(endpoint, {
    method = "POST",
    body = ngx.encode_args(body),
    headers = headers,
    ssl_verify = (opts.ssl_verify ~= "no")
  })
  if not res then
    err = "accessing token endpoint ("..endpoint..") failed: "..err
    ngx.log(ngx.ERR, err)
    return nil, err
  end

  ngx.log(ngx.DEBUG, "token endpoint response: ", res.body)

  return openidc_parse_json_response(res);
end

-- make a call to the userinfo endpoint
local function openidc_call_userinfo_endpoint(opts, access_token)
  if not opts.discovery.userinfo_endpoint then
    ngx.log(ngx.DEBUG, "no userinfo endpoint supplied")
    return nil, nil
  end

  local httpc = http.new()
  local res, err = httpc:request_uri(opts.discovery.userinfo_endpoint, {
    headers = {
      ["Authorization"] = "Bearer "..access_token,
    },
    ssl_verify = (opts.ssl_verify ~= "no")
  })
  if not res then
    err = "accessing userinfo endpoint ("..opts.discovery.userinfo_endpoint..") failed: "..err
    ngx.log(ngx.ERR, err)
    return nil, err
  end

  ngx.log(ngx.DEBUG, "userinfo response: ", res.body)

  -- parse the response from the user info endpoint
  return openidc_parse_json_response(res)
end

-- handle a "code" authorization response from the OP
local function openidc_authorization_response(opts, session)
  local args = ngx.req.get_uri_args()
  local err

  if not args.code or not args.state then
    err = "unhandled request to the redirect_uri: "..ngx.var.request_uri
    ngx.log(ngx.ERR, err)
    return nil, err, session.data.original_url
  end

  -- check that the state returned in the response against the session; prevents CSRF
  if args.state ~= session.data.state then
    err = "state from argument: "..(args.state and args.state or "nil").." does not match state restored from session: "..(session.data.state and session.data.state or "nil")
    ngx.log(ngx.ERR, err)
    return nil, err, session.data.original_url
  end

  -- check the iss if returned from the OP
  if args.iss and args.iss ~= opts.discovery.iss then
    err = "iss from argument: "..args.iss.." does not match expected issuer: "..opts.discovery.iss
    ngx.log(ngx.ERR, err)
    return nil, err, session.data.original_url
  end

  -- check the client_id if returned from the OP
  if args.client_id and args.client_id ~= opts.client_id then
    err = "client_id from argument: "..args.client_id.." does not match expected client_id: "..opts.client_id
    ngx.log(ngx.ERR, err)
    return nil, err, session.data.original_url
  end

  -- assemble the parameters to the token endpoint
  local body = {
    grant_type="authorization_code",
    code=args.code,
    redirect_uri=openidc_get_redirect_uri(opts),
  }

  local current_time = ngx.time()
  -- make the call to the token endpoint
  local json, err = openidc_call_token_endpoint(opts, opts.discovery.token_endpoint, body, opts.token_endpoint_auth_method)
  if err then
    return nil, err, session.data.original_url
  end

  -- process the token endpoint response with the id_token and access_token
  local enc_hdr, enc_pay, enc_sign = string.match(json.id_token, '^(.+)%.(.+)%.(.+)$')
  local jwt = openidc_base64_url_decode(enc_pay)
  local id_token = cjson.decode(jwt)

  -- validate the id_token contents
  if openidc_validate_id_token(opts, id_token, session.data.nonce) == false then
    err = "id_token validation failed"
    return nil, err, session.data.original_url
  end

  -- call the user info endpoint
  -- TODO: should this error be checked?
  local user, err = openidc_call_userinfo_endpoint(opts, json.access_token)

  ensure_session_started(session)
  -- mark this sessions as authenticated
  session.data.authenticated = true
  -- clear state and nonce to protect against potential misuse
  session.data.nonce = nil
  session.data.state = nil
  if user then
    session.data.user = user
  end

  if json.refresh_token ~= nil then
    session.data.refresh_token = json.refresh_token
  end

  if json.access_token ~= nil then
    session.data.access_token = json.access_token
    session.data.access_token_expiration = current_time + json.expires_in
    if json.id_token ~= nil then
      -- correlation between access_token and id_token
      session.data.id_token = json.id_token
    end
  end

  session:save()

  -- redirect to the URL that was accessed originally
  return session.data.original_url, nil, session
end

-- get the Discovery metadata from the specified URL
local function openidc_discover(url, ssl_verify)
  ngx.log(ngx.DEBUG, "In openidc_discover - URL is "..url)
	
  local json, err
  local v = openidc_cache_get("discovery", url)
  if not v then

    ngx.log(ngx.DEBUG, "Discovery data not in cache. Making call to discovery endpoint")
    -- make the call to the discovery endpoint
    local httpc = http.new()
    local res, error = httpc:request_uri(url, {
      ssl_verify = (ssl_verify ~= "no")
    })
    if not res then
      err = "accessing discovery url ("..url..") failed: "..error
      ngx.log(ngx.ERR, err)
    else
      ngx.log(ngx.DEBUG, "Response data: "..res.body)
      json, err = openidc_parse_json_response(res)
      if json then
        openidc_cache_set("discovery", url, cjson.encode(json), 24 * 60 * 60)
      else
        err = "could not decode JSON from Discovery data" .. (err and (": " .. err) or '')
        ngx.log(ngx.ERR, err)
      end
    end

  else
    json = cjson.decode(v)
  end

  return json, err
end

-- main routine for OpenID Connect user authentication
function openidc.authenticate(opts, target_url, unauth_action, session_opts)
  local err

  -- Ensure we have a valid discovery document before proceeding
  if not opts.discovery_loaded then
    local discovery, err = openidc.discover(opts)
    if err then
      ngx.log(ngx.ERR, "Failed to discover OpenID Connect provider: " .. err)
      return nil, err
    end
    
    -- Log successful discovery
    ngx.log(ngx.DEBUG, "Successfully loaded discovery document")
    
    -- Ensure the discovery document has the required endpoints
    if not discovery.authorization_endpoint then
      err = "Discovery document does not contain authorization_endpoint"
      ngx.log(ngx.ERR, err)
      return nil, err
    end
  end

  local session = require("resty.session").open(session_opts)

  target_url = target_url or ngx.var.request_uri

  local access_token

  -- see if this is a request to the redirect_uri i.e. an authorization response
  local path = ngx.var.request_uri:match("(.-)%?") or ngx.var.request_uri
  if path == opts.redirect_uri_path then
    local target_url, err = openidc_authorization_response(opts, session)
    if err then
      ngx.log(ngx.ERR, "authorization response handling failed: ", err)
      return nil, err, target_url
    end
    ngx.log(ngx.DEBUG, "authorization response redirect to: ", target_url)
    return ngx.redirect(target_url)
  end

  -- get the token from the session
  access_token = session.data.access_token

  -- if we have no access token, then redirect to the authorization endpoint
  if not access_token then
    if unauth_action == "pass" then
      return
      -- leave unathenticated request as is
    end
    if unauth_action == "deny" then
      ngx.header["WWW-Authenticate"] = 'Bearer realm="'..opts.realm..'"'
      ngx.status = 401
      ngx.say('Unauthorized')
      ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
    return openidc_authorize(opts, session, target_url)
  end

  -- validate the token
  return openidc_bearer_jwt_verify(opts, access_token)
end

-- get a valid access_token (eventually refreshing the token)
local function openidc_access_token(opts, session, try_to_renew)

  local err
  local access_token
  local expires_in
  local refresh_token

  -- get the token from the session
  access_token = session.data.access_token
  expires_in = session.data.access_token_expiration
  refresh_token = session.data.refresh_token

  if access_token and refresh_token and try_to_renew then
    if expires_in < ngx.time() then
      ngx.log(ngx.DEBUG, "access_token expired. try to refresh with refresh_token")
      local body = {
        grant_type="refresh_token",
        refresh_token=refresh_token,
        scope=opts.scope and opts.scope or "openid email profile"
      }
      local json, err = openidc_call_token_endpoint(opts, opts.discovery.token_endpoint, body, opts.token_endpoint_auth_method)
      if err then
        ngx.log(ngx.ERR, "failed to refresh access token: ", err)
        return nil, err
      end
      ngx.log(ngx.DEBUG, "access_token refreshed: ", json.access_token, " updated refresh_token: ", json.refresh_token)

      ensure_session_started(session)
      session.data.access_token = json.access_token
      session.data.access_token_expiration = ngx.time() + json.expires_in
      if json.refresh_token then
        session.data.refresh_token = json.refresh_token
      end
      session:save()
      
      access_token = json.access_token
    end
  end

  return access_token, err
end

-- get a valid access_token (eventually refreshing the token)
function openidc.access_token(opts, session_opts)

  local session = require("resty.session").open(session_opts)

  return openidc_access_token(opts, session, true)

end


-- main routine for OAuth 2.0 token introspection
function openidc.introspect(opts)

  -- get the access token from the request
  local access_token = ngx.var.http_authorization
  if access_token then
    local divider = access_token:find(' ')
    if divider then
      access_token = access_token:sub(divider+1)
    end
  end

  if access_token == nil then
    ngx.header["WWW-Authenticate"] = 'Bearer realm="'..opts.realm..'"'
    ngx.status = 401
    ngx.say('Unauthorized')
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end

  -- see if we've previously cached the introspection result for this access token
  local json
  local v = openidc_cache_get("introspection", access_token)
  if not v then

    -- assemble the parameters to the introspection (token) endpoint
    local token_param_name = opts.introspection_token_param_name and opts.introspection_token_param_name or "token"

    local body = {}

    body [token_param_name] = access_token

    if opts.client_id then
      body.client_id=opts.client_id
    end
    if opts.client_secret then
      body.client_secret=opts.client_secret
    end

    -- merge any provided extra parameters
    if opts.introspection_params then
      for k,v in pairs(opts.introspection_params) do body[k] = v end
    end

    -- call the introspection endpoint
    json = openidc_call_token_endpoint(opts, opts.introspection_endpoint, body, nil)
    
    -- cache the results
    if json and json.active then
      local expiry_claim = opts.expiry_claim or "exp"
      if json[expiry_claim] then
        local ttl = json[expiry_claim]
        openidc_cache_set("introspection", access_token, cjson.encode(json), ttl)
      end
    else
      -- in case of failure, we can't save the introspection to the cache.
    end

  else
    json = cjson.decode(v)
  end

  return json

end

-- main routine for OAuth 2.0 JWT token validation
function openidc.bearer_jwt_verify(opts, access_token)

  local err
  local json

  -- Load the discovery document if it's not already loaded
  if not opts.discovery_loaded then
    local discovery, discovery_err = openidc.discover(opts)
    if discovery_err then
      ngx.log(ngx.ERR, "failed to discover OpenID Connect provider: ", discovery_err)
      return nil, discovery_err
    end
    opts.discovery = discovery
    opts.discovery_loaded = true
  end

  -- see if we've previously cached the validation result for this access token
  local v = openidc_cache_get("introspection", access_token)
  if not v then
    
    -- do the verification first time
    local jwt = require "resty.jwt"
    json = jwt:verify(opts.secret, access_token)

    if json and json.verified == true then
      json = json.payload
      -- cache the results
      openidc_cache_set("introspection", access_token, cjson.encode(json), json.exp - ngx.time())
    else 
      err = "invalid token: ".. json.reason
    end
    
  else
    -- decode from the cache
    json = cjson.decode(v)
  end
  
  -- check the token expiry
  if json then
    if json.exp and json.exp < ngx.time() then
      ngx.log(ngx.ERR, "token expired: json.exp=", json.exp, ", ngx.time()=", ngx.time())
      err = "JWT expired"
    end
  end
  
  return json, err
end

function openidc.get_discovery_doc(opts)
  local err
  local v

  if opts.discovery_doc and type(opts.discovery_doc) == "string" then
    v = openidc_cache_get("discovery", opts.discovery_doc)
  end

  if not v then
    if opts.discovery_doc and type(opts.discovery_doc) == "string" then
      v = opts.discovery_doc
    else
      v, err = openidc_discover(opts.discovery, opts.ssl_verify)
      if err then
        return nil, err
      end
      v = cjson.encode(v)
    end
    if opts.discovery_doc and type(opts.discovery_doc) == "string" then
      openidc_cache_set("discovery", opts.discovery_doc, v, 24 * 60 * 60)
    end
  end
  return cjson.decode(v)
end

-- main routine for OpenID Connect discovery
function openidc.discover(opts)
  local err
  local v

  -- Check for discovery URL in either discovery or discovery_document_url
  local discovery_url = opts.discovery_document_url or opts.discovery
  if not discovery_url then
    return nil, "no discovery URL provided in options"
  end

  local discovery
  if opts.discovery and type(opts.discovery) == "table" then
    -- If discovery is already a table, use it directly
    discovery = opts.discovery
  else
    -- make the call to the discovery endpoint
    local httpc = http.new()
    local res, error = httpc:request_uri(discovery_url, {
      ssl_verify = (opts.ssl_verify ~= "no")
    })
    if not res then
      err = "accessing discovery url (" .. discovery_url .. "): " .. error
      ngx.log(ngx.ERR, err)
      return nil, err
    end

    if res.status ~= 200 then
      err = "accessing discovery url (" .. discovery_url .. ") failed: " .. res.status
      ngx.log(ngx.ERR, err)
      return nil, err
    end

    -- Parse the JSON response and validate discovery data
    discovery, err = cjson.decode(res.body)
    if err then
      err = "could not decode discovery document JSON from " .. discovery_url .. ": " .. err
      ngx.log(ngx.ERR, err)
      return nil, err
    end

    -- Validate required fields in discovery document
    if not discovery.issuer then
      err = "discovery document JSON from " .. discovery_url .. " does not contain issuer"
      ngx.log(ngx.ERR, err)
      return nil, err
    end

    -- Log discovery document for debugging
    ngx.log(ngx.DEBUG, "Discovery document loaded: " .. cjson.encode(discovery))
  end

  -- Ensure we have the required endpoints
  if not discovery.authorization_endpoint then
    err = "discovery document JSON from " .. discovery_url .. " does not contain authorization_endpoint"
    ngx.log(ngx.ERR, err)
    return nil, err
  end

  if not discovery.token_endpoint then
    err = "discovery document JSON from " .. discovery_url .. " does not contain token_endpoint"
    ngx.log(ngx.ERR, err)
    return nil, err
  end

  -- Store discovery document in opts
  opts.discovery = discovery
  opts.discovery_loaded = true

  return discovery, nil
end

return openidc 