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



echo "############## ONE_KEY_BUILD start #############"

export NEXUS_URL=$(cat /scripts/system/before/nexus/.lock)
export NEXUS_USERNAME="admin"
export NEXUS_PASSWORD="admin123"
echo $NEXUS_URL

PROJECT_PATH="/opt/modules/bigtop"
RPM_PACKAGE="/data/rpm-package/bigtop"
mkdir -p "$RPM_PACKAGE"



echo "1.0.0 版本编译开始"
bash /scripts/build/bigtop/build.sh
echo "1.0.0 版本结束"

echo "1.0.1 版本编译开始"
bash /scripts/build/bigtop/build1_0_1.sh
echo "1.0.1 版本编译结束"

echo "1.0.2 版本编译开始"
bash /scripts/build/bigtop/build1_0_2.sh
echo "1.0.2 版本编译结束"

echo "1.0.3 版本编译开始"
bash /scripts/build/bigtop/build1_0_3.sh
echo "1.0.3 版本编译结束"

echo "1.0.4 版本编译开始"
bash /scripts/build/bigtop/build1_0_4.sh
echo "1.0.4 版本编译结束"


# 开启 gcc 高版本
source /opt/rh/devtoolset-7/enable

cd "$PROJECT_PATH"

# 定义所有组件列表，并标注版本历史
ALL_COMPONENTS=(
  # 1.0.0 版本
  bigtop-groovy-rpm
  bigtop-jsvc-rpm
  bigtop-select-rpm
  bigtop-utils-rpm
  zookeeper-rpm
  hadoop-rpm
  flink-rpm
  hbase-rpm
  hive-rpm
  kafka-rpm
  spark-rpm
  solr-rpm
  tez-rpm
  zeppelin-rpm
  livy-rpm
  # 1.0.1 版本新增
  sqoop-rpm
  ranger-rpm
  # 1.0.2 版本新增
  redis-rpm
  # 1.0.3 版本新增
  phoenix-rpm
  dolphinscheduler-rpm
)

# 编译所有组件
gradle "${ALL_COMPONENTS[@]}" \
  -PparentDir=/usr/bigtop \
  -Dbuildwithdeps=true \
  -PpkgSuffix


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


echo "############## ONE_KEY_BUILD end #############"
