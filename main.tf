provider "aws" {
  region  = var.region
  profile = var.profile
}

locals {
  common_tags = {
    Project = "Antigravity"
  }
}

# Artifacts Bucket (Required by Skill)
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.bucket_name}-artifacts"
  force_destroy = true
  tags          = local.common_tags
}

resource "aws_s3_bucket_versioning" "artifacts_versioning" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Static Website Bucket
resource "aws_s3_bucket" "website" {
  bucket        = var.bucket_name
  force_destroy = true
  tags          = local.common_tags
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website_pab" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.website_pab
  ]
}

# CodeStar Connection for GitHub
resource "aws_codestarconnections_connection" "github" {
  name          = "antigravity-github-conn"
  provider_type = "GitHub"
  tags          = local.common_tags
}

# CodeBuild Role
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role-antigravity-v2"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
         Effect = "Allow",
         Principal = { Service = "codebuild.amazonaws.com" },
         Action = "sts:AssumeRole"
      }
    ]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "codebuild-policy-antigravity-v2"
  role = aws_iam_role.codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
          aws_s3_bucket.website.arn,
          "${aws_s3_bucket.website.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# CodePipeline Role
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role-antigravity-v2"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
         Effect = "Allow",
         Principal = { Service = "codepipeline.amazonaws.com" },
         Action = "sts:AssumeRole"
      }
    ]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline-policy-antigravity-v2"
  role = aws_iam_role.codepipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
          aws_s3_bucket.website.arn,
          "${aws_s3_bucket.website.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = aws_codestarconnections_connection.github.arn
      }
    ]
  })
}

# CodeBuild Project
resource "aws_codebuild_project" "build" {
  name          = "antigravity-build"
  description   = "Builds the static website"
  service_role  = aws_iam_role.codebuild_role.arn
  tags          = local.common_tags

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_CUSTOM_CACHE"]
  }
}

# CodePipeline
resource "aws_codepipeline" "pipeline" {
  name     = "antigravity-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  tags     = local.common_tags

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = var.github_repo_id
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "DeployToS3"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      input_artifacts = ["build_output"]
      version         = "1"
      configuration = {
        BucketName = aws_s3_bucket.website.bucket
        Extract    = "true"
      }
    }
  }
}
