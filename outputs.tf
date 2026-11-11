output "vpc_id" {
  value = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "Point your domain (CNAME/alias) at this"
  value       = aws_lb.alb.dns_name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.cluster.name
}

output "frontend_service_name" {
  value = aws_ecs_service.frontend.name
}

output "frontend_task_definition_arn" {
  value = aws_ecs_task_definition.frontend.arn
}

output "api_service_name" {
  value = aws_ecs_service.api.name
}

output "api_task_definition_arn" {
  value = aws_ecs_task_definition.api.arn
}

output "app_deploy_role_arn" {
  description = "Set as the AWS_DEPLOY_ROLE_ARN variable in the app repo's GitHub settings"
  value       = aws_iam_role.app_deploy.arn
}
