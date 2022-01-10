package: package-rpm package-deb

ensure-build:
	mkdir -p build

package-rpm: ensure-build
	rm -f build/fck-nat-1.0.0-any.rpm
	fpm -t rpm -p build/fck-nat-1.0.0-any.rpm

package-deb: ensure-build
	rm -f build/fck-nat-1.0.0-any.deb
	fpm -t deb -p build/fck-nat-1.0.0-any.deb

ami-arm64:
	packer build -var-file="packer/fck-nat-arm64.pkrvars.hcl" -var-file="packer/fck-nat-public-all-regions.pkrvars.hcl" packer/fck-nat.pkr.hcl
