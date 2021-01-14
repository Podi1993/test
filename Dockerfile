FROM debian:stable

# https://github.com/nginx/nginx
ENV NGINX_VER 1.18.0
# https://github.com/chobits/ngx_http_proxy_connect_module
ENV PROXY_CONNECT_V 0.0.1
ENV PROXY_CONNECT_M master

RUN set -x \
        # 添加用户/用户组
        && addgroup --system --gid 39000 nginx \
        && adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false --uid 39000 nginx \
        && rm -rf /etc/localtime  \
        # 更换国内时区
        && ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
        # 更换国内apt源
        && mv /etc/apt/sources.list /etc/apt/sources.list.bak \
        && echo "deb http://mirrors.aliyun.com/debian stable main" > /etc/apt/sources.list \
        && echo "deb http://mirrors.aliyun.com/debian stable-updates main" >> /etc/apt/sources.list \
        # 安装ca证书工具
        && apt-get update \
        && apt-get install -y --no-install-recommends --no-install-suggests ca-certificates \
        # 安装源码编译依赖
#        && apt clean all \
#        && apt update \
#        && apt install -y --no-install-recommends --no-install-suggests \
            patch \
            libpcre3-dev \
            libssl-dev \
            zlib1g-dev \
            curl \
            gcc \
            gzip \
            make \
            tar \
            unzip \ 
        # 下载nginx源码
        && cd /tmp \
        && curl -Lo nginx.tar.gz https://nginx.org/download/nginx-${NGINX_VER}.tar.gz \
        && tar xzvf /tmp/nginx.tar.gz \
        # 下载proxy_connect模块补丁
#       && curl -Lo proxy_connect.tar.gz https://github.com/chobits/ngx_http_proxy_connect_module/archive/v${PROXY_CONNECT_V}.tar.gz \
        && curl -Lo proxy_connect.zip https://github.com/chobits/ngx_http_proxy_connect_module/archive/${PROXY_CONNECT_M}.zip \
#       && tar xzvf proxy_connect.tar.gz \
        && unzip proxy_connect.zip \
        && cd nginx-${NGINX_VER} \
        && patch -p1 < /tmp/ngx_http_proxy_connect_module-${PROXY_CONNECT_M}/patch/proxy_connect_rewrite_1018.patch \
        && mkdir -p /var/cache/nginx \
        && ./configure \
            --prefix=/etc/nginx \
            --sbin-path=/usr/sbin/nginx \
            --modules-path=/usr/lib/nginx/modules \
            --conf-path=/etc/nginx/nginx.conf \
            --error-log-path=/var/log/nginx/error.log \
            --http-log-path=/var/log/nginx/access.log \
            --pid-path=/var/run/nginx.pid \
            --lock-path=/var/run/nginx.lock \
            --http-client-body-temp-path=/var/cache/nginx/client_temp \
            --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
            --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
            --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
            --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
            --user=nginx \
            --group=nginx \
            --with-compat \
            --with-file-aio \
            --with-threads \
            --with-http_addition_module \
            --with-http_auth_request_module \
            --with-http_dav_module \
            --with-http_flv_module \
            --with-http_gunzip_module \
            --with-http_gzip_static_module \
            --with-http_mp4_module \
            --with-http_random_index_module \
            --with-http_realip_module \
            --with-http_secure_link_module \
            --with-http_slice_module \
            --with-http_ssl_module \
            --with-http_stub_status_module \
            --with-http_sub_module \
            --with-http_v2_module \
            --with-mail \
            --with-mail_ssl_module \
            --with-stream \
            --with-stream_realip_module \
            --with-stream_ssl_module \
            --with-stream_ssl_preread_module \
            --with-cc-opt='-g -O2 -fdebug-prefix-map=/data/builder/debuild/nginx-${NGINX_VER}/debian/debuild-base/nginx-${NGINX_VER}=. -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
            --with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' \
            --add-module=/tmp/ngx_http_proxy_connect_module-${PROXY_CONNECT_M} \
        && make \
        && make install \
        && rm -rf /tmp/* \
        && apt-get remove --purge --auto-remove -y \
        && apt clean all \
        && rm -rf /var/cache/apt \
        && rm -rf /var/lib/apt/lists/* \
        && mkdir -p /etc/nginx/conf.d \
        && rm /etc/nginx/nginx.conf \
        && mkdir -p /usr/share/nginx \
        && mv /etc/nginx/html /usr/share/nginx/ \
        && ln -sf /dev/stdout /var/log/nginx/access.log \
        && ln -sf /dev/stderr /var/log/nginx/error.log \
        && mkdir /docker-entrypoint.d

COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf
COPY docker-entrypoint.sh /
COPY 10-listen-on-ipv6-by-default.sh /docker-entrypoint.d
COPY 20-envsubst-on-templates.sh /docker-entrypoint.d
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]

