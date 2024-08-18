# onprem

## Installation

1. Copy [nginx.conf](nginx.conf) to */etc/nginx/nginx.conf*.
2. Copy [reverse-proxy](reverse-proxy) to */etc/nginx/sites-available*.
3. Create a symlink from */etc/nginx/sites-available/reverse-proxy* to */etc/nginx/sites-available/reverse-proxy*.
4. Follow the instructions in the next section to set up SSL certificates.

## Certificates

Install snapd:

    sudo snap install --classic certbot

Prepare certbot:

    sudo ln -s /snap/bin/certbot /usr/bin/certbot
    sudo certbot --nginx

The interactive *certbot* command will ask some questions, proceed through the prompts.

This sets up SSL including automatic renewal for all sites in *reverse-proxy*.
