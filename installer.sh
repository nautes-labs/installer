#!/bin/bash

CONTAINER_NAME=nautes-installer
if [ -z "$INSTALLER_VERSION" ]
then
    INSTALLER_VERSION="latest"
fi

NAUTES_PATH="/opt/nautes"
NAUTES_LOG_PATH="${NAUTES_PATH}/out/logs"
NAUTES_VAR_PATH="${NAUTES_PATH}/vars"

INSTALLATION_PROGRESS_PATH="${NAUTES_PATH}/flags"
FLAG_CREATE_HOST="create_host"
FLAG_KUBERNETES="kubernetes"
FLAG_INSTALLATION_INIT="init"
FLAG_GIT_REGISTRY="gitrepo"
FLAG_TENANT_INIT="tenant_repo"
FLAG_NAUTES="nautes"
FLAG_SECRET_STORE="secret_store"

COLOR_GREEN=$(tput setaf 2)
COLOR_RED=$(tput setaf 1)
COLOR_NORMAL=$(tput sgr0)


function init() {
    mkdir -p ${NAUTES_LOG_PATH}
    mkdir -p ${NAUTES_VAR_PATH}
    cp vars.yaml ${NAUTES_VAR_PATH}

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

    if ! [ "$1" = "debug" ]; then
        docker pull ghcr.io/nautes-labs/installer:${INSTALLER_VERSION} 
    fi


    if ! [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
        docker run -d --name ${CONTAINER_NAME} ${EXTRA_MOUNT}\
         -v ${NAUTES_PATH}/out:/opt/out \
         -v ${NAUTES_PATH}/terraform:/tmp/terraform \
         -v ${NAUTES_PATH}/flags:/tmp/flags \
         -v ${NAUTES_VAR_PATH}:/tmp/vars \
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
    
    mkdir -p ${INSTALLATION_PROGRESS_PATH}

    docker exec -i $CONTAINER_NAME clone-repos | tee -a $LOG_FILE 

    if ! [ -e ${INSTALLATION_PROGRESS_PATH}/$FLAG_CREATE_HOST ]; then
        docker exec -i $CONTAINER_NAME create-hosts | tee -a $LOG_FILE 
        touch ${INSTALLATION_PROGRESS_PATH}/$FLAG_CREATE_HOST
    fi

    if ! [ -e ${INSTALLATION_PROGRESS_PATH}/$FLAG_KUBERNETES ]; then
        docker exec -i $CONTAINER_NAME install-k8s | tee -a $LOG_FILE 
        touch ${INSTALLATION_PROGRESS_PATH}/$FLAG_KUBERNETES
    fi

    docker exec -i $CONTAINER_NAME install-nautes | tee -a $LOG_FILE 
}

function enable_progress() {
    for i in "$@"; do
        if [ $i = "create_host" ]; then 
            rm -f ${INSTALLATION_PROGRESS_PATH}/${FLAG_CREATE_HOST} 
        elif [ $i = "kubernetes" ]; then
            rm -f ${INSTALLATION_PROGRESS_PATH}/${FLAG_KUBERNETES}
        elif [ $i = "init" ]; then
            rm -f ${INSTALLATION_PROGRESS_PATH}/${FLAG_INSTALLATION_INIT}
        elif [ $i = "git" ]; then
            rm -f ${INSTALLATION_PROGRESS_PATH}/${FLAG_GIT_REGISTRY}
        elif [ $i = "tenant_init" ]; then
            rm -f ${INSTALLATION_PROGRESS_PATH}/${FLAG_TENANT_INIT}
        elif [ $i = "nautes" ]; then
            rm -f ${INSTALLATION_PROGRESS_PATH}/${FLAG_NAUTES}
        else
            echo "Enable $i is not supported"
        fi
    done
}

function disable_progress() {
    for i in "$@"; do
        if [ $i = "create_host" ]; then 
            touch ${INSTALLATION_PROGRESS_PATH}/${FLAG_CREATE_HOST} 
        elif [ $i = "kubernetes" ]; then
            touch ${INSTALLATION_PROGRESS_PATH}/${FLAG_KUBERNETES}
        elif [ $i = "init" ]; then
            touch ${INSTALLATION_PROGRESS_PATH}/${FLAG_INSTALLATION_INIT}
        elif [ $i = "git" ]; then
            touch ${INSTALLATION_PROGRESS_PATH}/${FLAG_GIT_REGISTRY}
        else
            echo "Skipping $i is not supported"
        fi
    done
}

function show_progress() {
    printf "# Install Progress\n"
    show_one_progress ${INSTALLATION_PROGRESS_PATH}/${FLAG_CREATE_HOST}          "create_host"
    show_one_progress ${INSTALLATION_PROGRESS_PATH}/${FLAG_KUBERNETES}           "kubernetes"
    show_one_progress ${INSTALLATION_PROGRESS_PATH}/${FLAG_INSTALLATION_INIT}    "init"
    show_one_progress ${INSTALLATION_PROGRESS_PATH}/${FLAG_GIT_REGISTRY}         "git"
    show_one_progress ${INSTALLATION_PROGRESS_PATH}/${FLAG_TENANT_INIT}          "tenant_init"
    show_one_progress ${INSTALLATION_PROGRESS_PATH}/${FLAG_NAUTES}               "nautes"
}

function show_one_progress() {
    if [ -e $1 ]; then
        printf "%-15s${COLOR_GREEN}%s${COLOR_NORMAL}\n" "$2:" "clear"
    else
        printf "%-15s${COLOR_RED}%s${COLOR_NORMAL}\n" "$2:" "not clear"
    fi
}

function show_progress_help() {
    printf "%-10s%s\n" "do:" "Set step as not clear"
    printf "%-10s%s\n" "skip:" "Set step as clear"
    printf "%-10s%s\n" "show:" "Show progress status"
}

function progress() {
    mkdir -p ${INSTALLATION_PROGRESS_PATH}

    if [ "$1" = "do" ]; then
        shift
        enable_progress $@
        show_progress
    elif [ "$1" = "skip" ]; then
        shift
        disable_progress $@
        show_progress
    elif [ "$1" = "show" ]; then
        show_progress
    else
        show_progress_help        
    fi 
}

function show_installer_help() {
    printf "# Support commands\n"
    printf "%-10s%s\n" "debug" "Start installer in debug mod."
    printf "%-10s%s\n" "destroy" "Clear all server resources created by installers. It will not clean up data that has already been generated."
    printf "%-10s%s\n" "install" "Install nautes."
    printf "%-10s%s\n" "progress" "Display the current installation progress. User can set to skip or redo a certain step."
}

if [ "$1" == "debug" ]; then
    set -e
    init
    if ! [ -e bin/init-vault ]; then 
        curl -L https://github.com/nautes-labs/init-vault/releases/download/v0.2.0/init-vault_linux_amd64.tar.gz | tar zx -C ./bin
    fi
    run_container "debug"
    docker exec -it $CONTAINER_NAME sh
elif [ "$1" == "destroy" ]; then
    run_container "destroy"
    destroy 
elif [ "$1" == "install" ]; then
    init
    run_container 
    install
elif [ "$1" == "progress" ]; then
    shift
    progress $@
else
    show_installer_help
fi

