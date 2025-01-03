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

# flex版本设置
FLEX_VERSION="2.6.4"
FLEX_TAR="flex-${FLEX_VERSION}.tar.gz"
FLEX_URL="https://github.com/westes/flex/releases/download/v${FLEX_VERSION}/${FLEX_TAR}"
INSTALL_DIR="/opt/flex-${FLEX_VERSION}"

# 检查flex是否已经安装
if [ -d "${INSTALL_DIR}" ]; then
  echo "flex ${FLEX_VERSION} 已经安装，跳过安装步骤"
else
  # 安装依赖
  echo "安装必要的依赖..."
  sudo yum groupinstall -y "Development Tools"
  sudo yum install -y wget

  # 下载并解压 flex 源代码
  echo "下载 flex ${FLEX_VERSION}..."
  wget -O /tmp/${FLEX_TAR} ${FLEX_URL}

  # 解压源代码
  echo "解压 flex 源代码..."
  sudo tar -xzf /tmp/${FLEX_TAR} -C /tmp

  # 编译并安装 flex
  echo "编译并安装 flex ${FLEX_VERSION}..."
  cd /tmp/flex-${FLEX_VERSION}
  ./configure --prefix=${INSTALL_DIR}
  make -j$(nproc)
  sudo make install

  # 清理临时文件
  echo "清理临时文件..."
  rm -rf /tmp/flex-${FLEX_VERSION} /tmp/${FLEX_TAR}
fi

# 设置环境变量（将 flex 的路径添加到 /etc/profile）
echo "设置 flex 环境变量..."
if ! grep -q "FLEX_HOME" /etc/profile; then
  echo "export FLEX_HOME=${INSTALL_DIR}" | sudo tee -a /etc/profile > /dev/null
  echo "export PATH=\$FLEX_HOME/bin:\$PATH" | sudo tee -a /etc/profile > /dev/null
  echo "环境变量已添加到 /etc/profile 中"
else
  echo "环境变量 FLEX_HOME 已经设置"
fi

# 重新加载 /etc/profile 使环境变量生效
source /etc/profile

echo "flex ${FLEX_VERSION} 安装完成并配置环境变量"

