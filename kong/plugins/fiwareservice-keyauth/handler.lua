local constants = require "kong.constants"
local kong_meta = require "kong.meta"

local kong = kong
local type = type
local pcall = pcall
local error = error

local HEADERS_CONSUMER_ID           = constants.HEADERS.CONSUMER_ID
local HEADERS_CONSUMER_CUSTOM_ID    = constants.HEADERS.CONSUMER_CUSTOM_ID
local HEADERS_CONSUMER_USERNAME     = constants.HEADERS.CONSUMER_USERNAME
local HEADERS_CREDENTIAL_IDENTIFIER = constants.HEADERS.CREDENTIAL_IDENTIFIER
local HEADERS_ANONYMOUS             = constants.HEADERS.ANONYMOUS

local plugin = {
  PRIORITY = 1000, -- set the plugin priority, which determines plugin execution order
  VERSION = kong_meta.version, -- version in X.Y.Z format. Check hybrid-mode compatibility requirements.
}

local _realm = 'Key realm="' .. _KONG._NAME .. '"'

local ERR_NO_API_KEY             = { status = 401, message = "No API key found in request" }
local ERR_INVALID_AUTH_CRED      = { status = 401, message = "Invalid authentication credentials" }
local ERR_INVALID_PLUGIN_CONF    = { status = 500, message = "Invalid plugin configuration" }
local ERR_UNEXPECTED             = { status = 500, message = "An unexpected error occurred" }


local function load_credential(key)

  local cred, err = kong.db.keyauth_credentials:select_by_key(key)
  if not cred then
    return nil, err
  end

  if cred.ttl == 0 then
    return nil
  end

  return cred, nil, cred.ttl
end


local function get_credential(headers, auth_header_name)

  local key = headers[auth_header_name]

  if not key or type(key) ~= "string" or key == "" then
    kong.response.set_header("WWW-Authenticate", _realm)
    error(ERR_NO_API_KEY)
  end

  local cache = kong.cache
  local credential_cache_key = kong.db.keyauth_credentials:cache_key(key)
  local credential, err, hit_level = cache:get(credential_cache_key, { resurrect_ttl = 0.001 }, load_credential, key)
  if err then
    kong.log.err(err)
    error(ERR_UNEXPECTED)
  end

  if not credential or hit_level == 4 then
    error(ERR_INVALID_AUTH_CRED)
  end

  return credential
end


local function get_consumer(credential)

  local cache = kong.cache
  local consumer_cache_key = kong.db.consumers:cache_key(credential.consumer.id)
  local consumer, err = cache:get(consumer_cache_key, nil, kong.client.load_consumer, credential.consumer.id)

  if err then
    kong.log.err(err)
    error(ERR_UNEXPECTED)
  end

  if not consumer then
    kong.log.err(err)
    error(ERR_INVALID_PLUGIN_CONF)
  end

  return consumer
end


local function rewrite_headers(plugin_conf, credential, consumer)


  local set_header = kong.service.request.set_header
  local clear_header = kong.service.request.clear_header

  kong.client.authenticate(consumer, credential)

  clear_header(HEADERS_ANONYMOUS)

  if plugin_conf.hide_credentials then
    kong.service.request.clear_header(plugin_conf.auth_header)
  end

  if consumer.id then
    set_header(HEADERS_CONSUMER_ID, consumer.id)
  else
    clear_header(HEADERS_CONSUMER_ID)
  end

  if consumer.custom_id then
    set_header(HEADERS_CONSUMER_CUSTOM_ID, consumer.custom_id)
  else
    clear_header(HEADERS_CONSUMER_CUSTOM_ID)
  end

  if  consumer.username then
    set_header(HEADERS_CONSUMER_USERNAME, consumer.username)
  else
    clear_header(HEADERS_CONSUMER_USERNAME)
  end

  if credential.id then
    set_header(HEADERS_CREDENTIAL_IDENTIFIER, credential.id)
  else
    clear_header(HEADERS_CREDENTIAL_IDENTIFIER)
  end
end


local function do_authentication(plugin_conf)

  local headers = kong.request.get_headers()

  local credential = get_credential(headers, plugin_conf.auth_header)
  local consumer = get_consumer(credential)

  rewrite_headers(plugin_conf, credential, consumer)
end


function plugin:access(plugin_conf)

  local ok, err = pcall(do_authentication, plugin_conf)

  if not ok then
    return kong.response.error(err.status, err.message, err.headers)
  end
end


return plugin
