  
terraform {
	backend "s3" {
		bucket = "terraform.dyno.com"
		key    = "terraform.tfstate"
		region = "us-east-1"
		profile = "dyno"
		workspace_key_prefix = "s3sftp"
	}
}

# PROVIDERS
provider "aws" {
	region = "us-east-1"
	profile = "dyno.${terraform.workspace}"
}

resource "aws_s3_bucket" "sftp" {
  bucket = "dyno.${terraform.workspace}.sftp.com"
  versioning {
    enabled = true
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "sg_22" {
  name = "sg_22"
  vpc_id = data.aws_vpc.default.id
  ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # tags {
  #   "Environment" = var.environment_tag
  # }
}

resource "aws_key_pair" "ec2key" {
  key_name = "S3FS"
  public_key = file("S3FS.pub")
}

# resource "aws_key_pair" "deployer" {
#   key_name   = "S3FS"
#   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDIwZTJnQnwXALyA5XrjSWsdgVnCKVK/Bb8Xzu7WYaj+g6lZtmGPpC/wO/KQQD/zZYjchIHBY1FBw1Cue+HJWDx56OvBm2gpve2dnghBPFAWvboTwCgD6ntFVxIITebCDFCwkBl0TsLlbtNS0b2niJ15nJQAiS/sFRSpO/77SHTw+LZH/HUwPA+NaD8MPyWU4klZ00+floq3/pWZlgd9lJJbNcI0BJAoMJZS0h7P+BG7QQ+zAZvF+VGzkLAyOvnMxcZFAXrOJ8cmVoTNlxx7h3SryzH/7+U5j8D589UXfUnNzdagPIcpRxlaRpYewTQftLXGAGsaQHmBcrxhRNkaEZKSEmSRtjqzob6+8RAkyPO8kot+cQBUjUGXUHRh+fbOi/Uw4u/+hVoWX+k/QqVb0p8e2z51X5n9V6+SX5us8H786kD6MWbHuzAqknYhqgFZiM2U1cFbuSNhxTxpOMjM+E0Q4Ne4ifQsxVQ+N5ndsNK5A82EgmPIKyNEZFG6J5Aej8= joseja17@Joses-MacBook-Pro.local"
# }

resource "aws_instance" "web" {
  tags =  {
    name = "${aws_key_pair.ec2key.key_name}"
  }
  # ...
  ami = "ami-0323c3dd2da7fb37d"
  instance_type = "t3.micro"
  # subnet_id = "${aws_subnet.subnet_public.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_22.id}"]
  key_name = "${aws_key_pair.ec2key.key_name}"

  connection {
    type     = "ssh"
    user     = "ec2-user"
    password = ""
    host = self.public_ip
    private_key = file(aws_key_pair.ec2key.key_name)
  }

  provisioner "file" {
    source      = "setup.sh"
    destination = "/tmp/setup.sh"
  }

    provisioner "file" {
    source      = "sshd_config.txt"
    destination = "/tmp/sshd_config.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup.sh",
      "/tmp/setup.sh ${terraform.workspace} us-east-1",
    ]
  }

}

output "public_ip" {
  value = aws_instance.web.public_ip
}