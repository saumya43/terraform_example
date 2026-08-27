#Create autoscaling group for configuration
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

resource "aws_launch_configuration" "cluster_host" {
  image_id      = "ami-0fb653ca2d3203ac1"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.sg_01.id]

  user_data = var.user_data

  # Required when using a launch configuration with an auto scaling group.
lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg_01" {
  name: var.cluster_name
  launch_configuration = aws_launch_configuration.cluster_host.name
  vpc_zone_identifier  = var.subnet_ids
  target_group_arns = var.target_group_arns
  health_check_type = var.health_check_type

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}"
    propagate_at_launch = true
  }
  dynamic "tag" {
    for_each = var.custom_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# creating autoscaling scheduled
resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  count = var.enable_autoscaling ? 1 : 0

  scheduled_action_name  = "${var.cluster_name}-scale-out-during-business-hours"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 10
  recurrence             = "0 9 * * *"
  autoscaling_group_name = aws_autoscaling_group.asg_01.name
}

resource "aws_autoscaling_schedule" "scale_in_at_night" {
  count = var.enable_autoscaling ? 1 : 0

  scheduled_action_name  = "${var.cluster_name}-scale-in-at-night"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 2
  recurrence             = "0 17 * * *"
  autoscaling_group_name = aws_autoscaling_group.asg_01.name
}