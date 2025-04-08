# Step 1: 修改 sshd_config 文件
sudo sed -i 's/^PubkeyAuthentication.*$/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Step 2: 如果配置不存在，则添加新行
grep -q '^PubkeyAuthentication' /etc/ssh/sshd_config || echo 'PubkeyAuthentication yes' | sudo tee -a /etc/ssh/sshd_config

# Step 3: 重启 SSH 服务
sudo systemctl restart ssh

# Step 4: 验证配置
grep '^PubkeyAuthentication' /etc/ssh/sshd_config

# 判断公钥内容是否存在，不存在则写入
grep -q -F "$(cat .ssh/id_rsa.pub)" .ssh/authorized_keys || cat .ssh/id_rsa.pub >> .ssh/authorized_keys

if ! grep -q "$USER ALL=(ALL) NOPASSWD:ALL" /etc/sudoers; then
    echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
fi