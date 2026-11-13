#################################################
# ECS cluster, task definitions and services
#################################################

resource "aws_ecs_cluster" "cluster" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ---------- Frontend ----------
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = var.frontend_container_name
      image     = var.frontend_image
      essential = true
      portMappings = [
        {
          containerPort = var.frontend_container_port
          hostPort      = var.frontend_container_port
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-frontend-svc"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.frontend_desired_count
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 90

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_tg.arn
    container_name   = var.frontend_container_name
    container_port   = var.frontend_container_port
  }

  network_configuration {
    subnets          = [aws_subnet.priv_subnet_1.id, aws_subnet.priv_subnet_2.id]
    security_groups  = [aws_security_group.frontend_sg.id]
    assign_public_ip = false
  }

  # Target group must be attached to the ALB before the service is created
  depends_on = [aws_lb_listener.https]
}

# ---------- API ----------
locals {
  ssm_arn_prefix = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_prefix}"

  # Shared by the migrate and api containers
  api_environment = [
    { name = "ALGORITHM", value = "HS256" },
    { name = "ACCESS_TOKEN_EXPIRE_MINUTES", value = "60" },
  ]
  api_secrets = [
    { name = "DATABASE_URL", valueFrom = "${local.ssm_arn_prefix}/DATABASE_URL" },
    { name = "SECRET_KEY", valueFrom = "${local.ssm_arn_prefix}/SECRET_KEY" },
  ]
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    # Runs alembic migrations against the database, then exits.
    # The api container below only starts if this exits successfully.
    {
      name        = "migrate"
      image       = var.api_image
      essential   = false
      command     = ["python", "-m", "app.migrate"]
      environment = local.api_environment
      secrets     = local.api_secrets
    },
    {
      name        = var.api_container_name
      image       = var.api_image
      essential   = true
      environment = local.api_environment
      secrets     = local.api_secrets
      dependsOn = [
        { containerName = "migrate", condition = "SUCCESS" }
      ]
      portMappings = [
        {
          containerPort = var.api_container_port
          hostPort      = var.api_container_port
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-api-svc"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 90

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_tg.arn
    container_name   = var.api_container_name
    container_port   = var.api_container_port
  }

  network_configuration {
    subnets          = [aws_subnet.priv_subnet_1.id, aws_subnet.priv_subnet_2.id]
    security_groups  = [aws_security_group.api_sg.id]
    assign_public_ip = false
  }

  depends_on = [aws_lb_listener_rule.api]
}
