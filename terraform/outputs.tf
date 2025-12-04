# ========================================
# outputs.tf - Route 53 + ACM + ALB対応版
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
  value       = var.domain_name != "" ? local.zone_id : "N/A (no domain configured)"
}

output "route53_name_servers" {
  description = "Route 53 Name Servers (use these if migrating existing domain)"
  value = var.domain_name != "" ? (
    var.use_existing_domain ? (
      length(data.aws_route53_zone.existing) > 0 ? data.aws_route53_zone.existing[0].name_servers : []
    ) : (
      length(aws_route53_zone.main) > 0 ? aws_route53_zone.main[0].name_servers : []
    )
  ) : []
}

# エラーの原因となっていた domain_migration_instructions ブロックは削除しました。
# ネームサーバーの情報が必要な場合は、上記の route53_name_servers の出力を参照してください。

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

# コスト情報も同様に複雑な文字列操作を含むため、エラー回避のためにシンプル化、または削除しても構いません。
# ここでは残していますが、もしここでもエラーが出る場合は削除してください。
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
    
    ========================================
  EOT
}

output "deployment_complete_message" {
  description = "Deployment completion message"
  value = "Deployment completed! Access your app at: ${var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"}"
}
