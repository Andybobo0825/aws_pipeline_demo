<!-- markdownlint-disable MD013 -->

# AWS DevOps Portfolio: ECS, ECR, CodePipeline, and Terraform

This project demonstrates a complete AWS DevOps delivery workflow:
GitHub -> CodePipeline -> CodeBuild -> Amazon ECR -> Amazon ECS Fargate.
Infrastructure is provisioned with Terraform, and application logs are collected
with CloudWatch Logs.

The repository is designed as a GitHub-ready portfolio project that shows how a
containerized Flask API can be built, versioned, pushed to a managed image
registry, and deployed through an AWS-native CI/CD pipeline.

## Overview

- **Application:** Python Flask API exposing `/` and `/health` on port `8080`.
- **Container:** Docker image built from the repository root.
- **Registry:** Amazon ECR stores immutable commit-tagged images plus `latest`.
- **Runtime:** Amazon ECS Fargate runs the container behind an Application Load
  Balancer.
- **CI/CD:** AWS CodePipeline orchestrates source, build, and ECS deployment.
- **Build:** AWS CodeBuild builds the Docker image, pushes it to ECR, and emits
  the ECS deployment artifact.
- **Infrastructure:** Terraform manages VPC, ALB, ECS, ECR, CodeBuild,
  CodePipeline, IAM, S3 artifacts, and CloudWatch Logs.

No secrets are committed. GitHub source integration is parameterized through an
AWS CodeStar connection ARN variable that must be created and authorized outside
this repository.

## Architecture

```text
Developer push
  -> GitHub repository
      -> AWS CodePipeline
          -> Source stage: CodeStarSourceConnection
          -> Build stage: AWS CodeBuild
              -> Docker build
              -> Tag image with Git commit SHA prefix
              -> Push image to Amazon ECR
              -> Generate imagedefinitions.json
          -> Deploy stage: Amazon ECS standard deploy action
              -> ECS service rolling update
                  -> ECS Fargate task pulls image from ECR
                      -> Application Load Balancer routes traffic

Terraform
  -> VPC, public subnets, routing, security groups
  -> ALB, target group, listener
  -> ECR repository
  -> ECS cluster, task definition, service
  -> CloudWatch log group
  -> S3 artifact bucket
  -> CodeBuild project
  -> CodePipeline pipeline
  -> IAM roles and least-privilege policies

CloudWatch Logs <- ECS task stdout/stderr
```

## CI/CD Flow

1. A developer pushes a commit to the configured GitHub branch.
2. CodePipeline reads the repository through the configured
   `CodeStarSourceConnection` source action.
3. CodeBuild logs in to Amazon ECR.
4. CodeBuild builds the Docker image from `Dockerfile`.
5. CodeBuild tags the image with the first seven characters of the Git commit
   SHA and also tags it as `latest`.
6. CodeBuild pushes both tags to the ECR repository.
7. CodeBuild writes `imagedefinitions.json` as the build artifact.
8. CodePipeline passes `imagedefinitions.json` to the ECS standard deploy action.
9. ECS updates the `app` container in the service task definition and performs a
   rolling deployment.
10. The Application Load Balancer serves the new task when health checks pass.

The ECS standard deploy action consumes an image definitions file named
`imagedefinitions.json`. The file maps the ECS task definition container name to
the new image URI. In this project the container name is `app`, so the generated
artifact is expected to look like this:

```json
[{"name":"app","imageUri":"<account>.dkr.ecr.<region>.amazonaws.com/<repo>:<sha>"}]
```

## Terraform Resources

The `infra/` directory provisions the minimum viable AWS footprint for this
portfolio deployment.

### Network and Load Balancing

- VPC
- Two public subnets
- Internet gateway
- Public route table and associations
- ALB security group allowing inbound HTTP on port `80`
- ECS service security group allowing port `8080` only from the ALB
- Application Load Balancer
- Target group using `ip` targets for Fargate tasks
- HTTP listener forwarding to the target group

### Container Runtime

- ECR repository with image scanning enabled
- ECS cluster
- ECS task execution role
- ECS task role
- ECS task definition with container name `app`
- ECS Fargate service
- CloudWatch log group for application logs

### CI/CD

- S3 artifact bucket with a unique suffix
- CodeBuild service role and least-privilege policy
- CodeBuild project using `buildspec.yml`
- CodePipeline service role and least-privilege policy
- CodePipeline with Source, Build, and Deploy stages
- GitHub source configured with a CodeStar connection ARN variable

### Key Variables

Expected variable names may include:

- `aws_region`
- `project_name`
- `environment`
- `container_port`
- `github_owner`
- `github_repo`
- `github_branch`
- `codestar_connection_arn`

Use `infra/terraform.tfvars.example` as a template and keep real account IDs,
connection ARNs, and environment-specific values out of version control.
Treat the connection ARN as environment-specific configuration even when it is
not an application secret.

## Project Structure

```text
.
├── app/
│   ├── main.py
│   └── requirements.txt
├── infra/
│   ├── providers.tf
│   ├── variables.tf
│   ├── locals.tf
│   ├── network.tf
│   ├── alb.tf
│   ├── ecr.tf
│   ├── logs.tf
│   ├── iam.tf
│   ├── ecs.tf
│   ├── codebuild.tf
│   ├── pipeline.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── docs/
│   └── screenshots/
│       └── README.md
├── buildspec.yml
├── Dockerfile
├── .dockerignore
└── README.md
```

## Deployment Steps

### 1. Prerequisites

Install and configure:

- AWS CLI with credentials for the target account
- Terraform `>= 1.6`
- Docker
- Git

Create and authorize an AWS CodeStar connection for GitHub before applying the
pipeline. The resulting connection ARN should be passed through Terraform as a
variable, not hardcoded in source files.

### 2. Configure Terraform Variables

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with non-secret deployment settings:

```hcl
aws_region              = "ap-east-1"
project_name            = "aws-devops-portfolio"
environment             = "dev"
container_port          = 8080
github_owner            = "<github-owner>"
github_repo             = "<github-repo>"
github_branch           = "main"
codestar_connection_arn = "<authorized-codestar-connection-arn>"
```

Do not commit `terraform.tfvars` if it contains account-specific values.

### 3. Format and Validate Terraform

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```

Review the plan carefully before creating resources. This project creates AWS
infrastructure that may incur cost.

### 4. Apply Infrastructure

```bash
terraform apply
```

After apply completes, note the ALB DNS output and the ECR repository URL.

### 5. Trigger the Pipeline

Push a commit to the configured GitHub branch:

```bash
git add .
git commit -m "Update application"
git push origin main
```

CodePipeline should start from the GitHub source stage, run CodeBuild, and then
perform an ECS standard deployment using the generated `imagedefinitions.json`.

### 6. Clean Up

When the demo is no longer needed:

```bash
cd infra
terraform destroy
```

Confirm that ECR images and any retained logs are acceptable before destroying
or manually deleting retained resources.

## Validation Steps

### Local Application Check

```bash
python -m venv .venv
. .venv/bin/activate
pip install -r app/requirements.txt
python -m flask --app app.main run --host 0.0.0.0 --port 8080
curl http://localhost:8080/
curl -i http://localhost:8080/health
```

Expected result:

- `/` returns JSON containing `message` and the current `APP_ENV` value.
- `/health` returns HTTP `200` and a JSON status payload.

### Local Docker Check

```bash
docker build -t aws-devops-portfolio:local .
docker run --rm -p 8080:8080 -e APP_ENV=local aws-devops-portfolio:local
curl http://localhost:8080/health
```

Expected result: the container starts on port `8080` and health checks pass.

### Terraform Check

```bash
cd infra
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
```

Expected result: formatting, initialization, validation, and planning complete
successfully with no hardcoded secrets required.

### Pipeline Check

In the AWS Console or CLI, verify:

- CodePipeline Source, Build, and Deploy stages succeed.
- CodeBuild logs show Docker login, build, tag, push, and artifact generation.
- The ECR repository contains both `<sha>` and `latest` image tags.
- The build artifact contains `imagedefinitions.json` with container name `app`.
- ECS service desired count is `1` and the deployment reaches steady state.
- The ALB target group reports healthy targets.

### Runtime Check

```bash
ALB_DNS_NAME="<alb-dns-output>"
curl "http://${ALB_DNS_NAME}/"
curl -i "http://${ALB_DNS_NAME}/health"
```

Expected result:

- `/` returns a successful JSON response.
- `/health` returns HTTP `200`.
- CloudWatch Logs shows application stdout/stderr from the ECS task.

## Screenshots Placeholder

Replace the placeholders below with evidence from a successful deployment.
Do not include account IDs, private repository names, secrets, or sensitive ARNs
unless they are intentionally redacted.

| Evidence | Suggested path | What to capture |
| --- | --- | --- |
| Architecture diagram | `docs/screenshots/architecture.png` | GitHub to CodePipeline to CodeBuild to ECR to ECS Fargate |
| Pipeline success | `docs/screenshots/codepipeline-success.png` | All CodePipeline stages succeeded |
| Build success | `docs/screenshots/codebuild-success.png` | Docker build, ECR push, and artifact generation |
| ECR image | `docs/screenshots/ecr-image.png` | `<sha>` and `latest` tags in the repository |
| ECS service | `docs/screenshots/ecs-service.png` | Service stable with desired count `1` |
| ALB response | `docs/screenshots/app-response.png` | `/` and `/health` responses |
| CloudWatch logs | `docs/screenshots/cloudwatch-logs.png` | Application logs from ECS tasks |

## DevOps Skills Demonstrated

- Containerizing a Python Flask API with Docker
- Designing an AWS-native CI/CD workflow with CodePipeline
- Building and publishing images with CodeBuild and Amazon ECR
- Deploying containers to ECS Fargate behind an ALB
- Producing ECS standard deployment artifacts with `imagedefinitions.json`
- Managing infrastructure with Terraform modules/files and variables
- Applying least-privilege IAM boundaries for build and deployment services
- Using Git commit SHA image tags for traceable releases
- Collecting runtime logs with CloudWatch Logs
- Documenting validation evidence for a portfolio-ready GitHub repository

## References

- AWS CodePipeline ECS deploy action:
  <https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-ECS.html>
- AWS image definitions file reference:
  <https://docs.aws.amazon.com/codepipeline/latest/userguide/file-reference.html>
- AWS CodePipeline GitHub connections:
  <https://docs.aws.amazon.com/codepipeline/latest/userguide/connections-github.html>
- Terraform AWS provider `aws_codepipeline` resource:
  <https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline>
