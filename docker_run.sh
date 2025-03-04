#!/bin/bash  

# 构建 valley 镜像  
docker build -t valley -f dockerfile .    

# 创建网络（如果不存在）  
docker network inspect ambari-env_ambari-env-network >/dev/null 2>&1 || \
docker network create --driver bridge --subnet=172.20.0.0/24 ambari-env_ambari-env-network  

# 启动 nginx 容器  
docker run -d \
  --name nginx \
  --hostname nginx \
  --network ambari-env_ambari-env-network \
  --ip 172.20.0.10 \
  -p 86:80 \
  --ulimit nofile=65535:65535 \
  -v ./scripts:/scripts \
  -v ./common/data/rpm-package:/data/rpm-package \
  --privileged \
  valley  

# 启动 valley master 容器（依赖 nginx）  
docker run -d \
  --name valley1 \
  --hostname valley1 \
  --network ambari-env_ambari-env-network \
  --ip 172.20.0.11 \
  -p 28088:8080 \
  --ulimit nofile=65535:65535 \
  -v ./scripts:/scripts \
  -v ./common/conf:/opt/modules/conf \
  -v ./common/data/mvn:/root/.m2 \
  -v ./common/data/rpm-package:/data/rpm-package \
  --privileged \
  valley  

# 启动 valley slave 容器（依赖 nginx）  
docker run -d \
  --name valley2 \
  --hostname valley2 \
  --network ambari-env_ambari-env-network \
  --ip 172.20.0.12 \
  --ulimit nofile=65535:65535 \
  -v ./scripts:/scripts \
  -v ./common/conf:/opt/modules/conf \
  -v ./common/data/mvn:/root/.m2 \
  -v ./common/data/rpm-package:/data/rpm-package \
  --privileged \
  valley  

docker run -d \
  --name valley3 \
  --hostname valley3 \
  --network ambari-env_ambari-env-network \
  --ip 172.20.0.13 \
  --ulimit nofile=65535:65535 \
  -v ./scripts:/scripts \
  -v ./common/conf:/opt/modules/conf \
  -v ./common/data/mvn:/root/.m2 \
  -v ./common/data/rpm-package:/data/rpm-package \
  --privileged \
  valley 

docker run -d \
  --name valley4 \
  --hostname valley4 \
  --network ambari-env_ambari-env-network \
  --ip 172.20.0.14 \
  --ulimit nofile=65535:65535 \
  -v ./scripts:/scripts \
  -v ./common/conf:/opt/modules/conf \
  -v ./common/data/mvn:/root/.m2 \
  -v ./common/data/rpm-package:/data/rpm-package \
  --privileged \
  valley  