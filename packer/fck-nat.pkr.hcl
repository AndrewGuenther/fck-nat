packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "amazon-linux-2" {
  ami_name      = "fck-nat"
  instance_type = "t4g.micro"
  region        = "us-west-2"
  # TODO: Should build off the AL2 minimal AMI
  source_ami    = "ami-0bd804c6ae66f0dcd"
  ssh_username  = "ec2-user"
}

build {
  name = "fck-nat"
  sources = [
    "source.amazon-ebs.amazon-linux-2"
  ]

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

