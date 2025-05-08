#!/bin/bash

set -e
echo "############## SETUP JDK START #############"

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

# 配置 JAVA_HOME 函数
configure_java_home() {
    JDK_FILE_HOME_PATH="/usr/lib/jvm/java-8-openjdk-amd64"
    # 使用 sed 命令更新或添加 JAVA_HOME 变量
    if grep -q "^export JAVA_HOME=" /etc/profile; then
        sudo sed -i "s#^export JAVA_HOME=.*#export JAVA_HOME=${JDK_FILE_HOME_PATH}#" /etc/profile
    else
        echo "export JAVA_HOME=${JDK_FILE_HOME_PATH}" | sudo tee -a /etc/profile
    fi

    # 更新 PATH 变量以包含 JAVA_HOME/bin
    if ! grep -q "^export PATH=.*\$JAVA_HOME/bin" /etc/profile; then
        echo "export PATH=\$PATH:\$JAVA_HOME/bin" | sudo tee -a /etc/profile
    fi

    # 重新加载 /etc/profile 文件以应用更改
    source /etc/profile

    # 验证 JAVA_HOME 设置
    echo "JAVA_HOME is set to: $JAVA_HOME"
}


main() {
    for i in "${!HOSTNAMES[@]}"; do
        hostname=${HOSTNAMES[i]}
        user=${USERS[i]}
        ip=${IPS[i]}
        ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no "$user@$hostname" "
            echo '++$user@$hostname Beginning Installation...'
            if javac -version 2>&1 | grep -q '^javac 1\.8'; then
                echo '++JDK already installed'
            else
                sudo apt install openjdk-8-jdk-headless -y
            fi
            $(declare -f configure_java_home); configure_java_home
        "
    done
}

# 执行主函数
main

echo "############## SETUP JDK END #############"
