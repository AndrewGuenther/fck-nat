packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "ami_regions" {
  default = []
}

variable "sources" {
  default = ["source.amazon-ebs.fck-nat-arm64"]
}

variable "virtualization_type" {
  default = "hvm"
}

variable "architecture" {
  default = "arm64"
}

variable "instance_type" {
  default = {
    "arm64" =  "t4g.micro"
    "x86_64" = "t4i.micro"
  }
}

variable "region" {
  default = "us-west-2"
}

variable "base_image_name" {
  default = "*amzn2-ami-minimal-*"
}

variable "ssh_username" {
  default = "ec2-user"
}

locals {
  version = "1.0"
}

source "amazon-ebs" "fck-nat" {
  ami_name                = "fck-nat-${var.virtualization_type}-${local.version}${formatdate("YYYYMMDD", timestamp())}-${var.architecture}-ebs"
  ami_virtualization_type = var.virtualization_type
  ami_regions             = var.ami_regions
  instance_type           = "${lookup(var.instance_type, var.architecture, "error")}"
  region                  = var.region
  ssh_username            = var.ssh_username
  source_ami_filter {
    filters = {
      virtualization-type = var.virtualization_type
      architecture        = var.architecture
      name                = var.base_image_name
      root-device-type    = "ebs"
    }
    owners = [
      "amazon"
    ]
    most_recent = true
  }
}

build {
  name = "fck-nat"
  sources = ["source.amazon-ebs.fck-nat"]

  provisioner "file" {
    content = <<-EOT
    *nat
    -A POSTROUTING -o eth0 -j MASQUERADE
    COMMIT
    EOT
    destination = "/tmp/iptables"
  }

  provisioner "shell" {
    inline = [
      "sudo yum install iptables-services -y",
      "sudo systemctl enable iptables",
      "sudo systemctl start iptables",
      "sudo mv /tmp/iptables /etc/sysconfig/iptables",
      "echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf"
    ]
  }
}

