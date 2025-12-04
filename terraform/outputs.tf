# ========================================
# outputs.tf - Route 53 + ACM + ALB対応版 (Simplified)
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
  value       = var.domain_name != "" ? local.zone_id : "N/A (no domain configured)"
}

# ネームサーバー情報はここで出力されます
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

# ========================================
# ACM関連
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
# Application URL
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
# デプロイ完了メッセージ
# ========================================

output "deployment_info" {
  description = "Deployment summary"
  value       = "Deployment completed! Access your app at: ${var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"}"
}
