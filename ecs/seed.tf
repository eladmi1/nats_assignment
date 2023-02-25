resource "aws_ecs_task_definition" "nats_seed_task" {
  family                   = "nats_seed_task"
  container_definitions    = jsonencode([
      {
        "command": ["--cluster_name", "NATS", "--cluster", "nats://0.0.0.0:6222", "--http_port", "8222"],
         "essential": true,
         "image": "nats:latest",
         "name": "nats_seed",
         "portMappings": [
            {
               "containerPort": 8222,
               "hostPort": 8222
            },
            {
               "containerPort": 4222,
               "hostPort": 4222
            }
         ]
      }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 512
  cpu                      = 256
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
}

resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = "${var.http_monitoring_port}"
    to_port     = "${var.http_monitoring_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "application_load_balancer" {
  name               = "nats-alb"
  load_balancer_type = "application"
  subnets = [
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}",
    "${aws_default_subnet.default_subnet_c.id}"
  ]
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

resource "aws_lb_target_group" "http_target_group" {
  name        = "nats-target-group"
  port        = "${var.http_monitoring_port}"
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_default_vpc.default_vpc.id}" 
  health_check {
    matcher = "200"
    path = "/"
  }
}

resource "aws_ecs_service" "nats_service" {
  name            = "nats-service"
  cluster         = aws_ecs_cluster.nats_cluster.id
  task_definition = aws_ecs_task_definition.nats_seed_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  
  load_balancer {
    target_group_arn = "${aws_lb_target_group.http_target_group.arn}" 
    container_name   = "nats_seed"
    container_port   = "${var.http_monitoring_port}"
  }
  
  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}", "${aws_default_subnet.default_subnet_c.id}"]
    security_groups  = ["${aws_security_group.load_balancer_security_group.id}"]
    assign_public_ip = true
  }
}

resource "aws_lb_listener" "http_monitor" {
  load_balancer_arn = "${aws_alb.application_load_balancer.arn}" 
  port              = "${var.http_monitoring_port}"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.http_target_group.arn}" 
  }
}

resource "aws_route53_record" "www" {
  zone_id = "Z03426271WYK1UIK7PFGW"
  name    = "www.314d.link"
  type    = "A"

  alias {
    name                   = aws_alb.application_load_balancer.dns_name
    zone_id                = aws_alb.application_load_balancer.zone_id
    evaluate_target_health = true
  }
}