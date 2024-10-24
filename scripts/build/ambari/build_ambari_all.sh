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

echo "############## BUILD_AMBARI_ALL start #############"


PROJECT_PATH="/opt/modules/ambari"
RPM_PACKAGE="/data/rpm-package/ambari"

mkdir -p "$RPM_PACKAGE"


echo "1.0.0 版本编译开始"
bash /scripts/build/ambari/build.sh
echo "1.0.0 版本结束"

echo "1.0.1 版本编译开始"
bash /scripts/build/ambari/build1_0_1.sh
echo "1.0.1 版本编译结束"

echo "1.0.2 版本编译开始"
bash /scripts/build/ambari/build1_0_2.sh
echo "1.0.2 版本编译结束"

echo "1.0.3 版本编译开始"
bash /scripts/build/ambari/build1_0_3.sh
echo "1.0.3 版本编译结束"





# 开启 gcc 高版本
source /opt/rh/devtoolset-7/enable
cd "$PROJECT_PATH"



#mvn -T 16 -B clean install package rpm:rpm -Drat.skip=true -Dcheckstyle.skip=true -DskipTests -Dpython.ver="python >= 2.6" -Preplaceurl -X
mvn -T 16 -B  install package rpm:rpm -Drat.skip=true -Dcheckstyle.skip=true -DskipTests -Dpython.ver="python >= 2.6" -Preplaceurl
find "$PROJECT_PATH" -iname '*.rpm' -exec cp -rv {} "$RPM_PACKAGE" \;


echo "############## BUILD_AMBARI_ALL end #############"
