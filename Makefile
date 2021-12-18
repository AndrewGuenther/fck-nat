package:
	mkdir -p build
	rm -f build/fck-nat-1.0.0-any.deb build/fck-nat-1.0.0-any.rpm
	fpm -t deb -p build/fck-nat-1.0.0-any.deb
	fpm -t rpm -p build/fck-nat-1.0.0-any.rpm