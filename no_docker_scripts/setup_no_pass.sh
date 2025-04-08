#!/bin/bash

set -e
echo "############## SETUP NO_PASS START #############"

# 定义数组，分别存储主机名和IP地址
HOSTNAMES=()
USERS=()
IPS=()

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

# 打印主机名、用户名和 IP 地址的组合
echo "++HOSTNAME + USER + IP list..."
for i in "${!HOSTNAMES[@]}"; do
    echo "HOSTNAME: ${HOSTNAMES[i]}, USER: ${USERS[i]}, IP: ${IPS[i]}"
done

# 更新 /etc/hosts 文件
for i in "${!HOSTNAMES[@]}"; do
    source_hostname=${HOSTNAMES[i]}
    source_user=${USERS[i]}
    source_ip=${IPS[i]}
    echo "++Update $source_hostname /etc/hosts ..."
    for j in "${!HOSTNAMES[@]}"; do
        target_hostname=${HOSTNAMES[j]}
        target_user=${USERS[j]}
        target_ip=${IPS[j]}
        ssh -o StrictHostKeyChecking=no "$source_user@$source_ip" "
            if ! grep -q '$target_ip $target_hostname' /etc/hosts; then
                echo '$target_ip $target_hostname' | sudo tee -a /etc/hosts
            fi
        " || { echo "Failed to update /etc/hosts on $source_ip"; exit 1; }
        # echo "删除已知主机记录..."
        # ssh -o StrictHostKeyChecking=no "$source_user@$source_ip" "
        #     ssh-keygen -R '$source_hostname' &>/dev/null
        # " || { echo "Failed to remove known host for $ssh_hostname"; exit 1; }
    done
done

for i in "${!HOSTNAMES[@]}"; do
    source_hostname=${HOSTNAMES[i]}
    source_user=${USERS[i]}
    source_ip=${IPS[i]}
    for j in "${!HOSTNAMES[@]}"; do
        target_hostname=${HOSTNAMES[j]}
        target_user=${USERS[j]}
        target_ip=${IPS[j]}
        # 验证无密码登录
        echo "++Verify passwordless login from $source_hostname to $target_hostname..."
        ssh -o StrictHostKeyChecking=no "$source_user@$source_hostname" "
            ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no $target_user@$target_hostname '
                echo Passwordless SSH setup successful from $source_hostname to $target_hostname!
            '
        " || { echo "Passwordless SSH setup failed from $source_hostname to $target_hostname"; exit 1; }
        echo "++Verify passwordless login from $source_ip to $target_ip..."
        ssh -o StrictHostKeyChecking=no "$source_user@$source_ip" "
            ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no $target_user@$target_ip '
                echo Passwordless SSH setup successful from $source_ip to $target_ip!
            '
        " || { echo "Passwordless SSH setup failed from $source_ip to $target_ip"; exit 1; }
    done
done

echo "############## SETUP NO_PASS END #############"