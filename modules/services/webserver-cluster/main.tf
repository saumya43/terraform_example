resource "aws_instance" "new_host" {
  ami           = "ami-0fb653ca2d3203ac1"
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.sg_01.id]

  user_data = <<-EOF
            #!/bin/bash
            echo "Hello, World" > index.html
            nohup busybox httpd -f -p 8080 &
            EOF


  user_data_replace_on_change = true

  tags = {
    Name = "terraform-example"
  }
}

locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}
variable "service_port" {
 description = "defines to port to run app "
 type        = number
 default     = 8080
}

#output "public_ip" {
 # value       = aws_instance.new_host.public_ip
  #description = "The public IP address of the web server"
#}

output "alb_dns_name" {
  value       = aws_lb.alb_01.dns_name
  description = "The domain name of the load balancer"
}

resource "aws_security_group" "sg_01" {
  name = "${var.cluster_name}-instance"
}
resource "aws_security_group_rule" "allow_instance_inbound" {
type              = "ingress"
security_group_id = aws_security_group.sg_01.id

from_port   = var.service_port
to_port     = var.service_port
protocol    = local.tcp_protocol
cidr_blocks = local.all_ips
}
  

#Create autoscaling group for configuration

resource "aws_launch_configuration" "cluster_host" {
  image_id      = "ami-0fb653ca2d3203ac1"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.sg_01.id]

  user_data = templatefile("${path.module}/user-data.sh", {
    server_port = var.service_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  })

  # Required when using a launch configuration with an auto scaling group.
lifecycle {
    create_before_destroy = true
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_autoscaling_group" "asg_01" {
  launch_configuration = aws_launch_configuration.cluster_host.name
  vpc_zone_identifier  = data.aws_subnets.default.ids
  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}"
    propagate_at_launch = true
  }
}

#Create elastic load balancer using terraform

resource "aws_lb" "alb_01" {
  name               = "${var.cluster_name}-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

#define listener

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb_01.arn
  port              = local.http_port
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}


resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port   = local.http_port
  to_port     = local.http_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id

  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = local.all_ips
}

resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.service_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}
data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "us-east-2"
  }
}

