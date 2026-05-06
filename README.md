<!-- markdownlint-disable MD013 -->

# AWS DevOps 作品集：ECS、ECR、CodePipeline 與 Terraform

這是一個可放進 GitHub 作品集的 AWS DevOps 專案。專案展示一條完整的自動化交付鏈：

```text
GitHub -> CodePipeline -> CodeBuild -> Amazon ECR -> Amazon ECS Fargate
```

應用程式以 Docker 容器化，映像檔推送到 Amazon ECR，服務部署到 Amazon ECS Fargate，基礎設施由 Terraform 管理，應用程式日誌由 CloudWatch Logs 收集。

本專案重點不是複雜商業邏輯，而是證明我能把「程式碼、容器、雲端基礎設施、CI/CD、部署驗證」串成可重複、可版本化、可驗證的 DevOps 流程。

## 專案目標

依據 `aws-devops-portfolio-ecs-ecr-codepipeline-terraform.md` 的規格，本專案要展示以下能力：

- 使用 Docker 將 Python Flask API 容器化。
- 使用 Terraform 建立 AWS 基礎設施。
- 使用 Amazon ECR 管理 container image。
- 使用 AWS CodeBuild 自動 build image、tag image、push image。
- 使用 AWS CodePipeline 串接 GitHub、CodeBuild 與 ECS deploy。
- 使用 Amazon ECS Fargate 執行容器服務。
- 使用 Application Load Balancer 對外提供 HTTP 服務。
- 使用 CloudWatch Logs 收集 ECS task stdout/stderr。
- 使用 Git commit SHA 前 7 碼作為 image tag，讓部署版本可追蹤。
- 使用 `imagedefinitions.json` 讓 CodePipeline ECS standard deploy action 更新 ECS service。

## 功能總覽

### 應用程式功能

- Python Flask API。
- `/` endpoint 回傳 JSON，包含：
  - `message`
  - `env`，由環境變數 `APP_ENV` 控制。
- `/health` endpoint 回傳 HTTP `200`，供 ALB target group health check 使用。
- container 對外使用 port `8080`。
- request log 輸出到 stdout，方便 CloudWatch Logs 收集。

### 容器化功能

- 使用 `Dockerfile` 建立 Python runtime image。
- 使用 Gunicorn 啟動 Flask app。
- 使用 `.dockerignore` 排除 Git、Terraform、docs 等不需要進入 image 的內容。
- 本機可用 Docker build/run 驗證服務。

### CI/CD 功能

- GitHub push 後觸發 CodePipeline。
- Source stage 使用 AWS CodeStarSourceConnection 連接 GitHub。
- Build stage 使用 CodeBuild：
  - 登入 Amazon ECR。
  - 以 repository root 建立 Docker image。
  - 使用 Git commit SHA 前 7 碼作為 image tag。
  - 同時推送 `${sha}` 與 `latest` 到 ECR。
  - 產生 ECS deploy 需要的 `imagedefinitions.json`。
- Deploy stage 使用 ECS standard deploy action：
  - 讀取 `imagedefinitions.json`。
  - 更新 ECS service 中 container name 為 `app` 的 image。
  - 讓 ECS service 執行 rolling update。

### AWS 基礎設施功能

Terraform 會建立最小可行的 AWS DevOps demo 架構：

- VPC。
- 兩個 public subnets。
- Internet Gateway。
- Public route table 與 route table associations。
- Application Load Balancer。
- Target Group，target type 使用 `ip`，符合 Fargate + `awsvpc` 常見配置。
- HTTP Listener，對外開 port `80`。
- ALB Security Group，允許 public HTTP 流量。
- ECS Service Security Group，只允許 ALB 連到 container port `8080`。
- Amazon ECR repository，啟用 image scan on push。
- ECS Cluster。
- ECS Task Definition。
- ECS Service，使用 Fargate launch type。
- ECS Task Execution Role。
- ECS Task Role。
- CloudWatch Log Group。
- S3 Artifact Bucket，供 CodePipeline 存放 artifact。
- CodeBuild Project。
- CodePipeline Pipeline。
- CodeBuild / CodePipeline / ECS 所需 IAM roles 與較小權限 policies。

### 作品集展示功能

這份作品集可用來展示：

- 我能設計 AWS 原生 CI/CD 流程。
- 我理解 ECR、ECS、CodeBuild、CodePipeline 的職責切分。
- 我能用 Terraform 管理雲端資源，而不是手動點 Console。
- 我知道 ECS standard deploy 需要 `imagedefinitions.json`。
- 我能用 Git commit SHA 做部署版本追蹤。
- 我能用 CloudWatch Logs 驗證容器服務實際有在執行。
- 我能整理 README、架構、驗證步驟與截圖證據，讓專案可被面試官快速理解。

## 架構

```text
Developer push
  -> GitHub Repository
      -> AWS CodePipeline
          -> Source Stage: CodeStarSourceConnection
          -> Build Stage: AWS CodeBuild
              -> Docker build
              -> Tag image with Git commit SHA prefix
              -> Push image to Amazon ECR
              -> Generate imagedefinitions.json
          -> Deploy Stage: Amazon ECS standard deploy action
              -> Update ECS Service
                  -> ECS Fargate Task pulls image from ECR
                      -> Application Load Balancer routes traffic

Terraform
  -> VPC / Subnets / Internet Gateway / Route Table
  -> Security Groups
  -> ALB / Target Group / Listener
  -> ECR Repository
  -> ECS Cluster / Task Definition / Service
  -> CloudWatch Log Groups
  -> S3 Artifact Bucket
  -> CodeBuild Project
  -> CodePipeline Pipeline
  -> IAM Roles and Policies

CloudWatch Logs <- ECS Task stdout/stderr
```

## CI/CD 流程

1. 開發者 push commit 到 GitHub。
2. CodePipeline 透過 CodeStarSourceConnection 取得 source code。
3. CodePipeline 進入 Build stage，啟動 CodeBuild。
4. CodeBuild 登入 Amazon ECR。
5. CodeBuild 根據 `Dockerfile` build image。
6. CodeBuild 以 Git commit SHA 前 7 碼 tag image。
7. CodeBuild 同時 push `${sha}` 與 `latest` 到 ECR。
8. CodeBuild 產生 `imagedefinitions.json`。
9. CodePipeline Deploy stage 讀取 `imagedefinitions.json`。
10. ECS standard deploy action 更新 ECS Service。
11. ECS Fargate 建立新 task，從 ECR 拉取新 image。
12. ALB health check 通過後，流量導到新 task。
13. CloudWatch Logs 可看到應用程式輸出。

`imagedefinitions.json` 範例：

```json
[{"name":"app","imageUri":"<account>.dkr.ecr.<region>.amazonaws.com/<repo>:<sha>"}]
```

其中 `name` 必須對應 ECS task definition 裡的 container name。本專案固定使用 `app`。

## 技術選型

| 類別 | 技術 | 用途 |
| --- | --- | --- |
| Application | Python Flask | 建立簡單 API demo |
| App Server | Gunicorn | 在 container 中執行 Flask app |
| Container | Docker | 將應用程式容器化 |
| Image Registry | Amazon ECR | 儲存 Docker image |
| Runtime | Amazon ECS Fargate | 執行容器服務 |
| Load Balancer | Application Load Balancer | 對外提供 HTTP endpoint |
| CI/CD Orchestrator | AWS CodePipeline | 串接 Source、Build、Deploy |
| Build Service | AWS CodeBuild | Build image、push ECR、產生 artifact |
| Infrastructure as Code | Terraform | 建立與管理 AWS 資源 |
| Logging | CloudWatch Logs | 收集 ECS task logs |
| Source | GitHub | 程式碼來源與 pipeline 觸發點 |

## 專案結構

```text
.
├── app/
│   ├── main.py
│   ├── requirements.txt
│   └── test_main.py
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

## Terraform 資源說明

### Network

- `aws_vpc.this`：專案 VPC。
- `aws_subnet.public`：兩個 public subnet。
- `aws_internet_gateway.this`：讓 public subnet 可連 Internet。
- `aws_route_table.public`：public route table。
- `aws_route_table_association.public`：subnet route table 綁定。

### Load Balancer

- `aws_lb.app`：Application Load Balancer。
- `aws_lb_target_group.app`：ALB target group，target type 為 `ip`。
- `aws_lb_listener.http`：HTTP listener，port `80`。
- `aws_security_group.alb`：允許外部 HTTP 流量。
- `aws_security_group.ecs_service`：只允許 ALB 打到 ECS service。

### Container Runtime

- `aws_ecr_repository.app`：儲存 application image。
- `aws_ecs_cluster.this`：ECS cluster。
- `aws_ecs_task_definition.app`：ECS task definition，container name 固定為 `app`。
- `aws_ecs_service.app`：ECS Fargate service。
- `aws_cloudwatch_log_group.ecs`：ECS task logs。

### CI/CD

- `aws_s3_bucket.artifacts`：CodePipeline artifact bucket。
- `aws_codebuild_project.this`：Docker build / ECR push / artifact generation。
- `aws_codepipeline.this`：Source、Build、Deploy 三階段 pipeline。
- `aws_cloudwatch_log_group.codebuild`：CodeBuild logs。

### IAM

- ECS task execution role。
- ECS task role。
- CodeBuild service role 與 ECR/S3/Logs 權限。
- CodePipeline service role 與 CodeStar connection、CodeBuild、ECS、S3、IAM PassRole 權限。

## 前置需求

本機需要：

- AWS CLI，且已設定可建立相關資源的 credentials。
- Terraform `>= 1.5`。
- Docker。
- Git。
- Python 3。

AWS 端需要：

- 可建立 ECR、ECS、ALB、VPC、IAM、S3、CodeBuild、CodePipeline、CloudWatch Logs 的權限。
- 一個已建立並授權 GitHub repo 的 AWS CodeStarSourceConnection / CodeConnections connection ARN。

> 注意：`codestar_connection_arn` 是環境設定值，請放在 `terraform.tfvars`，不要硬寫在 Terraform code 或 README 中。

## 部署步驟

### 1. 設定 Terraform 變數

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

編輯 `terraform.tfvars`：

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

### 2. 初始化與檢查 Terraform

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```

`terraform plan` 會需要有效 AWS credentials。確認 plan 後再 apply。

### 3. 建立 AWS 資源

```bash
terraform apply
```

完成後記下 Terraform output：

- `application_url`
- `alb_dns_name`
- `ecr_repository_url`
- `codepipeline_name`
- `codebuild_project_name`

### 4. Push commit 觸發 Pipeline

```bash
git add .
git commit -m "Update application"
git push origin main
```

Pipeline 應會依序執行：

```text
Source -> Build -> Deploy
```

### 5. 驗證服務

```bash
ALB_DNS_NAME="<terraform-output-alb-dns-name>"
curl "http://${ALB_DNS_NAME}/"
curl -i "http://${ALB_DNS_NAME}/health"
```

預期：

- `/` 回傳 JSON。
- `/health` 回傳 HTTP `200`。
- CloudWatch Logs 可看到 Flask/Gunicorn log。

### 6. 清除資源

```bash
cd infra
terraform destroy
```

此專案會建立 AWS 資源，可能產生費用；demo 結束後請清除不需要的資源。

## 本機驗證

### Flask API 測試

```bash
python -m venv .venv
. .venv/bin/activate
pip install -r app/requirements.txt pytest
pytest -q
```

### 本機啟動 Flask

```bash
. .venv/bin/activate
python -m flask --app app.main run --host 0.0.0.0 --port 8080
curl http://localhost:8080/
curl -i http://localhost:8080/health
```

### Docker 測試

```bash
docker build -t aws-devops-portfolio:local .
docker run --rm -p 8080:8080 -e APP_ENV=local aws-devops-portfolio:local
curl http://localhost:8080/health
```

### Terraform 測試

```bash
cd infra
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
```

## 驗收清單

完成部署後，應逐項確認：

- Terraform 可以成功建立 ECR。
- Terraform 可以成功建立 ECS cluster、service、task definition。
- ALB 可以取得 DNS name。
- ECS service desired count = `1`，且 service 穩定運行。
- CodeBuild 可以登入 ECR。
- ECR 中看得到 `${sha}` 與 `latest` image tags。
- `imagedefinitions.json` 正確包含 container name `app` 與 image URI。
- CodePipeline Source、Build、Deploy stages 全部成功。
- `/health` 回傳 HTTP `200`。
- CloudWatch Logs 看得到應用程式輸出。

## 截圖證據建議

部署成功後，建議在 `docs/screenshots/` 放入以下截圖，作為作品集證據：

| 證據 | 建議檔名 | 截圖內容 |
| --- | --- | --- |
| 架構圖 | `architecture.png` | GitHub -> CodePipeline -> CodeBuild -> ECR -> ECS Fargate |
| Pipeline 成功 | `codepipeline-success.png` | Source / Build / Deploy stages 成功 |
| Build 成功 | `codebuild-success.png` | Docker build、ECR push、artifact generation |
| ECR image | `ecr-image.png` | `${sha}` 與 `latest` tags |
| ECS service | `ecs-service.png` | Desired count = 1 且 service stable |
| App response | `app-response.png` | `/` 與 `/health` 回應 |
| CloudWatch logs | `cloudwatch-logs.png` | ECS task stdout/stderr logs |

請避免把 AWS account ID、private repo、secret、完整敏感 ARN 直接曝光在截圖中。

## DevOps 能力展示

這個作品集專案可在履歷或面試中說明：

- Containerization with Docker。
- Infrastructure as Code with Terraform。
- Continuous Delivery with AWS CodePipeline。
- Automated Build with AWS CodeBuild。
- Image Registry with Amazon ECR。
- Deployment to Amazon ECS Fargate。
- Load balancing with ALB。
- Log collection with CloudWatch Logs。
- Versioned deployment with Git commit SHA image tags。
- Least-privilege IAM policy design。
- Release artifact generation with `imagedefinitions.json`。

可使用的履歷描述：

```text
Built a containerized application delivery pipeline on AWS using CodePipeline, CodeBuild, ECR, ECS Fargate, and Terraform, enabling automated image build, registry push, and rolling deployment.
```

## 參考資料

- AWS CodePipeline ECS deploy action：
  <https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-ECS.html>
- AWS image definitions file：
  <https://docs.aws.amazon.com/codepipeline/latest/userguide/file-reference.html>
- AWS CodePipeline GitHub connections：
  <https://docs.aws.amazon.com/codepipeline/latest/userguide/connections-github.html>
- Terraform AWS provider `aws_codepipeline` resource：
  <https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline>
