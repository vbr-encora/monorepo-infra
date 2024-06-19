data "aws_iam_policy_document" "ecs_task_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name_prefix        = "demo-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_doc.json
}

resource "aws_iam_role" "ecs_exec_role" {
  name_prefix        = "demo-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_doc.json
}

resource "aws_iam_role_policy_attachment" "ecs_exec_role_policy" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-ecs-cluster"
}

resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
  name = "test1"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "cluster_capacity_provider" {
  cluster_name = aws_ecs_cluster.ecs_cluster.name

  capacity_providers = [aws_ecs_capacity_provider.ecs_capacity_provider.name, aws_ecs_capacity_provider.capacity_provider_backend.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/demo"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family             = "my-ecs-task"
  network_mode       = "awsvpc"
  task_role_arn      = aws_iam_role.ecs_task_role.arn
  execution_role_arn = aws_iam_role.ecs_exec_role.arn
  cpu                = 128

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "738989335057.dkr.ecr.us-east-1.amazonaws.com/docker-monorepo:frontend_latest"
      essential = true
      cpu       = 128
      memory    = 128
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-region"        = "us-east-1",
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name,
          "awslogs-stream-prefix" = "frontend"
        }
      },
    }
  ])
}


resource "aws_ecs_service" "ecs_service" {
  name            = "my-ecs-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count   = 2

  network_configuration {
    subnets         = [aws_subnet.subnet.id, aws_subnet.subnet2.id]
    security_groups = [aws_security_group.security_group.id]
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
    weight            = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "frontend"
    container_port   = 80
  }

  depends_on = [aws_autoscaling_group.ecs_asg, aws_lb_target_group.ecs_tg]
}

resource "aws_ecs_capacity_provider" "capacity_provider_backend" {
  name = "capacity_provider_back"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg_backend.arn

    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_task_definition" "ecs_task_definition_backend" {
  family             = "my-ecs-task-backend"
  network_mode       = "awsvpc"
  task_role_arn      = aws_iam_role.ecs_task_role.arn
  execution_role_arn = aws_iam_role.ecs_exec_role.arn
  cpu                = 128
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "738989335057.dkr.ecr.us-east-1.amazonaws.com/docker-monorepo:backend_latest"
      essential = true
      cpu       = 128
      memory    = 128
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-region"        = "us-east-1",
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name,
          "awslogs-stream-prefix" = "backend"
        }
      },
    }
  ])
}


resource "aws_ecs_service" "ecs_service_backend" {
  name            = "my-ecs-service-backend"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition_backend.arn
  desired_count   = 1

  network_configuration {
    subnets         = [aws_subnet.subnet3.id]
    security_groups = [aws_security_group.security_group.id]
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.capacity_provider_backend.name
    weight            = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg_backend.arn
    container_name   = "backend"
    container_port   = 3000
  }

  depends_on = [aws_autoscaling_group.ecs_asg_backend, aws_lb_target_group.ecs_tg_backend]
}
