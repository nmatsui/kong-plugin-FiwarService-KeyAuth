local helpers   = require "spec.helpers"
local cjson     = require "cjson"
local meta      = require "kong.meta"
local constants = require "kong.constants"


local PLUGIN_NAME = "fiwareservice-keyauth"


local HOST_1        = "test1.example.com"
local HOST_2        = "test2.example.com"
local TENANT_1_NAME = "Test-tenant1-name"
local TENANT_1_KEY  = "Test-tenant1-credential"
local TENANT_2_NAME = "Test-tenant2-name"
local TENANT_2_KEY  = "Test-tenant2-credential"


for _, strategy in helpers.all_strategies() do if strategy ~= "cassandra" then
  describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()
    local client
    local consumer1
    local credential1
    local consumer2
    local credential2

    lazy_setup(function()

      local bp = helpers.get_db_utils(strategy == "off" and "postgres" or strategy, nil, { PLUGIN_NAME })

      local route1 = bp.routes:insert {
        hosts = { HOST_1 },
      }
      bp.plugins:insert {
        name = PLUGIN_NAME,
        route = { id = route1.id },
        config = {},
      }

      local route2 = bp.routes:insert {
        hosts = { HOST_2 },
      }
      bp.plugins:insert {
        name = PLUGIN_NAME,
        route = { id = route2.id },
        config = { hide_credentials = true },
      }

      consumer1 = bp.consumers:insert {
        username = TENANT_1_NAME,
      }
      credential1 = bp.keyauth_credentials:insert {
        key = TENANT_1_KEY,
        consumer = { id = consumer1.id },
      }

      consumer2 = bp.consumers:insert {
        username = TENANT_2_NAME,
      }
      credential2 = bp.keyauth_credentials:insert {
        key = TENANT_2_KEY,
        consumer = { id = consumer2.id },
      }

      -- start kong
      assert(helpers.start_kong({
        -- set the strategy
        database   = strategy,
        -- use the custom test template to create a local mock server
        nginx_conf = "spec/fixtures/custom_nginx.template",
        -- make sure our plugin gets loaded
        plugins = "bundled," .. PLUGIN_NAME,
        -- write & load declarative config, only if 'strategy=off'
        declarative_config = strategy == "off" and helpers.make_yaml_file() or nil,
      }))
    end)

    lazy_teardown(function()
      helpers.stop_kong(nil, true)
    end)

    before_each(function()
      client = helpers.proxy_client()
    end)

    after_each(function()
      if client then client:close() end
    end)


    describe("[success]", function()

      local function test_request_headers(tenant, res)
        local consumer, credential
        if tenant.name == TENANT_1_NAME then
          consumer = consumer1
          credential = credential1
        else
          consumer = consumer2
          credential = credential2
        end

        assert.request(res).has_no.header(constants.HEADERS.HEADERS_ANONIMOUS)
        local consumer_id_header_value = assert.request(res).has.header(constants.HEADERS.CONSUMER_ID)
        assert.is_equal(consumer.id, consumer_id_header_value)
        local consumer_custom_id_header_value = assert.request(res).has.header(constants.HEADERS.CONSUMER_CUSTOM_ID)
        assert.is_equal(consumer.custom_id, consumer_custom_id_header_value)
        local consumer_username_header_value = assert.request(res).has.header(constants.HEADERS.CONSUMER_USERNAME)
        assert.is_equal(consumer.username, consumer_username_header_value)
        local credential_id_header_value = assert.request(res).has.header(constants.HEADERS.CREDENTIAL_IDENTIFIER)
        assert.is_equal(credential.id, credential_id_header_value)
      end

      for _, method in pairs({ "GET", "POST", "PUT", "PATCH", "DELETE", "OPTION" }) do
        for _, tenant in pairs({
          { name = TENANT_1_NAME, key = TENANT_1_KEY },
          { name = TENANT_2_NAME, key = TENANT_2_KEY } }) do

          it("authenticates and authrizes when valid credential/tenant combination is given [" .. method .. "]", function()
            local res = assert(client:send {
              method = method,
              path = "/status/200",
              headers = {
                ["host"] = HOST_1,
                ["authorization"] = tenant.key,
                ["fiware-service"] = tenant.name,
              }
            })
            assert.response(res).has.status(200)
            local auth_header_value = assert.request(res).has.header("authorization")
            assert.is_equal(tenant.key, auth_header_value)
            local fiwareservice_header_value = assert.request(res).has.header("fiware-service")
            assert.is_equal(tenant.name, fiwareservice_header_value)
            test_request_headers(tenant, res)
          end)

          it("authenticates and authrizes even if 'hide_credentials' is set [" .. method .. "]", function()
            local res = assert(client:send {
              method = method,
              path = "/status/200",
              headers = {
                ["host"] = HOST_2,
                ["authorization"] = tenant.key,
                ["fiware-service"] = tenant.name,
              }
            })
            assert.response(res).has.status(200)
            assert.request(res).has_no.header("authorization")
            local fiwareservice_header_value = assert.request(res).has.header("fiware-service")
            assert.is_equal(tenant.name, fiwareservice_header_value)
            test_request_headers(tenant, res)
          end)

        end
      end
    end)


    describe("[unauthorized]", function()
      for _, method in pairs({ "GET", "POST", "PUT", "PATCH", "DELETE", "OPTION" }) do

        it("returns '401 Unauthorized' when no auth header exists [" .. method .. "]", function()
          local res = assert(client:send {
            method = method,
            path = "/status/200",
            headers = {
              ["host"] = HOST_1
            }
          })
          assert.response(res).has.status(401)
          assert.response(res).has.header("WWW-Authenticate")
          assert.is_same('Key realm="' .. meta._NAME .. '"', res.headers["WWW-Authenticate"])
          assert.is_same({ message = "No API key found in request" }, cjson.decode((res:read_body())))
        end)

        it("returns '401 Unauthorized' when the auth header is empty [" .. method .. "]", function()
          local res = assert(client:send {
            method = method,
            path = "/status/200",
            headers = {
              ["host"] = HOST_1,
              ["authorization"] = ""
            }
          })
          assert.response(res).has.status(401)
          assert.response(res).has.header("WWW-Authenticate")
          assert.is_same('Key realm="' .. meta._NAME .. '"', res.headers["WWW-Authenticate"])
          assert.is_same({ message = "No API key found in request" }, cjson.decode((res:read_body())))
        end)

        it("returns '401 Unauthorized' when the credential is not registerd [" .. method .. "]", function()
          local res = assert(client:send {
            method = method,
            path = "/status/200",
            headers = {
              ["host"] = HOST_1,
              ["authorization"] = "unregistered-credential",
            }
          })
          assert.response(res).has.status(401)
          assert.response(res).has_no.header("WWW-Authenticate")
          assert.is_same({ message = "Invalid authentication credentials" }, cjson.decode((res:read_body())))
        end)

        it("returns '401 Unauthorized' when only 'fiware-service' header exists [" .. method .. "]", function()
          local res = assert(client:send {
            method = method,
            path = "/status/200",
            headers = {
              ["host"] = HOST_1,
              ["fiware-service"] = TENANT_1_NAME,
            }
          })
          assert.response(res).has.status(401)
          assert.response(res).has.header("WWW-Authenticate")
          assert.is_same('Key realm="' .. meta._NAME .. '"', res.headers["WWW-Authenticate"])
          assert.is_same({ message = "No API key found in request" }, cjson.decode((res:read_body())))
        end)

      end
    end)


    describe("[forbidden]", function()
      for _, method in pairs({ "GET", "POST", "PUT", "PATCH", "DELETE", "OPTION" }) do

        it("returns '403 Forbidden' when no 'fiware-service' header exists [" .. method .. "]", function()
          local res = assert(client:send {
            method = method,
            path = "/status/200",
            headers = {
              ["host"] = HOST_1,
              ["authorization"] = TENANT_1_KEY,
            }
          })
          assert.response(res).has.status(403)
          assert.is_same({ message = "No Fiware-Service found in request" }, cjson.decode((res:read_body())))
        end)

        it("returns '403 Forbidden' when the 'fiware-service' header is empty [" .. method .. "]", function()
          local res = assert(client:send {
            method = method,
            path = "/status/200",
            headers = {
              ["host"] = HOST_1,
              ["authorization"] = TENANT_1_KEY,
              ["fiware-service"] = ""
            }
          })
          assert.response(res).has.status(403)
          assert.is_same({ message = "No Fiware-Service found in request" }, cjson.decode((res:read_body())))
        end)

        it("returns '403 Forbidden' when the tenant is not registerd [" .. method .. "]", function()
          local res = assert(client:send {
            method = method,
            path = "/status/200",
            headers = {
              ["host"] = HOST_1,
              ["authorization"] = TENANT_1_KEY,
              ["fiware-service"] = "unregistered-tenant",
            }
          })
          assert.response(res).has.status(403)
          assert.is_same({ message = "Invalid tenant" }, cjson.decode((res:read_body())))
        end)

        it("returns '403 Forbidden' when the tenant/credential combination is invalid [" .. method .. "]", function()
          local res = assert(client:send {
            method = method,
            path = "/status/200",
            headers = {
              ["host"] = HOST_1,
              ["authorization"] = TENANT_1_KEY,
              ["fiware-service"] = TENANT_2_NAME,
            }
          })
          assert.response(res).has.status(403)
          assert.is_same({ message = "Invalid tenant" }, cjson.decode((res:read_body())))
        end)

      end
    end)

  end)

end end
