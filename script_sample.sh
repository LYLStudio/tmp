#download openssl and pcre2 source code and build nginx with them, then copy the built nginx to the shared volume
# https://nginx.org/download/nginx-1.31.1.tar.gz
# https://github.com/openssl/openssl/releases/download/openssl-3.5.6/openssl-3.5.6.tar.gz
# https://github.com/pcre2/pcre2/releases/download/pcre2-10.42/pcre2-10.42.tar.gz
# https://zlib.net/zlib-1.3.2.tar.gz

# almalinux:9
docker build -t nginx-build:latest .
docker run --rm -it -v "$(pwd)/volume":/vol -p 80:80 nginx-build:latest

# almalinux:8
docker build -t nginx-build:8 .       
docker run --rm -it -v "$(pwd)/volume":/vol -p 80:80 nginx-build:8

# redhat/ubi9 or ubi8 for testing the built nginx
docker run --rm -it -v "$(pwd)/volume":/vol -p 80:80 redhat/ubi9


./configure --prefix= --sbin-path=sbin/nginx --modules-path=modules --conf-path=conf/nginx.conf --error-log-path=logs/error.log --http-log-path=logs/access.log --pid-path=logs/nginx.pid --lock-path=logs/nginx.lock --http-client-body-temp-path=temp/client_body --http-proxy-temp-path=temp/proxy --http-fastcgi-temp-path=temp/fastcgi --http-uwsgi-temp-path=temp/uwsgi --http-scgi-temp-path=temp/scgi --with-pcre=/vol/pcre2 --with-openssl=/vol/openssl --with-zlib=/vol/zlib --with-http_ssl_module --with-http_v2_module --with-http_v3_module --with-http_realip_module --with-http_stub_status_module --with-http_gzip_static_module --with-http_sub_module --with-stream --with-stream_ssl_module --with-threads --with-cc-opt='-O2'

make 
make install DESTDIR=/vol/nginx-$(date +%Y%m%d) 
cd /vol/nginx-$(date +%Y%m%d) && mkdir -p temp && ./sbin/nginx -t

#./sbin/nginx -p $PWD/ -c conf/nginx.conf