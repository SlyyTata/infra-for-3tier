variable "project_name" {
  description = "Prefix used to name resources so they don't clash with other stacks"
  type        = string

  validation {
    # ALB / target group names are limited to 32 characters
    condition     = length(var.project_name) <= 20 && can(regex("^[a-zA-Z0-9-]+$", var.project_name))
    error_message = "project_name must be 20 characters or fewer and contain only letters, numbers and hyphens."
  }
}

variable "region" {
  description = "The AWS region to deploy the resources"
  type        = string
}

# ---------- Networking ----------
variable "cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "pub_subnet_cidr_block_1" {
  description = "The CIDR block for the first public subnet"
  type        = string
}

variable "pub_subnet_cidr_block_2" {
  description = "The CIDR block for the second public subnet"
  type        = string
}

variable "priv_subnet_cidr_block_1" {
  description = "The CIDR block for the first private subnet"
  type        = string
}

variable "priv_subnet_cidr_block_2" {
  description = "The CIDR block for the second private subnet"
  type        = string
}

variable "certificate_arn" {
  description = "The ACM certificate ARN for the HTTPS listener"
  type        = string
}

# ---------- Frontend ----------
variable "frontend_image_tag" {
  description = "Tag of the frontend image in ECR used by Terraform's task definition (CD deploys commit-SHA tags on top)"
  type        = string
  default     = "latest"
}

variable "frontend_container_name" {
  description = "Name of the frontend container"
  type        = string
}

variable "frontend_container_port" {
  description = "Port the frontend container listens on"
  type        = number
}

variable "frontend_health_check_path" {
  description = "Health check path for the frontend target group"
  type        = string
  default     = "/"
}

variable "frontend_desired_count" {
  description = "Number of frontend tasks"
  type        = number
  default     = 2
}

# ---------- API ----------
variable "api_image_tag" {
  description = "Tag of the API image in ECR used by Terraform's task definition (CD deploys commit-SHA tags on top)"
  type        = string
  default     = "latest"
}

variable "api_container_name" {
  description = "Name of the API container"
  type        = string
}

variable "api_container_port" {
  description = "Port the API container listens on"
  type        = number
}

variable "api_health_check_path" {
  description = "Health check path for the API target group. Health checks go straight to the task (not through listener rules), so it doesn't need to be under /api"
  type        = string
  default     = "/health"
}

variable "api_desired_count" {
  description = "Number of API tasks"
  type        = number
  default     = 2
}

# ---------- App secrets ----------
variable "ssm_parameter_prefix" {
  description = "SSM Parameter Store path holding the API secrets (DATABASE_URL, SECRET_KEY) as SecureStrings"
  type        = string
  default     = "/realmile"
}

# ---------- App CD (GitHub Actions OIDC) ----------
variable "github_app_repo" {
  description = "owner/repo whose CD workflow may deploy new images to the ECS services"
  type        = string
  default     = "SlyyTata/realmile-logistics"
}

variable "github_app_branch" {
  description = "Only workflow runs on this branch of github_app_repo can assume the deploy role"
  type        = string
  default     = "main"
}
