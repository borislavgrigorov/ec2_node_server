##################################################################################
# VARIABLES
##################################################################################

variable "aws_private_key_file_path" {}
variable "ec2_user" {}

variable "key_name" {
  default = "aws_key"
}

variable "network_address_space" {
  default = "10.1.0.0/16"
}

variable "project_tag" {
  default = "terraform_ec2_test_project"
}

variable "environment_tag" {
  default = "dev"
}

variable "instance_count" {
  default = 1
}

variable "subnet_count" {
  default = 1
}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {}

##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available" {}

##################################################################################
# RESOURCES
##################################################################################

# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block           = "${var.network_address_space}"
  enable_dns_hostnames = "true"

  tags {
    Name        = "${var.project_tag}-${var.environment_tag}-vpc"
    Project     = "${var.project_tag}"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name        = "${var.project_tag}-${var.environment_tag}-igw"
    Project     = "${var.project_tag}"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_subnet" "subnet" {
  count = "${var.subnet_count}"

  # Creates the necessary subnets
  cidr_block              = "${cidrsubnet(var.network_address_space, 8, count.index + 1)}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"

  tags {
    Name        = "${var.project_tag}-${var.environment_tag}-subnet-${count.index + 1}"
    Project     = "${var.project_tag}"
    Environment = "${var.environment_tag}"
  }
}

# ROUTING #
resource "aws_route_table" "rtb" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags {
    Name        = "${var.project_tag}-${var.environment_tag}-rtb"
    Project     = "${var.project_tag}"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_route_table_association" "rta-subnet" {
  count          = "${var.subnet_count}"
  subnet_id      = "${element(aws_subnet.subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.rtb.id}"
}

# SECURITY GROUPS #
# Elastic load balancer security group
resource "aws_security_group" "elb-sg" {
  name   = "elb-sg"
  vpc_id = "${aws_vpc.vpc.id}"

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "${var.project_tag}-${var.environment_tag}-elb-sg"
    Project     = "${var.project_tag}"
    Environment = "${var.environment_tag}"
  }
}

# Instance security group
resource "aws_security_group" "instance-sg" {
  name   = "instance-sg"
  vpc_id = "${aws_vpc.vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    # this restricts http access to addresses in our VPC which belongs to our network address space
    cidr_blocks = ["${var.network_address_space}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "${var.project_tag}-${var.environment_tag}-instance-sg"
    Project     = "${var.project_tag}"
    Environment = "${var.environment_tag}"
  }
}

# LOAD BALANCER #
resource "aws_elb" "web" {
  name = "web-elb"

  subnets         = ["${aws_subnet.subnet.*.id}"]
  security_groups = ["${aws_security_group.elb-sg.id}"]
  instances       = ["${aws_instance.instance.*.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  tags {
    Name        = "${var.project_tag}-${var.environment_tag}-elb"
    Project     = "${var.project_tag}"
    Environment = "${var.environment_tag}"
  }
}

# INSTANCES #
resource "aws_instance" "instance" {
  count                  = "${var.instance_count}"
  ami                    = "ami-061e7ebbc234015fe"
  instance_type          = "t2.nano"
  subnet_id              = "${element(aws_subnet.subnet.*.id, count.index % var.subnet_count)}"
  vpc_security_group_ids = ["${aws_security_group.instance-sg.id}"]
  key_name               = "${var.key_name}"

  connection {
    user        = "${var.ec2_user}"
    private_key = "${file(var.aws_private_key_file_path)}"
  }

  tags {
    Name        = "${var.project_tag}-${var.environment_tag}-instance-${count.index + 1}"
    Project     = "${var.project_tag}"
    Environment = "${var.environment_tag}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras install nginx1.12 -y",
      "sudo service nginx start",
      "echo '<html><head><title>Server</title></head><body><p style=\"text-align: center;\"><span><span style=\"font-size:28px;\">Instance: ${count.index}</span></span></p></body></html>' | sudo tee /usr/share/nginx/html/index.html",
    ]
  }
}

##################################################################################
# OUTPUT
##################################################################################

output "aws_elb_public_dns" {
  value = "${aws_elb.web.dns_name}"
}
