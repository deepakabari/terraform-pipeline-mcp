# Node Express CRUD — AWS CodePipeline Deployment

This project deploys a Node.js Express CRUD API to **AWS S3** using a fully automated **AWS CodePipeline + CodeBuild** CI/CD pipeline, provisioned with **Terraform**.

## Architecture

```
GitHub (push to main)
    │
    ▼
┌──────────────────────────────────────────────────────┐
│  AWS CodePipeline                                    │
│                                                      │
│  ┌────────────┐   ┌────────────┐   ┌──────────────┐  │
│  │   Source    │──▶│   Build    │──▶│   Deploy     │  │
│  │  (GitHub)  │   │ (CodeBuild)│   │  (S3 Sync)   │  │
│  └────────────┘   └────────────┘   └──────────────┘  │
└──────────────────────────────────────────────────────┘
```

## Infrastructure (Terraform)

| Resource | Purpose |
|---|---|
| `aws_s3_bucket.website` | Hosts the static website / app artifacts |
| `aws_s3_bucket.codepipeline_artifacts` | Stores pipeline intermediate artifacts |
| `aws_codestarconnections_connection.github` | Connects CodePipeline to your GitHub repo |
| `aws_codebuild_project.build` | Builds the project (`npm install` → `npm run build`) |
| `aws_codepipeline.pipeline` | Orchestrates Source → Build → Deploy |

## Getting Started

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.0
- AWS CLI configured with appropriate credentials
- A GitHub account with the target repository

### 1. Initialize & Apply Terraform

```bash
terraform init
terraform plan
terraform apply
```

### 2. Activate the CodeStar Connection

> **Important:** After the first `terraform apply`, the CodeStar connection will be in a **PENDING** state. You must manually confirm it in the AWS Console:
>
> 1. Go to **AWS Console → Developer Tools → Settings → Connections**
> 2. Select the `github-connection`
> 3. Click **Update pending connection**
> 4. Authorize AWS to access your GitHub account/repo

### 3. Trigger the Pipeline

Once the connection is active, any push to the configured branch (default: `main`) will automatically trigger the pipeline:

- **Source** — Pulls code from GitHub
- **Build** — Runs `npm install`, `npm run build`, and syncs to S3
- **Deploy** — Extracts build artifacts to the website S3 bucket

## Project Structure

```
├── buildspec.yml       # CodeBuild build specification
├── main.tf             # Core Terraform infrastructure
├── variables.tf        # Terraform input variables
├── package.json        # Node.js dependencies
└── src/
    ├── index.js        # Express app entry point
    ├── controllers/    # Route controllers
    ├── routes/         # API route definitions
    └── services/       # Business logic
```

## Variables

| Variable | Default | Description |
|---|---|---|
| `region` | `us-east-1` | AWS region |
| `profile` | `default` | AWS CLI profile |
| `bucket_name` | `node-express-crud-deploy-...` | S3 website bucket name |
| `project_name` | `node-express-crud` | Prefix for AWS resource names |
| `github_repo_id` | `deepakabari/terraform-pipeline-mcp` | GitHub `owner/repo` |
| `github_branch` | `main` | Branch that triggers the pipeline |

## Outputs

| Output | Description |
|---|---|
| `website_url` | Public URL of the S3-hosted website |
| `pipeline_name` | Name of the CodePipeline |
| `codebuild_project_name` | Name of the CodeBuild project |
| `codestar_connection_arn` | ARN of the CodeStar connection (confirm after first apply) |
