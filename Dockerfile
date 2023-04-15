FROM alpine:3.17.3

ENV PATH=$PATH:/opt/bin
COPY bin /opt/bin

RUN set -x \
 && cd /tmp \
 && apk add --no-cache git zip terraform vim openssh py3-pip gcc libc-dev python3-dev openssl-dev helm tree curl tar bash \
 && echo "set mouse=" > /root/.vimrc \
 && echo -e '\
Host *\n\
    PasswordAuthentication yes\n\
    StrictHostKeyChecking no\n\
    UserKnownHostsFile /dev/null\n\
    IdentityFile /opt/out/hosts/id_rsa'\
>> /etc/ssh/ssh_config \
 && curl -OL https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
 && chmod +x ./kubectl \
 && mv ./kubectl /usr/local/bin/kubectl \
 && git clone --depth=1 https://github.com/kubernetes-sigs/kubespray.git --branch v2.19.1 /opt/kubespray \
 && pip install -r /opt/kubespray/requirements.txt \
 && ansible-galaxy install geerlingguy.gitlab \
 && curl -OL https://github.com/nautes-labs/init-vault/releases/download/v0.2.0/init-vault_linux_amd64.tar.gz \
 && tar zxf init-vault_linux_amd64.tar.gz \
 && mv init-vault /opt/bin \
 && rm /tmp/*

COPY nautes /opt/nautes
RUN set -x \
 && pip install -r /opt/nautes/requirements.txt \
 && git clone --depth=1 https://github.com/ansible-community/ansible-vault.git /opt/nautes/roles/ansible-vault

WORKDIR /opt

