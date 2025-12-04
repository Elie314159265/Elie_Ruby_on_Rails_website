# ========================================
# main.tf - Route 53ドメイン + ACM SSL対応版
# ========================================
# 
# 【新機能】
# 1. ✅ Route 53でドメイン自動登録（オプション）
# 2. ✅ AWS Certificate Manager (ACM)で無料SSL証明書
# 3. ✅ Application Load Balancer (ALB)追加
# 4. ✅ 完全自動化（Let's Encrypt不要）
# 
# 【注意】
# - Route 53ドメイン登録は別途料金が発生します
# - 既存ドメインがある場合は、var.use_existing_domain = true に設定
# 
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
# Route 53 - ドメイン登録とホストゾーン
# ========================================

# ✅ 既存のホストゾーンを参照（use_existing_domain = true の場合）
data "aws_route53_zone" "existing" {
  count = var.use_existing_domain && var.domain_name != "" ? 1 : 0
  name  = var.domain_name
}

# ✅ 新規: Route 53ドメイン登録（オプション）
resource "aws_route53domains_registered_domain" "main" {
  count = var.register_new_domain ? 1 : 0

  domain_name = var.domain_name

  name_server {
    name = aws_route53_zone.main[0].name_servers[0]
  }
  name_server {
    name = aws_route53_zone.main[0].name_servers[1]
  }
  name_server {
    name = aws_route53_zone.main[0].name_servers[2]
  }
  name_server {
    name = aws_route53_zone.main[0].name_servers[3]
  }

  # ドメイン自動更新
  auto_renew = true

  tags = {
    Name = "${var.project_name}-domain"
  }

  # 注意: ドメイン登録には5-15分かかることがあります
  lifecycle {
    prevent_destroy = true
  }
}

# ✅ 新規: Route 53 Hosted Zone（use_existing_domain = false の場合のみ作成）
resource "aws_route53_zone" "main" {
  count = !var.use_existing_domain && var.domain_name != "" ? 1 : 0
  name  = var.domain_name

  tags = {
    Name = "${var.project_name}-hosted-zone"
  }
}

# ✅ ローカル変数: 既存または新規のゾーンIDを選択
locals {
  zone_id = var.use_existing_domain ? (
    length(data.aws_route53_zone.existing) > 0 ? data.aws_route53_zone.existing[0].zone_id : ""
  ) : (
    length(aws_route53_zone.main) > 0 ? aws_route53_zone.main[0].zone_id : ""
  )
}

# ✅ 新規: Aレコード（ALB向け）
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

# ✅ 新規: wwwサブドメイン
resource "aws_route53_record" "www" {
  count   = var.domain_name != "" && var.create_www_subdomain ? 1 : 0
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
# ACM - SSL証明書（無料）
# ========================================

# ✅ 新規: ACM証明書リクエスト
resource "aws_acm_certificate" "main" {
  count             = var.domain_name != "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  # wwwサブドメイン対応
  subject_alternative_names = var.create_www_subdomain ? ["www.${var.domain_name}"] : []

  tags = {
    Name = "${var.project_name}-certificate"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ✅ 新規: DNS検証レコード自動作成
resource "aws_route53_record" "cert_validation" {
  for_each = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.zone_id
}

# ✅ 新規: 証明書検証完了待機
resource "aws_acm_certificate_validation" "main" {
  count                   = var.domain_name != "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  # ドメイン登録が完了してからDNS検証を開始
  depends_on = [
    aws_route53domains_registered_domain.main,
    aws_route53_record.cert_validation
  ]

  # タイムアウトを設定（デフォルト75分）
  timeouts {
    create = "45m"
  }
}

# ========================================
# Network - VPC, Subnets
# ========================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ✅ 変更: ALB用に2つのPublic Subnetを作成（Multi-AZ）
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-a"
  }
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}c"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-c"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
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

# ✅ 変更: ALB用Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  # HTTP (HTTPSへのリダイレクト用)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere (redirect to HTTPS)"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# ✅ 変更: EC2用Security Group（ALBからのトラフィックのみ許可）
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for EC2 instance (ALB traffic only)"
  vpc_id      = aws_vpc.main.id

  # ALBからのHTTPトラフィックのみ許可
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow traffic from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# ========================================
# IAM Roles
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
# Application Load Balancer
# ========================================

# ✅ 新規: Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_c.id]

  enable_deletion_protection = false
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# ✅ 新規: Target Group
resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/up"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# ✅ 新規: EC2インスタンスをターゲットグループに登録
resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.rails_app.id
  port             = 3000
}

# ✅ 新規: ALB Listener (HTTP → HTTPS リダイレクト)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
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

# ✅ 新規: ALB Listener (HTTPS)
resource "aws_lb_listener" "https" {
  count             = var.domain_name != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.main[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  depends_on = [aws_acm_certificate_validation.main]
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

  # ✅ 変更: user_dataからNginx/Certbot削除（ALB+ACMで不要）
  user_data = templatefile("${path.module}/user_data_alb.sh", {
    rails_master_key = var.rails_master_key
  })

  tags = {
    Name = "${var.project_name}-ec2"
    Project = var.project_name 
  }
}

# ✅ 注意: Elastic IPは不要（ALBのDNS名を使用）
# resource "aws_eip" "rails_app" は削除
