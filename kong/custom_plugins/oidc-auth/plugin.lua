local OidcHandler = require "kong.plugins.oidc-auth.handler"
local OidcSchema = require "kong.plugins.oidc-auth.schema"

-- Define the plugin
local OidcPlugin = {
  PRIORITY = 1000,
  VERSION = "1.0.0",
  PRIORITY = OidcHandler.PRIORITY,
  VERSION = OidcHandler.VERSION,
  SCHEMA = OidcSchema,
}

-- Return the plugin object
return OidcPlugin 