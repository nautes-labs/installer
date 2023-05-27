#!/bin/bash

set -e

NAUTES_PATH="/opt/nautes"
NAUTES_LOG_PATH="/tmp"

CONTAINER_NAME=nautes-installer
if [ -z "$INSTALLER_VERSION" ]
then
    INSTALLER_VERSION="latest"
fi

if ! [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
	docker run -d --name $CONTAINER_NAME \
    -v $NAUTES_PATH/out:/opt/out \
    -v $NAUTES_PATH/terraform:/tmp/terraform \
    ghcr.io/nautes-labs/installer:${INSTALLER_VERSION} \
      tail -f /dev/null
fi

docker exec -it $CONTAINER_NAME destroy-hosts | tee ${NAUTES_LOG_PATH}/destroy.log
docker rm -f $CONTAINER_NAME                  | tee -a ${NAUTES_LOG_PATH}/destroy.log
rm -rvf $NAUTES_PATH                          | tee -a ${NAUTES_LOG_PATH}/destroy.log

