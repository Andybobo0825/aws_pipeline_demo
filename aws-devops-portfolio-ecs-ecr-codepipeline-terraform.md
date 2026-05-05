# AWS DevOps 作品集實作說明

## 目標

建立一個可放進 GitHub 作品集的 DevOps 專案，展示以下能力：

- Docker 容器化
- AWS CodePipeline + CodeBuild 自動化 CI/CD
- Image 推送到 Amazon ECR
- 部署到 Amazon ECS Fargate
- Terraform 管理基礎設施
- CloudWatch Logs 觀測
- 以 Git commit SHA 作為 image tag

依據 AWS 官方定義：
Amazon ECR 是受管的 container image registry，用來儲存與管理映像。citeturn660028search3
CodePipeline 的 ECS deploy action 會使用 `imagedefinitions.json` 來更新 ECS 使用的 image。citeturn660028search1turn660028search9
Terraform 是 IaC 工具，用來 build、change、version infrastructure。citeturn660028search2

---

## 架構

```text
GitHub
  -> CodePipeline
      -> CodeBuild
          -> Docker build
          -> Docker push to ECR
          -> 產生 imagedefinitions.json
      -> ECS Deploy Action
          -> 更新 ECS Service
              -> ECS Task 從 ECR 拉新 image
                  -> ALB 導流到新 task

CloudWatch Logs <- ECS Task logs
Terraform -> 建立並管理上述 AWS 資源
```

---

## 專案成果要展示什麼

此作品集的重點不是單純把網站上線，而是展示你有能力完成以下鏈條：

1. 將應用程式容器化
2. 將映像自動建置並推送到 ECR
3. 以 CodePipeline 自動部署到 ECS
4. 用 Terraform 管理 infra
5. 以 CloudWatch Logs 驗證服務執行
6. 以 README、架構圖、流程圖與截圖證明你真的跑過

---

## 建議作品主題

建議做一個簡單但完整的服務，不要把重點放在商業邏輯。

推薦：

- Flask API
- FastAPI API
- Node.js Express API

最低需求：

- `/` 回傳 hello
- `/health` 回傳 200
- 可從環境變數讀取 `APP_ENV`
- log 會印到 stdout

---

## Repo 結構

```text
aws-devops-portfolio/
├─ app/
│  ├─ main.py
│  ├─ requirements.txt
│  └─ ...
├─ infra/
│  ├─ main.tf
│  ├─ variables.tf
│  ├─ outputs.tf
│  ├─ iam.tf
│  ├─ ecs.tf
│  ├─ ecr.tf
│  ├─ pipeline.tf
│  ├─ network.tf
│  └─ terraform.tfvars.example
├─ buildspec.yml
├─ Dockerfile
├─ .dockerignore
├─ README.md
└─ docs/
   ├─ architecture.png
   ├─ pipeline.png
   ├─ codepipeline-success.png
   ├─ codebuild-success.png
   ├─ ecr-image.png
   ├─ ecs-service.png
   └─ cloudwatch-logs.png
```

---

## 技術選型

- Runtime: Python Flask
- Container: Docker
- Registry: Amazon ECR
- Orchestration: Amazon ECS Fargate
- CI/CD: CodePipeline + CodeBuild
- IaC: Terraform
- Logging: CloudWatch Logs
- Front door: Application Load Balancer

此選型的原因：

- ECR 專門負責存 image，不負責執行。citeturn660028search3
- ECS 是 AWS 原生容器編排服務，適合作為 ECR 後的部署目標。這是根據 AWS 官方對 ECS 與 CodePipeline ECS deploy action 的角色描述整理。citeturn660028search9
- CodeBuild 負責建置與測試；CodePipeline 負責把 source、build、deploy 串成一個 release workflow。這是依 AWS 官方服務定義整理。citeturn660028search1turn660028search9

---

## 前置條件

### 本機

- AWS CLI 已安裝並設定 profile
- Terraform 已安裝
- Docker 已安裝
- Git 已安裝

### AWS 權限

至少要能建立以下資源：

- ECR
- ECS Cluster / Service / Task Definition
- ALB / Target Group / Security Group
- VPC / Subnets
- IAM Roles / Policies
- S3 Bucket
- CodeBuild
- CodePipeline
- CloudWatch Logs

### GitHub

- 一個公開 repo 或私人 repo
- 可供 CodePipeline 存取的連線方式

註：CodePipeline 連 GitHub 的具體方式會因 AWS 當前支援模式不同而改變，實作時以 AWS Console 或官方文件可選來源為準。這裡不假設特定 GitHub OAuth 舊版配置仍為唯一方案。

---

## 實作範圍

此版本採用：

- 單一 API 服務
- 單一 ECR repository
- 單一 ECS service
- Fargate launch type
- 單一 ALB
- 單一 CodeBuild project
- 單一 CodePipeline
- 單一環境 `dev`

後續擴充可再加：

- staging / prod
- Terraform backend 遠端 state
- WAF
- Route 53 / ACM / HTTPS
- 多 service
- Blue/Green deploy

---

# 第一部分：應用程式

## 1. Flask 範例

`app/main.py`

```python
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.get("/")
def index():
    return jsonify({
        "message": "hello from ecs",
        "env": os.getenv("APP_ENV", "unknown")
    })

@app.get("/health")
def health():
    return jsonify({"status": "ok"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
```

`app/requirements.txt`

```txt
flask==3.0.3
gunicorn==22.0.0
```

---

## 2. Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

EXPOSE 8080

CMD ["gunicorn", "-b", "0.0.0.0:8080", "main:app"]
```

`.dockerignore`

```text
.git
.gitignore
__pycache__
*.pyc
infra/
docs/
README.md
```

---

# 第二部分：CodeBuild

## 3. buildspec.yml

重點：

- 取得 AWS account id 與 region
- login ECR
- build image
- 以 commit SHA 前 7 碼作為 image tag
- push image 到 ECR
- 產生 `imagedefinitions.json`

`buildspec.yml`

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
      - AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
      - REPOSITORY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}
      - IMAGE_TAG=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com
  build:
    commands:
      - echo Build started on `date`
      - docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} .
      - docker tag ${REPOSITORY_URI}:${IMAGE_TAG} ${REPOSITORY_URI}:latest
  post_build:
    commands:
      - echo Build completed on `date`
      - docker push ${REPOSITORY_URI}:${IMAGE_TAG}
      - docker push ${REPOSITORY_URI}:latest
      - printf '[{"name":"%s","imageUri":"%s"}]' "app" "${REPOSITORY_URI}:${IMAGE_TAG}" > imagedefinitions.json
artifacts:
  files:
    - imagedefinitions.json
```

依據 AWS CodePipeline 文件，ECS 標準部署動作會讀取 `imagedefinitions.json`，其中必須包含 container name 與 image URI。citeturn660028search1turn660028search9

---

# 第三部分：Terraform

## 4. Terraform 要建立哪些資源

最小可行版本建議建立：

### 網路
- VPC
- 2 public subnets
- Internet Gateway
- Route Table
- Security Groups

### 容器與部署
- ECR repository
- ECS cluster
- ECS task execution role
- ECS task role
- CloudWatch log group
- ECS task definition
- ECS service
- Application Load Balancer
- Target Group
- Listener

### CI/CD
- S3 artifact bucket
- CodeBuild project
- CodePipeline role
- CodeBuild role
- CodePipeline pipeline

### IAM
- ECS task execution role policy
- CodeBuild push ECR 權限
- CodePipeline 取 artifact / 呼叫 ECS 權限
- 若有 GitHub 連線則補相應來源權限

---

## 5. Terraform 檔案分工建議

### `providers.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

### `variables.tf`

```hcl
variable "aws_region" {
  type    = string
  default = "ap-east-1"
}

variable "project_name" {
  type    = string
  default = "aws-devops-portfolio"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "container_port" {
  type    = number
  default = 8080
}
```

### `locals.tf`

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

---

## 6. ECR

`ecr.tf`

```hcl
resource "aws_ecr_repository" "app" {
  name                 = "${local.name_prefix}-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}
```

ECR 是用來儲存 image 的 registry，不是部署目標。citeturn660028search3

---

## 7. CloudWatch Logs

```hcl
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 7
  tags              = local.common_tags
}
```

---

## 8. ECS Cluster

`ecs.tf`

```hcl
resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"
  tags = local.common_tags
}
```

---

## 9. IAM：ECS Task Execution Role

```hcl
resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-task-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
```

---

## 10. Task Definition

```hcl
resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name_prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "APP_ENV"
          value = var.environment
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.common_tags
}
```

註：正式環境中的敏感值不應直接硬寫在 task definition；應考慮 Secrets Manager 或 SSM Parameter Store 注入。這是 AWS ECS 常見實務方向，但本文件先聚焦在作品集最小可行版。

---

## 11. ALB 與 Security Group

此處只列重點，實作交給 agent 完成。

需要：

- ALB security group：開 80
- ECS service security group：只允許來自 ALB security group 的 8080
- Target group：target type 用 `ip`
- Listener：80 forward 到 target group

因為 Fargate 搭配 `awsvpc`，target group 常用 `ip`。此為 AWS ECS/Fargate 的常見配置要求。

---

## 12. ECS Service

```hcl
resource "aws_ecs_service" "app" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_service.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]

  tags = local.common_tags
}
```

---

## 13. CodeBuild Role

CodeBuild 至少要有：

- CloudWatch Logs 寫入權限
- S3 artifact bucket 存取權限
- ECR push/pull 權限
- `sts:GetCallerIdentity`

agent 實作時請以最小權限撰寫 IAM policy，不要直接給 AdministratorAccess。

---

## 14. CodeBuild Project

```hcl
resource "aws_codebuild_project" "this" {
  name         = "${local.name_prefix}-build"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "ECR_REPOSITORY_NAME"
      value = aws_ecr_repository.app.name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/codebuild/${local.name_prefix}"
    }
  }

  tags = local.common_tags
}
```

CodeBuild 是用來 build、test、產出 artifact 的 managed build service。此角色定位與 CodePipeline 的工作流程編排不同。這是根據 AWS 服務官方描述整理。citeturn660028search1turn660028search9

---

## 15. S3 Artifact Bucket

```hcl
resource "aws_s3_bucket" "artifacts" {
  bucket = "${local.name_prefix}-artifacts-<unique-suffix>"
}
```

註：bucket name 必須全域唯一，agent 需加 random suffix 或 `random_string`。

---

## 16. CodePipeline

CodePipeline 至少 3 個 stage：

1. Source
2. Build
3. Deploy

### Deploy stage

採用 ECS standard deploy action，輸入為 build 產生的 `imagedefinitions.json`。AWS 官方文件已明確說明此檔案的用途。citeturn660028search1turn660028search9

Terraform 實作重點：

- artifact_store 使用 S3 bucket
- source stage 連 GitHub
- build stage 指向 CodeBuild
- deploy stage 指向 ECS service

註：Source action 的 provider 與 connection 型態，請依當前 AWS 可用方式實作，不要假設舊版 GitHub OAuth 為唯一選項。

---

# 第四部分：README 呈現方式

## 17. README 必備章節

### 專案摘要

直接寫：

- 這是 AWS DevOps demo
- GitHub push 後自動建置與部署
- image 進 ECR，服務跑在 ECS Fargate
- Terraform 管理 infra

### 架構圖

至少畫出：

- GitHub
- CodePipeline
- CodeBuild
- ECR
- ECS Fargate
- ALB
- CloudWatch Logs
- Terraform

### CI/CD 流程

```text
Developer pushes code to GitHub
-> CodePipeline is triggered
-> CodeBuild builds and tags Docker image
-> Image is pushed to Amazon ECR
-> imagedefinitions.json is generated
-> CodePipeline deploys to Amazon ECS
-> ECS performs rolling update
```

### DevOps Practices

README 建議列出：

- Containerization with Docker
- Infrastructure as Code with Terraform
- Continuous Delivery with AWS CodePipeline
- Automated Build with AWS CodeBuild
- Image Registry with Amazon ECR
- Deployment to Amazon ECS Fargate
- Log collection with CloudWatch Logs
- Versioning with Git commit SHA

### 證據截圖

至少放：

- CodePipeline success
- CodeBuild success
- ECR image tag
- ECS service running
- App response
- CloudWatch Logs

---

# 第五部分：交給 Codex Agent 的執行任務

以下段落可直接交給 agent。

---

## Agent 任務說明

請建立一個完整可執行的 AWS DevOps 作品集專案，需求如下：

### 目標

使用以下組合建立一條完整交付鏈：

- GitHub 作為 source
- AWS CodePipeline 作為 CI/CD pipeline orchestrator
- AWS CodeBuild 負責 Docker build 與 push image
- Amazon ECR 作為 image registry
- Amazon ECS Fargate 作為部署目標
- Terraform 作為 IaC
- CloudWatch Logs 作為 log 收集

### 應用需求

- 使用 Python Flask 建立簡單 API
- `/` 回傳 JSON，內容含 `message` 與 `APP_ENV`
- `/health` 回傳 200
- container port 使用 8080
- stdout/stderr 可正常輸出 log

### Repo 結構

請建立以下結構：

```text
app/
infra/
Dockerfile
buildspec.yml
README.md
.dockerignore
```

### Terraform 要求

請用 Terraform 建立最小可行架構：

- VPC
- 2 public subnets
- Internet Gateway
- Route Table
- ALB
- Target Group
- Listener
- Security Groups
- ECS Cluster
- ECS Task Definition
- ECS Service
- CloudWatch Log Group
- ECR Repository
- S3 Artifact Bucket
- CodeBuild Project
- CodePipeline
- 必要的 IAM Roles / Policies

### Terraform 實作要求

- AWS provider 使用 `hashicorp/aws`
- 區域預設可設為 `ap-east-1` 或變數化
- 使用 `locals` 管理命名與 tags
- IAM policy 盡量最小權限
- 請將 Terraform 拆分為多個 `.tf` 檔，不要全部塞一檔
- 請提供 `terraform.tfvars.example`
- 請提供 `outputs.tf`

### ECS / Pipeline 要求

- ECS 使用 Fargate
- ALB 對外開 80，轉發到 container 8080
- Task definition container name 固定為 `app`
- CodeBuild build image 後，tag 使用 Git commit SHA 前 7 碼
- 同時 push `${sha}` 與 `latest`
- `buildspec.yml` 必須產生 `imagedefinitions.json`
- CodePipeline deploy stage 使用 ECS standard deploy action

### README 要求

README 必須包含：

1. Overview
2. Architecture
3. CI/CD Flow
4. Terraform Resources
5. Project Structure
6. Deployment Steps
7. Validation Steps
8. Screenshots Placeholder
9. DevOps Skills Demonstrated

### 驗收標準

完成後，應可達成：

- `terraform init && terraform plan` 可成功
- `terraform apply` 後可建立完整資源
- push 新 commit 後可觸發 pipeline
- CodeBuild 可 build 並 push image 到 ECR
- CodePipeline 可部署到 ECS
- ALB URL 可成功回應 `/` 與 `/health`
- CloudWatch Logs 可看到應用程式輸出

### 額外要求

- 程式碼需乾淨、可讀、模組化
- 所有可變動值盡量參數化
- 不要把 secret 寫死在 repo
- 若某些 GitHub source connection 細節依 AWS 當前可用方式不同，請以目前可行且官方支援的作法實作

---

# 第六部分：你在作品集中怎麼描述

你可以在 GitHub repo 首段直接寫：

```markdown
This project demonstrates a complete AWS DevOps workflow:
GitHub -> CodePipeline -> CodeBuild -> Amazon ECR -> Amazon ECS Fargate.
Infrastructure is provisioned with Terraform, and application logs are collected with CloudWatch Logs.
```

你在面試或履歷中可以用這句：

```text
Built a containerized application delivery pipeline on AWS using CodePipeline, CodeBuild, ECR, ECS Fargate, and Terraform, enabling automated image build, registry push, and rolling deployment.
```

---

# 第七部分：驗證清單

完成後請逐項確認：

- Terraform 能成功建立 ECR
- Terraform 能成功建立 ECS cluster/service/task definition
- ALB 可取得 DNS name
- ECS service desired count = 1 並穩定運行
- CodeBuild 能成功登入 ECR
- ECR 內看得到 `${sha}` 與 `latest`
- `imagedefinitions.json` 有正確輸出
- CodePipeline deploy 成功
- `/health` 回 200
- CloudWatch Logs 看得到 app log

---

# 第八部分：後續加分方向

若最小版完成，可再擴充：

- HTTPS：ACM + ALB HTTPS listener
- 自訂網域：Route 53
- private subnet + NAT
- Secrets Manager / SSM Parameter Store
- staging / prod 雙環境
- remote state：S3 + DynamoDB lock
- GitHub Actions 與 AWS Pipeline 雙版本比較
- blue/green deploy
- ECS auto scaling
- WAF

---

## 最終定位

這個專案在作品集裡要表達的不是「我把網站上線」，而是：

- 我會容器化
- 我會 AWS 原生 CI/CD
- 我理解 ECR、ECS、CodeBuild、CodePipeline 的職責切分
- 我會用 Terraform 管理基礎設施
- 我能把部署流程做成可重複、可版本化、可驗證的系統

