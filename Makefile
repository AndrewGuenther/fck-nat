package: package-rpm package-deb

ensure-build:
	mkdir -p build

package-rpm: ensure-build
	rm -f build/fck-nat-1.1.0-any.rpm
	fpm -t rpm -p build/fck-nat-1.1.0-any.rpm

al2-ami-arm64: package-rpm
	packer build -var-file="packer/fck-nat-arm64.pkrvars.hcl" -var-file="packer/fck-nat-al2.pkrvars.hcl" $(regions_file) packer/fck-nat.pkr.hcl

al2-ami-x86: package-rpm
	packer build -var-file="packer/fck-nat-x86_64.pkrvars.hcl" -var-file="packer/fck-nat-al2.pkrvars.hcl" $(regions_file) packer/fck-nat.pkr.hcl

al2-ami: al2-ami-arm64 al2-ami-x86

all-amis: al2-ami

publish: regions_file = -var-file="packer/fck-nat-public-all-regions.pkrvars.hcl"
publish: all-amis

test:
	rm -f cdk/cdk.context.json
	cd cdk && cdk deploy FckNatTestStack
	aws ssm send-command --document-name "AWS-RunShellScript" --targets "Key=tag:connectivity-test-target,Values=true" --parameters '{"commands":["curl https://www.google.com"]}'
