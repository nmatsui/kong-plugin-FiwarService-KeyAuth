[![Unix build](https://img.shields.io/github/workflow/status/Kong/kong-plugin/Test?label=Test&logo=linux)](https://github.com/Kong/kong-plugin/actions/workflows/test.yml)
[![Luacheck](https://github.com/Kong/kong-plugin/workflows/Lint/badge.svg)](https://github.com/Kong/kong-plugin/actions/workflows/lint.yml)

# Kong plugin Fiware-Service Key-Auth

This Kong plugin authenticates a HTTP client similar to the "key-auth" plugin by using auth header, and authorizes the client by verifying that the value of "fiware-service" header corresponds to the client's credential.  


This plugin would help you to improve the security level of [fiware-orion's multi-tenancy](https://fiware-orion.readthedocs.io/en/3.8.0/orion-api.html#multi-tenancy) by using [`Kong API Gateway`](https://github.com/Kong/kong).

## Try this plugin

### Preparation
1. You should make docker & docker compose plugin available.
1. Clone this repository like below:
    ```
    git clone https://github.com/nmatsui/kong-plugin-FiwarService-KeyAuth.git; cd kong-plugin-FiwarService-KeyAuth
    ```

### Start Kong API Gateway & fiware-orion
1. Build a customized kong image which is installed this plugin.
    ```
    docker compose build
    ```
1. Start containers.
    ```
    docker compose up -d
    ```
1. Wait a moment until the containers are ready.

### Make this plugin available
1. Make sure that this plugin is available.
    ```
    curl -s http://localhost:8001/ | jq '.plugins.available_on_server."fiwareservice-keyauth"'
    ```
1. Create a service and a route.
    ```
    curl -i -X POST http://localhost:8001/services -d "name=orion" -d "url=http://orion:1026"
    ```
    ```
    curl -i -X POST http://localhost:8001/services/orion/routes -d "hosts[]=orion.example.com"
    ```
1. Enable this plugin for the created service.
    ```
    curl -i -X POST http://localhost:8001/services/orion/plugins -d "name=fiwareservice-keyauth"
    ```
### Register test tenants
1. Register a consumer with the tenant name as its username, and map a key-auth credential to that consumer.
    ```
    curl -i -X POST http://localhost:8001/consumers -d "username=tenant1"
    ```
    ```
    curl -i -X POST http://localhost:8001/consumers/tenant1/key-auth -d "key=a_credential_of_tenant1"
    ```
    > You should change the above credential.
1. Similary, register another tenant.
    ```
    curl -i -X POST http://localhost:8001/consumers -d "username=tenant2"
    ```
    ```
    curl -i -X POST http://localhost:8001/consumers/tenant2/key-auth -d "key=a_credential_of_tenant2"
    ```
### Try authorization and authentication by this plugin
1. You are not authenticate without a credential
    ```
    curl -i http://localhost:8000/version -H "Host: orion.example.com"
    ```
1. Even if your credential is correct, you can not access other tenants.
    ```
    curl -i http://localhost:8000/version -H "Host: orion.example.com" \
         -H "Authorization: a_credential_of_tenant1" -H "fiware-service: tenant2"
    ```
1. If the credential/tenant pair is correct, you are allowed to use fiware-orion.
    ```
    curl -i http://localhost:8000/version -H "Host: orion.example.com" \
         -H "Authorization: a_credential_of_tenant1" -H "fiware-service: tenant1"
    ```

### Try multi-tenancy with fiware-orion
1. Tenant1's owner registers a new Entity.
    ```
    curl -i -X POST http://localhost:8000/v2/entities -H "Host: orion.example.com" \
         -H "Content-Type: application/json" \
         -H "Authorization: a_credential_of_tenant1" -H "fiware-service: tenant1" \
         -d @- << __EOS__
    {
      "id": "Room1",
      "type": "Room",
      "temperature": {
        "value": 23,
        "type": "Float"
      },
      "pressure": {
        "value": 720,
        "type": "Float"
      }
    }
    __EOS__
    ```
1. Tenant1's owner can retrieve that registered Entity.
    ```
    curl -s http://localhost:8000/v2/entities/Room1 -H "Host: orion.example.com" \
         -H "Authorization: a_credential_of_tenant1" -H "fiware-service: tenant1" | jq .
    ```
1. Tenant2's owner can not detect Entities registerd as tenant1 in the first place.
    ```
    curl -s http://localhost:8000/v2/entities -H "Host: orion.example.com" \
         -H "Authorization: a_credential_of_tenant2" -H "fiware-service: tenant2" | jq .
    ```
1. Of cource, tenant2's owner can not retrieve tenant1's Entities by his credential.
    ```
    curl -s http://localhost:8000/v2/entities/Room1 -H "Host: orion.example.com" \
         -H "Authorization: a_credential_of_tenant2" -H "fiware-service: tenant1" | jq .
    ```

## Parameters

| Parameter | Type | required? | Default | Description |
|:--|:--|:--|:--|:--|
| name | string | *required* | | The name of the plugin, in this case `fiwareservice-keyauth` |
| config.auth\_header | string |*optional* | **authorization** | Describes an authentication header name where this plugin will look for a credential. The key names may only contain [a-z], [A-Z], [0-9] and [-]. |
| config.fiwareservice\_header | string | *optional*   | **Fiware-Service** | Describes the Fiware-Service header name. |
| config.hide\_credentials | boolean | *optional* | **false**  | An optional boolean value telling this plugin to send or not to send the credential to the upstream service. If true, this plugin strips the credential from the request header before proxying it to upstream. |

## Container images

| Module | Version | Repository |
|:--|:--|:--|
| Kong API Gateway | kong:3.1.1-alpine | [Docker official](https://hub.docker.com/_/kong) |
| fiware orion | fiware/orion:3.8.0 | [Fiware official](https://hub.docker.com/r/fiware/orion) |
| PostgreSQL | postgres:15.1-bullseye | [Docker official](https://hub.docker.com/_/postgres) |
| MongoDB | mongo:4.4 | [Docker official](https://hub.docker.com/_/mongo) |

## Development

This plugin is designed to work with the [`kong-pongo`](https://github.com/Kong/kong-pongo).  
Please check out kong-pongo's `README` files for usage instructions. For a complete walkthrough check [this blogpost on the Kong website](https://konghq.com/blog/custom-lua-plugin-kong-gateway).

## LICENSE

[Apache-2.0 License](/LICENSE)

## Copyright

Copyright (c) 2023 Nobuyuki Matsui <nobuyuki.matsui@gmail.com>

