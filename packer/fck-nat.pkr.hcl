packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}


variable "version" {
  type = string
}

variable "ami_regions" {
  type = list(string)
  default = []
}

variable "ami_users" {
  type = list(string)
  default = []
}

variable "ami_groups" {
  type = list(string)
  default = []
}

variable "virtualization_type" {
  default = "hvm"
}

variable "architecture" {
  default = "arm64"
}

variable "flavor" {
  default = "al2023"
}

variable "instance_type" {
  default = {
    "arm64"  = "t4g.micro"
    "x86_64" = "t3.micro"
  }
}

variable "region" {
  default = "us-west-2"
}

variable "base_image_name" {
  default = "*al2023-ami-minimal-*-kernel-*"
}

variable "base_image_owner" {
  default = "amazon"
}

variable "ssh_username" {
  default = "ec2-user"
}

variable "jool_version" {
  default = "4.1.7"
}

source "amazon-ebs" "fck-nat" {
  ami_name                = "fck-nat-${var.flavor}-${var.virtualization_type}-${var.version}-${formatdate("YYYYMMDD", timestamp())}-${var.architecture}-ebs"
  ami_virtualization_type = var.virtualization_type
  ami_regions             = var.ami_regions
  ami_users               = var.ami_users
  ami_groups              = var.ami_groups
  instance_type           = "${lookup(var.instance_type, var.architecture, "error")}"
  region                  = var.region
  ssh_username            = var.ssh_username
  temporary_key_pair_type = "ed25519"
  source_ami_filter {
    filters = {
      virtualization-type = var.virtualization_type
      architecture        = var.architecture
      name                = var.base_image_name
      root-device-type    = "ebs"
    }
    owners = [
      var.base_image_owner
    ]
    most_recent = true
  }
}

build {
  name = "fck-nat"
  sources = ["source.amazon-ebs.fck-nat"]

  # Install updates
  provisioner "shell" {
    inline = [
      "sudo yum update -y",
      "sudo reboot"
    ]
    expect_disconnect = true
  }

  # Install jool for NAT64
  provisioner "shell" {
    start_retry_timeout = "2m"
    inline = [
      "sudo yum install gcc make elfutils-libelf-devel kernel-devel libnl3-devel iptables-devel dkms -y",
      "curl -L https://www.jool.mx/download/jool-${var.jool_version}.tar.gz -o- | tar xzf - --directory /tmp",
      "sudo dkms install /tmp/jool-${var.jool_version}",
      "cd /tmp/jool-${var.jool_version}",
      "./configure && make && sudo make install",
      "sudo rm -rf /tmp/jool-${var.jool_version}"
      "sudo yum uninstall gcc make elfutils-libelf-devel kernel-devel libnl3-devel iptables-devel -y"
    ]
  }
  
  provisioner "file" {
    source = "build/fck-nat-${var.version}-any.rpm"
    destination = "/tmp/fck-nat-${var.version}-any.rpm"
  }

  # Install fck-nat
  provisioner "shell" {
    inline = [
      "sudo yum install amazon-cloudwatch-agent iptables -y",
      "sudo yum --nogpgcheck -y localinstall /tmp/fck-nat-${var.version}-any.rpm",
      "sudo rm -f /tmp/fck-nat-${var.version}-any.rpm",
    ]
  }
}

