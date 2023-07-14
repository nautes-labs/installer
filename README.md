# Installer

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![ansible](https://img.shields.io/badge/ansible-v2.12.5-brightgreen)](https://go.dev/doc/install)
[![version](https://img.shields.io/badge/version-v0.3.5-green)](https://nautes.io)

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

/opt/nautes/out 中存储了已安装组件的相关信息:

- GitLab 用于托管租户的配置库，用户应用的源代码、部署清单和流水线配置等。GitLab 的管理员密码，以及租户配置库的访问信息等存储在 git 子目录下。
- Vault 用于存储和管理租户的密钥数据。Vault 的 unseal key 和 root token 存储在 vault 子目录下。
- Kubernetes 集群用于承载所有的租户管理组件。集群的 kubeconfig 存储在 kubernetes 子目录下。
- ArgoCD 用于监听租户配置库，并根据仓库中的配置声明向 Kubernetes 集群同步租户配置。ArgoCD 的管理员密码存储在 argocd 子目录下。
- Dex 用于提供基于 OIDC 协议的统一认证服务。dex 的客户端密钥存储在 kubernetes 子目录下。

> 文件夹中的内容根据安装的方式的不同会有所不同。如：用户自己提供gitlab的情况下，目录中不会有gitlab的管理员密码。

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
- 实例规格：ecs.g6.large(2C8G)
- 系统盘：ESSD云盘 PL0 40G
- 网络：实例公网IP
- 数目： 1
- 用途： GitLab

安装程序默认使用 [抢占式实例模式](https://help.aliyun.com/document_detail/52088.html?spm=5176.ecsbuyv3.0.0.2a2736756P0dh1) 创建云服务器，该模式存在实例被自动释放的风险。如果您希望体验更稳定的环境，请在 vars.yaml 增加以下配置，让安装程序切换至 [按量付费模式](https://help.aliyun.com/document_detail/40653.html?spm=5176.ecsbuyv3.0.0.2a2736756P0dh1) 申请资源。

```yaml
alicloud_save_money: false
```

两种付费模式的费用预估如下（不包含流量费）：

- 按量付费：58.2￥/天

- 抢占式实例：16.6￥/天

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
./installer.sh progress skip kubernetes gitrepo
```

如果用户需要重新执行已经完成的安装步骤，则可以通过以下命令把步骤标识为未完成的状态。

```shell
./installer.sh progress do kubernetes
./installer.sh install
```

>该操作只是将安装进度标识成未完成，没有清理的步骤或者重新执行安装的操作，需要重新执行install命令安装。
>
>后续步骤可能依赖前置步骤。只执行前置步骤的重装可能导致环境失效。

查看安装进度及可操作的节点。(部分节点不支持跳过)
```shell
./installer.sh progress show
> # Install Progress
> kubernetes:    clear
> gitrepo:       clear
> tenant_init:   not clear
> nautes:        not clear
```

可操作的安装步骤说明
| 步骤 | 说明 |
| --- | --- |
| kubernetes | 安装 kubernetes |
| gitrepo | 安装 gitlab |
| tenant_init | 初始化 git 仓库以及创建租户配置库 |
| nautes | 安装nautes |

- 使用现有机器

    需要在 vars.yaml 中补充的配置项:
    ```yaml
    # 机器的访问信息。
    ansible_inventory_file: |
      # 如果使用现有的 gitlab, 不要写这一段内容。
      [gitlab]
      gitlab-0 ansible_host=${ gitlab host ip }
      # ========= end =========

      # 如果使用现有的 kubernetes, 不要写这一段内容。
      [kube_control_plane]
      k8s-0 ansible_host=${ k8s host ip }

      [kube_node]
      k8s-0

      [etcd]
      k8s-0

      [k8s_cluster:children]
      kube_control_plane
      kube_node
      # ========= end =========

      [vault]
      vault-0 ansible_host=${ vault host ip }

      [all:vars]
      no_log=true
      local_path_provisioner_enabled=true

    # 如果机器是通过证书SSH访问的，把证书原文填写到以下变量中。(这对证书需要能访问到 ansible_inventory_file 中定义的所有机器)
    ansible_ssh_keypair:
      private:
      public:
    ```

 - 使用现有 kubernetes 集群

     跳过安装步骤的命令：
     ```yaml
     ./installer.sh progress skip kubernetes
     ```

     需要在 vars.yaml 中补充的配置项:
     ```yaml
     kube_apiserver_kubeconfig: |
       apiVersion: v1
       clusters:
       - cluster:
           certificate-authority-data: ...
           server: https://127.0.0.1:6443
         name: default
       contexts:
       - context:
           cluster: default
           user: default
         name: default
       current-context: default
       kind: Config
       users:
       - name: default
         user:
           client-certificate-data: ...
           client-key-data: ...
     ```

     备注: kubeconfig 文件要对应集群的管理员角色。

  - 使用现有 Gitlab

      跳过安装步骤的命令：
      ```yaml
      ./installer.sh progress skip gitrepo
      ```

      需要在 vars.yaml 中补充的配置项:
      ```yaml
      # Git 仓库的 HTTPS 访问地址。
      git_external_url: "https://127.0.0.1:443"
      # Git 仓库的 SSH 访问地址。
      git_ssh_addr: "ssh://git@127.0.0.1:22"
      # 拥有 api 和 sudo 权限的 token， 用于初始化租户配置库和 Git 仓库的全局配置。
      git_init_token: ""
      # Git 仓库的 CA 证书。（填写原文）
      git_ca: ""
      ```

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
