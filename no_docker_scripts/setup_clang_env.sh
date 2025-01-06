#!/bin/bash

set -ex

# 设置版本和路径信息
PYTHON_VERSION="3.7.12"
PYTHON_SRC_TAR="/opt/modules/Python-${PYTHON_VERSION}.tgz"
PYTHON_SRC_DIR="/opt/modules/Python-${PYTHON_VERSION}"
PYTHON_INSTALL_PREFIX="/usr/local"
LLVM_VERSION="16.0.6"
LLVM_SRC_TAR="llvm-${LLVM_VERSION}.src.tar.xz"
LLVM_SRC_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/${LLVM_SRC_TAR}"
LLVM_SRC_DIR="/opt/llvm-${LLVM_VERSION}-src"
LLVM_BUILD_DIR="/opt/llvm-build"
LLVM_INSTALL_DIR="/opt/llvm-${LLVM_VERSION}"

# 检查是否以 root 用户运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 用户运行该脚本。"
  exit 1
fi

# 安装必要依赖
echo "安装必要依赖..."
yum groupinstall -y "Development Tools"
yum install -y gcc gcc-c++ zlib-devel bzip2 bzip2-devel readline-devel \
    sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel cmake3 \
    python3 wget ninja-build centos-release-scl devtoolset-11

# 激活 Devtoolset-11（提供 GCC 11）
echo "激活 Devtoolset-11..."
source /opt/rh/devtoolset-11/enable

# 检查 CMake 版本
echo "检查 CMake 版本..."
cmake3 --version | grep -E "cmake version 3\.(1[5-9]|[2-9][0-9])"
if [ $? -ne 0 ]; then
  echo "CMake 版本不足 3.15，请升级！"
  exit 1
fi

# **编译 Python 3.7**
echo "开始编译 Python ${PYTHON_VERSION}..."
if [ ! -f "${PYTHON_SRC_TAR}" ]; then
  echo "未找到 Python 源码压缩文件：${PYTHON_SRC_TAR}，请确认路径！"
  exit 1
fi

# 解压 Python 源码
if [ -d "${PYTHON_SRC_DIR}" ]; then
  echo "删除旧的 Python 解压目录..."
  rm -rf "${PYTHON_SRC_DIR}"
fi
tar -xf "${PYTHON_SRC_TAR}" -C /opt/modules/

cd "${PYTHON_SRC_DIR}" || exit
./configure --prefix="${PYTHON_INSTALL_PREFIX}" --enable-shared CFLAGS="-fPIC" LDFLAGS="-Wl,-rpath=${PYTHON_INSTALL_PREFIX}/lib"
make -j$(nproc)
sudo make altinstall

# 验证动态库生成
if [ ! -f "${PYTHON_INSTALL_PREFIX}/lib/libpython3.7m.so" ]; then
  echo "Python 动态库未生成，退出！"
  exit 1
fi

# 配置 Python 动态库路径
echo "配置 Python 动态库路径..."
sed -i '/PYTHON\/lib/d' /etc/profile
echo "export LD_LIBRARY_PATH=${PYTHON_INSTALL_PREFIX}/lib:\$LD_LIBRARY_PATH" >> /etc/profile
source /etc/profile
sudo ldconfig

# 验证动态库路径
echo "验证动态库路径..."
ldconfig -p | grep libpython3.7m.so
if [ $? -ne 0 ]; then
  echo "动态库路径加载失败，请手动检查！"
  exit 1
fi

# **编译 LLVM**
echo "开始编译 LLVM ${LLVM_VERSION}..."

# 下载 LLVM 源码
if [ ! -f "/opt/${LLVM_SRC_TAR}" ]; then
  echo "正在下载 LLVM 源码..."
  wget -O "/opt/${LLVM_SRC_TAR}" "${LLVM_SRC_URL}"
fi

# 解压 LLVM 源码
if [ -d "${LLVM_SRC_DIR}" ]; then
  echo "删除旧的 LLVM 源码目录..."
  rm -rf "${LLVM_SRC_DIR}"
fi
mkdir -p "${LLVM_SRC_DIR}"
tar -xf "/opt/${LLVM_SRC_TAR}" -C "${LLVM_SRC_DIR}" --strip-components=1

# 创建构建目录
if [ -d "${LLVM_BUILD_DIR}" ]; then
  echo "删除旧的 LLVM 构建目录..."
  rm -rf "${LLVM_BUILD_DIR}"
fi
mkdir -p "${LLVM_BUILD_DIR}"

# 配置 LLVM 编译
echo "配置 LLVM 编译..."
cd "${LLVM_BUILD_DIR}"
cmake -G "Ninja" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;compiler-rt;lld;polly;mlir;openmp" \
  -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
  -DCMAKE_INSTALL_PREFIX="${LLVM_INSTALL_DIR}" \
  -DPYTHON_EXECUTABLE="${PYTHON_INSTALL_PREFIX}/bin/python3.7" \
  -DPYTHON_LIBRARY="${PYTHON_INSTALL_PREFIX}/lib/libpython3.7m.so" \
  "${LLVM_SRC_DIR}"

# 编译和安装 LLVM
echo "编译 LLVM..."
ninja -j4
echo "安装 LLVM..."
ninja install

# 配置 LLVM 环境变量
echo "配置 LLVM 环境变量..."
sed -i '/LLVM\/bin/d' /etc/profile
sed -i '/LLVM\/lib/d' /etc/profile
echo "export PATH=\$PATH:${LLVM_INSTALL_DIR}/bin" >> /etc/profile
echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${LLVM_INSTALL_DIR}/lib" >> /etc/profile
source /etc/profile

# 验证 LLVM 安装
echo "验证 LLVM 安装..."
if [ -f "${LLVM_INSTALL_DIR}/bin/clang" ]; then
  echo "LLVM 和 Clang ${LLVM_VERSION} 安装成功！"
  "${LLVM_INSTALL_DIR}/bin/clang" --version
else
  echo "LLVM 安装失败，请检查日志！"
  exit 1
fi

echo "验证 Python 安装..."
"${PYTHON_INSTALL_PREFIX}/bin/python3.7" --version
"${LLVM_INSTALL_DIR}/bin/llvm-config" --has-python

echo "脚本执行完成，Python 和 LLVM 已成功安装！"
