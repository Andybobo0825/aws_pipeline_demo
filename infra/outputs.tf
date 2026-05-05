output "alb_dns_name" {
  description = "Public DNS name for the application load balancer."
  value       = aws_lb.app.dns_name
}

output "application_url" {
  description = "HTTP URL for the deployed Flask service."
  value       = "http://${aws_lb.app.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URI used by CodeBuild."
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.app.name
}

output "codepipeline_name" {
  description = "CodePipeline pipeline name."
  value       = aws_codepipeline.this.name
}

output "artifact_bucket_name" {
  description = "S3 bucket used by CodePipeline artifacts."
  value       = aws_s3_bucket.artifacts.bucket
}
