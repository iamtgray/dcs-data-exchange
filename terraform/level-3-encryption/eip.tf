# Elastic IP for the NLB that fronts the OpenTDF platform.
# Gives the platform a stable IP that can be baked into
# server.public_hostname at Terraform time.

resource "aws_eip" "opentdf" {
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-opentdf"
    Project = var.project_name
  }
}

resource "aws_lb" "opentdf" {
  name               = "${var.project_name}-nlb"
  internal           = false
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = data.aws_subnets.default.ids[0]
    allocation_id = aws_eip.opentdf.id
  }
}

resource "aws_lb_target_group" "opentdf" {
  name        = "${var.project_name}-tg"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    protocol = "HTTP"
    path     = "/healthz"
    port     = "8080"
  }
}

resource "aws_lb_listener" "opentdf" {
  load_balancer_arn = aws_lb.opentdf.arn
  port              = 8080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.opentdf.arn
  }
}
