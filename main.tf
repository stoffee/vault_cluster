
## By Default AWS does not allow any incoming or outgoing traffic from an EC2 instance, therefore we need a security group!
resource "aws_security_group" "instance" {
	name	=	"terraform-example-instance"

	ingress {
		from_port		= var.server_port
		to_port			= var.server_port
		protocol	  = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
}

## New security group for ALB to allow ingress and egress, accept incoming requests on port 80 for HTTP and outgoing requests over all ports
resource "aws_security_group" "alb" {
	name	= "terraform-example-alb"

	# Allow inbound HTTP over port 80
	ingress {
		from_port		= 80
		to_port			= 80
		protocol		= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	# -1 denotes all protocols. 
	egress {
		from_port		= 0
		to_port			= 0
		protocol		= "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}


## Launch Configurations specify how to configure each EC2 instance in the ASG
resource "aws_launch_configuration" "example" {
	image_id				= "ami-06d51e91cea0dac8d"
	instance_type		= "t2.micro"
	security_groups = aws_security_group.instance.id

	user_data = <<-EOF
							#!/bin/bash
							echo 'Robert, sup nigga' > index.html
							nohup busybox httpd -f -p 8080 &
							EOF

	# Terraform will invert the order in which it replaces resources, creating the replacement resource first
	lifecycle { 
		create_before_destroy = true
	}
}

resource "aws_autoscaling_group" "example" {
	launch_configuration = aws_launch_configuration.example.name
	vpc_zone_identifier	 = data.aws_subnet_ids.default.ids

	min_size = 2
	max_size = 4

	tag {
		key								= "Name"
		value							= "terraform-asg-example"
	}
	propogate_at_launch = true
}

##################################################

## Load Balancers

##################################################



## Oh snap! Now that we have multiple hosts, and multiple IP's from such hosts, how can we present our end user with a single IP to use? Well.... A Load Balancer ofcourse!
resource "aws_lb" "example" {
	name								= "terraform-asg-example"
	load_balancer_type	= "application"
	subnets							= data.aws_subnet_ids.default.ids
	# Tell the ALB to use the security group we created for it
	security_groups			= [aws_security_group.alb.id]
}

# The listener configures the ALB to listen on port 80 over HTTP 
resource "aws_lb_listener" "http" {
	load_balancer_arn		= aws_lb.example.arn
	port								= 80
	protocol						= "HTTP"

	# by default, return 404 page 
	default_action {
		type	= "fixed-response"

		fixed_response {
			content_type = "text/plain"
			message_body = "There's nothing here besides this nothing here statement"
			status_code  = 404
		}
	}
}

resource "aws_lb_target_group" "asg" {
	name			= "terraform-asg-example"
	port			= var.server_port
	protocol  = "HTTP"
	vpc_id		= data.aws_vpc.default.id



###############################################

## Data Sources

###############################################
data "aws_vpc" "default" {
	default = true
}

data "aws_subnet_ids" "default" {
	vpc_id = data.aws_vpc.default.id
}
