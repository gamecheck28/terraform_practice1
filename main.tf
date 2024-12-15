provider "aws" {
    region = "us-east-1"
}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable public_key_location {}
variable my_system_public_key {}

resource "aws_vpc" "myapp-vpc" {
    cidr_block = "${var.vpc_cidr_block}"
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}

resource "aws_subnet" "myapp-subnet-1" {
    vpc_id = aws_vpc.myapp-vpc.id
    cidr_block = "${var.subnet_cidr_block}"
    availability_zone = var.avail_zone
    tags = {
        Name = "${var.env_prefix}-subnet-1"
    }
}

resource "aws_internet_gateway" "myapp-igw" {
    vpc_id = aws_vpc.myapp-vpc.id
    tags = {
        Name = "${var.env_prefix}-igw"
    }
}

resource "aws_route_table" "myapp-route-table" {
    vpc_id = aws_vpc.myapp-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }
    tags = {
        Name = "${var.env_prefix}-rtb"
    }
}

resource "aws_route_table_association" "a-rtb-subnet" {
    subnet_id = aws_subnet.myapp-subnet-1.id
    route_table_id = aws_route_table.myapp-route-table.id
}

resource "aws_security_group" "myapp-sg" {
    name = "myapp-sg"
    vpc_id = aws_vpc.myapp-vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }

    tags = {
        Name = "${var.env_prefix}-sg"
    }
}

#data "aws_ami" "latest-amazon-linux-image" {
#    most_recent = true
#    owners = ["amazon"]
#    filter {
#        name = "name"
#        values = ["Amazon Linux 2023 AMI"]
#    }
#}

resource "aws_key_pair" "ssh-key" {
    key_name = "server-client-key-pair"
    #public_key = file(var.public_key_location)
    public_key = var.my_system_public_key
}

resource "aws_instance" "myapp-server" {
    ami = "ami-0453ec754f44f9a4a"
    instance_type = var.instance_type
    subnet_id = aws_subnet.myapp-subnet-1.id
    vpc_security_group_ids = [aws_security_group.myapp-sg.id]
    availability_zone = var.avail_zone
    associate_public_ip_address = true
    #key_name = "server-client-key-pair"
    key_name = aws_key_pair.ssh-key.key_name

    #user_data = <<EOF
    #                #!/bin/bash
    #                sudo yum update -y && sudo yum install -y docker
    #                sudo systemctl start docker
    #                sudo usermod -aG docker ec2-user
    #                sudo docker run -p 8080:80 nginx
    #            EOF

    #instead of the commands mentioning here, you can run the script directly as shown eblow
    user_data = file("entry-script.sh")

    tags = {
        Name = "${var.env_prefix}-server"
    }
}

output "ec2_public_ip" {
    value = aws_instance.myapp-server.public_ip
}