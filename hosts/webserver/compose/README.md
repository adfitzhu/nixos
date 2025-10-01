This folder contains docker-compose services for the webserver host.

Secrets handling
----------------
Do not commit real credentials to Git.
Provide environment files on the host under /etc/secrets with 0750 permissions.
This folder includes a sample `wp1.env` showing the exact format; copy its
contents (with your own secure values) to `/etc/secrets/wp1.env` on the server.

WordPress example (wp1)
- Secrets file path: /etc/secrets/wp1.env
- Required keys:
  MYSQL_DATABASE=wordpress
  MYSQL_USER=wordpress
  MYSQL_PASSWORD=change_me
  MYSQL_ROOT_PASSWORD=change_me_root
  WORDPRESS_DB_NAME=wordpress
  WORDPRESS_DB_USER=wordpress
  WORDPRESS_DB_PASSWORD=change_me
  # Optional (defaults to wp1-db:3306 in compose):
  # WORDPRESS_DB_HOST=wp1-db:3306

Nextcloud AIO
- The AIO mastercontainer does not need DB credentials in this compose file.
- Configure domains and settings via the AIO admin at 127.0.0.1:8080 and your Caddy vhost.

General tips
- Restart policy is set to unless-stopped so containers will come back after reboot.
- If you ever run `docker compose down`, containers are removed and won't auto-start until you run `docker compose up -d` again.
- To add more sites, copy wp1 services with a new name and a new host port, and create a matching Caddy vhost.

Sharing environment across multiple services
- Reuse the same env_file across services:
  - env_file: [/etc/secrets/wp1.env] under both db and app
- Use a repo-level .env for variable substitution in the compose file (not for secrets):
  - WORDPRESS_IMAGE_TAG: 6.6-php8.2-apache
  - then reference as image: wordpress:${WORDPRESS_IMAGE_TAG}
- Use YAML anchors/aliases for repeated environment blocks when values aren’t secret.
