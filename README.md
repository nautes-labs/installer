# Installer

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![ansible](https://img.shields.io/badge/ansible-v2.12.5-brightgreen)](https://go.dev/doc/install)
[![version](https://img.shields.io/badge/version-v0.3.1-green)](https://nautes.io)

Installer 项目为 Nautes 提供了自动化安装能力，支持基于公有云、私有云、主机、及 Kubernets 集群进行安装，本文档以阿里云为例描述了在公有云安装 Nautes 的过程。

## 准备环境

- 安装机：AMD64 架构的 Linux 服务器，需要预先安装 Docker、Git、Bash，并确保 /opt/nautes 目录没有被占用。
- 公有云密钥：一个阿里云账号的访问密钥，如果您使用的是 RAM 用户，请确保 RAM 用户有 AliyunECSFullAccess 和 AliyunVPCFullAccess 权限。详情参考 [创建 AccessKey](https://help.aliyun.com/document_detail/116401.html)。

> 安装程序会调用阿里云的 API 申请资源，这个过程会产生一定的费用（请参考[阿里云费用说明](#阿里云费用说明 )）。
>
> 受阿里云的计费规则限制，请确保上述阿里云账号内的余额大于100元人民币，否则安装程序无法调用阿里云的 API 申请资源。

## 执行安装

创建安装程序的配置文件。

```bash
cat <<EOT >> vars.yaml
access_key: < your alicloud access key >
secret_key: < your alicloud secret key >
EOT
```

执行以下命令进行默认安装。

```bash
curl https://raw.githubusercontent.com/nautes-labs/installer/main/installer.sh | bash -
```

或者

```bash
curl -OL https://raw.githubusercontent.com/nautes-labs/installer/main/installer.sh
chmod +x installer.sh
./installer.sh
```

> 默认安装单节点的 K3s ，根据安装机公网带宽大小，整个安装过程预计耗时15~25分钟。安装成功后，您可以在 /opt/nautes 目录下找到安装后的组件信息。如果安装失败，您可以通过 /opt/nautes/out/logs 目录下的日志排查问题。

## 查看安装结果

/opt/nautes/flags 中存储了安装进度的标识文件。安装程序会根据标识文件跳过已完成的安装步骤。

/opt/nautes/terraform 中存储了 terraform 的状态文件，记录了安装程序在阿里云上申请的资源清单。

/opt/nautes/out 中存储了已安装组件的相关信息：

- GitLab 用于托管租户的配置库，用户应用的源代码、部署清单和流水线配置等。GitLab 的管理员密码，以及租户配置库的访问信息等存储在 gitlab 子目录下。
- Vault 用于存储和管理租户的密钥数据。Vault 的 unseal key 和 root token 存储在 vault 子目录下。
- Kubernetes 集群用于承载所有的租户管理组件。集群的 kubeconfig 存储在 kubernetes 子目录下。
- ArgoCD 用于监听租户配置库，并根据仓库中的配置声明向 Kubernetes 集群同步租户配置。ArgoCD 的管理员密码存储在 argocd 子目录下。
- Dex 用于提供基于 OIDC 协议的统一认证服务。dex 的客户端密钥存储在 kubernetes 子目录下。

除此之外，/opt/nautes/out 下其他子目录的相关信息：

- hosts：云服务器的 IP 地址和访问密钥。
- pki：访问组件需要使用的证书和签发证书的 CA。
- service：租户管理集群、Dex、ArgoCD、Vault、GitLab、Nautes API Server 的访问地址。
- logs：安装程序的日志。

## 销毁环境

> 请确保未删除安装机上的 /opt/nautes 目录。执行销毁命令的目录下有安装程序的配置文件 vars.yaml。
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

安装程序默认使用[抢占式实例模式](https://help.aliyun.com/document_detail/52088.html?spm=5176.ecsbuyv3.0.0.2a2736756P0dh1)创建云服务器，该模式存在实例被自动释放的风险。如果您希望体验更稳定的环境，请在 vars.yaml 增加以下配置，让安装程序切换至[按量付费模式](https://help.aliyun.com/document_detail/40653.html?spm=5176.ecsbuyv3.0.0.2a2736756P0dh1)申请资源。

```yaml
alicloud.save_money: false
```

两种付费模式的费用预估如下（不包含流量费）：

- 按量付费：56.112￥/天

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
repos.tenant_template.url: https://github.com/nautes-labs/tenant-repo-template.git
repos.tenant_template.version: main
```

### 使用标准 K8s

安装开始前，在 vars.yaml 文件中添加以下配置。

```yaml
deploy.kubernetes.type: k8s
deploy.kubernetes.node_num: 3
```

### 完整参数清单

请参考 [vars.yaml.sample](https://github.com/nautes-labs/installer/blob/main/vars.yaml.sample)。
