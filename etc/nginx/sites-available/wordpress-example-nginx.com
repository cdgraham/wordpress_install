server {
	listen *:80;
	listen [::]:80;

	server_name EXAMPLE.com www.EXAMPLE.com;
	root /var/www/EXAMPLE.com/httpdocs;
	include sites-common/*.conf;
	index index.php;
        return 301 https://$host$request_uri;
}

server {
	# listens both on IPv4 and IPv6 on 443 and enables HTTPS and HTTP/2 support.
	# HTTP/2 is available in nginx 1.9.5 and above.
	listen *:443 ssl http2;
	listen [::]:443 ssl http2;

	ssl_certificate /etc/letsencrypt/live/EXAMPLE.com/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/EXAMPLE.com/privkey.pem;

	server_name EXAMPLE.com www.EXAMPLE.com;
	root /var/www/EXAMPLE.com/httpdocs;
	include sites-common/*.conf;
	index index.php;

	access_log   /var/log/nginx/EXAMPLE.com.access.log combined buffer=64k flush=5m;
	error_log    /var/log/nginx/EXAMPLE.com.error.log;
}
