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
#
# Author: JaneTTR

set -e

echo "############## INSTALL NGINX start #############"

# 文件路径和全局变量
REPO_DIR="/data/rpm-package"
NGINX_BIN="/usr/sbin/nginx"
NGINX_CONF="/etc/nginx/conf.d/yum_repo.conf"

# 检查并安装所需的软件包
install_packages() {
    local packages=("nginx" "createrepo")
    for package in "${packages[@]}"; do
        if ! rpm -q $package &> /dev/null; then
            echo "未安装 $package。正在安装..."
            yum install -y $package
        else
            echo "$package 已安装。"
        fi
    done
}

# 停止已有的nginx进程
stop_existing_nginx() {
    if pgrep nginx &> /dev/null; then
        echo "检测到已有的nginx进程，正在停止..."
        pkill nginx
    fi
}

# 生成或更新YUM仓库元数据
update_repo_metadata() {
    if [ -d "${REPO_DIR}/repodata" ]; then
        createrepo --update ${REPO_DIR}
    else
        createrepo ${REPO_DIR}
    fi
}

# 配置Nginx
configure_nginx() {
    cat <<EOL | tee ${NGINX_CONF}
server {
    listen 80;
    server_name localhost;
    location / {
        autoindex on;
        alias ${REPO_DIR}/;
    }
}
EOL
}

# 启动Nginx服务
start_nginx() {
    stop_existing_nginx
    ${NGINX_BIN}
    echo "Nginx服务配置完成并已启动。"
}

# 验证Nginx是否正在运行
verify_nginx() {
    if pgrep nginx &> /dev/null; then
        echo "Nginx 正在运行。"
    else
        echo "Nginx 未能启动，请检查配置。"
        exit 1
    fi
}

# 主函数
main() {
    install_packages
    update_repo_metadata
    configure_nginx
    start_nginx
    verify_nginx
}

main "$@"

echo "############## INSTALL NGINX end #############"
