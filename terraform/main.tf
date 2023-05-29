# the Terraform configuration defines an AWS provider and an aws_instance resource. The resource specifies the Amazon Machine Image (AMI), instance type, and key pair to be used. It also includes a tag for identifying the instance.

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "devtest1" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  key_name      = "devtest1"

  tags = {
    Name = "devtest1"
  }

  # After provisions the EC2 instance we are using the Terraform provisioner to run remote-exec commands. 
  # These commands update the apt cache, install Python 3 pip, and install Ansible on the instance
  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install -y python3-pip",
      "pip3 install ansible",
    ]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/devtest1.pem")
    host        = self.public_ip
  }

  # The configuration also includes a null_resource with a local-exec provisioner. 
  # This provisioner triggers the execution of the Ansible playbook configure.yml on the provisioned EC2 instance. 
  # The Ansible playbook will be executed locally by running the ansible-playbook command.
  resource "null_resource" "ansible" {
    triggers = {
      instance_id = aws_instance.devtest1.id
    }

    provisioner "local-exec" {
      command = "ansible-playbook -i '${aws_instance.devtest1.public_ip},' configure.yml"
    }
  }
}

resource "aws_db_instance" "devtest1_db" {
  engine             = "mysql"
  instance_class     = "db.t3.micro"
  allocated_storage  = 20
  username           = "admin"
  password           = "p1020304050w"
}

resource "aws_s3_bucket" "devtest1_bucket" {
  bucket = "devtest1_bucket"
  acl    = "private"

  tags = {
    Name = "devtest1 Bucket"
  }
}

resource "aws_vpc" "devtest1_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "devtest1 VPC"
  }
}

resource "aws_subnet" "devtest1_subnet" {
  vpc_id                  = aws_vpc.devtest1_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
}

resource "aws_security_group" "devtest1_sg" {
  name        = "devtest1_sg"
  description = "devtest1 security group"

  vpc_id = aws_vpc.devtest1_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_lb" "devtest1_bucket_lb" {
  name               = "devtest1_bucket_lb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.devtest1_subnet.id]

  security_groups = [aws_security_group.devtest1_sg.id]

  tags = {
    Name = "devtest1 load balancer"
  }
}

resource "aws_lb_target_group" "devtest1_target_group" {
  name     = "devtest1-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.devtest1_vpc.id
}

resource "aws_lb_listener" "devtest1_listener" {
  load_balancer_arn = aws_lb.example_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.devtest1_target_group.arn
  }
}

resource "aws_cloudwatch_metric_alarm" "devtest1_cpu_alarm" {
  alarm_name          = "devtest1_cpu_alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "This metric monitors CPU utilization"
  alarm_actions       = [aws_sns_topic.cpu_overload_alert.arn]
}

resource "aws_sns_topic" "cpu_overload_alert" {
  name = "cpu_overload_alert"
}
