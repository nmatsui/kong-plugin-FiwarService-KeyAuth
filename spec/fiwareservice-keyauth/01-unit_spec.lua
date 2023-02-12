local PLUGIN_NAME = "fiwareservice-keyauth"


-- helper function to validate data against a schema
local validate do
  local validate_entity = require("spec.helpers").validate_plugin_config_schema
  local plugin_schema = require("kong.plugins."..PLUGIN_NAME..".schema")

  function validate(data)
    return validate_entity(data, plugin_schema)
  end
end


describe(PLUGIN_NAME .. ": (schema)", function()

  it("acceps no parameter", function()
    local ok, err = validate({})
    assert.is_nil(err)
    assert.is_same({
      auth_header = "authorization",
      fiwareservice_header = "Fiware-Service",
      hide_credentials = false
    }, ok.config)
  end)

  it("acceps customization of 'auth_header' parameter", function()
    local ok, err = validate({
      auth_header = "Test-auth-header",
    })
    assert.is_nil(err)
    assert.is_same({
      auth_header = "Test-auth-header",
      fiwareservice_header = "Fiware-Service",
      hide_credentials = false
    }, ok.config)
  end)

  it("acceps customization of 'fiwareservice_header' parameter", function()
    local ok, err = validate({
      fiwareservice_header = "Test-fiwareservice-header",
    })
    assert.is_nil(err)
    assert.is_same({
      auth_header = "authorization",
      fiwareservice_header = "Test-fiwareservice-header",
      hide_credentials = false
    }, ok.config)
  end)

  it("acceps customization of 'hide_credentials' parameter", function()
    local ok, err = validate({
      hide_credentials = true,
    })
    assert.is_nil(err)
    assert.is_same({
      auth_header = "authorization",
      fiwareservice_header = "Fiware-Service",
      hide_credentials = true
    }, ok.config)
  end)

  it("accepts customization of all parameters", function()
    local ok, err = validate({
      auth_header = "Test-auth-header",
      fiwareservice_header = "Test-fiwareservice-header",
      hide_credentials = true,
    })
    assert.is_nil(err)
    assert.is_same({
      auth_header = "Test-auth-header",
      fiwareservice_header = "Test-fiwareservice-header",
      hide_credentials = true,
    }, ok.config)
  end)

end)
