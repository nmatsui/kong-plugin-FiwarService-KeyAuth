local typedefs = require "kong.db.schema.typedefs"


local PLUGIN_NAME = "fiwareservice-keyauth"


local schema = {
  name = PLUGIN_NAME,
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { auth_header = typedefs.header_name {
              required = true,
              default = "authorization" },
          },
          { fiwareservice_header = typedefs.header_name {
              required = true,
              default = "Fiware-Service" }
          },
          { hide_credentials = {
              type = "boolean",
              required = true,
              default = false },
          },
        },
      },
    },
  },
}

return schema
