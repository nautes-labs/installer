#!/bin/bash

set -e

NAUTES_PATH="/opt/nautes"
NAUTES_LOG_PATH="/tmp"
CONTAINER_NAME=nautes-installer
INSTALLER_VERSION=v0.2.0

if ! [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
	docker run -d --name $CONTAINER_NAME \
    -v $NAUTES_PATH/out:/opt/out \
    -v $NAUTES_PATH/terraform:/tmp/terraform \
    ghcr.io/nautes-labs/installer:${INSTALLER_VERSION} \
      tail -f /dev/null
fi

docker exec $CONTAINER_NAME destroy-hosts | tee ${NAUTES_LOG_PATH}/destroy.log
docker rm -f $CONTAINER_NAME              | tee -a ${NAUTES_LOG_PATH}/destroy.log
rm -rvf $NAUTES_PATH                      | tee -a ${NAUTES_LOG_PATH}/destroy.log

