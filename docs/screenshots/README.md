# Screenshot Evidence Checklist

Store deployment evidence screenshots in this directory after the AWS demo has
been applied and the pipeline has run successfully.

Recommended files:

- `architecture.png` - architecture diagram or exported drawing
- `codepipeline-success.png` - Source, Build, and Deploy stages succeeded
- `codebuild-success.png` - Docker build, ECR push, and artifact upload logs
- `ecr-image.png` - commit SHA and `latest` tags visible in Amazon ECR
- `ecs-service.png` - ECS service stable with desired count `1`
- `app-response.png` - ALB responses for `/` and `/health`
- `cloudwatch-logs.png` - application stdout/stderr in CloudWatch Logs

Before committing screenshots, redact account IDs, sensitive ARNs, private repo
names, or other environment-specific details that should not be public.

Capture screenshots only after `terraform apply` and a successful pipeline run so
the portfolio evidence matches the deployed AWS resources.
