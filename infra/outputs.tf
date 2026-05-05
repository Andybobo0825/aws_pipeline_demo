output "alb_dns_name" {
  description = "Public DNS name for the application load balancer."
  value       = aws_lb.app.dns_name
}

output "application_url" {
  description = "HTTP URL for the deployed application."
  value       = "http://${aws_lb.app.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL used by CodeBuild and ECS."
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

output "codebuild_project_name" {
  description = "CodeBuild project name."
  value       = aws_codebuild_project.this.name
}

output "codepipeline_name" {
  description = "CodePipeline name."
  value       = aws_codepipeline.this.name
}

output "artifact_bucket_name" {
  description = "S3 bucket used by CodePipeline for artifacts."
  value       = aws_s3_bucket.artifacts.bucket
}
