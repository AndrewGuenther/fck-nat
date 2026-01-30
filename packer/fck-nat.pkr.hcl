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

variable "snapshot_groups" {
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

variable "ami_prefix" {
  default = ""
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

variable "vpc_id" {
  type    = string
}

variable "subnet_id" {
  type    = string
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
  default = "4.1.13"
}

variable "boost_version" {
  default = "1.83.0"
}

variable "gwlb_version" {
  default = "main"
}

source "amazon-ebs" "fck-nat" {
  ami_name                  = "fck-nat-${var.ami_prefix}${var.flavor}-${var.virtualization_type}-${var.version}-${formatdate("YYYYMMDD", timestamp())}-${var.architecture}-ebs"
  ami_virtualization_type   = var.virtualization_type
  ami_regions               = var.ami_regions
  ami_users                 = var.ami_users
  ami_groups                = var.ami_groups
  snapshot_groups           = var.snapshot_groups
  instance_type             = "${lookup(var.instance_type, var.architecture, "error")}"
  region                    = var.region
  ssh_username              = var.ssh_username
  ssh_clear_authorized_keys = true
  temporary_key_pair_type   = "ed25519"
  vpc_id                  = var.vpc_id != "" ? var.vpc_id : null
  subnet_id               = var.subnet_id != "" ? var.subnet_id : null
  launch_block_device_mappings {
    device_name = "/dev/xvda"
    volume_size = 4
    delete_on_termination = true
  }
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
      "sudo yum install gcc make elfutils-libelf-devel kernel-devel kernel-headers libnl3-devel iptables-devel dkms -y",
      "curl -L https://github.com/NICMx/Jool/releases/download/v${var.jool_version}/jool-${var.jool_version}.tar.gz -o- | tar xzf - --directory /tmp",
      "sudo dkms install /tmp/jool-${var.jool_version}",
      "cd /tmp/jool-${var.jool_version}",
      "./configure && make && sudo make install",
      "sudo rm -rf /tmp/jool-${var.jool_version}",
      "sudo yum remove gcc make elfutils-libelf-devel kernel-devel libnl3-devel iptables-devel -y"
    ]
  }
  
  provisioner "file" {
    source = "build/fck-nat-${var.version}-any.rpm"
    destination = "/tmp/fck-nat-${var.version}-any.rpm"
  }

  # Install fck-nat
  provisioner "shell" {
    inline = [
      "sudo yum install amazon-cloudwatch-agent amazon-ssm-agent iptables -y",
      "sudo yum --nogpgcheck -y localinstall /tmp/fck-nat-${var.version}-any.rpm",
      "sudo rm -f /tmp/fck-nat-${var.version}-any.rpm",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo yum install -y conntrack-tools"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo dnf install -y kpatch-dnf",
      "sudo dnf kernel-livepatch -y auto",
      "sudo dnf install -y kpatch-runtime",
      "sudo dnf update kpatch-runtime",
      "sudo systemctl enable kpatch.service && sudo systemctl start kpatch.service",
    ]
  }

  # Install gwlb tunnel handler
  provisioner "shell" {
    inline = [
      "sudo dnf install -y cmake3 gcc g++ git",
      "cd /home/${var.ssh_username}",
      "curl -L -o boost.tar.gz https://archives.boost.io/release/${var.boost_version}/source/boost_${replace(var.boost_version, ".", "_")}.tar.gz",
      "tar -xzf boost.tar.gz",
      "mv boost_${replace(var.boost_version, ".", "_")} boost",
      "cd /opt",
      "sudo git clone --branch ${var.gwlb_version} https://github.com/aws-samples/aws-gateway-load-balancer-tunnel-handler.git",
      "cd aws-gateway-load-balancer-tunnel-handler",
      "sudo sed -i 's%//#define NO_RETURN_TRAFFIC%#define NO_RETURN_TRAFFIC%' utils.h",  # Disable return GWLB interface to improve performance
      "sudo cmake3 .",
      "sudo make"
    ]
  }

  provisioner "file" {
    source = "gwlb/"
    destination = "/tmp"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/gwlbtun.service /usr/lib/systemd/system/gwlbtun.service",
      "sudo mv /tmp/gwlb-up.sh /opt/aws-gateway-load-balancer-tunnel-handler/gwlb-up.sh",
      "sudo mv /tmp/gwlbtun.conf /etc/gwlbtun.conf",
      "sudo chmod +x /opt/aws-gateway-load-balancer-tunnel-handler/gwlb-up.sh",
      "sudo systemctl daemon-reload",
      "sudo systemctl disable gwlbtun.service",
      "sudo dnf remove -y cmake3 gcc g++ git"
    ]
  }
}
