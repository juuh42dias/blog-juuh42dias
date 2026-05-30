---
layout: post
title: "ChatGPT: basic example of an Nginx configuration file using an auto-signed SSL certificate"
date: 2023-03-10 20:09:55 +0000
categories: ssl certificate
tags: ssl certificate
description: "This article was created by ChatGPT  Here is a basic example of an Nginx configuration file using an..."
canonical_url: https://dev.to/juuh42dias/chatgpt-basic-example-of-an-nginx-configuration-file-using-an-auto-signed-ssl-certificate-jpg
source: dev.to
---

This article was created by ChatGPT

Here is a basic example of an Nginx configuration file using an auto-signed SSL certificate:

```bash
Copy code
server {
    listen 443 ssl;
    server_name example.com;
    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;

    location / {
        # your application code here
    }
}
```
Here are the steps to generate the auto-signed SSL certificate and key files:

Generate the SSL certificate and key files using OpenSSL:

```shell
$ openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/nginx-selfsigned.key \
  -out /etc/ssl/certs/nginx-selfsigned.crt
```
This command will prompt you for some information to include in the certificate, such as the Common Name (CN) which should be set to your domain name (e.g. example.com).

Verify that the certificate and key files were generated:

```shell
$ ls -l /etc/ssl/private/nginx-selfsigned.key /etc/ssl/certs/nginx-selfsigned.crt
```
You should see output similar to:

```bash
-rw-r--r-- 1 root root 1091 Feb 24 15:44 /etc/ssl/certs/nginx-selfsigned.crt
-rw-r--r-- 1 root root 1675 Feb 24 15:44 /etc/ssl/private/nginx-selfsigned.key
```
Copy the configuration file above into your Nginx server block, replacing the example.com server name with your own domain name.

Reload the Nginx configuration:

```bash
$ sudo systemctl reload nginx
```
That's it! Your Nginx server should now be configured to use the auto-signed SSL certificate.