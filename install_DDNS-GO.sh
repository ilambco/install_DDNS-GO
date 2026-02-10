#!/bin/bash

# 1. 颜色与初始化
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}正在启动 ddns-go 超级全自动安装脚本...${NC}"

# 2. 权限检查
[[ $EUID -ne 0 ]] && echo -e "${RED}请使用 root 运行!${NC}" && exit 1

# 3. 【关键】全自动修复系统环境
echo -e "${YELLOW}正在清理并优化系统环境...${NC}"

# 如果有源报错（比如那个 xanmod），强制跳过报错的源，优先保证依赖安装
# 移除已知的报错源防止卡死
if [ -f /etc/apt/sources.list.d/xanmod-kernel.list ]; then
    mv /etc/apt/sources.list.d/xanmod-kernel.list /etc/apt/sources.list.d/xanmod-kernel.list.bak
    echo -e "${YELLOW}检测到失效的 XanMod 源，已自动禁用备份。${NC}"
fi

# 尝试强制安装依赖
apt-get update --allow-releaseinfo-change -qq
apt-get install -y curl wget tar jq --fix-broken > /dev/null 2>&1

# 检查依赖是否真的装上了，如果 jq 还不在，尝试备用手段
if ! command -v jq &> /dev/null; then
    echo -e "${RED}APT 依赖安装失败，正在尝试强制修复...${NC}"
    apt-get update --fix-missing
    apt-get install -y curl wget tar jq
fi

# 4. 架构检测
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)  BIN_ARCH="linux_x86_64" ;;
    aarch64) BIN_ARCH="linux_arm64" ;;
    armv7l)  BIN_ARCH="linux_armv7" ;;
    *) echo -e "${RED}不支持的架构: ${ARCH}${NC}"; exit 1 ;;
esac

# 5. 端口设置 (修复变量解析逻辑)
echo -e "${YELLOW}请输入你想使用的端口号 (直接按回车则使用默认 9876):${NC}"
read -p "PORT: " USER_PORT
ACTUAL_PORT=${USER_PORT:-9876}

# 6. 获取最新版本
echo -e "${YELLOW}正在从 GitHub 抓取最新稳定版...${NC}"
LATEST_TAG=$(curl -s https://api.github.com/repos/jeessy2/ddns-go/releases/latest | jq -r .tag_name)
VERSION=${LATEST_TAG#v}

if [ -z "$VERSION" ] || [ "$VERSION" == "null" ]; then
    # 万一 API 失败，硬编码一个稳定版作为兜底
    VERSION="6.15.0"
    echo -e "${YELLOW}抓取失败，使用兜底版本 v${VERSION}${NC}"
fi

# 7. 下载与安装
echo -e "${YELLOW}开始下载 ddns-go v${VERSION}...${NC}"
DOWNLOAD_URL="https://github.com/jeessy2/ddns-go/releases/download/v${VERSION}/ddns-go_${VERSION}_${BIN_ARCH}.tar.gz"

TMP_DIR=$(mktemp -d)
if ! wget -qO- "$DOWNLOAD_URL" | tar -zxv -C "$TMP_DIR"; then
    echo -e "${RED}下载失败，请检查网络是否能访问 GitHub${NC}"
    exit 1
fi

# 卸载旧版并安装
[ -f "/usr/local/bin/ddns-go" ] && /usr/local/bin/ddns-go -s uninstall > /dev/null 2>&1
mv "$TMP_DIR/ddns-go" /usr/local/bin/ddns-go
chmod +x /usr/local/bin/ddns-go

# 使用自定义端口安装服务
/usr/local/bin/ddns-go -s install -l :${ACTUAL_PORT}

# 8. 清理并显示结果
rm -rf "$TMP_DIR"
IP_V4=$(curl -s4 ifconfig.me || echo "无法获取外网IP")

echo -e "\n${GREEN}==============================================${NC}"
echo -e "${GREEN}  ddns-go v${VERSION} 安装成功！${NC}"
echo -e "${YELLOW}  Web界面地址: http://${IP_V4}:${ACTUAL_PORT}${NC}"
echo -e "${YELLOW}  本地访问地址: http://localhost:${ACTUAL_PORT}${NC}"
echo -e "${GREEN}==============================================${NC}"
