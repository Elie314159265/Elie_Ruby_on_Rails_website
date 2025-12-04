#!/bin/bash
set -e


# ログ設定
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting EC2 User Data Script (ALB Mode) ==="

# システムアップデート
apt-get update
apt-get upgrade -y

# 必要なパッケージのインストール
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git

# Docker インストール
echo "=== Installing Docker ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Dockerをubuntuユーザーで実行可能に
usermod -aG docker ubuntu

# Docker起動と自動起動設定
systemctl start docker
systemctl enable docker

# Docker Composeのインストール
echo "=== Installing Docker Compose ==="
DOCKER_COMPOSE_VERSION="2.24.5"
curl -L "https://github.com/docker/compose/releases/download/v$${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# アプリケーション用ディレクトリ作成
mkdir -p /home/ubuntu/app
chown ubuntu:ubuntu /home/ubuntu/app

# 環境変数設定
echo "RAILS_MASTER_KEY=${rails_master_key}" > /home/ubuntu/app/.env
chmod 600 /home/ubuntu/app/.env
chown ubuntu:ubuntu /home/ubuntu/app/.env

# ========================================
# Nginx/Certbotは不要（ALB + ACMで代替）
# ========================================

# CloudWatch Logs Agent
echo "=== Installing CloudWatch Agent ==="
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# CloudWatch Agent設定（アプリケーションログのみ）
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CLOUDWATCH_CONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/rails-portfolio/system",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
CLOUDWATCH_CONFIG

# CloudWatch Agent起動
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Systems Manager Agent確認
systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service

echo "=== User Data Script Completed ==="
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker-compose --version)"
echo ""
echo "=== Architecture ==="
echo "ALB (HTTPS:443) → EC2 (HTTP:3000) → Rails App"
echo ""
echo "=== SSL/TLS ==="
echo "Managed by: AWS Certificate Manager (ACM)"
echo "Certificate: Auto-renewed by AWS"
echo ""
echo "=== Next Steps ==="
echo "1. Deploy your Rails application via GitHub Actions"
echo "2. Access via ALB DNS or custom domain"
echo "3. Monitor health checks in ALB Target Group"
