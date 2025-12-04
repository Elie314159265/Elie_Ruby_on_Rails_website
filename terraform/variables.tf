# ========================================
# variables.tf - Route 53 + ACM対応版
# ========================================
# 
# 【新規変数】
# 1. register_new_domain - Route 53でドメイン新規登録するか
# 2. use_existing_domain - 既存ドメインを使用するか
# 3. create_www_subdomain - wwwサブドメインを作成するか
# 
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
  default     = "rails-portfolio"
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

# ✅ 新規: Route 53でドメインを新規登録するか
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

# ✅ 新規: 既存ドメインを使用するか（お名前.com等で取得済み）
variable "use_existing_domain" {
  description = "Use an existing domain (registered outside of AWS)"
  type        = bool
  default     = false
  
  # true の場合: 
  # - Route 53 Hosted Zoneのみ作成（年$0.50）
  # - 既存ドメインのネームサーバーをRoute 53に変更する必要があります
}

# ✅ 新規: wwwサブドメインを作成するか
variable "create_www_subdomain" {
  description = "Create www subdomain (e.g., www.example.com)"
  type        = bool
  default     = true
}
