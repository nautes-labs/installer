# Installer

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![ansible](https://img.shields.io/badge/ansible-v2.12.5-brightgreen)](https://go.dev/doc/install)
[![version](https://img.shields.io/badge/version-v0.3.1-green)](https://nautes.io)

Installer 项目为 Nautes 提供了自动化安装能力，支持基于公有云、私有云、主机、及 Kubernets 集群进行安装，本文档以阿里云为例描述了在公有云安装 Nautes 的过程。

## 准备环境

- 安装机：AMD64 架构的 Linux 服务器，需要预先[安装 Docker](https://docs.docker.com/engine/install/)、Git、Bash，并确保 /opt/nautes 目录没有被占用。
- 公有云密钥：一个阿里云账号的访问密钥，如果您使用的是 RAM 用户，请确保 RAM 用户有 AliyunECSFullAccess 和 AliyunVPCFullAccess 权限。详情参考 [创建 AccessKey](https://help.aliyun.com/document_detail/116401.html)。

> 安装程序会调用阿里云的 API 申请资源，这个过程会产生一定的费用（请参考 [阿里云费用说明](#阿里云费用说明 )）。
>
> 受阿里云的计费规则限制，请确保上述阿里云账号内的余额大于100元人民币，否则安装程序无法调用阿里云的 API 申请资源。

## 执行安装

> 安装程序需要从 GitHub 获取相关配置（例如镜像等），请确保安装机与 GitHub 之间的网络连接正常。

创建安装程序的配置文件。

```bash
cat <<EOT >> vars.yaml
access_key: < your alicloud access key >
secret_key: < your alicloud secret key >
EOT
```

执行以下命令进行默认安装。

```bash
curl https://raw.githubusercontent.com/nautes-labs/installer/main/installer.sh | bash -s install
```

或者

```bash
curl -OL https://raw.githubusercontent.com/nautes-labs/installer/main/installer.sh
chmod +x installer.sh
./installer.sh install
```

> 默认安装单节点的 K3s ，根据安装机公网带宽大小，整个安装过程预计耗时15~25分钟。安装成功后，您可以在 /opt/nautes 目录下找到安装后的组件信息。如果安装失败，您可以通过 /opt/nautes/out/logs 目录下的日志排查问题。
>
> 安装过程中出现任何问题，请参考 [常见问题](#常见问题)。

## 查看安装结果

/opt/nautes/flags 中存储了安装进度的标识文件。安装程序会根据标识文件跳过已完成的安装步骤。

/opt/nautes/terraform 中存储了 terraform 的状态文件，记录了安装程序在阿里云上申请的资源清单。

/opt/nautes/vars 中存储了用户安装配置文件的缓存。

/opt/nautes/out 中存储了已安装组件的相关信息：

- GitLab 用于托管租户的配置库，用户应用的源代码、部署清单和流水线配置等。GitLab 的管理员密码，以及租户配置库的访问信息等存储在 git 子目录下。
- Vault 用于存储和管理租户的密钥数据。Vault 的 unseal key 和 root token 存储在 vault 子目录下。
- Kubernetes 集群用于承载所有的租户管理组件。集群的 kubeconfig 存储在 kubernetes 子目录下。
- ArgoCD 用于监听租户配置库，并根据仓库中的配置声明向 Kubernetes 集群同步租户配置。ArgoCD 的管理员密码存储在 argocd 子目录下。
- Dex 用于提供基于 OIDC 协议的统一认证服务。dex 的客户端密钥存储在 kubernetes 子目录下。

除此之外，/opt/nautes/out 下其他子目录的相关信息：

- hosts：云服务器的 IP 地址和访问密钥。
- pki：访问组件需要使用的证书和签发证书的 CA。
- service：租户管理集群、Dex、ArgoCD、Vault、GitLab、Nautes API Server 的访问地址。
- logs：安装程序的日志。

> Nautes API Server 的 Swagger UI 相对路径：/q/swagger-ui。
>
> 租户配置库：用于存储租户管理相关的配置信息。每个租户有一个租户配置库。

## 销毁环境

> 请确保未删除安装机上的 /opt/nautes 目录，并且执行销毁命令的目录下有安装程序的配置文件 vars.yaml。
>
> 销毁程序将删除所有从云服务中申请的资源，暂不支持单独对组件执行卸载。

```bash
curl https://raw.githubusercontent.com/nautes-labs/installer/main/installer.sh | bash -s destroy
```

或者

```bash
./installer.sh destroy
```

## 阿里云费用说明

安装程序所申请的云服务器的默认规格如下：

- 区域：中国香港-可用区B
- 镜像：Ubuntu 22.04 64位
- 实例规格：ecs.c6.large(2C4G)
- 系统盘：ESSD云盘 PL0 40G
- 网络：实例公网IP
- 数目： 2
- 用途：K3s、Vault

---

- 区域：中国香港-可用区B
- 镜像：Ubuntu 22.04 64位
- 实例规格：ecs.g5.large(2C8G)
- 系统盘：ESSD云盘 PL0 40G
- 网络：实例公网IP
- 数目： 1
- 用途： GitLab

安装程序默认使用 [抢占式实例模式](https://help.aliyun.com/document_detail/52088.html?spm=5176.ecsbuyv3.0.0.2a2736756P0dh1) 创建云服务器，该模式存在实例被自动释放的风险。如果您希望体验更稳定的环境，请在 vars.yaml 增加以下配置，让安装程序切换至 [按量付费模式](https://help.aliyun.com/document_detail/40653.html?spm=5176.ecsbuyv3.0.0.2a2736756P0dh1) 申请资源。

```yaml
alicloud_save_money: false
```

两种付费模式的费用预估如下（不包含流量费）：

- 按量付费：56.1￥/天

- 抢占式实例：13.5￥/天

> 实际产生的费用会受到市场价格波动的影响，以上预估值仅供参考。

## 自定义安装

### 使用指定版本的安装程序镜像

安装开始前，设置环境变量 INSTALLER_VERSION。

```bash
export INSTALLER_VERSION=vX.Y.Z
```

### 使用指定租户配置库模板

安装开始前，在 vars.yaml 文件中添加以下配置。

```yaml
repos_tenant_template_url: https://github.com/nautes-labs/tenant-repo-template.git
repos_tenant_template_version: main
```

### 使用标准 K8s

安装开始前，在 vars.yaml 文件中添加以下配置。

```yaml
kubernetes_type: k8s
kubernetes_node_num: 3
```

### 完整参数清单

请参考 [vars.yaml.sample](https://github.com/nautes-labs/installer/blob/main/vars.yaml.sample)。

### 选择性安装

用户可以根据自己的情况跳过安装步骤， 例如：用户已经准备好了物理机器，k8s 环境和 gitlab 服务, 可以通过以下命令跳过这些步骤。
```shell
./installer progress skip create_host kubernetes git
```

如果用户需要重新执行已经完成的安装步骤，则可以通过以下命令把步骤标识为未完成的状态。

```shell
./installer progress do create_host kubernetes
./installer install
```

>该操作只是标识为未完成，没有清理的步骤和执行安装的操作，需要重新执行install命令安装。
>
>后续步骤可能依赖前置步骤。只启用前置步骤的重装可能导致环境失效。

查看安装进度及可操作的节点。(部分节点不支持跳过)
```shell
./installer progress show
## Install Progress
#create_host:   clear
#kubernetes:    clear
#init:          not clear
#git:           clear
#tenant_init:   not clear
#nautes:        not clear
```

- 跳过创建运行机器

    命令：
    ```yaml
    ./installer progress skip create_host
    ```

    需要补充的文件:

    1. /opt/nautes/out/hosts/ansible_hosts
        ```yaml
        # 使用已有的gitlab的情况下可以不用填写gitlab信息
        [gitlab]
        gitlab-0 ansible_host=${ gitlab host ip }

        [kube_control_plane]
        k8s-0 ansible_host=${ k8s host ip }

        [kube_node]
        k8s-0

        [etcd]
        k8s-0

        [k8s_cluster:children]
        kube_control_plane
        kube_node

        [vault]
        vault-0 ansible_host=${ vault host ip }

        [all:vars]
        no_log=true
        local_path_provisioner_enabled=true
        ```
    2. /opt/nautes/out/hosts/id_rsa 和 /opt/nautes/out/hosts/id_rsa.pub

        所有机器可以通过这对密钥访问到root账号。

    备注：目前安装程序在跳过 gitlab 和 k8s 的安装的情况下，依旧会创建对应的机器。

 - 跳过安装 kubernetes 集群

    命令：
    ```yaml
    ./installer progress skip kubernetes
    ```

    备注: 需要保证节点 k8s-0 中存在文件 /root/.kube/config，可以通过该文件以管理员身份操作集群。

 - 跳过证书生成

    步骤说明：该步骤会生成整套系统所需的所有密钥对。具体如下:
    | 文件名 | 用途 |
    | --- | --- |
    | ca.pem | 签发证书的私钥 |
    | ca.crt | 签发证书的公钥， 下面所有的密钥对都要能通过此文件进行有效性校验 |
    | API.key | nautes api server 访问 vault proxy 的私钥 |
    | API.crt | nautes api server 访问 vault proxy 的公钥 |
    | CLUSTER.key | nautes cluster operator 访问 vault proxy 的私钥 |
    | CLUSTER.crt | nautes cluster operator 访问 vault proxy 的公钥 |
    | RUNTIME.key | nautes runtime operator 访问 vault proxy 的私钥 |
    | RUNTIME.crt | nautes runtime operator 访问 vault proxy 的公钥 |
    | gitlab-0.key | gitlab https 端口的私钥 |
    | gitlab-0.crt | gitlab https 端口的公钥 |
    | vault-0.key | vault 和 vault proxy https 端口的私钥 |
    | vault-0.crt | vault 和 vault proxy https 端口的公钥 |
    | entrypoint.key | nautes 服务 https 端口的私钥 |
    | entrypoint.crt | nautes 服务 https 端口的公钥 |

    命令：
    ```yaml
    ./installer progress skip init
    ```

    需要补充的文件:

    | 文件名 | 备注 |
    | --- | --- |
    | /opt/nautes/out/pki/ca.crt |
    | /opt/nautes/out/pki/API.key |
    | /opt/nautes/out/pki/API.crt |
    | /opt/nautes/out/pki/CLUSTER.key |
    | /opt/nautes/out/pki/CLUSTER.crt |
    | /opt/nautes/out/pki/RUNTIME.key |
    | /opt/nautes/out/pki/RUNTIME.crt |
    | /opt/nautes/out/pki/gitlab-0.key | 通过安装程序部署gitlab时需要提供 |
    | /opt/nautes/out/pki/gitlab-0.crt | 通过安装程序部署gitlab时需要提供 |
    | /opt/nautes/out/pki/vault-0.key |
    | /opt/nautes/out/pki/vault-0.crt |
    | /opt/nautes/out/pki/entrypoint.key |
    | /opt/nautes/out/pki/entrypoint.crt |

    备注:
    1. 本安装程序暂不支持不同用途的证书使用不同的ca进行签发。
    2. nautes 服务访问 vault proxy 的密钥对签发请参考[这里](https://github.com/nautes-labs/vault-proxy/blob/main/README.md)。
    3. entrypoint 密钥对需要签发的域名为 "*.{{ 集群的访问入口 }}"， 在没有修改变量 "kube_entrypoint_domain" 的情况下，默认是 "{{ k8s-0 的 ip }}.nip.io"。


  - 跳过安装 gitlab

    命令：
    ```yaml
    ./installer progress skip git
    ```

    需要补充的配置项:

    ```yaml
    # Git 仓库的 HTTPS 访问地址。
    git_external_url: "https://127.0.0.1:443"
    # Git 仓库的 SSH 访问地址。
    git_ssh_addr: "ssh://git@127.0.0.1:22"
    # 拥有 api 和 sudo 权限的 token， 用于初始化租户配置库和 Git 仓库的全局配置。
    git_init_token: ""
    # Git 仓库的 CA 证书。
    git_ca: ""
    # SSH 访问时需要信任的 know hosts 信息。
    # known hosts 文件的路径可能在gitlab.rb文件中配置。如果没有，默认在 /etc/ssh/ 目录下。
    git_ssh_fingerprints: []
    ```

  - 创建 nautes 在 git 仓库中所需要的资源 及 租户配置库

    备注：此步骤不支持跳过。

  - 在k8s中安装nautes

    备注：此步骤不支持跳过。

## 常见问题

**安装 Nautes 过程中的步骤 [init-host : Create instance] 报错：code: 403, The resource is out of stock in the specified zone，应该怎么解决？**

安装程序默认使用 [抢占式实例模式](https://help.aliyun.com/document_detail/52088.html?spm=5176.ecsbuyv3.0.0.2a2736756P0dh1) 创建指定规格的云服务器。

如果默认规格的云服务器库存不足，将出现以上错误。

查找报错信息中 `in resource "alicloud_instance" ` 之后的实例名称，例如：gitlab、kubernetes、vault。

根据不同的实例名称，在 `vars.yaml` 文件中，按需添加对应参数以修改云服务器的默认规格。修改配置之后，请先[销毁环境](#销毁环境)，再重新[执行安装程序](#执行安装)即可解决该问题。

```yaml
# 以下参数值仅为建议实例类型，您可以修改实例类型为资源规格不低于建议实例类型的其他类型
# GitLab 的云服务器实例类型
gitlab_instance_type: ecs.g6.large
# Kubernetes 的云服务器实例类型
kubernetes_instance_type: ecs.c5.large
# Vault 的云服务器实例类型
vault_instance_type: ecs.c5.large
