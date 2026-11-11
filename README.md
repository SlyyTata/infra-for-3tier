# 3rd-tier-custom-infra

ECS Fargate stack with separate frontend and API services behind one ALB.

- `/api/*` -> API service
- everything else -> frontend service

State: `s3://slyy-tata-bck-remote/three-tier-ecs-fargate/terraform.tfstate`

## Layout

| File | Contents |
|---|---|
| `provider.tf` | Terraform/provider versions, S3 backend |
| `variables.tf` | Input variables |
| `network.tf` | VPC, subnets, IGW, NAT, route tables |
| `security_groups.tf` | ALB, frontend and API security groups |
| `alb.tf` | ALB, target groups, listeners, `/api` routing rule |
| `iam.tf` | ECS task execution role |
| `logs.tf` | CloudWatch log groups |
| `ecs.tf` | ECS cluster, task definitions, services |
| `outputs.tf` | Outputs |

Create a `terraform.tfvars` (git-ignored) with values for the variables in `variables.tf`.
