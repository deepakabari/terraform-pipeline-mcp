---
name: AWS Node.js Pipeline Specialist
description: Deploy a Node.js app using Terraform, CodeBuild, and CodePipeline.
---

# Skill: AWS Node.js Pipeline Specialist

## Objective

Deploy a Node.js app using Terraform, CodeBuild, and CodePipeline.

## Constraints

- Always use S3 for artifacts.
- CodeBuild must use `amazonlinux2-x86_64-standard:4.0`.
- If a Terraform apply fails, use the `aws-mcp` hook to check IAM policy simulator.

## Iteration Loop

1. Generate Terraform code.
2. Run `terraform plan` and show me the output.
3. Upon approval, execute `terraform apply`.
4. Check CodePipeline status via MCP until "Succeeded".
