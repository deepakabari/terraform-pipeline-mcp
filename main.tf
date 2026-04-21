terraform {
  backend "s3" {
    bucket = "node-express-crud-tfstate-982689565504"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

locals {
  common_tags = {
    Project = "Antigravity"
  }
}

# ──────────────────────────────────────────────
# Elastic Beanstalk Application & Environment
# ──────────────────────────────────────────────

resource "aws_elastic_beanstalk_application" "app" {
  name        = var.project_name
  description = "Node Express CRUD App"
}

# Find the latest Node.js 20 Amazon Linux 2023 stack
data "aws_elastic_beanstalk_solution_stack" "nodejs" {
  most_recent = true
  name_regex  = "^64bit Amazon Linux 2023 (.*) running Node.js 20(.*)$"
}

resource "aws_elastic_beanstalk_environment" "env" {
  name                = "${var.project_name}-env"
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.nodejs.name

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_profile.name
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DYNAMODB_TABLE"
    value     = aws_dynamodb_table.items.name
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance" # No load balancer to keep costs low
  }
}

# IAM Role/Profile for EC2 instances inside Elastic Beanstalk
resource "aws_iam_role" "eb_role" {
  name = "${var.project_name}-eb-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eb_web_tier" {
  role       = aws_iam_role.eb_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_instance_profile" "eb_profile" {
  name = "${var.project_name}-eb-profile"
  role = aws_iam_role.eb_role.name
}

# ──────────────────────────────────────────────
# DynamoDB Table
# ──────────────────────────────────────────────
resource "aws_dynamodb_table" "items" {
  name           = "${var.project_name}-items"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = local.common_tags
}

resource "aws_iam_role_policy" "eb_dynamodb_policy" {
  name = "${var.project_name}-eb-dynamodb"
  role = aws_iam_role.eb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.items.arn
      }
    ]
  })
}


# ──────────────────────────────────────────────
# S3 — CodePipeline Artifact Store
# ──────────────────────────────────────────────
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket        = "${var.bucket_name}-pipeline-artifacts"
  force_destroy = true
  tags          = local.common_tags
}

# ──────────────────────────────────────────────
# CodeStar Connection — GitHub v2 source
# ──────────────────────────────────────────────
resource "aws_codestarconnections_connection" "github" {
  name          = "github-connection"
  provider_type = "GitHub"
  tags          = local.common_tags
}

# ──────────────────────────────────────────────
# IAM — CodeBuild Service Role
# ──────────────────────────────────────────────
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-${var.project_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "codebuild-${var.project_name}-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      }
    ]
  })
}

# ──────────────────────────────────────────────
# IAM — CodePipeline Service Role
# ──────────────────────────────────────────────
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-${var.project_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline-${var.project_name}-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = [
          aws_codebuild_project.build.arn,
          aws_codebuild_project.terraform_apply.arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = "codestar-connections:UseConnection"
        Resource = aws_codestarconnections_connection.github.arn
      },
      # Elastic Beanstalk Deploy Permissions
      {
        Effect = "Allow"
        Action = [
          "elasticbeanstalk:*",
          "autoscaling:*",
          "ec2:*",
          "cloudformation:*"
        ]
        Resource = "*"
      },
      {
        # Broad permissions needed for CodePipeline to initialize and manage EB deployment buckets
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "arn:aws:s3:::elasticbeanstalk-*",
          "arn:aws:s3:::elasticbeanstalk-*/*"
        ]
      }
    ]
  })
}

# ──────────────────────────────────────────────
# IAM — Terraform CodeBuild Service Role
# ──────────────────────────────────────────────
resource "aws_iam_role" "terraform_codebuild_role" {
  name = "terraform-codebuild-${var.project_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_admin_policy" {
  role       = aws_iam_role.terraform_codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ──────────────────────────────────────────────
# CodeBuild — Terraform Apply Project
# ──────────────────────────────────────────────
resource "aws_codebuild_project" "terraform_apply" {
  name         = "${var.project_name}-terraform-apply"
  description  = "Runs terraform apply in CodePipeline"
  service_role = aws_iam_role.terraform_codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    
    environment_variable {
      name  = "TF_IN_AUTOMATION"
      value = "true"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-tf.yml"
  }
}

# ──────────────────────────────────────────────
# CodeBuild — Build Project
# ──────────────────────────────────────────────
resource "aws_codebuild_project" "build" {
  name         = "${var.project_name}-build"
  description  = "Packages project for EB"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

# ──────────────────────────────────────────────
# CodePipeline — Full CI/CD Pipeline
# ──────────────────────────────────────────────
resource "aws_codepipeline" "pipeline" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  # Stage 1 — Source (GitHub)
  stage {
    name = "Source"

    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = var.github_repo_id
        BranchName       = var.github_branch
        DetectChanges    = "true"
      }
    }
  }

  # Stage 2 — Package (CodeBuild)
  stage {
    name = "Build"

    action {
      name             = "CodeBuild"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  # Stage 3 — Terraform Deploy
  stage {
    name = "Terraform_Apply"

    action {
      name             = "Terraform_Deploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]

      configuration = {
        ProjectName = aws_codebuild_project.terraform_apply.name
      }
    }
  }

  # Stage 4 — Deploy App to Elastic Beanstalk
  stage {
    name = "Deploy_App"

    action {
      name            = "Deploy_to_EB"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ElasticBeanstalk"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ApplicationName = aws_elastic_beanstalk_application.app.name
        EnvironmentName = aws_elastic_beanstalk_environment.env.name
      }
    }
  }
}

# ──────────────────────────────────────────────
# Outputs
# ──────────────────────────────────────────────
output "elastic_beanstalk_environment_url" {
  description = "The URL where your Node.js API is running"
  value       = "http://${aws_elastic_beanstalk_environment.env.cname}"
}

output "pipeline_name" {
  value = aws_codepipeline.pipeline.name
}

output "codestar_connection_arn" {
  value = aws_codestarconnections_connection.github.arn
}
