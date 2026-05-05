variable "aws_region" {
  description = "AWS region used for all regional resources."
  type        = string
  default     = "ap-east-1"
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "aws-devops-portfolio"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "container_port" {
  description = "Port exposed by the Flask container."
  type        = number
  default     = 8080
}

variable "desired_count" {
  description = "Number of ECS tasks to run."
  type        = number
  default     = 1
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = string
  default     = "512"
}

variable "vpc_cidr" {
  description = "CIDR block for the demo VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDR blocks for the ALB and Fargate service."
  type        = list(string)
  default     = ["10.40.1.0/24", "10.40.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "Provide at least two public subnet CIDRs."
  }
}

variable "github_connection_arn" {
  description = "CodeStar Connections ARN for the GitHub repository source. Create and authorize this outside Terraform if needed."
  type        = string
}

variable "github_owner" {
  description = "GitHub repository owner or organization."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "github_branch" {
  description = "GitHub branch watched by CodePipeline."
  type        = string
  default     = "main"
}

variable "log_retention_days" {
  description = "CloudWatch log retention for ECS and CodeBuild logs."
  type        = number
  default     = 7
}
