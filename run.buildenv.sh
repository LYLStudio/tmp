#!/bin/bash

# 預設版本為 9
VERSION=${1:-9}

# 防呆檢查：只允許輸入 8 或 9
if [ "$VERSION" != "8" ] && [ "$VERSION" != "9" ]; then
    echo "❌ 錯誤：無效的版本！請輸入 8 或 9 (例如: ./run.sh 8)"
    exit 1
fi

IMAGE_NAME="nginx-build:${VERSION}"
HOST_VOLUME_DIR="$(pwd)/volume"

# 確保主機的 volume 目錄存在，避免被 Docker 自動建立成 root 權限目錄
mkdir -p "$HOST_VOLUME_DIR"

echo "🚀 [1/2] 正在動態建置 AlmaLinux:${VERSION} 開發環境..."
docker build --build-arg ALMA_VERSION="${VERSION}" -t "$IMAGE_NAME" .

if [ $? -ne 0 ]; then
    echo "❌ 鏡像建置失敗，請檢查 Dockerfile！"
    exit 1
fi

echo "🐳 [2/2] 正在啟動容器 ${IMAGE_NAME}..."
echo "💡 提示：本機的 ./volume 已掛載至容器內的 /vol 帳號 esbadmin"
docker run --rm -it \
  -v "$HOST_VOLUME_DIR":/vol \
  -p 80:80 \
  "$IMAGE_NAME"
