resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/codebuild/${local.name_prefix}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}
