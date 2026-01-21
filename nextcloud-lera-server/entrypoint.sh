#!/bin/sh

# SETTING NGINX SERVER
echo """
user ${NEXTCLOUD_RUNTIME_USER};
worker_processes auto;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

http {
	include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    
	upstream php-fpm {
        server unix:/run/php-fpm/${NEXTCLOUD_RUNTIME_USER}.sock;
    }

	server {
        listen       ${HTTP_PORT};
        listen       [::]:${HTTP_PORT};
        server_name  _;
        root         /app;

        index index.php index.html index.htm;

		location ~ \.(php|phar)(/.*)?$ {
			fastcgi_split_path_info ^(.+\.(?:php|phar))(/.*)$;

			fastcgi_intercept_errors on;
			fastcgi_index  index.php;
			include        fastcgi_params;
			fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
			fastcgi_param  PATH_INFO $fastcgi_path_info;
			fastcgi_pass   php-fpm;
		}	
    }
}
""" > /etc/nginx/nginx.conf
