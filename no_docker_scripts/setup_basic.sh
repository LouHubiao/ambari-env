#!/bin/bash

set -e
echo "############## SETUP BASIC START #############"

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


# 主函数
main() {
    for i in "${!HOSTNAMES[@]}"; do
        hostname=${HOSTNAMES[i]}
        user=${USERS[i]}
        ip=${IPS[i]}
        ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no "$user@$hostname" "
            echo '++$user@$hostname Beginning Installation...'
            # sudo apt update
            sudo apt install -y openssh-client curl unzip tar wget gcc python2-dev openssl nmap expect
        "
    done
}

# 执行主函数
main

echo "############## SETUP BASIC END #############"
