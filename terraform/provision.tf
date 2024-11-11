provider "aws" {
	region = "us-east-2"
}

variable "scylla_instance_type" {
	default = "i4i.8xlarge"
}

variable "loader_instance_type" {
	default = "c7i.12xlarge"
}

resource "tls_private_key" "tablets_demo" {
	algorithm = "RSA"
	rsa_bits = 4096
}

# Hopefully you won't ever need to configure anything below here.
resource "aws_vpc" "tablets_demo" {
	cidr_block = "172.31.0.0/16"
	enable_dns_support = true
	enable_dns_hostnames = true

	tags = {
		Name = "tablets_demo"
	}
}

resource "aws_internet_gateway" "tablets_demo_igw" {
	vpc_id = aws_vpc.tablets_demo.id

	tags = {
		Name = "tablets_demo_igw"
	}
}

resource "aws_subnet" "tablets_demo_subnet" {
	vpc_id = aws_vpc.tablets_demo.id
	cidr_block = "172.31.0.0/16"
	map_public_ip_on_launch = true

	tags = {
		Name = "tablets_demo_subnet"
	}
}

resource "aws_route_table" "tablets_demo_public_rt" {
	vpc_id = aws_vpc.tablets_demo.id
	tags = {
		Name = "tablets_demo_public_rt"
	}
}

resource "aws_route" "public_route" {
	route_table_id = aws_route_table.tablets_demo_public_rt.id
	destination_cidr_block = "0.0.0.0/0"
	gateway_id = aws_internet_gateway.tablets_demo_igw.id
}

resource "aws_route_table_association" "tablets_demo_public_rt_assoc" {
	subnet_id = aws_subnet.tablets_demo_subnet.id
	route_table_id = aws_route_table.tablets_demo_public_rt.id
}

resource "aws_security_group" "tablets_demo_sg" {
	vpc_id = aws_vpc.tablets_demo.id
	name = "tablets_demo_sg"

	ingress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = [aws_vpc.tablets_demo.cidr_block] # Internal ingress
	}

	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = [aws_vpc.tablets_demo.cidr_block] # Internal egress
	}

	# Public Internet
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # External traffic
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9042
    to_port     = 9042
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 19042
    to_port     = 19042
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic to external networks
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

	tags = {
		Name = "tablets_demo_sg"
	}
}
resource "aws_key_pair" "kp" {
	key_name = "tablets-demo" # Ideally, replace it with something unique to you
	public_key = tls_private_key.tablets_demo.public_key_openssh

}

resource "aws_placement_group" "tablets_demo" {
  name     = "tablets_demo"
  strategy = "cluster"

  tags = {
    Name = "tablets_demo"
  }
}

resource "local_file" "pem_file" {
	filename = pathexpand("./tablets_demo.pem")
	file_permission = "600"
	sensitive_content = tls_private_key.tablets_demo.private_key_pem
}

resource "aws_instance" "scylladb_node" {
	count = 6
	ami = "ami-00eb69d236edcfaf8" # https://cloud-images.ubuntu.com/locator/ec2/
	instance_type = var.scylla_instance_type
	key_name = aws_key_pair.kp.key_name
	user_data = file("${path.module}/scylla-bootstrap.sh")

	private_ip = "172.31.0.10${count.index + 1}"

	subnet_id = aws_subnet.tablets_demo_subnet.id
	vpc_security_group_ids = [aws_security_group.tablets_demo_sg.id]
	placement_group = aws_placement_group.tablets_demo.name

	root_block_device {
		volume_size = 64 #GB
		volume_type = "gp3"
	}

	tags = {
		Name = "scylladb-node-${count.index + 1}"
	}

}

resource "aws_instance" "loader_node" {
	count = 3
	ami = "ami-00eb69d236edcfaf8"
	instance_type = var.loader_instance_type
	key_name = aws_key_pair.kp.key_name
	user_data = file("${path.module}/loader_monitoring_setup.sh")

	private_ip = "172.31.0.20${count.index + 1}"
        subnet_id = aws_subnet.tablets_demo_subnet.id
        vpc_security_group_ids = [aws_security_group.tablets_demo_sg.id]
        placement_group = aws_placement_group.tablets_demo.name
         
        root_block_device {
                volume_size = 64 #GB
                volume_type = "gp3"
        }       
        
        tags = {
                Name = "loader-node-${count.index + 1}"
        }

        connection {
                host = "${self.public_ip}"
                type = "ssh"
                user = "ubuntu"
                #private_key = file("${path.module}/tablets_demo.pem")
		private_key = tls_private_key.tablets_demo.private_key_pem
        }   


	provisioner "file" {
		source = "${path.module}/tablets_demo.pem"
		destination = "/home/ubuntu/.ssh/id_rsa"
	}

	provisioner "remote-exec" {
		inline = [
		  "chmod 700 /home/ubuntu/.ssh",
                  "chown -R ubuntu:ubuntu /home/ubuntu",
                  "chmod 600 /home/ubuntu/.ssh/id_rsa"
                ]
        }
}
