#!/bin/bash

set -e
echo "############## SETUP NTP_SYNC START #############"

# 读取文件内容并分别存储主机名和IP地址
FILE_PATH="./no_docker_scripts/nodes"  # 请确保文件路径正确
if [[ -f "$FILE_PATH" ]]; then
    while IFS= read -r line; do
        # 拆分主机名和IP地址
        HOSTNAME=$(echo "$line" | cut -d':' -f1)
        USER=$(echo "$line" | cut -d':' -f2 | cut -d'@' -f1)
        IP=$(echo "$line" | cut -d':' -f2 | cut -d'@' -f2)
        HOSTNAMES+=("$HOSTNAME")
        USERS+=("$USER")
        IPS+=("$IP")
    done < "$FILE_PATH"
else
    echo "++The file $FILE_PATH does not exist..."
    exit 1
fi

# 从IP列表中选取最小的IP作为服务端，其他的作为客户端
IFS=$'\n' sorted_ips=($(sort <<<"${IPS[*]}"))
unset IFS
SERVER_IP="${sorted_ips[0]}"

# 检查并安装Chrony
install_chrony() {
  if ! command -v chronyd &> /dev/null; then
    echo "++Chrony is not installed. Installing now..."
    sudo apt install chrony -y
  else
    echo "++Chrony already installed"
  fi
}

# 停止已有的chronyd进程
stop_existing_chronyd() {
  if pgrep chronyd &> /dev/null; then
    echo "++An existing chronyd process has been detected and is being stopped...."
    sudo systemctl stop chronyd
  fi
}

# 配置Chrony服务器
configure_server() {
  sudo tee /etc/chrony/chrony.conf > /dev/null <<EOL
# 使用国内NTP服务器作为上游时间源
server ntp.ntsc.ac.cn iburst
server ntp1.aliyun.com iburst
server ntp2.aliyun.com iburst
server ntp3.aliyun.com iburst

# 允许其他机器访问
allow 192.168.0.0/16  
allow 10.0.0.0/8
allow 172.16.0.0/12

# 本地时钟源
local stratum 10

# Drift文件
driftfile /var/lib/chrony/drift

# 日志文件
logdir /var/log/chrony
EOL

  stop_existing_chronyd
  sudo systemctl start chrony
  sudo systemctl enable chrony
  echo "++The Chrony server configuration is complete and has been started..."
}

# 配置Chrony客户端
configure_client() {
  local user=$1
  local hostname=$2
  ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no "$user@$hostname" "
    sudo tee /etc/chrony/chrony.conf > /dev/null <<EOL
# 设置 $SERVER_IP 为时间服务器
server $SERVER_IP iburst

# Drift文件
driftfile /var/lib/chrony/drift

# 日志文件
logdir /var/log/chrony
EOL
  $(declare -f install_chrony); install_chrony
  $(declare -f stop_existing_chronyd); stop_existing_chronyd
  sudo systemctl start chrony
  sudo systemctl enable chrony"
  echo "++The Chrony client at $CLIENT_IP has been configured and started successfully..."
}

# 验证Chrony客户端
verify_client() {
  local user=$1
  local hostname=$2
  ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no "$user@$hostname" "
    sudo systemctl status chronyd > /dev/null 2>&1
    if [ $? -eq 0 ]; then  
      echo 'Chronyd active'
    else  
      echo 'Chronyd inactive'
    fi  
    # chronyc tracking
  " || { echo "chronyc tracking failed from $hostname"; exit 1; }
}

# 主函数
main() {
  echo "++Install and configure Chrony on the server..."
  install_chrony
  configure_server

  for i in "${!HOSTNAMES[@]}"; do
    hostname=${HOSTNAMES[i]}
    user=${USERS[i]}
    ip=${IPS[i]}
    if [[ "$ip" != "$SERVER_IP" ]]; then
      echo "++Install and configure Chrony on the client $hostname..."
      configure_client $user $hostname
      echo "++Verify the Chrony configuration of the client $hostname..."
      verify_client $user $hostname
    fi
  done

  echo "++Chrony setup complete..."
}

# 执行主函数
main

echo "############## SETUP NTP_SYNC END #############"