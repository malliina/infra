# onprem

## Installation

1. Copy [nginx.conf](nginx.conf) to */etc/nginx/nginx.conf*.
2. Copy [reverse-proxy](reverse-proxy) to */etc/nginx/sites-available*.
3. Create a symlink from */etc/nginx/sites-available/reverse-proxy* to */etc/nginx/sites-available/reverse-proxy*.

## Certificates

Dry run:

    certbot renew --dry-run

Renewal:

    certbot renew
