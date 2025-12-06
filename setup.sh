#!/bin/bash
# ========================================
# Rails + AWS デプロイ環境 初期設定スクリプト
# ========================================

set -e  # エラーで停止

echo "Rails+AWSデプロイ環境の初期設定を開始します"
echo ""

# ========================================
# 1. プロジェクト名の取得
# ========================================

read -p "プロジェクト名を入力してください（例：my-website）: " PROJECT_NAME
export PROJECT_NAME="$PROJECT_NAME"
if [ -z "$PROJECT_NAME" ]; then
  echo "プロジェクト名が入力されていません"
  exit 1
fi

echo "プロジェクト名: $PROJECT_NAME"
echo ""

# ========================================
# 2. ドメイン名の取得（オプション）
# ========================================

read -p "ドメインを使用しますか？ (y/n): " USE_DOMAIN

if [ "$USE_DOMAIN" = "y" ]; then
  read -p "ドメイン名を入力: " DOMAIN_NAME
else
  DOMAIN_NAME=""
fi
export DOMAIN_NAME="$DOMAIN_NAME"

# ========================================
# 3. .gitignore の更新
# ========================================

echo "=== .gitignore を更新しています ==="

# 既存の.gitignoreに追記（重複チェック）
if ! grep -q "# Terraform" .gitignore 2>/dev/null; then
  cat >> .gitignore << 'EOF'

# Terraform
terraform/.terraform/
terraform/.terraform.lock.hcl
terraform/terraform.tfstate
terraform/terraform.tfstate.backup
terraform/*.tfplan
terraform/terraform.tfvars

# AWS
.aws/

# Editor
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db
EOF
  echo ".gitignore を更新しました"
else
  echo ".gitignore は既に設定済みです"
fi

echo ""

# ========================================
# 4. Terraform のインストール
# ========================================

# Terraformインストールの前に依存チェック
if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
  echo "wget または curl が必要です"
  exit 1
fi

echo "=== Terraform をインストールしています ==="

if command -v terraform &> /dev/null; then
  CURRENT_VERSION=$(terraform version | head -n 1 | awk '{print $2}')
  echo "Terraform は既にインストールされています: $CURRENT_VERSION"
else
  # OS判定
  OS="$(uname -s)"
  case "${OS}" in
    Linux*)
      echo "Linux環境を検出しました"
      
      # アーキテクチャ判定
      ARCH="$(uname -m)"
      case "${ARCH}" in
        x86_64)
          TF_ARCH="amd64"
          ;;
        aarch64|arm64)
          TF_ARCH="arm64"
          ;;
        *)
          echo "サポートされていないアーキテクチャ: ${ARCH}"
          exit 1
          ;;
      esac
      
      # Terraformダウンロード＆インストール
      TF_VERSION="1.7.0"
      wget "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${TF_ARCH}.zip"
      unzip "terraform_${TF_VERSION}_linux_${TF_ARCH}.zip"
      sudo mv terraform /usr/local/bin/
      rm "terraform_${TF_VERSION}_linux_${TF_ARCH}.zip"
      ;;
      
    Darwin*)
      echo "macOS環境を検出しました"
      
      # Homebrewでインストール
      if command -v brew &> /dev/null; then
        brew tap hashicorp/tap
        brew install hashicorp/tap/terraform
      else
        echo "Homebrewがインストールされていません"
        echo "Homebrewをインストールするか、手動でTerraformをインストールしてください"
        exit 1
      fi
      ;;
      
    *)
      echo "サポートされていないOS: ${OS}"
      exit 1
      ;;
  esac
  
  echo "Terraform をインストールしました"
fi

# バージョン確認
terraform version
echo ""

# ========================================
# 5. Terraform ディレクトリ＆ファイル作成
# ========================================

echo "=== Terraform ファイルを作成しています ==="

mkdir -p terraform
cd terraform

# terraform.tfvars 作成
if [ -f terraform.tfvars ]; then
  echo "terraform.tfvars は既に存在します（スキップ）"
else
  # RAILS_MASTER_KEY 取得
  if [ -f ../config/master.key ]; then
    MASTER_KEY=$(cat ../config/master.key)
    export MASTER_KEY
    RAILS_MASTER_KEY=$MASTER_KEY
    export RAILS_MASTER_KEY
  else
    echo "config/master.key が見つかりません"
    read -p "RAILS_MASTER_KEY を入力してください: " MASTER_KEY
    export MASTER_KEY
    RAILS_MASTER_KEY=$MASTER_KEY
    export RAILS_MASTER_KEY
  fi
  
  cat > terraform.tfvars << EOF
aws_region       = "ap-northeast-1"
environment      = "production"
project_name     = "$PROJECT_NAME"
instance_type    = "t3.micro"
rails_master_key = "$MASTER_KEY"

# ドメイン設定（ドメインを使わない場合は空欄）
domain_name          = "$DOMAIN_NAME"
register_new_domain  = false
use_existing_domain  = true
create_www_subdomain = true
EOF
  
  echo "terraform.tfvars を作成しました"
fi

# terraform.tfvars.example 作成
if [ ! -f terraform.tfvars.example ]; then
  cat > terraform.tfvars.example << 'EOF'
# Terraform 変数の例
# このファイルをコピーして terraform.tfvars を作成してください

aws_region       = "ap-northeast-1"
environment      = "production"
project_name     = "your-project-name"
instance_type    = "t3.micro"
rails_master_key = "your-rails-master-key-here"

# ドメイン設定
domain_name          = ""  # 例: "example.com"
register_new_domain  = false
use_existing_domain  = true
create_www_subdomain = true
EOF
  
  echo "terraform.tfvars.example を作成しました"
fi

# その他のTerraformファイルが存在しない場合のみ作成
for file in main.tf outputs.tf variables.tf ec2_init.sh; do
  if [ ! -f "$file" ]; then
    touch "$file"
    echo "$file を作成しました"
  else
    echo "$file は既に存在します（スキップ）"
  fi
done

echo ""


# main.tfの作成

cat > main.tf << 'EOF'
# ========================================
# main.tf 
# ========================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

# Ubuntu AMI取得
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ========================================
# Route 53 - 既存のHosted Zoneを参照
# ========================================

# ドメイン購入時に自動作成された（あるいは手動作成した）ゾーンを参照します
data "aws_route53_zone" "existing" {
  count        = var.domain_name != "" ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

locals {
  zone_id = var.domain_name != "" ? data.aws_route53_zone.existing[0].zone_id : ""
}

# Aレコード（ALB向け）
resource "aws_route53_record" "main" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# wwwサブドメイン
resource "aws_route53_record" "www" {
  count   = var.create_www_subdomain ? 1 : 0
  zone_id = local.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# ========================================
# ACM - SSL証明書
# ========================================

resource "aws_acm_certificate" "main" {
  count = var.domain_name != "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = var.create_www_subdomain ? [
    "www.${var.domain_name}"
  ] : []

  lifecycle {
    create_before_destroy = true
  }
}

# DNS検証用レコードの作成
resource "aws_route53_record" "cert_validation" {
  for_each = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}
  zone_id = local.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]

  allow_overwrite = true
}

# 証明書発行の完了待ち
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]

  timeouts {
    create = "45m"
  }
}

# ========================================
# CloudWatch Logs (ロググループ管理)
# ========================================
resource "aws_cloudwatch_log_group" "system" {
  name              = "/aws/ec2/${var.project_name}/system"
  retention_in_days = 30  # 30日で古いログを自動削除（節約）

  tags = {
    Name = "${var.project_name}-log-group"
  }
}

# ========================================
# Network - VPC & Subnets
# ========================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-a" }
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}c"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-c" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

# ========================================
# Security Groups
# ========================================

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB Security Group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "EC2 Security Group (Allow ALB only)"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ========================================
# IAM Roles (SSM & CloudWatch)
# ========================================

resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.project_name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# ========================================
# ALB (Load Balancer)
# ========================================

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_c.id]
}

resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path    = "/up"
    matcher = "200"
  }
}

resource "aws_lb_listener" "https" {
  count = var.domain_name != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main[0].certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ========================================
# EC2 Instance
# ========================================

resource "aws_instance" "rails_app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id              = aws_subnet.public_a.id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = templatefile("${path.module}/ec2_init.sh", {
    rails_master_key = var.rails_master_key
    project_name     = var.project_name
  })

  tags = {
    Name    = "${var.project_name}-ec2"
    Project = var.project_name 
  }
}

# EC2とALBターゲットグループの紐付け
resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.rails_app.id
  port             = 3000
}
EOF


# ec2_init.shの自動作成
cat > ec2_init.sh << 'EOF'
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

echo "=== Installing AWS CLI v2 ==="
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get install -y unzip
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
echo "AWS CLI version: $(aws --version)"


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
curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
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
            "log_group_name": "/aws/ec2/${project_name}/system",
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

echo "setup completed!"
EOF




# outputs.tfの自動作成
cat > outputs.tf << 'EOF'
# ========================================
# outputs.tf 
# ========================================

# ========================================
# EC2関連
# ========================================

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.rails_app.id
}

output "ssm_connection_command" {
  description = "AWS Systems Manager Session Manager connection command"
  value       = "aws ssm start-session --target ${aws_instance.rails_app.id} --region ${var.aws_region}"
}

# ========================================
# ALB関連
# ========================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.main.arn
}

# ========================================
# Route 53関連
# ========================================

output "route53_zone_id" {
  description = "Route 53 Hosted Zone ID"
  value       = local.zone_id
}

output "route53_name_servers" {
  description = "Route 53 Name Servers"
  value       = data.aws_route53_zone.existing[0].name_servers
}

# ========================================
# ACM関連
# ========================================

output "acm_certificate_arn" {
  description = "ARN of the ACM SSL certificate"
  value       = aws_acm_certificate.main.arn
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate"
  value       = aws_acm_certificate.main.status
}

# ========================================
# Application URL
# ========================================

output "application_url" {
  description = "Application URL (use this to access your app)"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"
}

output "www_url" {
  description = "WWW subdomain URL"
  value       = var.create_www_subdomain ? "https://www.${var.domain_name}" : "N/A"
}

# ========================================
# デプロイ完了メッセージ
# ========================================

output "deployment_info" {
  description = "Deployment summary"
  value       = "Deployment completed! Access your app at: https://${var.domain_name}"
}
EOF



# variables.tfの自動作成
cat > variables.tf << 'EOF'
# ========================================
# variables.tf 
# ========================================

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro" # Free tier eligible: t2.micro / Production: t3.small
}

variable "rails_master_key" {
  description = "Rails master key for encrypted credentials"
  type        = string
  sensitive   = true
}

# ========================================
# Route 53 & Domain関連
# ========================================

variable "domain_name" {
  description = "Domain name for the application (e.g., example.com)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]\\.[a-z]{2,}$", var.domain_name)) || var.domain_name == ""
    error_message = "Domain name must be a valid domain (e.g., example.com)"
  }
}

# Route 53でドメインを新規登録するか
variable "register_new_domain" {
  description = "Register a new domain via Route 53 (costs apply, see pricing below)"
  type        = bool
  default     = false
  
  # Route 53 ドメイン登録料金（年額）:
  # .com: $13/年
  # .net: $13/年
  # .org: $13/年
  # .jp: $40/年
  # .co.jp: $60/年
  # 
  # 詳細: https://d32ze2gidvkk54.cloudfront.net/Amazon_Route_53_Domain_Registration_Pricing_20140731.pdf
}

# 既存ドメインを使用するか（Route53やお名前.com等で取得済み）
variable "use_existing_domain" {
  description = "Use an existing domain (registered outside of AWS)"
  type        = bool
  default     = true
}

# wwwサブドメインを作成するか
variable "create_www_subdomain" {
  description = "Create www subdomain (e.g., www.example.com)"
  type        = bool
  default     = true
}
EOF







# ========================================
# 6. Dockerfile の作成
# ========================================

echo "=== Dockerfile を作成しています ==="

if [ -f Dockerfile ]; then
  echo "Dockerfile は既に存在します（スキップ）"
else
  cat > Dockerfile << 'EOF'

ARG RUBY_VERSION=3.4.7
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
      libjemalloc2 \
      libvips \
      curl && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Build stage
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libyaml-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompile assets
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Final stage
FROM base

# Create rails user
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

USER 1000:1000

# Copy artifacts from build stage
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Entrypoint prepares the database
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Expose port
EXPOSE 3000

# Start server
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
EOF
  
  echo "Dockerfile を作成しました"
fi

echo ""

# ========================================
# 7. .dockerignore の作成
# ========================================

echo "=== .dockerignore を作成しています ==="

if [ -f .dockerignore ]; then
  echo ".dockerignore は既に存在します（スキップ）"
else
  cat > .dockerignore << 'EOF'
# Git
.git/
.gitignore
.gitattributes

# Bundler
.bundle

# Environment
.env*
!.env.example

# Rails
/log/*
!/log/.keep
/tmp/*
!/tmp/.keep
/tmp/pids/*
!/tmp/pids/.keep
/storage/*
!/storage/.keep
/tmp/storage/*
!/tmp/storage/.keep

# Public assets
/public/assets
/public/packs
/public/packs-test

# Node modules
/node_modules/
/app/assets/builds/*
!/app/assets/builds/.keep

# Editor
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# GitHub
/.github

# Terraform
/terraform

# Credentials
/config/master.key
/config/credentials/*.key
EOF
  
  echo ".dockerignore を作成しました"
fi

echo ""

# ========================================
# 8. GitHub Actions ワークフローディレクトリ作成
# ========================================

echo "=== GitHub Actions ワークフローディレクトリを作成しています ==="

mkdir -p .github/workflows
touch .github/workflows/deploy-app.yml
touch .github/workflows/terraform-plan.yml

if [ ! -f .github/workflows/.gitkeep ]; then
  touch .github/workflows/.gitkeep
  echo ".github/workflows/ を作成しました"
else
  echo ".github/workflows/ は既に存在します"
fi

# URLの決定（ドメインがない場合はALB等の確認メッセージを入れる）
if [ -n "$DOMAIN_NAME" ]; then
  APP_URL_VAL="https://$DOMAIN_NAME"
else
  APP_URL_VAL="(Check Terraform Output for ALB URL)"
fi

cat > .github/workflows/deploy-app.yml << 'EOF'
name: Deploy Application

on:
  push:
    branches:
      - main
    paths:
      - 'app/**'
      - 'config/**'
      - 'db/**'
      - 'lib/**'
      - 'public/**'
      - 'Gemfile'
      - 'Gemfile.lock'
      - 'Dockerfile'
      - '.dockerignore'
  workflow_dispatch:
    inputs:
      instance_id:
        description: 'EC2 Instance ID (optional)'
        required: false
        type: string

env:
  AWS_REGION: ap-northeast-1
  PROJECT_NAME: REPLACE_ME_PROJECT_NAME
  DOMAIN_NAME: REPLACE_ME_DOMAIN_NAME

jobs:
  deploy:
    name: Deploy Rails Application
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Get EC2 Instance ID
        id: get_instance
        run: |
          if [ -n "${{ inputs.instance_id }}" ]; then
            INSTANCE_ID="${{ inputs.instance_id }}"
            echo "Using manually provided instance ID: $INSTANCE_ID"
          else
            INSTANCE_ID=$(aws ec2 describe-instances \
              --filters "Name=tag:Project,Values=${{ env.PROJECT_NAME }}" \
                        "Name=instance-state-name,Values=running" \
              --query "Reservations[0].Instances[0].InstanceId" \
              --output text)
            
            if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
              echo "EC2 instance not found!"
              echo "Please ensure infrastructure is created via Terraform first."
              exit 1
            fi
            
            echo "Auto-detected instance ID: $INSTANCE_ID"
          fi
          
          echo "instance_id=$INSTANCE_ID" >> $GITHUB_OUTPUT
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Build Docker Image
        run: |
          docker build -t ${{ env.PROJECT_NAME }}:latest .
          docker save ${{ env.PROJECT_NAME }}:latest | gzip > ${{ env.PROJECT_NAME }}.tar.gz
      
      - name: Check EC2 Instance Status
        run: |
          echo "Checking EC2 instance status..."
          STATUS=$(aws ec2 describe-instance-status \
            --instance-ids ${{ steps.get_instance.outputs.instance_id }} \
            --query "InstanceStatuses[0].InstanceStatus.Status" \
            --output text)
          
          if [ "$STATUS" != "ok" ]; then
            echo "⚠️ Instance status is: $STATUS"
            echo "Waiting for instance to be ready..."
            aws ec2 wait instance-status-ok \
              --instance-ids ${{ steps.get_instance.outputs.instance_id }}
          fi
          
          echo "EC2 instance is ready!"
      
      - name: Upload Docker Image to S3
        run: |
          BUCKET_NAME="${{ env.PROJECT_NAME }}-deploy-temp-$(date +%s)"
          aws s3 mb s3://$BUCKET_NAME
          aws s3 cp ${{ env.PROJECT_NAME }}.tar.gz s3://$BUCKET_NAME/
          echo "DEPLOY_BUCKET=$BUCKET_NAME" >> $GITHUB_ENV
      
      - name: Deploy via Systems Manager
        run: |
          echo "Deploying to instance: ${{ steps.get_instance.outputs.instance_id }}"
          
          COMMAND_ID=$(aws ssm send-command \
            --instance-ids ${{ steps.get_instance.outputs.instance_id }} \
            --document-name "AWS-RunShellScript" \
            --parameters commands="[
              'echo \"=== Starting Deployment ===\"',
              'cd /home/ubuntu/app',
              'echo \"Downloading Docker image...\"',
              'aws s3 cp s3://${{ env.DEPLOY_BUCKET }}/${{ env.PROJECT_NAME }}.tar.gz . --quiet',
              'echo \"Loading Docker image...\"',
              'docker load < ${{ env.PROJECT_NAME }}.tar.gz',
              'echo \"Stopping old container...\"',
              'docker stop rails-app 2>/dev/null || true',
              'docker rm rails-app 2>/dev/null || true',
              'echo \"Starting new container...\"',
              'docker run -d --name rails-app --restart unless-stopped -p 3000:3000 -e RAILS_ENV=production -e RAILS_MASTER_KEY=${{ secrets.RAILS_MASTER_KEY }} ${{ env.PROJECT_NAME }}:latest',
              'sleep 5',
              'echo \"Running health check...\"',
              'curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/up | grep -q "200"',
              'echo \"Cleaning up...\"',
              'rm -f ${{ env.PROJECT_NAME }}.tar.gz',
              'docker image prune -f --filter \"until=24h\"',
              'echo \"=== Deployment Complete ===\"'
            ]" \
            --output text \
            --query "Command.CommandId")
          
          echo "Command ID: $COMMAND_ID"
          echo "command_id=$COMMAND_ID" >> $GITHUB_ENV
          
          echo "Waiting for deployment to complete..."
          aws ssm wait command-executed \
            --command-id $COMMAND_ID \
            --instance-id ${{ steps.get_instance.outputs.instance_id }} \
            --cli-read-timeout 600
          
          STATUS=$(aws ssm get-command-invocation \
            --command-id $COMMAND_ID \
            --instance-id ${{ steps.get_instance.outputs.instance_id }} \
            --query "Status" \
            --output text)
          
          echo "Deployment status: $STATUS"
          
          if [ "$STATUS" != "Success" ]; then
            echo "Deployment failed!"
            exit 1
          fi
          
          echo "Deployment successful!"
      
      - name: Cleanup S3 Bucket
        if: always()
        run: |
          if [ ! -z "${{ env.DEPLOY_BUCKET }}" ]; then
            echo "Cleaning up S3 bucket..."
            aws s3 rm s3://${{ env.DEPLOY_BUCKET }}/${{ env.PROJECT_NAME }}.tar.gz --quiet || true
            aws s3 rb s3://${{ env.DEPLOY_BUCKET }} --force || true
            echo "Cleanup complete"
          fi
      
      - name: Cleanup
        if: always()
        run: |
          rm -f ${{ env.PROJECT_NAME }}.tar.gz
      
      - name: Deployment Summary
        if: always()
        run: |
          echo "## Deployment Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Instance ID**: ${{ steps.get_instance.outputs.instance_id }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Application URL**: https://${{ env.DOMAIN_NAME }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Command ID**: ${{ env.command_id }}" >> $GITHUB_STEP_SUMMARY
EOF

sed "s/REPLACE_ME_DOMAIN_NAME/$DOMAIN_NAME/g" .github/workflows/deploy-app.yml > .github/workflows/deploy-app.yml.tmp && mv .github/workflows/deploy-app.yml.tmp .github/workflows/deploy-app.yml
sed "s/REPLACE_ME_PROJECT_NAME/$PROJECT_NAME/g" .github/workflows/deploy-app.yml > .github/workflows/deploy-app.yml.tmp && mv .github/workflows/deploy-app.yml.tmp .github/workflows/deploy-app.yml



cat > .github/workflows/terraform-plan.yml << 'EOF'
name: Terraform Plan

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
  workflow_dispatch:

env:
  AWS_REGION: ap-northeast-1
  TERRAFORM_VERSION: 1.9.0
  # 後にsedで置換
  DOMAIN_NAME: REPLACE_ME_DOMAIN_NAME

jobs:
  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    
    defaults:
      run:
        working-directory: terraform
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}
          terraform_wrapper: false
      
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        continue-on-error: true
      
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Validate
        run: terraform validate
      
      - name: Terraform Plan
        id: plan
        run: |
          terraform plan \
            -var="rails_master_key=${{ secrets.RAILS_MASTER_KEY }}" \
            -var="domain_name=${{ env.DOMAIN_NAME }}" \
            -out=tfplan
        continue-on-error: true
      
      - name: Upload Terraform Plan
        uses: actions/upload-artifact@v4
        with:
          name: tfplan-${{ github.sha }}
          path: terraform/tfplan
          retention-days: 30
      
      - name: Terraform Plan Summary
        if: always()
        run: |
          echo "## Terraform Plan Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          if [ "${{ steps.plan.outcome }}" == "success" ]; then
            echo "Terraform Plan succeeded" >> $GITHUB_STEP_SUMMARY
            echo "" >> $GITHUB_STEP_SUMMARY
            echo "### Next Steps" >> $GITHUB_STEP_SUMMARY
            echo "1. Review the plan output above" >> $GITHUB_STEP_SUMMARY
            echo "2. If approved, run locally:" >> $GITHUB_STEP_SUMMARY
            echo "   \`\`\`bash" >> $GITHUB_STEP_SUMMARY
            echo "   cd terraform" >> $GITHUB_STEP_SUMMARY
            echo "   terraform apply" >> $GITHUB_STEP_SUMMARY
            echo "   \`\`\`" >> $GITHUB_STEP_SUMMARY
          else
            echo "Terraform Plan failed" >> $GITHUB_STEP_SUMMARY
            echo "" >> $GITHUB_STEP_SUMMARY
            echo "Please check the logs above and fix any errors." >> $GITHUB_STEP_SUMMARY
          fi
      
      - name: Check Plan Status
        if: steps.plan.outcome != 'success'
        run: exit 1
EOF
sed "s/REPLACE_ME_DOMAIN_NAME/$DOMAIN_NAME/g" .github/workflows/terraform-plan.yml > .github/workflows/terraform-plan.yml.tmp && mv .github/workflows/terraform-plan.yml.tmp .github/workflows/terraform-plan.yml





echo ""

# ========================================
# 9. 設定確認
# ========================================

echo "========================================="
echo "初期設定が完了しました！"
echo "========================================="
echo ""
echo "設定内容:"
echo "  プロジェクト名: $PROJECT_NAME"
echo "  ドメイン名: ${DOMAIN_NAME:-なし}"
echo "  リージョン: ap-northeast-1"
echo ""
echo "作成されたファイル:"
echo "  .gitignore（更新）"
echo "  terraform/terraform.tfvars"
echo "  terraform/terraform.tfvars.example"
echo "  terraform/main.tf"
echo "  terraform/variables.tf"
echo "  terraform/outputs.tf"
echo "  terraform/ec2_init.sh"
echo "  Dockerfile"
echo "  .dockerignore"
echo "  .github/workflows/deploy-app.yml"
echo "  .github/workflows/terraform-plan.yml"
echo ""
echo "インストールされたツール:"
terraform version | head -n 1
echo ""
echo "次のステップ:"
echo ""
echo "  1. 手動でまずterraform init,plan,applyを実行する"
echo "     cd terraform/"
echo "     terraform init"
echo "     terraform plan"
echo "     terraform apply #ここでAWSリソースが作成される"
echo ""
echo "  2. GitHubリポジトリにpush"
echo "     git add ."
echo "     git commit -m \"Initial setup for AWS deployment\""
echo "     git push origin main"
echo "  この時GitHubActionsのCI/CDパイプラインが走ります。"
echo ""
echo "========================================="
echo "セットアップスクリプト完了！"
echo "========================================="
