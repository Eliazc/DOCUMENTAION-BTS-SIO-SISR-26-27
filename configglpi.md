```bash
<VirtualHost *:80>
    ServerName glpi.bzhboutique.local
    DocumentRoot /var/www/glpi/public
    <Directory /var/www/glpi/public>
        Options Indexes FollowSymlinks
        Require all granted
        RewriteEngine On

        RewriteCond %{HTTP:Authorization} ^(.+)$
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
</VirtualHost>
```
