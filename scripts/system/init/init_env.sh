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
echo "############## INIT YUM start #############"
FLAG_FILE="/var/lib/init/.lock"
mkdir -p /var/lib/init

IS_NGINX="$1"

FILE_PATH="/scripts/.init_nginx_done" # 请确保文件路径正确

# 读取文件内容并分别存储主机名和IP地址
if [[ -f "$FILE_PATH" ]]; then
    while IFS= read -r line || [ -n "$line" ]; do
        # 拆分主机名和IP地址
        NGINX_IP=$(echo "$line" | cut -d'@' -f2)
    done < "$FILE_PATH"
else
    echo "文件 $FILE_PATH 不存在"
    exit 1
fi

install_yum() {
    /bin/rm -rf /etc/yum.repos.d/CentOS*
    curl -o /etc/yum.repos.d/aliyun-CentOS-7.repo http://mirrors.aliyun.com/repo/Centos-7.repo
    curl -o /etc/yum.repos.d/aliyun-epel-7.repo http://mirrors.aliyun.com/repo/epel-7.repo

    cat >/etc/yum.repos.d/yum-public.repo <<EOF
[yum-public-mariadb]
name=YUM Public Repository
baseurl=https://mirrors.aliyun.com/mariadb/yum/10.11/centos7-amd64/
gpgkey = https://mirrors.aliyun.com/mariadb/yum/RPM-GPG-KEY-MariaDB
enabled=1
gpgcheck=0
[centos-sclo-sclo]
name=CentOS-7 - SCLo sclo
baseurl=https://mirrors.aliyun.com/centos/7/sclo/x86_64/sclo/
gpgkey = https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
enabled=1
gpgcheck=0
[centos-sclo-rh]
name=CentOS-7 - SCLo rh
baseurl=https://mirrors.aliyun.com/centos/7/sclo/x86_64/rh/
gpgkey = https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
enabled=1
gpgcheck=0
EOF

    # nginx机器不需要设置
    if [[ -z "$IS_NGINX" || "$IS_NGINX" == "false" ]]; then
      cat >/etc/yum.repos.d/ambari.repo <<EOF
[centos-ambari]
name=centos-ambari
baseurl=http://${NGINX_IP}/
enabled=1
gpgcheck=0
EOF
    fi

    yum clean all
    yum makecache

    echo "执行初始化脚本"
    yum -y install centos-release-scl centos-release-scl-rh openssh-server passwd sudo net-tools unzip wget
}

install_yum

if [ ! -f "$FLAG_FILE" ]; then
  echo 'root:root' | chpasswd
  ssh-keygen -A
  if [ ! -f "/etc/ssh/sshd_config" ]; then
    touch /etc/ssh/sshd_config
  fi
  sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
  # 写入ll
  grep -qxF 'alias ll="ls -al"' /etc/profile || sed -i '$ a alias ll="ls -al"' /etc/profile
  source /etc/profile
  touch "$FLAG_FILE"
  echo "source /etc/profile" >>/root/.bashrc
else
  echo "yum 已经完成初始化"
fi
echo "############## INIT YUM end #############"
