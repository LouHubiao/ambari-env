set -e

echo "############## UPDATE NGINX start #############"

REPO_DIR="/data/rpm-package"
FILE_PATH="/scripts/.init_done"
NGINX_BIN="/usr/sbin/nginx"
NGINX_CONF="/etc/nginx/conf.d/yum_repo.conf"

if [[ -f "$FILE_PATH" ]]; then
  while IFS= read -r line; do
    # 拆分主机名和IP地址
    HOSTNAME=$(echo "$line" | cut -d'@' -f1)
    IP=$(echo "$line" | cut -d'@' -f2)
    HOSTNAMES+=("$HOSTNAME")
    IPS+=("$IP")
  done <"$FILE_PATH"
else
  echo "文件 $FILE_PATH 不存在"
  exit 1
fi

# 从IP列表中选取最小的IP作为服务端
IFS=$'\n' sorted_ips=($(sort <<<"${IPS[*]}"))
unset IFS
SERVER_IP="${sorted_ips[0]}"
CLIENT_IPS=("${sorted_ips[@]:1}")

# 停止已有的nginx进程
stop_existing_nginx() {
    if pgrep nginx &> /dev/null; then
        echo "检测到已有的nginx进程，正在停止..."
        pkill nginx
    fi
}

# 配置Nginx
configure_nginx() {
    cat <<EOL | tee ${NGINX_CONF}
server {
    listen 80;
    server_name localhost;
    location / {
        autoindex on;
        alias ${REPO_DIR}/;
    }
    location /cliservice {
        proxy_pass http://${SERVER_IP}:10001;
        proxy_http_version 1.1;  
        proxy_set_header Connection "keep-alive";  
        proxy_set_header Host \$host;  
        proxy_set_header Upgrade \$http_upgrade;  
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for; 

        client_max_body_size 100m;  
 
        proxy_connect_timeout 600;  
        proxy_send_timeout 600;  
        proxy_read_timeout 600;
    }
}
EOL
}

# 启动Nginx服务
start_nginx() {
    stop_existing_nginx
    ${NGINX_BIN}
    echo "Nginx服务更新完成并已启动。"
}

# 验证Nginx是否正在运行
verify_nginx() {
    if pgrep nginx &> /dev/null; then
        echo "Nginx 正在运行。"
    else
        echo "Nginx 未能启动，请检查配置。"
        exit 1
    fi
}

# 主函数
main() {
    configure_nginx
    start_nginx
    verify_nginx
}

main "$@"

echo "############## UPDATE NGINX end #############"