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


bash /scripts/build/ambari/build_ambari_all.sh
bash /scripts/build/bigtop/build_bigtop_all.sh


bash /scripts/build/ambari-infra/build.sh
bash /scripts/build/ambari-metrics/build.sh

echo "############## ONE_KEY_BUILD end #############"
