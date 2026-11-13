#################################################
# Security groups
#################################################

resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Public ALB: HTTP/HTTPS in from the internet, out only to the app tasks"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "frontend_sg" {
  name        = "${var.project_name}-frontend-sg"
  description = "Frontend tasks: in only from the ALB, out only HTTPS"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "api_sg" {
  name        = "${var.project_name}-api-sg"
  description = "API tasks: in only from the ALB, out only HTTPS and Postgres"
  vpc_id      = aws_vpc.main.id
}

#################################################
# ALB rules
#################################################

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  #checkov:skip=CKV_AWS_260: Port 80 only answers with a redirect to HTTPS (see aws_lb_listener.http)
  security_group_id = aws_security_group.alb_sg.id
  description       = "HTTP from the internet (redirected to HTTPS)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb_sg.id
  description       = "HTTPS from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_to_frontend" {
  security_group_id            = aws_security_group.alb_sg.id
  description                  = "Forward requests and health checks to frontend tasks"
  referenced_security_group_id = aws_security_group.frontend_sg.id
  ip_protocol                  = "tcp"
  from_port                    = var.frontend_container_port
  to_port                      = var.frontend_container_port
}

resource "aws_vpc_security_group_egress_rule" "alb_to_api" {
  security_group_id            = aws_security_group.alb_sg.id
  description                  = "Forward /api requests and health checks to API tasks"
  referenced_security_group_id = aws_security_group.api_sg.id
  ip_protocol                  = "tcp"
  from_port                    = var.api_container_port
  to_port                      = var.api_container_port
}

#################################################
# Frontend rules
#################################################

resource "aws_vpc_security_group_ingress_rule" "frontend_from_alb" {
  security_group_id            = aws_security_group.frontend_sg.id
  description                  = "Requests and health checks from the ALB only"
  referenced_security_group_id = aws_security_group.alb_sg.id
  ip_protocol                  = "tcp"
  from_port                    = var.frontend_container_port
  to_port                      = var.frontend_container_port
}

# Accepted risk: Docker Hub has no fixed IPs; restricted to HTTPS
#trivy:ignore:AVD-AWS-0104
resource "aws_vpc_security_group_egress_rule" "frontend_https_out" {
  security_group_id = aws_security_group.frontend_sg.id
  description       = "HTTPS out via NAT: Docker Hub image pulls"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

#################################################
# API rules
#################################################

resource "aws_vpc_security_group_ingress_rule" "api_from_alb" {
  security_group_id            = aws_security_group.api_sg.id
  description                  = "Requests and health checks from the ALB only"
  referenced_security_group_id = aws_security_group.alb_sg.id
  ip_protocol                  = "tcp"
  from_port                    = var.api_container_port
  to_port                      = var.api_container_port
}

# Accepted risk: Docker Hub and AWS SSM have no fixed IPs; restricted to HTTPS
#trivy:ignore:AVD-AWS-0104
resource "aws_vpc_security_group_egress_rule" "api_https_out" {
  security_group_id = aws_security_group.api_sg.id
  description       = "HTTPS out via NAT: Docker Hub image pulls and SSM Parameter Store"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Accepted risk: Neon is an external managed Postgres with no fixed IPs; restricted to port 5432
#trivy:ignore:AVD-AWS-0104
resource "aws_vpc_security_group_egress_rule" "api_postgres_out" {
  security_group_id = aws_security_group.api_sg.id
  description       = "Postgres out via NAT to Neon (SSL enforced by the app)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
}
