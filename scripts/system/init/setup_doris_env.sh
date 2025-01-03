#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -ex



yum install -y  byacc flex automake libtool bison binutils zip unzip ncurses-devel ninja-build
yum install -y  autoconf automake libtool gettext-devel glibc-static libstdc++-static


# 定义变量
DOWNLOAD_URL="https://ghgo.xyz/https://github.com/apache/doris-thirdparty/releases/download/automation/doris-thirdparty-prebuilt-linux-x86_64.tar.xz"
FILE_NAME="doris-thirdparty-prebuilt-linux-x86_64.tar.xz"
DEST_DIR="/opt"

# 检查文件是否已存在
if [ -f "${DEST_DIR}/${FILE_NAME}" ]; then
    echo "文件 ${FILE_NAME} 已存在于目录 ${DEST_DIR}，跳过下载。"
else
    echo "文件 ${FILE_NAME} 不存在，开始下载..."
    wget -O "${DEST_DIR}/${FILE_NAME}" "${DOWNLOAD_URL}"
    if [ $? -eq 0 ]; then
        echo "文件下载完成：${DEST_DIR}/${FILE_NAME}"
    else
        echo "文件下载失败，请检查网络连接或下载 URL。"
        exit 1
    fi
fi