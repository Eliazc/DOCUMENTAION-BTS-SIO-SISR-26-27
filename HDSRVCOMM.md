# Historique des commandes — Serveur Web (Apache / GSB / Cluster HA)

Procédure reconstituée à partir de l'historique `bash` du serveur. Les commandes sont regroupées par étape ; les fautes de frappe et navigations inutiles (`cd`, `ls`) ont été retirées quand elles n'apportaient rien.

---

## 1. Configuration réseau

### 1.1 Interface réseau

```bash
ip a
vim /etc/network/interfaces
systemctl restart networking.service
ip a
```

### 1.2 Nom d'hôte

```bash
vim /etc/hostname
vim /etc/hosts
reboot
```

### 1.3 DNS et tests de connectivité

```bash
ping 172.16.0.254        # passerelle
ping 1.1.1.1
ping 8.8.8.8
vim /etc/resolv.conf
nslookup www.google.fr
```

---

## 2. Mise à jour du système

```bash
apt update
apt upgrade
apt autoremove
```

---

## 3. Installation d'Apache2

```bash
apt install apache2
systemctl enable apache2
systemctl restart apache2
systemctl status apache2
```

### Test local

```bash
apt install curl
curl localhost
```

---

## 4. Déploiement du site Sodecaf

### 4.1 Extraction et copie des fichiers

```bash
cd /home/etudiant/
tar -xvf sodecaf.tar
mkdir /var/www/sodecaf
mv sodecaf.html /var/www/sodecaf/
mv sodecaf_files/ /var/www/sodecaf/
```

### 4.2 Droits

```bash
cd /var/www/
chown -R www-data:www-data sodecaf/
chmod -R 755 sodecaf/
```

### 4.3 VirtualHost

```bash
cd /etc/apache2/sites-available/
cp 000-default.conf sodecaf.conf
vim sodecaf.conf
a2dissite 000-default.conf
a2ensite sodecaf.conf
systemctl reload apache2.service
apache2ctl configtest
```

### 4.4 Sécurisation d'Apache

```bash
vim /etc/apache2/conf-available/security.conf
systemctl reload apache2.service
```

---

## 5. Gestion des timeouts (module reqtimeout)

```bash
a2dismod reqtimeout
vim /etc/apache2/conf-available/sodecaf-timeouts.conf
a2enconf sodecaf-timeouts
a2enmod reqtimeout
apache2ctl configtest
systemctl restart apache2
```

---

## 6. Consultation des logs

```bash
cd /var/log/apache2/
cat error_sodecaf.log
cat access_sodecaf.log
tail -f /var/log/apache2/access_sodecaf.log /var/log/apache2/error_sodecaf.log
```

---

## 7. Protection anti-DoS avec Fail2ban

```bash
vim /etc/apache2/apache2.conf
apt install fail2ban
vim /etc/fail2ban/jail.d/apache-get-dos.conf
vim /etc/fail2ban/jail.d/custom.conf
vim /etc/fail2ban/filter.d/apache-get-dos.conf
systemctl restart fail2ban.service
systemctl status fail2ban.service
```

### Vérification

```bash
fail2ban-client status apache-get-dos
nft list ruleset
```

> Fail2ban a ensuite été supprimé lors du passage à l'application GSB (voir section 9.3).

---

## 8. HTTPS / SSL

### 8.1 Génération de la clé et de la demande de certificat

```bash
vim /etc/ssl/openssl.cnf
openssl genrsa -out /etc/ssl/private/srvwebkey.pem 4096
openssl req -new -key /etc/ssl/private/srvwebkey.pem -out /etc/ssl/srvwebdem.pem
```

### 8.2 Signature par l'autorité de certification

```bash
cd /etc/ssl
scp srvwebdem.pem etudiant@172.16.0.20:/home/etudiant
# Récupération du certificat signé
mv /home/etudiant/servwebcert.pem /etc/ssl/certs/
```

### 8.3 Activation dans Apache

```bash
vim /etc/apache2/sites-available/sodecaf.conf
a2enmod ssl
a2enmod rewrite       # redirection HTTP -> HTTPS
systemctl restart apache2
systemctl status apache2.service
```

---

## 9. Application GSB (appliFrais)

### 9.1 Déploiement des fichiers

```bash
mv /home/etudiant/appliFrais/appliFrais/ /var/www/
chown -R www-data:www-data /var/www/appliFrais/
chmod -R 750 /var/www/appliFrais/
```

### 9.2 Installation de PHP

```bash
apt install php
apt install php-mysql
systemctl reload apache2.service
```

### 9.3 VirtualHost GSB

```bash
cd /etc/apache2/sites-available/
cp sodecaf.conf gsb.conf
vim gsb.conf
a2dissite sodecaf.conf
a2ensite gsb.conf
systemctl stop fail2ban.service
apt purge fail2ban
apache2ctl configtest
systemctl reload apache2.service
```

### 9.4 Logs de l'application

```bash
tail /var/log/apache2/access_gsb.log
tail /var/log/apache2/error_gsb.log
```

### 9.5 Base de données MariaDB

```bash
apt install mariadb-server
cd /home/etudiant/appliFrais/
mysql -u root -p gsb_valide < gsb_frais_structure.sql
mysql -u root -p gsb_valide < gsb_frais_insert_tables_statiques.sql
mysql
```

### 9.6 Personnalisation de l'en-tête

```bash
vim /var/www/appliFrais/include/_entete.inc.html
```

---

## 10. Cluster haute disponibilité (Corosync / Pacemaker)

### 10.1 Installation

```bash
apt update
apt upgrade
apt install corosync pacemaker crmsh
systemctl status corosync.service
```

### 10.2 Clé d'authentification

```bash
corosync-keygen
ls -l /etc/corosync/
cat /etc/corosync/authkey
```

### 10.3 Configuration

```bash
cd /etc/corosync/
mv corosync.conf corosync.conf.sav
vim corosync.conf
corosync-cfgtool -s
systemctl restart corosync.service
crm status
```

### 10.4 Test de bascule (standby / online)

```bash
crm node standby      # met le nœud en veille
crm status
crm node online       # remet le nœud en ligne
crm status
```

### 10.5 Configuration des ressources

```bash
crm configure
crm configure show
```

---

## 11. Préparation de la réplication MariaDB

### 11.1 Configuration du serveur

```bash
vim /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl restart mariadb.service
```

### 11.2 Dossier de logs binaires

```bash
mkdir /var/log/mysql
chown -R mysql:mysql /var/log/mysql/
chmod -R 775 /var/log/mysql/
systemctl restart mariadb.service
systemctl status mariadb.service
```

---

## Aide-mémoire

| Commande | Rôle |
|----------|------|
| `a2ensite` / `a2dissite` | Active / désactive un site |
| `a2enmod` / `a2dismod` | Active / désactive un module |
| `a2enconf` | Active une configuration |
| `apache2ctl configtest` | Vérifie la syntaxe de la config Apache |
| `fail2ban-client status <jail>` | État d'une prison Fail2ban |
| `corosync-keygen` | Génère la clé du cluster |
| `corosync-cfgtool -s` | État des anneaux Corosync |
| `crm node standby` / `online` | Met un nœud en veille / en ligne |
