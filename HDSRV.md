# Haute disponibilité — Cluster Web (Corosync / Pacemaker / MySQL)

Procédure de mise en place d'un cluster à 2 nœuds (`srv-web1` / `srv-web2`) avec IP de failover et réplication MySQL maître-maître.

| Nœud | Adresse IP |
|------|------------|
| serv1 (srv-web1) | 172.16.0.10 |
| serv2 (srv-web2) | 172.16.0.11 |
| VIP (IPFailover) | 172.16.0.12 |

---

## 1. Installation des paquets

```bash
apt update
apt install corosync pacemaker crmsh
```

---

## 2. Configuration de Corosync

### 2.1 Sauvegarde du fichier existant

```bash
mv /etc/corosync/corosync.conf /etc/corosync/corosync.conf.save
```

### 2.2 Création du nouveau fichier

```bash
vim /etc/corosync/corosync.conf
```

```conf
totem {
    version: 2
    cluster_name: cluster_web
    crypto_cipher: aes256
    crypto_hash: sha1
    clear_node_high_bit: yes
}

logging {
    fileline: off
    to_logfile: yes
    logfile: /var/log/corosync/corosync.log
    to_syslog: no
    debug: off
    timestamp: on
    logger_subsys {
        subsys: QUORUM
        debug: off
    }
}

quorum {
    provider: corosync_votequorum
    expected_votes: 2
    two_nodes: 1
}

nodelist {
    node {
        name: serv1
        nodeid: 1
        ring0_addr: 172.16.0.10
    }
    node {
        name: serv2
        nodeid: 2
        ring0_addr: 172.16.0.11
    }
}

service {
    ver: 0
    name: pacemaker
}
```

### 2.3 Redémarrage et vérification

Redémarrer le service, puis :

```bash
crm status
```

---

## 3. Création du second nœud (clonage)

1. Mettre en pause `srv-web1`.
2. Cloner `srv-web1` et renommer le clone en `srv-web2`.
3. Sur le clone : changer les adresses IP.
4. Sur le clone : changer le `hostname` et le fichier `/etc/hosts` avec `srv-web2`.
5. Relancer `srv-web1`.

### Vérification

```bash
crm status
```

Résultat attendu :

```
Node List:
  Online: [ srv-web1 srv-web2 ]
```

> Le nœud est fait :D

---

## 4. ACT2 – PART1 – SECTION3 : Désactivation de STONITH et du Quorum

```bash
crm configure property stonith-enabled=false
crm configure property no-quorum-policy="ignore"
```

---

## 5. Ressource IP de failover (VIP)

### 5.1 Création de la ressource

```bash
crm configure primitive IPFailover ocf:heartbeat:IPaddr2 \
    params ip=172.16.0.12 cidr_netmask=24 nic=ens33 iflabel=VIP
```

### 5.2 Commandes utiles

```bash
crm configure show                  # affiche la configuration des nœuds
crm resource move IPFailover srv-web1   # bascule la VIP sur srv-web1
```

---

## 6. Réplication MySQL

### 6.1 Création de l'utilisateur de réplication (sur les deux serveurs)

```sql
CREATE USER 'replicateur'@'%' IDENTIFIED BY 'Btssio2017';
GRANT REPLICATION SLAVE ON *.* TO 'replicateur'@'%';
FLUSH PRIVILEGES;
SHOW MASTER STATUS;
```

> `SHOW MASTER STATUS` donne le `File` et la `Position` à reporter dans les commandes ci-dessous.

### 6.2 Sur srv-web2 (maître = srv-web1)

```sql
CHANGE MASTER TO
    MASTER_HOST='172.16.0.10',
    MASTER_USER='replicateur',
    MASTER_PASSWORD='Btssio2017',
    MASTER_LOG_FILE='mysql-bin.000004',
    MASTER_LOG_POS=1126;
```

### 6.3 Sur srv-web1 (maître = srv-web2)

```sql
CHANGE MASTER TO
    MASTER_HOST='172.16.0.11',
    MASTER_USER='replicateur',
    MASTER_PASSWORD='Btssio2017',
    MASTER_LOG_FILE='mysql-bin.000001',
    MASTER_LOG_POS=2845;
```

---

## Aide-mémoire des commandes

| Commande | Rôle |
|----------|------|
| `crm status` | État du cluster et des nœuds |
| `crm configure show` | Affiche la configuration courante |
| `crm configure property ...` | Modifie une propriété du cluster |
| `crm configure primitive ...` | Crée une ressource |
| `crm resource move <res> <node>` | Déplace une ressource sur un nœud |
| `SHOW MASTER STATUS` | Récupère le log binaire et la position |
