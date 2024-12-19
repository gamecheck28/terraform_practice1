terraform {
    required_version = ">=0.12"
    backend "s3" {
        bucket = "myapp-bucket-practice"
        key = "myapp/state.tfstate"
        region = "us-east-1"
    }
}

resource "aws_vpc" "myapp-vpc" {
    cidr_block = "${var.vpc_cidr_block}"
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}

resource "aws_route_table_association" "a-rtb-subnet" {
    #subnet_id = aws_subnet.myapp-subnet-1.vpc_id
    subnet_id = module.myapp-subnet.subnet.id
    #route_table_id = aws_route_table.myapp-route-table.id
    route_table_id = module.myapp-subnet.routetable.id
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

resource "aws_key_pair" "ssh-key" {
    key_name = "server-client-key-pair"
    public_key = var.my_system_public_key
}

resource "aws_instance" "myapp-server" {
    ami = "ami-0453ec754f44f9a4a"
    instance_type = var.instance_type
    #subnet_id = aws_subnet.myapp-subnet-1.id
    subnet_id = module.myapp-subnet.subnet.id
    vpc_security_group_ids = [aws_security_group.myapp-sg.id]
    availability_zone = var.avail_zone
    associate_public_ip_address = true
    key_name = aws_key_pair.ssh-key.key_name

    user_data = file("entry-script.sh")

    provisioner "local-exec" {
        command = "echo ${self.public_dns}; echo ${self.public_ip}"
    }

    tags = {
        Name = "${var.env_prefix}-server"
    }
}

module "myapp-subnet" {
    source = "./modules/subnet"
    vpc_id = aws_vpc.myapp-vpc.id
    subnet_cidr_block = var.subnet_cidr_block
    avail_zone = var.avail_zone
    env_prefix  = var.env_prefix
}