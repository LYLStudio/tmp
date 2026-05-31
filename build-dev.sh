#!/bin/bash

# ==========================================
# 0. 環境宣告與動態變數偵測
# ==========================================
TARGET_DATE=$(date +%Y%m%d)

# 自動偵測目前 RHEL/AlmaLinux 的主版本號 (如 8 或 9)，並定義對應標籤與輸出資料夾
OS_VERSION=$(grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release | cut -d. -f1)
OS_VERSION=${OS_VERSION:-UNKNOWN}
BUILD_LABEL="RHEL${OS_VERSION}-Portable-Build"

# 🚀 移除 if 判斷，直接以版本決定目錄名稱
OUTPUT_DIR="/vol/nginx-${TARGET_DATE}-${OS_VERSION}"

PACKAGES_DIR="/vol/packages"
SRC_DIR="/vol/src"
NGINX_SRC_DIR="${SRC_DIR}/nginx-1.31.1"

echo "🧹 [1/5] 正在重置並清空 ${SRC_DIR} 下的核心編譯環境..."
# 徹底刪除舊的原始碼資料夾，一勞永逸解決 OpenSSL 路徑快取與 BuildID 殘留衝突
rm -rf "${SRC_DIR}"
mkdir -p "${SRC_DIR}"

echo "📦 [2/5] 從 ${PACKAGES_DIR} 提取並解壓縮最新版原始碼包..."
# 確保原始碼檔案存在
for pkg in nginx-1.31.1.tar.gz openssl-3.5.6.tar.gz pcre2-10.47.tar.gz zlib-1.3.2.tar.gz; do
    if [ ! -f "${PACKAGES_DIR}/${pkg}" ]; then
        echo "❌ 錯誤：在 ${PACKAGES_DIR} 下找不到必要原始碼包：${pkg}"
        exit 1
    fi
done

# 解壓縮並重新命名為 configure 所需的對應路徑
tar -zxf "${PACKAGES_DIR}/nginx-1.31.1.tar.gz" -C "${SRC_DIR}/"
tar -zxf "${PACKAGES_DIR}/openssl-3.5.6.tar.gz" -C "${SRC_DIR}/" && mv "${SRC_DIR}/openssl-3.5.6" "${SRC_DIR}/openssl"
tar -zxf "${PACKAGES_DIR}/pcre2-10.47.tar.gz" -C "${SRC_DIR}/" && mv "${SRC_DIR}/pcre2-pcre2-10.47" "${SRC_DIR}/pcre2"
tar -zxf "${PACKAGES_DIR}/zlib-1.3.2.tar.gz" -C "${SRC_DIR}/" && mv "${SRC_DIR}/zlib-1.3.2" "${SRC_DIR}/zlib"

echo "⚙️ [3/5] 進入 Nginx 目錄，開始執行純相對路徑配置 (注入標籤: ${BUILD_LABEL})..."
cd "${NGINX_SRC_DIR}" || { echo "❌ 找不到 Nginx 原始碼目錄：${NGINX_SRC_DIR}"; exit 1; }

./configure --prefix= \
  --sbin-path=sbin/nginx \
  --modules-path=modules \
  --conf-path=conf/nginx.conf \
  --error-log-path=logs/error.log \
  --http-log-path=logs/access.log \
  --pid-path=logs/nginx.pid \
  --lock-path=logs/nginx.lock \
  --http-client-body-temp-path=temp/client_body \
  --http-proxy-temp-path=temp/proxy \
  --http-fastcgi-temp-path=temp/fastcgi \
  --http-uwsgi-temp-path=temp/uwsgi \
  --http-scgi-temp-path=temp/scgi \
  --with-pcre="${SRC_DIR}/pcre2" \
  --with-openssl="${SRC_DIR}/openssl" \
  --with-zlib="${SRC_DIR}/zlib" \
  --with-http_ssl_module \
  --with-http_v2_module \
  --with-http_v3_module \
  --with-http_realip_module \
  --with-http_stub_status_module \
  --with-http_gzip_static_module \
  --with-http_sub_module \
  --with-stream \
  --with-stream_ssl_module \
  --with-threads \
  --with-cc-opt='-O2' \
  --build="${BUILD_LABEL}"

if [ $? -ne 0 ]; then
    echo "❌ Configure 設定失敗！"
    exit 1
fi

echo "🛠️ [4/5] 開始全靜態模組編譯，並抽離安裝至 ${OUTPUT_DIR}..."
rm -rf "${OUTPUT_DIR}" # 清理舊的同名成品
make && make install DESTDIR="${OUTPUT_DIR}"

if [ $? -ne 0 ]; then
    echo "❌ 編譯或安裝失敗！"
    exit 1
fi

echo "🎯 [5/5] 進行可攜式相容性微調與驗證測試..."
cd "${OUTPUT_DIR}" || exit 1

# 必須在執行 nginx 語法檢查前，將相對路徑所需的全部暫存與日誌目錄建立好
mkdir -p temp logs

# 將預設 80 連接埠修改為免 root 權限的 8080 連接埠，確保 -t 測試順利
# sed -i 's/listen       80;/listen       8080;/g' conf/nginx.conf

# 執行相對路徑語法檢查
./sbin/nginx -t

if [ $? -eq 0 ]; then
    echo "🎉 恭喜！全靜態高可攜式 Nginx 已經成功編譯並通過語法檢查！"
    echo "📦 [環境標籤]：${BUILD_LABEL}"
    echo "📦 [成品目錄]：${OUTPUT_DIR}"
else
    echo "⚠️ 語法檢查發生異常，請確認上述錯誤訊息！"
fi
