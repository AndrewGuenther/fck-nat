VERSION := 1.3.0

package: package-rpm

ensure-build:
	mkdir -p build

package-rpm: ensure-build
	rm -f build/fck-nat-$(VERSION)-any.rpm
	fpm -t rpm --version $(VERSION) -p build/fck-nat-$(VERSION)-any.rpm

al2023-ami-arm64: package-rpm
	packer build -var 'version=$(VERSION)' -var-file="packer/fck-nat-arm64.pkrvars.hcl" -var-file="packer/fck-nat-al2023.pkrvars.hcl" $(regions_file) packer/fck-nat.pkr.hcl

al2023-ami-x86: package-rpm
	packer build -var 'version=$(VERSION)' -var-file="packer/fck-nat-x86_64.pkrvars.hcl" -var-file="packer/fck-nat-al2023.pkrvars.hcl" $(regions_file) packer/fck-nat.pkr.hcl

al2023-ami: al2023-ami-arm64 al2023-ami-x86

all-amis: al2023-ami

publish: regions_file = -var-file="packer/fck-nat-public-all-regions.pkrvars.hcl"
publish: all-amis
