#################################################
# Load balancer
#################################################

# Accepted risk: this is the public entry point of the website, so it must be internet-facing
#trivy:ignore:AVD-AWS-0053
resource "aws_lb" "alb" {
  #checkov:skip=CKV2_AWS_28: WAF (~$5+/month) deferred for this learning project; see README security section
  #checkov:skip=CKV_AWS_91: Logging intentionally disabled for this project; see README security section
  #checkov:skip=CKV_AWS_150: Deletion protection would block the routine terraform destroy of this stack
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.pub_subnet_1.id, aws_subnet.pub_subnet_2.id]
  security_groups    = [aws_security_group.alb_sg.id]

  drop_invalid_header_fields = true

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "frontend_tg" {
  #checkov:skip=CKV_AWS_378: TLS ends at the ALB; ALB-to-task traffic stays inside the private VPC
  # name_prefix + create_before_destroy lets the TG be replaced (e.g. port change)
  # without failing on "ResourceInUse" while the listener still points at it.
  name_prefix = "fe-"
  port        = var.frontend_container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # required for Fargate

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.frontend_health_check_path
    protocol            = "HTTP"
    port                = var.frontend_container_port
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 5
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.project_name}-fe-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "api_tg" {
  #checkov:skip=CKV_AWS_378: TLS ends at the ALB; ALB-to-task traffic stays inside the private VPC
  # name_prefix + create_before_destroy lets the TG be replaced (e.g. port change)
  # without failing on "ResourceInUse" while the listener still points at it.
  name_prefix = "api-"
  port        = var.api_container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # required for Fargate

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.api_health_check_path
    protocol            = "HTTP"
    port                = var.api_container_port
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 5
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.project_name}-api-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Default action sends everything to the frontend
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

# /api/* goes to the API. The ALB does NOT strip the prefix,
# so the API must serve its routes under /api.
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api", "/api/*"]
    }
  }
}

