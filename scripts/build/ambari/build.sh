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

echo "############## BUILD AMBARI start #############"

#########################
####      PATCH       ###
#########################

# 定义一个包含所有补丁文件路径的数组
patch_files=(
  "/scripts/build/ambari/patch/patch0-BOWER-MIRROR.diff"
  #如果不想要汉化，请注释下行代码
#  "/scripts/build/ambari/patch/patch1-CONVERT-CN.diff"
  "/scripts/build/ambari/patch/patch2-FIXED-POS-DISPLAY.diff"
  "/scripts/build/ambari/patch/patch3-ADMIN-BOWER-VERBOSE.diff"
)
PROJECT_PATH="/opt/modules/ambari"
RPM_PACKAGE="/data/rpm-package/ambari"

mkdir -p "$RPM_PACKAGE"

# 定义一个函数来应用补丁
apply_patch() {
  local patch_file=$1
  if patch -p1 --dry-run -R -d "$PROJECT_PATH" <"$patch_file" >/dev/null 2>&1; then
    echo "补丁：$patch_file 已经应用，跳过"
  else
    if patch -p1 --fuzz=0 --verbose -d "$PROJECT_PATH" <"$patch_file"; then
      echo "补丁：$patch_file 已经成功执行"
    else
      echo "补丁：$patch_file 执行失败"
      exit 1
    fi
  fi
}

# 遍历数组并应用每个补丁文件
for patch_file in "${patch_files[@]}"; do
  apply_patch "$patch_file"
done

#########################
####      BUILD       ###
#########################

cd "$PROJECT_PATH"

tar -zxvf /scripts/build/ambari/patch/source/bower.tar.gz -C "$PROJECT_PATH/ambari-admin/src/main/resources/ui/admin-web/"
# 使用指定镜像 phantomjs-2.1.1-linux-x86_64.tar.bz2 解决 admin 和 web 下载 github 下不下来问题
export PHANTOMJS_CDNURL=https://npmmirror.com/mirrors/phantomjs/



echo "############## BUILD AMBARI end #############"
