#!/bin/bash
# 版权所有 (c) JaneTTR 2025
# 项目名称：ambari-env
#
# 本文件属于付费部分代码，仅供个人学习和研究使用。
#
# 禁止行为：
# 1. 未经授权，不得将本文件或其编译后的代码用于任何商业用途；
# 2. 禁止重新分发本文件或其修改版本；
# 3. 禁止通过反编译、反向工程等手段试图绕过授权验证。
#
# 商业授权：
# 如需将本文件或其编译后的代码用于商业用途，必须获得版权所有者的书面授权。
# 联系方式：
# 邮箱：3832514048@qq.com
#
# 责任声明：
# 本文件按“现状”提供，不附带任何形式的担保，包括但不限于适销性、特定用途适用性或无侵权的担保。
#
# 如有任何疑问，请联系版权所有者。


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

