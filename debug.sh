#!/bin/bash

NAUTES_PATH="/opt/nautes"

CONTAINER_NAME=nautes-installer
if [ -z "$INSTALLER_VERSION" ]
then
    INSTALLER_VERSION="latest"
fi


if ! [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
  docker run -d --name $CONTAINER_NAME \
    -v $NAUTES_PATH/out:/opt/out \
    -v $NAUTES_PATH/terraform:/tmp/terraform \
    -v `pwd`/bin:/opt/bin \
    -v `pwd`/tenant-repo-template:/opt/management \
    -v `pwd`/nautes:/opt/nautes \
    -v `pwd`/ansible-vault:/opt/nautes/roles/ansible-vault \
    -v `pwd`/vars.yaml:/opt/vars.yaml \
    ghcr.io/nautes-labs/installer:${INSTALLER_VERSION} \
      tail -f /dev/null
fi

docker exec -it $CONTAINER_NAME sh
