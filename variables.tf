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
  description = "Name for the S3 bucket to store artifacts"
  type        = string
  default     = "node-express-crud-deploy-982689565504-us-east-1"
}

variable "github_repo_id" {
  description = "deepakabari/terraform-pipeline-mcp"
  type        = string
  default     = "deepakabari/terraform-pipeline-mcp"
}
