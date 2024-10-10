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

set -ex

echo "############## BUILD BIGTOP_RPM_TRANSFORM start #############"



PROJECT_PATH="/opt/modules/bigtop"
RPM_PACKAGE="/data/rpm-package/bigtop"
mkdir -p "$RPM_PACKAGE"



# 遍历 output 目录下的每个子目录
for dir in "$PROJECT_PATH"/output/*; do
    if [ -d "$dir" ]; then
        # 获取子目录的名称
        component=$(basename "$dir")

        # 创建目标目录
        mkdir -p "$RPM_PACKAGE/$component"

        # 查找并复制文件
        find "$dir" -iname '*.rpm' -not -iname '*.src.rpm' -exec cp -rv {} "$RPM_PACKAGE/$component" \;
    fi
done

echo "############## BUILD BIGTOP_RPM_TRANSFORM end #############"
