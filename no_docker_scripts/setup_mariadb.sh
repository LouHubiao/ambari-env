#!/bin/bash

set -e
echo "############## SETUP NTP_SYNC START #############"

# 定义MariaDB root用户密码
ROOT_PASSWORD="root"

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

# 检查并安装Expect
install_expect() {
  if ! command -v expect &> /dev/null; then
    echo "++Expect is not installed. Installing now..."
    sudo apt install -y expect
  else
    echo "++Expect is installed..."
  fi
}

# 写入优化后的MariaDB配置文件
write_my_cnf() {
  echo "++My.cnf is being updated..."
  sudo tee /etc/mysql/mariadb.conf.d/99-my.cnf <<EOL
[client]
# 设置客户端默认字符集为utf8mb4
default-character-set=utf8mb4
socket=/var/lib/mysql/mysql.sock

[mysqld]
# 基本设置
user=mysql
port=3306
basedir=/usr
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
pid-file=/var/run/mysqld/mysqld.pid

# 设置字符集为utf8mb4
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# 使用InnoDB存储引擎
default-storage-engine=InnoDB

# InnoDB引擎优化
# 设置InnoDB缓冲池大小，建议设置为物理内存的70-80%
innodb_buffer_pool_size=1G

# 设置InnoDB日志文件大小，建议设置为缓冲池大小的25%
innodb_log_file_size=256M

# 设置InnoDB日志缓冲区大小
innodb_log_buffer_size=64M

# 启用InnoDB文件每表存储
innodb_file_per_table=1

# 设置InnoDB锁等待超时时间
innodb_lock_wait_timeout=50

# 启用InnoDB缓冲池实例
innodb_buffer_pool_instances=4

# 启用InnoDB双写缓冲区
innodb_doublewrite=1

# 启用InnoDB自适应哈希索引
innodb_adaptive_hash_index=1

# 启用InnoDB文件格式
innodb_file_format=Barracuda

# 启用InnoDB压缩表
innodb_compression_level=6

# 启用InnoDB快速启动
innodb_fast_shutdown=1

# 启用InnoDB严格模式
innodb_strict_mode=1

# 启用InnoDB状态监控
innodb_status_file=1

# 启用InnoDB表空间监控
innodb_stats_on_metadata=0

# 启用InnoDB线程并发
innodb_thread_concurrency=8

# 网络设置
# 允许所有IP地址连接
bind-address=0.0.0.0

# 最大连接数
max_connections=500

# 日志设置
# 启用慢查询日志
slow_query_log=1
slow_query_log_file=/var/log/mysql/slow-query.log
long_query_time=2

[mysqldump]
# 设置mysqldump默认字符集为utf8mb4
default-character-set=utf8mb4
EOL
echo "++My.cnf update is complete..."
}

# 检查并安装MariaDB服务器
install_mariadb_server() {
  if ! command -v /usr/bin/mysql &> /dev/null; then
    echo "MariaDB is not installed. Installing now..."
    sudo apt install -y mariadb-server mariadb-client
  else
    # 检查MariaDB版本
    MARIADB_VERSION=$(/usr/bin/mysql -V | awk '{ print $5 }' | awk -F. '{ print $1 }')
    if [[ "$MARIADB_VERSION" -ne 10 ]]; then
      echo "++MariaDB version is not 10.x. Uninstalling now..."
      sudo apt remove -y mariadb-server mariadb-client
      echo "++MariaDB reinstalling 10.11..."
      sudo apt install -y mariadb-server mariadb-client
    else
      echo "++MariaDB 10.x is installed..."
    fi
  fi
}

# 检查并安装MariaDB客户端
install_mariadb_client() {
  if ! command -v /usr/bin/mysql &> /dev/null; then
    echo "MariaDB client is not installed. Installing now..."
    sudo apt install -y mariadb-client
  else
    echo "MariaDB client is installed"
  fi
}

# 检查并停止占用3306端口的进程
stop_port_3306() {
  if lsof -i:3306 &> /dev/null; then
    echo "++Port 3306 is occupied. Stopping the related processes..."
    lsof -i:3306 | awk 'NR>1 {print $2}' | sudo xargs kill -9
  else
    echo "++Port 3306 is not occupied..."
  fi
}

# 启动MariaDB守护进程
start_mariadb() {
  sudo systemctl start mariadb
  sudo systemctl enable mariadb
  sleep 5  # 等待MariaDB启动
}

# 安全安装MariaDB
secure_mariadb() {
  # 自动化 mariadb-secure-installation 的交互部分
  expect -c "
  set timeout 5
  spawn sudo mariadb-secure-installation
  expect \"Enter current password for root (enter for none):\"
  send \"\r\"
  expect \"Switch to unix_socket authentication\"
  send \"n\r\"
  expect \"Change the root password?\"
  send \"y\r\"
  expect \"New password:\"
  send \"$ROOT_PASSWORD\r\"
  expect \"Re-enter new password:\"
  send \"$ROOT_PASSWORD\r\"
  expect \"Remove anonymous users?\"
  send \"y\r\"
  expect \"Disallow root login remotely?\"
  send \"n\r\"
  expect \"Remove test database and access to it?\"
  send \"y\r\"
  expect \"Reload privilege tables now?\"
  send \"y\r\"
  expect eof
  "
}

# 配置MariaDB以允许远程连接
configure_remote_access() {
  mysql -uroot -p"$ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$ROOT_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
  sudo systemctl restart mysql
}

# 在服务器上安装并配置MariaDB
configure_server() {
  echo "++Install and configure MariaDB on the server $SERVER_HOSTNAME..."
  ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no "$SERVER_USER@$SERVER_HOSTNAME" "
    $(declare -f install_expect); install_expect
    $(declare -f write_my_cnf); write_my_cnf
    $(declare -f install_mariadb_server); install_mariadb_server
    $(declare -f stop_port_3306); stop_port_3306
    $(declare -f start_mariadb); start_mariadb
    $(declare -f secure_mariadb); ROOT_PASSWORD='$ROOT_PASSWORD'; secure_mariadb
    $(declare -f configure_remote_access); configure_remote_access"
  echo "++MariaDB server configuration is complete and has been started..."
}

# 在客户端上安装MariaDB客户端
configure_client() {
  for i in "${!HOSTNAMES[@]}"; do
    hostname=${HOSTNAMES[i]}
    user=${USERS[i]}
    ip=${IPS[i]}
    if [[ "$ip" != "$SERVER_IP" ]]; then
      echo "++Install and configure the MariaDB client on the client $hostname..."
      ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no "$user@$hostname" "
        $(declare -f install_mariadb_client); install_mariadb_client"
      echo "++MariaDB client on $hostname has been configured successfully"
    fi
  done
}


# 主函数
main() {
  echo "++Install and configure MariaDB on the server..."

  configure_server
  configure_client

  echo "++MariaDB setup complete..."
}

# 执行主函数
main

echo "############## SETUP NTP_SYNC END #############"