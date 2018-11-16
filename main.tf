provider "aws" {
  access_key = ""
  secret_key = ""
  region     = "us-east-1"
}

resource "aws_vpc" "tf_vpc" {
  cidr_block = "172.0.0.0/16"
  enable_dns_hostnames = true
 
  tags {
    Name = "tf-vpc"
  }
}


resource "aws_subnet" "tf_public" {
  vpc_id = "${aws_vpc.tf_vpc.id}"
  cidr_block = "172.0.1.0/24"
  availability_zone = "us-east-1a"

  tags {
    Name = "Web_Public_Subnet"
  }
}


resource "aws_subnet" "tf_private" {
  vpc_id = "${aws_vpc.tf_vpc.id}"
  cidr_block = "172.0.2.0/24"
availability_zone = "us-east-1b"

  tags {
    Name = "Db_Private_Subnet"
  }
}


resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.tf_vpc.id}"

  tags {
    Name = "tf_VPC_IGW"
  }
}



# Define the route table
resource "aws_route_table" "web-public-rt" {
  vpc_id = "${aws_vpc.tf_vpc.id}"


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "Public Subnet RT"
  }
}

# Assign the route table to the public Subnet
resource "aws_route_table_association" "web-public-rt" {
  subnet_id = "${aws_subnet.tf_public.id}"
  route_table_id = "${aws_route_table.web-public-rt.id}"
}


# Define the security group for public subnet
resource "aws_security_group" "sglb" {
  name = "vpc_test_lb"
  description = "Allow incoming HTTP connections to LB "

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id="${aws_vpc.tf_vpc.id}"

  tags {
    Name = "lb_SG"
  }
}

# Define the security group for web server

# Define the security group for public subnet

resource "aws_security_group" "sgweb" {
  name = "vpc_test_web"
  description = "Allow incoming HTTP connections & SSH access "

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups =["${aws_security_group.sglb.id}"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    security_groups =["${aws_security_group.sglb.id}"]
  }



  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks =  ["0.0.0.0/0"]
  }

 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id="${aws_vpc.tf_vpc.id}"

  tags {
    Name = "lb_SG"
  }
}


# Define the security group for private subnet
resource "aws_security_group" "sgdb"{
  name = "sg_test_web"
  description = "Allow traffic from public subnet"

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups =["${aws_security_group.sgweb.id}"]
  }

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["172.0.1.0/24"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["172.0.1.0/24"]
  }

  vpc_id = "${aws_vpc.tf_vpc.id}"

  tags {
    Name = "DB SG"
  }
}

# Define webserver inside the public subnet
resource "aws_instance" "wb" {
   ami  = "ami-06b5810be11add0e2"
   instance_type = "t1.micro"
   key_name = "viswa1145"
   subnet_id = "${aws_subnet.tf_public.id}"
   vpc_security_group_ids = ["${aws_security_group.sgweb.id}"]
   associate_public_ip_address = true
   user_data = <<-EOF
		#!/bin/bash
		sudo apt-get update
		sudo apt-get install apache2 -y
		cd /home/ubuntu/
		sudo mkdir viswa	      
		EOF

  tags {
    Name = "webserver_14.04"
  }
}




/*
resource "aws_ebs_volume" "data" {
  availability_zone = "us-east-1a"
  size              = 10
}


resource "aws_ebs_volume" "log" {
  availability_zone = "us-east-1a"
  size              = 10
}

resource "aws_volume_attachment" "ebs_att_data" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.data.id}"
  instance_id = "${aws_instance.wb.id}"
}

resource "aws_volume_attachment" "ebs_att_log" {
  device_name = "/dev/sdi"
  volume_id   = "${aws_ebs_volume.log.id}"
  instance_id = "${aws_instance.wb.id}"
}
*/


resource "aws_alb" "tf_alb" {
	name		=	"tf-alb"
	internal	=	false
	load_balancer_type = "application"
	security_groups	=	["${aws_security_group.sglb.id}"]
	subnets		=	["${aws_subnet.tf_public.id}", "${aws_subnet.tf_private.id}"]
	enable_deletion_protection = false
}



resource "aws_alb_target_group" "tf_alb_https" {
	name	= "tfalbhttps"
	vpc_id	= "${aws_vpc.tf_vpc.id}"
	port	= "80"
	protocol	= "HTTP"
	health_check {
                path = "/index.html"
                port = "80"
                protocol = "HTTP"
                healthy_threshold = 2
                unhealthy_threshold = 2
                interval = 5
                timeout = 4
                matcher = "200-308"
        }
}

resource "aws_alb_target_group_attachment" "alb_backend-01_http" {
  target_group_arn = "${aws_alb_target_group.tf_alb_https.arn}"
  target_id        = "${aws_instance.wb.id}"
  port             = 80

}




resource "aws_alb_listener" "alb_front_https" {
	load_balancer_arn	=	"${aws_alb.tf_alb.arn}"
	port			=	"80"
	protocol		=	"HTTP"
	default_action {
		target_group_arn	=	"${aws_alb_target_group.tf_alb_https.arn}"
		type			=	"forward"
	}
}



/*
resource "aws_s3_bucket" "s3_bucket_09" {
 bucket = "com-tf-testbucket-viswa-li"
 region = "us-east-1"
  
 tags {
    Name        = "My bucket"
    Environment = "Dev"
  }
}*/





