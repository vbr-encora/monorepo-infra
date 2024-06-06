variable "aws_region" {
  description = "AWS region"
}

variable "github_repo_url" {
  description = "URL del repositorio de GitHub"
}

variable "github_token" {
  description = "Token de GitHub"
}

variable "codebuild_project_name" {
  description = "Nombre del proyecto de CodeBuild"
}

variable "ecr_repo_name" {
  description = "Nombre del repositorio de ECR"
}

variable "codebuild_role_name" {
  description = "Nombre del rol de IAM para CodeBuild"
}