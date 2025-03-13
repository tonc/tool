#!/bin/bash

# 定义 Docker 和 Docker Compose 的下载地址
DOCKER_BASE_URL="https://mirrors.163.com/docker-ce/linux/static/stable"
DOCKER_COMPOSE_BASE_URL="https://ghfast.top/https://github.com/docker/compose/releases/download"

# 定义 Docker 和 Docker Compose 的版本
DOCKER_VERSION="28.0.1"
DOCKER_COMPOSE_VERSION="v2.33.1"

# 获取系统架构
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    DOCKER_ARCH="x86_64"
    DOCKER_COMPOSE_ARCH="linux-x86_64"
    ;;
  aarch64)
    DOCKER_ARCH="aarch64"
    DOCKER_COMPOSE_ARCH="linux-aarch64"
    ;;
  armv7l)
    DOCKER_ARCH="armhf"
    DOCKER_COMPOSE_ARCH="linux-armv7"
    ;;
  armv6l)
    DOCKER_ARCH="armel"
    DOCKER_COMPOSE_ARCH="linux-armv6"
    ;;
  ppc64le)
    DOCKER_ARCH="ppc64le"
    DOCKER_COMPOSE_ARCH="linux-ppc64le"
    ;;
  s390x)
    DOCKER_ARCH="s390x"
    DOCKER_COMPOSE_ARCH="linux-s390x"
    ;;
  *)
    echo "错误: 不支持的架构 $ARCH！"
    exit 1
    ;;
esac

# 定义安装目录
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/docker"

# 创建临时目录
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR" || exit 1

# 检查是否安装了 curl 或 wget
check_download_tool() {
  if command -v curl &> /dev/null; then
    DOWNLOAD_TOOL="curl"
  elif command -v wget &> /dev/null; then
    DOWNLOAD_TOOL="wget"
  else
    echo "错误: 未找到 curl 或 wget，请先安装其中之一！"
    exit 1
  fi
}

# 下载文件
download_file() {
  local url=$1
  local output=$2
  if [ "$DOWNLOAD_TOOL" = "curl" ]; then
    curl -fsSL -o "$output" "$url"
  elif [ "$DOWNLOAD_TOOL" = "wget" ]; then
    wget -q -O "$output" "$url"
  else
    echo "错误: 未找到下载工具！"
    exit 1
  fi
}

# 显示菜单
menu() {
  clear
  echo "========================================"
  echo " Docker 和 Docker Compose 安装脚本"
  echo "========================================"
  echo "1. 安装 Docker"
  echo "2. 安装 Docker Compose"
  echo "3. 安装 Docker 和 Docker Compose"
  echo "4. 退出"
  echo "========================================"
  read -p "请输入选项 (1-4): " choice
  case "$choice" in
    1) install_docker ;;
    2) install_docker_compose ;;
    3) install_docker && install_docker_compose ;;
    4) exit 0 ;;
    *) echo "无效选项！" && sleep 1 && menu ;;
  esac
}

# 安装 Docker
install_docker() {
  echo "正在下载 Docker 离线包..."
  DOCKER_URL="$DOCKER_BASE_URL/$DOCKER_ARCH/docker-$DOCKER_VERSION.tgz"
  download_file "$DOCKER_URL" docker.tgz || {
    echo "错误: 无法下载 Docker 离线包！"
    exit 1
  }

  echo "解压 Docker 离线包..."
  tar -xzvf docker.tgz

  echo "安装 Docker 二进制文件..."
  sudo cp docker/* "$INSTALL_DIR"

  echo "创建 Docker 系统服务文件..."
  sudo tee /etc/systemd/system/docker.service > /dev/null <<EOL
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/dockerd
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOL

  echo "创建 Docker 配置文件目录..."
  sudo mkdir -p "$CONFIG_DIR"

  echo "配置 daemon.json 文件..."
  sudo tee "$CONFIG_DIR/daemon.json" > /dev/null <<EOL
{
  "registry-mirrors": ["https://docker.1ms.run", "https://docker.1panel.live", "https://docker.1panel.top"]
}
EOL

  echo "重新加载 systemd 配置..."
  sudo systemctl daemon-reload

  echo "启动 Docker 服务..."
  sudo systemctl start docker

  echo "设置 Docker 服务开机自启..."
  sudo systemctl enable docker

  if docker --version; then
    echo "Docker 安装成功！"
  else
    echo "Docker 安装失败！"
    exit 1
  fi
}

# 安装 Docker Compose
install_docker_compose() {
  echo "正在下载 Docker Compose..."
  DOCKER_COMPOSE_URL="$DOCKER_COMPOSE_BASE_URL/$DOCKER_COMPOSE_VERSION/docker-compose-$DOCKER_COMPOSE_ARCH"
  download_file "$DOCKER_COMPOSE_URL" docker-compose || {
    echo "错误: 无法下载 Docker Compose！"
    exit 1
  }

  echo "安装 Docker Compose..."
  sudo cp docker-compose "$INSTALL_DIR/docker-compose"
  sudo chmod +x "$INSTALL_DIR/docker-compose"
  sudo ln -s "$INSTALL_DIR/docker-compose" /usr/bin/docker-compose

  if docker-compose --version; then
    echo "Docker Compose 安装成功！"
  else
    echo "Docker Compose 安装失败！"
    exit 1
  fi
}

# 清理临时文件
cleanup() {
  echo "清理临时文件..."
  rm -rf "$TMP_DIR"
}

# 主函数
main() {
  check_download_tool
  menu
  cleanup
}

# 执行主函数
main
