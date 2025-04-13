#!/bin/bash

set -e
echo "############## SETUP PYTHON START #############"

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
            if command -v python2 &> /dev/null; then
                echo '++Python2 already installed'
            else
                sudo apt update
                sudo apt install -y python2
                sudo update-alternatives --install /usr/bin/python python /usr/bin/python2 1
                if command -v python2 &> /dev/null; then
                    echo "++Python2 already installed."
                else
                    echo "++Failed to install Python 2."
                    exit 1
                fi
            fi
            if command -v pip2 &> /dev/null; then
                echo '++pip2 already installed'
            else
                curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py
                if [ $? -ne 0 ]; then
                    echo '++Failed to download get-pip.py.'
                    exit 1
                fi
                sudo python2 get-pip.py
                if [ $? -eq 0 ]; then
                    echo '++pip2 installed successfully.'
                else
                    echo '++Failed to install pip2.'
                    exit 1
                fi

                # 清理安装文件
                rm -f get-pip.py
            fi
            python2 -m pip install PyMySQL
        "
    done
}

# 执行主函数
main

echo "############## SETUP PYTHON END #############"
