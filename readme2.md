# Déploiement local du portfolio — Eliaz CHALONY

## Supression de l'image docker
```bash
docker image rm -f portfolio-eliaz-chalony:1.0
```

## Construction
```bash
docker build -t portfolio-prenom-nom:1.0 .
```

## Lancement
```bash
docker run --rm -d --name portfolio-test -p 8081:80 portfolio-prenom-nom:1.0
```

## Test
http://localhost:8081
