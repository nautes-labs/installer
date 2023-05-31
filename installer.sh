#!/bin/bash
set -x

CONTAINER_NAME=nautes-installer
if [ -z "$INSTALLER_VERSION" ]
then
    INSTALLER_VERSION="latest"
fi

NAUTES_PATH="/opt/nautes"
NAUTES_LOG_PATH="${NAUTES_PATH}/out/logs"
NAUTES_REPO_PATH="${NAUTES_PATH}/repos"

function git_clone() {
    if ! [ $# -eq 3 ]
    then
        echo "Insufficient parameters, git clone failed."
        exit 1
    fi

    local TARGET_DIR="${NAUTES_REPO_PATH}/$1"
    local REVISION=$2
    local URL=$3
    
    if [ -d "$TARGET_DIR/.git" ]; then
        echo "Repository $1 already exists, updating to the latest code..."
        git --git-dir="$TARGET_DIR/.git" --work-tree="$TARGET_DIR" pull
        if [ $? -ne 0 ]; then
            echo "Error: Failed to fetch updates from the remote repository."
            exit 1
        fi
    else
        echo "Repository $1 not found, cloning to the $TARGET_DIR directory..."
        echo "========================="
        echo "Using revision $REVISION "
        echo "========================="
        git clone --depth 1 -b $REVISION "$URL" "$TARGET_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to clone the repository."
            exit 1
        fi
    fi
}

function init() {
    mkdir -p ${NAUTES_LOG_PATH}
    mkdir -p ${NAUTES_REPO_PATH}

    if [ -z "$TENANT_REPO_TEMPLATE_REVISION" ]
    then
        TENANT_REPO_TEMPLATE_REVISION="main"
    fi
    local TENANT_REPO_URL="https://github.com/nautes-labs/tenant-repo-template.git"

    git_clone "management" ${TENANT_REPO_TEMPLATE_REVISION} ${TENANT_REPO_URL}

    if [ -z "${ANSIBLE_ROLE_VAULT_REVISION}" ]
    then
        ANSIBLE_ROLE_VAULT_REVISION="master"
    fi
    local ANSIBLE_ROLE_VAULT_URL="https://github.com/ansible-community/ansible-vault.git"

    git_clone "ansible-vault" ${ANSIBLE_ROLE_VAULT_REVISION} ${ANSIBLE_ROLE_VAULT_URL}

    if [ -z "${ANSIBLE_ROLE_GITLAB_REVISION}" ]
    then
        ANSIBLE_ROLE_GITLAB_REVISION="master"
    fi
    local ANSIBLE_ROLE_GITLAB_URL="https://github.com/geerlingguy/ansible-role-gitlab.git"

    git_clone "gitlab" ${ANSIBLE_ROLE_GITLAB_REVISION} ${ANSIBLE_ROLE_GITLAB_URL}
}

function run_container() {
    local EXTRA_MOUNT="-v ${NAUTES_REPO_PATH}/management:/opt/management \
-v ${NAUTES_REPO_PATH}/ansible-vault:/opt/nautes/roles/ansible-vault \
-v ${NAUTES_REPO_PATH}/gitlab:/opt/nautes/roles/gitlab"

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
    local LOG_FILE="${NAUTES_LOG_PATH}/install.log"
    rm $LOG_FILE && touch $LOG_FILE
    
    local INSTALLATION_PROGRESS_PATH="${NAUTES_PATH}/flags"
    mkdir -p ${INSTALLATION_PROGRESS_PATH}

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
    curl -L https://github.com/nautes-labs/init-vault/releases/download/v0.2.0/init-vault_linux_amd64.tar.gz | tar zx -C ./bin
    run_container "debug"
    docker exec -it $CONTAINER_NAME sh
elif [ "$1" == "destroy" ]; then
    run_container "destroy"
    destroy 
else
    init
    run_container 
    install
fi

