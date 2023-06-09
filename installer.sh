#!/bin/bash

CONTAINER_NAME=nautes-installer
if [ -z "$INSTALLER_VERSION" ]
then
    INSTALLER_VERSION="latest"
fi

NAUTES_PATH="/opt/nautes"
NAUTES_LOG_PATH="${NAUTES_PATH}/out/logs"

function init() {
    mkdir -p ${NAUTES_LOG_PATH}
}

function run_container() {
    local EXTRA_MOUNT=""

    if [ "$1" = "debug" ]; then
        EXTRA_MOUNT=" -v `pwd`/nautes:/opt/nautes \
-v `pwd`/bin:/opt/bin \
${EXTRA_MOUNT}"
    elif [ "$1" = "destroy" ]; then
        EXTRA_MOUNT=""
    fi

    if ! [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
        docker run -d --name ${CONTAINER_NAME} ${EXTRA_MOUNT}\
         -v ${NAUTES_PATH}/out:/opt/out \
         -v ${NAUTES_PATH}/terraform:/tmp/terraform \
         -v `pwd`/vars.yaml:/opt/vars.yaml \
         ghcr.io/nautes-labs/installer:${INSTALLER_VERSION} \
           tail -f /dev/null
    fi
}

function destroy() {
    set -e
    set -o pipefail
    docker exec $CONTAINER_NAME destroy-hosts   | tee /tmp/destroy.log 
    docker rm -f $CONTAINER_NAME                | tee -a /tmp/destroy.log
    rm -rvf $NAUTES_PATH                        | tee -a /tmp/destroy.log
}

function install() {
    set -e
    set -o pipefail
    local LOG_FILE="${NAUTES_LOG_PATH}/install.log"
    rm $LOG_FILE && touch $LOG_FILE
    
    local INSTALLATION_PROGRESS_PATH="${NAUTES_PATH}/flags"
    mkdir -p ${INSTALLATION_PROGRESS_PATH}

    docker exec -i $CONTAINER_NAME clone-repos | tee -a $LOG_FILE 

    local FLAG_CREATION_COMPLETED_HOST="${INSTALLATION_PROGRESS_PATH}/create_host"
    if ! [ -e $FLAG_CREATION_COMPLETED_HOST ]; then
        docker exec -i $CONTAINER_NAME create-hosts | tee -a $LOG_FILE 
        touch $FLAG_CREATION_COMPLETED_HOST
    fi

    local FLAG_INSTALLATION_COMPLETED_KUBERNETES="${INSTALLATION_PROGRESS_PATH}/kubernetes"
    if ! [ -e $FLAG_INSTALLATION_COMPLETED_KUBERNETES ]; then
        docker exec -i $CONTAINER_NAME install-k8s | tee -a $LOG_FILE 
        touch $FLAG_INSTALLATION_COMPLETED_KUBERNETES
    fi

    docker exec -i $CONTAINER_NAME install-nautes | tee -a $LOG_FILE 
}


if [ "$1" == "debug" ]; then
    set -e
    init
    if ! [ -e bin/init-vault ]; then 
        curl -L https://github.com/nautes-labs/init-vault/releases/download/v0.2.0/init-vault_linux_amd64.tar.gz | tar zx -C ./bin
    fi
    run_container "debug"
    docker exec -i $CONTAINER_NAME clone-repos
    docker exec -it $CONTAINER_NAME sh
elif [ "$1" == "destroy" ]; then
    run_container "destroy"
    destroy 
else
    init
    run_container 
    install
fi

