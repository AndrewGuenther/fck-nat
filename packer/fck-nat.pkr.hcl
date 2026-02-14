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
  default = "*al2023-ami-minimal-*-kernel-6.12-*"
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

locals {
  common_source = {
    ami_virtualization_type   = var.virtualization_type
    ami_regions               = var.ami_regions
    ami_users                 = var.ami_users
    ami_groups                = var.ami_groups
    snapshot_groups           = var.snapshot_groups
    instance_type             = lookup(var.instance_type, var.architecture, "error")
    region                    = var.region
    ssh_username              = var.ssh_username
    ssh_clear_authorized_keys = true
    temporary_key_pair_type   = "ed25519"
  }

  launch_block_device_mapping = {
    device_name           = "/dev/xvda"
    volume_size           = 4
    delete_on_termination = true
  }

  source_ami_filter = {
    filters = {
      virtualization-type = var.virtualization_type
      architecture        = var.architecture
      name                = var.base_image_name
      root-device-type    = "ebs"
    }
    owners      = [var.base_image_owner]
    most_recent = true
  }
}

source "amazon-ebs" "fck-nat" {
  ami_name                  = "fck-nat-${var.flavor}-${var.virtualization_type}-${var.version}-${formatdate("YYYYMMDD", timestamp())}-${var.architecture}-ebs"
  ami_virtualization_type   = local.common_source.ami_virtualization_type
  ami_regions               = local.common_source.ami_regions
  ami_users                 = local.common_source.ami_users
  ami_groups                = local.common_source.ami_groups
  snapshot_groups           = local.common_source.snapshot_groups
  instance_type             = local.common_source.instance_type
  region                    = local.common_source.region
  ssh_username              = local.common_source.ssh_username
  ssh_clear_authorized_keys = local.common_source.ssh_clear_authorized_keys
  temporary_key_pair_type   = local.common_source.temporary_key_pair_type
  dynamic "launch_block_device_mappings" {
    for_each = [local.launch_block_device_mapping]
    content {
      device_name           = launch_block_device_mappings.value.device_name
      volume_size           = launch_block_device_mappings.value.volume_size
      delete_on_termination = launch_block_device_mappings.value.delete_on_termination
    }
  }
  dynamic "source_ami_filter" {
    for_each = [local.source_ami_filter]
    content {
      filters     = source_ami_filter.value.filters
      owners      = source_ami_filter.value.owners
      most_recent = source_ami_filter.value.most_recent
    }
  }
}

source "amazon-ebs" "fck-nat-nat64" {
  ami_name                  = "fck-nat-nat64-${var.flavor}-${var.virtualization_type}-${var.version}-${formatdate("YYYYMMDD", timestamp())}-${var.architecture}-ebs"
  ami_virtualization_type   = local.common_source.ami_virtualization_type
  ami_regions               = local.common_source.ami_regions
  ami_users                 = local.common_source.ami_users
  ami_groups                = local.common_source.ami_groups
  snapshot_groups           = local.common_source.snapshot_groups
  instance_type             = local.common_source.instance_type
  region                    = local.common_source.region
  ssh_username              = local.common_source.ssh_username
  ssh_clear_authorized_keys = local.common_source.ssh_clear_authorized_keys
  temporary_key_pair_type   = local.common_source.temporary_key_pair_type
  dynamic "launch_block_device_mappings" {
    for_each = [local.launch_block_device_mapping]
    content {
      device_name           = launch_block_device_mappings.value.device_name
      volume_size           = launch_block_device_mappings.value.volume_size
      delete_on_termination = launch_block_device_mappings.value.delete_on_termination
    }
  }
  dynamic "source_ami_filter" {
    for_each = [local.source_ami_filter]
    content {
      filters     = source_ami_filter.value.filters
      owners      = source_ami_filter.value.owners
      most_recent = source_ami_filter.value.most_recent
    }
  }
}

build {
  name = "fck-nat"
  sources = ["source.amazon-ebs.fck-nat", "source.amazon-ebs.fck-nat-nat64"]

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
    only = ["amazon-ebs.fck-nat-nat64"]
    inline = [
      "sudo yum install gcc make elfutils-libelf-devel kernel6.12-devel-`uname -r` kernel6.12-headers-`uname -r` libnl3-devel iptables-devel dkms -y",
      "curl -L https://github.com/NICMx/Jool/releases/download/v${var.jool_version}/jool-${var.jool_version}.tar.gz -o- | tar xzf - --directory /tmp",
      "sudo dkms install /tmp/jool-${var.jool_version}",
      "cd /tmp/jool-${var.jool_version}",
      "./configure && make && sudo make install",
      "sudo rm -rf /tmp/jool-${var.jool_version}",
      "sudo yum remove gcc make elfutils-libelf-devel kernel6.12-devel libnl3-devel iptables-devel -y"
    ]
  }
  
  provisioner "file" {
    source = "build/fck-nat-${var.version}-any.rpm"
    destination = "/tmp/fck-nat-${var.version}-any.rpm"
  }

  # Install fck-nat
  provisioner "shell" {
    inline = [
      "sudo yum install amazon-cloudwatch-agent amazon-ssm-agent nftables -y",
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
}
