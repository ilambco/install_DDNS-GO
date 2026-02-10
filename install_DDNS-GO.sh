#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}正在启动 ddns-go 全自动安装脚本...${NC}"

# 1. 环境检测：必须以 root 权限运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误：请使用 root 权限或 sudo 运行此脚本。${NC}"
   exit 1
fi

# 2. 安装依赖工具
echo -e "${YELLOW}正在检测并安装依赖 (curl, wget, tar, jq)...${NC}"
apt update -qq && apt install -y curl wget tar jq > /dev/null 2>&1

# 3. 架构检测
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)  BIN_ARCH="linux_x86_64" ;;
    aarch64) BIN_ARCH="linux_arm64" ;;
    armv7l)  BIN_ARCH="linux_armv7" ;;
    *) echo -e "${RED}不支持的架构: ${ARCH}${NC}"; exit 1 ;;
esac
echo -e "${GREEN}检测到系统架构为: ${ARCH}${NC}"

# 4. 获取自定义端口
read -p "请输入你想使用的端口号 (默认 9876): " CUSTOM_PORT
CUSTOM_PORT=${CUSTOM_PORT:-9876}

# 5. 获取最新版本号
echo -e "${YELLOW}正在从 GitHub 获取最新版本信息...${NC}"
LATEST_TAG=$(curl -s https://api.github.com/repos/jeessy2/ddns-go/releases/latest | jq -r .tag_name)
# 去掉 tag 中的 'v'
VERSION=${LATEST_TAG#v}

if [ -z "$VERSION" ]; then
    echo -e "${RED}无法获取最新版本号，请检查网络连接。${NC}"
    exit 1
fi
echo -e "${GREEN}当前最新版本为: v${VERSION}${NC}"

# 6. 下载并解压
DOWNLOAD_URL="https://github.com/jeessy2/ddns-go/releases/download/v${VERSION}/ddns-go_${VERSION}_${BIN_ARCH}.tar.gz"
echo -e "${YELLOW}正在下载: ${DOWNLOAD_URL}${NC}"

TMP_DIR=$(mktemp -d)
wget -qO- "$DOWNLOAD_URL" | tar -zxv -C "$TMP_DIR" > /dev/null

# 7. 安装服务
echo -e "${YELLOW}正在安装 ddns-go 服务并配置端口 ${CUSTOM_PORT}...${NC}"

# 如果已经安装过，先尝试卸载旧服务
if [ -f "/usr/local/bin/ddns-go" ]; then
    /usr/local/bin/ddns-go -s uninstall > /dev/null 2>&1
fi

mv "$TMP_DIR/ddns-go" /usr/local/bin/ddns-go
chmod +x /usr/local/bin/ddns-go

# 使用自定义端口安装
/usr/local/bin/ddns-go -s install -l :${CUSTOM_PORT}

# 8. 清理临时文件
rm -rf "$TMP_DIR"

# 9. 结果反馈
echo -e "\n${GREEN}==============================================${NC}"
echo -e "${GREEN}  ddns-go v${VERSION} 安装成功！${NC}"
echo -e "${YELLOW}  访问地址: http://$(curl -s ifconfig.me):${CUSTOM_PORT}${NC}"
echo -e "${YELLOW}  本地访问: http://localhost:${CUSTOM_PORT}${NC}"
echo -e "${GREEN}==============================================${NC}"
echo -e "提示：如果是云服务器，请记得在安全组放行 ${CUSTOM_PORT} 端口。"
