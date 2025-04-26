#!/bin/bash

set -e
echo "############## SETUP NGINX START #############"

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

FILE_PATH="./no_docker_scripts/server_node"  # 请确保文件路径正确
if [[ -f "$FILE_PATH" ]]; then
    line=$(head -n 1 "$FILE_PATH")
    # 提取主机名、用户名和 IP 地址
    SERVER_HOSTNAME=$(echo "$line" | cut -d':' -f1)
    SERVER_USER=$(echo "$line" | cut -d':' -f2 | cut -d'@' -f1)
    SERVER_IP=$(echo "$line" | cut -d':' -f2 | cut -d'@' -f2)
    echo "Server Hostname: $SERVER_HOSTNAME"
    echo "Server User: $SERVER_USER"
    echo "Server IP: $SERVER_IP"
else
    echo "++The file $FILE_PATH does not exist..."
    exit 1
fi

# 检查并安装Nginx
install_nginx() {
    if ! dpkg -l | grep -qw nginx; then
        echo "++Nginx is not installed. Installing now..."
        sudo apt install nginx -y
    else
        echo "++Nginx already installed"
    fi
}

# 停止已有的nginx进程
stop_existing_nginx() {
    if pgrep nginx &> /dev/null; then
        echo "++An existing nginx process has been detected and is being stopped...."
        sudo systemctl stop nginx
    fi
}

# 配置Nginx服务器
configure_server() {
    echo "++Nginx config update is starting..."
    sudo tee /etc/nginx/conf.d/apt_deb_repo.conf <<EOL
server {
    listen 80;
    server_name localhost;
    location / {
        autoindex on;
        alias /usr/share/hdp/;
    }
}
EOL
    stop_existing_nginx
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo systemctl start nginx
    sudo systemctl enable nginx
    echo "++The Nginx server configuration is complete and has been started..."
}

# 配置客户机
configure_apt_source() {
    local user=$1
    local hostname=$2
    ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no "$user@$hostname" "
        sudo tee /etc/apt/sources.list.d/hdp.list > /dev/null <<EOL
deb [trusted=yes] http://$SERVER_HOSTNAME/2.7.8.0-213 ambari main
deb [trusted=yes] http://$SERVER_HOSTNAME/1.1.0.22 HDP-UTILS main
deb [trusted=yes] http://$SERVER_HOSTNAME/3.3.2.0-013 HDP main
EOL
        sudo apt-get update"
    echo "++The sources at $hostname has been configured..."
}

# apt-cache search ambari
# 验证Chrony客户端
verify_apt_source() {
    local user=$1
    local hostname=$2
    ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no "$user@$hostname" "
        search_result=\$(apt-cache search ambari 2>/dev/null)
        if [ -n \"\$search_result\" ]; then 
          echo 'apt-cache search ambari succeeded'
          echo \"\$search_result\"
        else  
          echo 'apt-cache search ambari failed or no result'
        fi  
    " || { echo "apt-cache search ambari failed on $hostname"; exit 1; }
}

# 主函数
main() {
    echo "++Install and configure nginx on the server..."
    install_nginx
    configure_server
    for i in "${!HOSTNAMES[@]}"; do
        hostname=${HOSTNAMES[i]}
        user=${USERS[i]}
        ip=${IPS[i]}
        echo "++configure apt source on $hostname..."
        configure_apt_source $user $hostname
        echo "++Verify the apt source configuration of $hostname..."
        verify_apt_source $user $hostname
    done
    echo "++Ningx setup complete..."
}

# 执行主函数
main

echo "############## SETUP NGINX END #############"