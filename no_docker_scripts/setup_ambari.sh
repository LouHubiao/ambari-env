#!/bin/bash

set -e
echo "############## SETUP AMBARI START #############"

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
    # echo "Server Hostname: $SERVER_HOSTNAME"
    # echo "Server User: $SERVER_USER"
    # echo "Server IP: $SERVER_IP"
else
    echo "++The file $FILE_PATH does not exist..."
    exit 1
fi

# 检查并安装Mysql驱动
install_mysql_driver() {
    CONNECTOR_URL="https://mirrors.aliyun.com/mysql/Connector-J/mysql-connector-java-5.1.48.tar.gz"
    JAR_PATH="/usr/share/java/mysql-connector-java.jar"
    TAR_FILE="/tmp/mysql-connector-java-5.1.48.tar.gz"
    TMP_DIR="/tmp/mysql-connector-java-tmp"
    if ! [ -f "$JAR_PATH" ]; then
        echo "++JAR not found. Downloading from $CONNECTOR_URL ..."
        wget -O "$TAR_FILE" "$CONNECTOR_URL"
        if [ $? -ne 0 ]; then  
            echo "++Download failed..."  
            exit 1  
        fi
        mkdir -p "$TMP_DIR"
        tar -xzf "$TAR_FILE" -C "$TMP_DIR"
        FOUND_JAR=$(find "$TMP_DIR" -name "mysql-connector-java-*.jar" | head -n 1)  
        if [ -z "$FOUND_JAR" ]; then  
            echo "++JAR not found after extraction..."  
            exit 2  
        fi  
        echo "++Copying $FOUND_JAR to $JAR_PATH ..."  
        sudo cp "$FOUND_JAR" "$JAR_PATH"  
        sudo chmod 644 "$JAR_PATH"  
        rm -rf "$TAR_FILE" "$TMP_DIR"
    else
        echo "++JAR already exists: $JAR_PATH"
    fi
}

# 创建 Ambari 用户
create_ambari_user() {
    if ! id "ambari" &>/dev/null; then
        echo "++Create Ambari User..."
        sudo useradd -r -m -U -d /var/lib/ambari-server -s /bin/bash ambari
        echo "++Create Ambari User Completed..."
    else
        echo "++Ambari user already exists..."
    fi
}

# 安装 Ambari Server
install_ambari_server() {
    echo "++Install Ambari Server..."
    sudo apt install -y ambari-server
    sudo chmod 755 /var/lib/ambari-server
    echo "++Install Ambari Server Completed..."
}

# 初始化数据库
initialize_database() {
    echo "++Initialize the database..."

    # 检查并创建数据库和用户
    mysql -uroot -proot <<EOF
CREATE DATABASE IF NOT EXISTS ambari;
CREATE DATABASE IF NOT EXISTS hive;

CREATE USER IF NOT EXISTS 'ambari'@'%' IDENTIFIED BY 'ambari';
CREATE USER IF NOT EXISTS 'hive'@'%' IDENTIFIED BY 'hive';

GRANT ALL PRIVILEGES ON *.* TO 'ambari'@'%' IDENTIFIED BY 'ambari' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'ambari'@'localhost' IDENTIFIED BY 'ambari' WITH GRANT OPTION;

GRANT ALL PRIVILEGES ON *.* TO 'hive'@'%' IDENTIFIED BY 'hive' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'hive'@'localhost' IDENTIFIED BY 'hive' WITH GRANT OPTION;

FLUSH PRIVILEGES;
EOF

    # 检查并执行 Ambari DDL 脚本
    if ! mysql -u ambari -pambari -e "USE ambari; SHOW TABLES LIKE 'metainfo';" | grep -q 'metainfo'; then
        echo "Execute Ambari DDL script..."
        mysql -u ambari -pambari ambari </var/lib/ambari-server/resources/Ambari-DDL-MySQL-CREATE.sql
    else
        echo "++The Ambari DDL script has been executed and does not need to be run again..."
    fi
}

# 使用 expect 自动化 ambari-server setup
setup_ambari_server() {
    echo "++Configure Ambari Server..."
    sudo ambari-server setup --jdbc-db=mysql --jdbc-driver=$JAR_PATH
    expect -c "
set timeout -1
spawn sudo ambari-server setup
expect \"Customize user account for ambari-server daemon\"
send \"n\r\"

# 检查 JDK 状态并进行相应操作
expect {
  \"Enter choice (1):\" {
    send \"2\r\"
    expect \"Path to JAVA_HOME:\"
    send \"$::env(JAVA_HOME)\r\"
  }
  \"Do you want to change\" {
    send \"n\r\"
  }
}

expect {
  \"Completing setup...\" {
    # Do nothing, just continue
  }
  \"Enable Ambari Server to download and install GPL\" {
    send \"y\r\"
  }
}

expect \"Enter advanced database configuration\" {
  send \"y\r\"
}
expect \"Choose one of the following options:\" {
  send \"3\r\"
}

expect \"Hostname\"
send \"$SERVER_IP\r\"
expect \"Port\"
send \"3306\r\"
expect \"Database name\"
send \"ambari\r\"
expect \"Username\"
send \"ambari\r\"
expect \"Enter Database Password\"
send \"ambari\r\"
expect {
  \"Configuring ambari database...\" {
    # Do nothing, just continue
  }
  \"Re-enter password: \" {
    send \"ambari\r\"
  }
}

expect {
  \"Configuring remote database connection properties...\" {
    # Do nothing, just continue
  }
  \"Should ambari use existing default jdbc\" {
    send \"y\r\"
  }
}

expect \"Proceed with configuring remote database connection properties\"
send \"y\r\"
expect eof
" || { echo "Configure Ambari Server failed"; exit 1; }
}

# 启动 Ambari Server
start_ambari_server() {
  echo "++Start Ambari Server..."
  sudo ambari-server restart
  sudo systemctl enable ambari-server
  echo "++Start Ambari Server Completed..."
}

# 安装 Ambari Agent
install_ambari_agent() {
  echo "++Install Ambari Agent..."
  sudo apt install -y ambari-agent
  CONF_FILE="/etc/ambari-agent/conf/ambari-agent.ini"
  sudo sed -i "/^\[server\]/, /^\[/ s/^hostname=.*/hostname=${SERVER_IP}/" "$CONF_FILE"
  sudo ambari-agent restart
  sudo systemctl enable ambari-agent
  echo "++Install Ambari Agent Completed..."
}

# 主函数
main() {
    echo "++Install and configure Ambari on the server..."
    install_mysql_driver
    create_ambari_user
    install_ambari_server
    initialize_database
    setup_ambari_server
    start_ambari_server
    install_ambari_agent
    for i in "${!HOSTNAMES[@]}"; do
      hostname=${HOSTNAMES[i]}
      user=${USERS[i]}
      ip=${IPS[i]}
      if [[ "$ip" != "$SERVER_IP" ]]; then
        echo "++Install Ambari on the client $hostname..."
        ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no "$user@$hostname" "
SERVER_IP='$SERVER_IP'
$(declare -f install_ambari_agent); install_ambari_agent"
      fi
    done

    echo "++Ambari setup complete..."
}

# 执行主函数
main

echo "############## SETUP AMBARI END #############"