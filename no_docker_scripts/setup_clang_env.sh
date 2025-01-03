#!/bin/bash

# 设置版本信息和路径
LLVM_VERSION="16.0.6"
LLVM_SRC_TAR="llvm-${LLVM_VERSION}.src.tar.xz"
LLVM_SRC_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/${LLVM_SRC_TAR}"
SRC_DIR="/opt/llvm-${LLVM_VERSION}-src"
BUILD_DIR="/opt/llvm-build"
INSTALL_DIR="/opt/llvm-${LLVM_VERSION}"

# 检查是否以 root 用户运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 用户运行该脚本。"
  exit 1
fi

# 安装依赖
echo "安装必要的依赖..."
yum groupinstall -y "Development Tools"
yum install -y cmake3 python3 wget ninja-build gcc gcc-c++ make centos-release-scl devtoolset-11

# 激活 Devtoolset-11（提供 GCC 11）
echo "激活 Devtoolset-11..."
source /opt/rh/devtoolset-11/enable

# 确保 cmake 版本满足要求
echo "检查 CMake 版本..."
if ! cmake3 --version | grep -q "3."; then
  echo "CMake 版本太低，安装 cmake3..."
  yum install -y cmake3
  ln -sf /usr/bin/cmake3 /usr/bin/cmake
fi

# 下载源码
if [ ! -f "/opt/${LLVM_SRC_TAR}" ]; then
  echo "正在下载 LLVM ${LLVM_VERSION} 源码..."
  wget -O "/opt/${LLVM_SRC_TAR}" "${LLVM_SRC_URL}"
else
  echo "LLVM ${LLVM_VERSION} 源码包已存在，跳过下载。"
fi

# 解压源码
if [ ! -d "${SRC_DIR}" ]; then
  echo "解压 LLVM ${LLVM_VERSION} 源码到 ${SRC_DIR}..."
  mkdir -p "${SRC_DIR}"
  tar -xf "/opt/${LLVM_SRC_TAR}" -C "${SRC_DIR}" --strip-components=1
else
  echo "LLVM 源码已解压，跳过此步骤。"
fi

# 创建构建目录
if [ ! -d "${BUILD_DIR}" ]; then
  echo "创建构建目录 ${BUILD_DIR}..."
  mkdir -p "${BUILD_DIR}"
else
  echo "构建目录已存在，跳过此步骤。"
fi

# 配置 CMake
echo "配置 CMake 构建..."
cd "${BUILD_DIR}"
cmake -G "Ninja" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  "${SRC_DIR}"

# 开始编译
echo "开始编译 LLVM 和 Clang..."
ninja

# 安装到指定目录
echo "安装 LLVM 和 Clang 到 ${INSTALL_DIR}..."
ninja install

# 配置环境变量
if ! grep -q "${INSTALL_DIR}/bin" /etc/profile; then
  echo "将安装路径添加到环境变量中..."
  echo "export PATH=\$PATH:${INSTALL_DIR}/bin" >> /etc/profile
  echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${INSTALL_DIR}/lib" >> /etc/profile
  source /etc/profile
else
  echo "环境变量已配置，跳过此步骤。"
fi

# 验证安装
echo "验证安装..."
if [ -f "${INSTALL_DIR}/bin/clang" ]; then
  echo "LLVM 和 Clang ${LLVM_VERSION} 安装成功！"
  "${INSTALL_DIR}/bin/clang" --version
else
  echo "安装失败，请检查脚本输出日志。"
  exit 1
fi

echo "脚本执行完成。LLVM 和 Clang 已成功安装！"
