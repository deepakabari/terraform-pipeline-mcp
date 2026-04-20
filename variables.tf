variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS profile"
  type        = string
  default     = "default"
}

variable "bucket_name" {
  description = "Name for the S3 bucket that hosts the static website"
  type        = string
  default     = "node-express-crud-deploy-982689565504-us-east-1"
}

variable "project_name" {
  description = "Project name used to prefix AWS resource names"
  type        = string
  default     = "node-express-crud"
}

variable "github_repo_id" {
  description = "GitHub repository in the format owner/repo"
  type        = string
  default     = "deepakabari/terraform-pipeline-mcp"
}

variable "github_branch" {
  description = "GitHub branch to trigger the pipeline on push"
  type        = string
  default     = "main"
}
