variable "aws_region" {
  description = "AWS region where the portfolio stack is deployed."
  type        = string
  default     = "ap-east-1"
}

variable "project_name" {
  description = "Short project name used in AWS resource names."
  type        = string
  default     = "aws-devops-portfolio"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,24}$", var.project_name))
    error_message = "project_name must be 3-25 lowercase letters, numbers, or hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,12}$", var.environment))
    error_message = "environment must be 2-13 lowercase letters, numbers, or hyphens, starting with a letter."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets used by ALB and public Fargate tasks."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDR blocks are required."
  }
}

variable "availability_zones" {
  description = "Optional explicit availability zones. Leave empty to use the first two available zones in aws_region."
  type        = list(string)
  default     = []
}

variable "container_port" {
  description = "Port exposed by the application container and ALB target group."
  type        = number
  default     = 8080
}

variable "desired_count" {
  description = "Desired ECS service task count."
  type        = number
  default     = 1
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "github_owner" {
  description = "GitHub organization or user that owns the source repository."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name used by CodePipeline source."
  type        = string
}

variable "github_branch" {
  description = "GitHub branch that triggers CodePipeline."
  type        = string
  default     = "main"
}

variable "codestar_connection_arn" {
  description = "ARN of an existing AWS CodeStar Connections / CodeConnections connection authorized for the GitHub repo."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^arn:aws[a-zA-Z-]*:(codestar-connections|codeconnections):", var.codestar_connection_arn))
    error_message = "codestar_connection_arn must be a CodeStar Connections or CodeConnections connection ARN."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days for ECS application and CodeBuild logs."
  type        = number
  default     = 7
}
