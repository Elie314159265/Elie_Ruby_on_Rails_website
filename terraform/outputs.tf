# ========================================
# outputs.tf - Route 53 + ACM + ALB対応版
# ========================================
# 
# 【新規Output】
# 1. alb_dns_name - ALBのDNS名
# 2. route53_name_servers - Route 53ネームサーバー（既存ドメイン移行用）
# 3. acm_certificate_arn - SSL証明書ARN
# 4. application_url - 最終的なアプリケーションURL
# 
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
# ALB関連（新規）
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
# Route 53関連（新規）
# ========================================

output "route53_zone_id" {
  description = "Route 53 Hosted Zone ID"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].zone_id : "N/A (no domain configured)"
}

output "route53_name_servers" {
  description = "Route 53 Name Servers (use these if migrating existing domain)"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].name_servers : []
}

# ✅ 新規: 既存ドメイン移行時の手順出力
output "domain_migration_instructions" {
  description = "Instructions for migrating existing domain to Route 53"
  value = var.use_existing_domain && var.domain_name != "" ? (<<-EOT

    ========================================
    既存ドメインのネームサーバー変更手順
    ========================================

    現在のドメインレジストラ（お名前.com、ムームードメイン等）で、
    以下のRoute 53ネームサーバーに変更してください:

    ${join("\n    ", var.domain_name != "" ? aws_route53_zone.main[0].name_servers : [])}

    変更後、DNS伝播に最大48時間かかる場合があります（通常は数時間）。

    確認コマンド:
    dig ${var.domain_name} NS +short

    ========================================
  EOT
  ) : "N/A (not using existing domain)"
}

# ========================================
# ACM関連（新規）
# ========================================

output "acm_certificate_arn" {
  description = "ARN of the ACM SSL certificate"
  value       = var.domain_name != "" ? aws_acm_certificate.main[0].arn : "N/A (no domain configured)"
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate"
  value       = var.domain_name != "" ? aws_acm_certificate.main[0].status : "N/A"
}

# ========================================
# Application URL（最終）
# ========================================

output "application_url" {
  description = "Application URL (use this to access your app)"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"
}

output "www_url" {
  description = "WWW subdomain URL"
  value       = var.domain_name != "" && var.create_www_subdomain ? "https://www.${var.domain_name}" : "N/A"
}

# ========================================
# コスト情報（参考）
# ========================================

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD)"
  value = <<-EOT
    
    ========================================
    月額コスト見積もり（東京リージョン）
    ========================================
    
    EC2 (${var.instance_type}):           $${var.instance_type == "t3.micro" ? "7.59" : var.instance_type == "t2.micro" ? "9.50" : "15.00"}
    EBS (20GB gp3):                       $1.60
    ALB:                                  $18.00
    Route 53 Hosted Zone:                 $0.50
    ACM Certificate:                      $0.00 (無料)
    CloudWatch Logs (~1GB):               $0.50
    Data Transfer (~10GB):                $0.90
    ${var.register_new_domain ? "Route 53 Domain (.com):              $1.08 (年$13を月割)" : ""}
    ----------------------------------------
    合計:                                 $${var.register_new_domain ? "29.17" : "28.09"}/月
    
    ※ Free Tier適用時:
    - EC2 t2.micro: 750時間/月無料（初年度）
    - データ転送: 15GB/月無料
    → 初年度の実質コスト: 約$19-20/月
    
    ========================================
  EOT
}

# ========================================
# デプロイ完了メッセージ
# ========================================

output "deployment_complete_message" {
  description = "Deployment completion message"
  value = <<-EOT
    
    ========================================
    🎉 デプロイ完了！
    ========================================
    
    ✅ Application Load Balancer: 起動完了
    ✅ EC2 Instance: 起動完了
    ✅ Route 53: ${var.domain_name != "" ? "設定完了" : "未設定"}
    ✅ ACM SSL Certificate: ${var.domain_name != "" ? "発行完了" : "未設定"}
    
    📌 アクセス方法:
    ${var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"}
    
    📌 管理方法:
    aws ssm start-session --target ${aws_instance.rails_app.id}
    
    ${var.use_existing_domain && var.domain_name != "" ? "⚠️  既存ドメイン使用時の注意:\nドメインレジストラでネームサーバーを変更してください。\n詳細は 'terraform output domain_migration_instructions' を参照。" : ""}
    
    ========================================
  EOT
}
