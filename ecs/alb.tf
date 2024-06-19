resource "aws_lb" "ecs_alb" {
  name                       = "ecs-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.security_group.id]
  subnets                    = [aws_subnet.subnet.id, aws_subnet.subnet2.id, aws_subnet.subnet3.id]
  enable_deletion_protection = false
  tags = {
    Name = "ecs-alb"
  }
}

resource "aws_lb_listener" "ecs_alb_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}

resource "aws_lb_target_group" "ecs_tg" {
  name        = "ecs-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "ecs_alb_listener_backend" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 3000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg_backend.arn
  }
}

resource "aws_lb_target_group" "ecs_tg_backend" {
  name        = "ecs-target-group-backend"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path = "/api"
  }
}

resource "aws_lb_listener_rule" "frontend_rule" {
  listener_arn = aws_lb_listener.ecs_alb_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_lb_listener_rule" "backend_rule" {
  listener_arn = aws_lb_listener.ecs_alb_listener_backend.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg_backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

