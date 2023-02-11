FROM kong:3.1.1-alpine

ENV PLUGIN_NAME=kong-plugin-fiwareservice-keyauth
ARG PLUGIN_VERSION=0.1.0-1
ENV KONG_PLUGINS=bundled,fiwareservice-keyauth

WORKDIR /opt
COPY . /opt/${PLUGIN_NAME}

USER root
RUN apk update && apk add zip unzip luarocks && \
    cd /opt/${PLUGIN_NAME} && \
    luarocks make && \
    luarocks pack ${PLUGIN_NAME} ${PLUGIN_VERSION} && \
    luarocks install ${PLUGIN_NAME}-${PLUGIN_VERSION}.all.rock
USER kong

