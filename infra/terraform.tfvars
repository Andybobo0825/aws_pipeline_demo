aws_region   = "us-east-1"
project_name = "aws-devops-portfolio"
environment  = "dev"

# Existing GitHub connection authorized in AWS Developer Tools > Connections.
# Accept the connection in the AWS console before running the pipeline.
codestar_connection_arn = "arn:aws:codeconnections:us-east-1:898912608626:connection/3f0f9120-02fa-4cc9-811f-cc3351c62378"
github_owner            = "Andybobo0825"
github_repo             = "aws_pipeline_demo"
github_branch           = "main"

vpc_cidr            = "10.20.0.0/16"
public_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]
# availability_zones = ["us-east-1a", "us-east-1b"]

container_port = 8080
desired_count  = 1
task_cpu       = 256
task_memory    = 512
