# IOT Fleet — Pipeline d'ingestion temps réel

Pipeline DataOps de gestion d'une flotte de capteurs IoT. Les mesures de température sont reçues via un webhook, validées, puis stockées **en parallèle** dans PostgreSQL (relationnel) et MongoDB (documentaire). Le pipeline est résilient (gestion d'erreurs et file de rejet) et envoie une **alerte e-mail** en cas de panne.

---

## Architecture

L'infrastructure est composée de quatre services Docker :

| Service   | Rôle                                                        |
|-----------|-------------------------------------------------------------|
| `postgres`| Base relationnelle — tables `capteurs` et `evenements`      |
| `mongodb` | Base documentaire — collection `Evenements`                 |
| `n8n`     | Orchestrateur du pipeline (webhook → validation → écritures)|
| `mailpit` | Serveur SMTP de test — capture les e-mails d'alerte         |

**Flux de données :**

```
generate_data.py
      │  POST (JSON)
      ▼
[Webhook] → [Code: validation] ─┬─→ [PostgreSQL : evenements]
                                └─→ [MongoDB : Evenements]
                                          │
                          en cas d'erreur ▼
                                   [Alerte e-mail SMTP → Mailpit]
```

Deux niveaux de résilience :
- **Niveau nœud** : capture des erreurs de *données* (ex. type invalide) via `Continue on Fail` + branche d'alerte.
- **Niveau global** : un *Error Workflow* capture les pannes d'*infrastructure* (base injoignable) qui échappent au niveau nœud.

---

## Prérequis

- **Docker Desktop** (inclut Docker Compose)
- **Python 3.x** (uniquement pour exécuter le générateur de données)

---

## Variables d'environnement

Les secrets et la configuration sont centralisés dans un fichier `.env` (jamais versionné). Un modèle `.env.example` est fourni.

| Variable            | Description                                  | Exemple         |
|---------------------|----------------------------------------------|-----------------|
| `POSTGRES_USER`     | Utilisateur PostgreSQL                        | `iot`           |
| `POSTGRES_PASSWORD` | Mot de passe PostgreSQL (**secret**)          | *(à définir)*   |
| `POSTGRES_DB`       | Nom de la base PostgreSQL                      | `iot_fleet`     |
| `GENERIC_TIMEZONE`  | Fuseau horaire utilisé par n8n                 | `Europe/Paris`  |
| `TZ`                | Fuseau horaire du conteneur                    | `Europe/Paris`  |

> La valeur de `POSTGRES_PASSWORD` dans `.env` doit être **identique** à celle saisie dans le credential PostgreSQL de n8n.

---

## Déploiement en une seule commande

```bash
cp .env.example .env        # Windows PowerShell : Copy-Item .env.example .env
# éditer .env et renseigner au minimum POSTGRES_PASSWORD
docker compose up -d
```

Cette commande démarre les quatre services. Les tables PostgreSQL (`capteurs`, `evenements`) et les cinq capteurs de démonstration sont créés **automatiquement** au premier lancement grâce à `sql/init.sql`.

**Interfaces disponibles :**
- n8n : http://localhost:5678
- Mailpit (boîte de réception des alertes) : http://localhost:8025

---

## Configuration n8n (première installation ou après un reset)

Les workflows sont versionnés en JSON, mais les **credentials n8n** (chiffrés dans le volume `n8n_data`) ne le sont pas. Après un déploiement vierge, il faut donc :

1. Ouvrir http://localhost:5678 et **créer le compte propriétaire**.
2. Dans **Credentials**, créer les trois accès :
   - **Postgres** — Host : `postgres` · Database : `iot_fleet` · User / Password : ceux du `.env` · Port : `5432` · SSL : désactivé.
   - **MongoDB** — Connection String : `mongodb://mongodb:27017` · Database : `iot_fleet`.
   - **SMTP** — Host : `mailpit` · Port : `1025` · User / Password : `iot` / `iot` · SSL : désactivé.
   > Les hôtes sont les **noms de service Docker** (`postgres`, `mongodb`, `mailpit`), jamais `localhost`.
3. **Importer les workflows** : menu → *Import from File* → `workflows/sensor-data.json`, puis `workflows/error-handler.json`.
4. Dans chaque nœud utilisant un credential (Postgres, MongoDB, Send Email), **re-sélectionner** le credential correspondant (les identifiants internes changent sur une instance neuve).
5. Dans le workflow `sensor-data` : menu **⋯** → *Settings* → **Error workflow** → sélectionner `Error Handler`.
6. **Publier** le workflow `sensor-data`.

---

## Générer des données

```bash
pip install requests
python generate_data.py
```

Le script envoie une mesure aléatoire toutes les 2 secondes vers l'URL de production du webhook. Le workflow `sensor-data` doit être **publié** pour que cette URL réponde.

---

## Vérifier les données

- **PostgreSQL** (DBeaver) — connexion `localhost:5432` :
  ```sql
  SELECT * FROM evenements ORDER BY id_evenement DESC LIMIT 20;
  ```
- **MongoDB** (Compass) — connexion `mongodb://localhost:27017`, base `iot_fleet`, collection `Evenements`.
- **Alertes** (Mailpit) — http://localhost:8025

---

## Maintenance — `reset.sh`

`reset.sh` (ou `reset.bat` sous Windows) exécute `docker compose down -v` puis `docker compose up -d` : une **remise à zéro totale** de l'environnement, garantissant que chaque session démarre sur une base saine.

**À savoir :**
- L'option `-v` supprime **tous** les volumes : `postgres`, `mongo` **et** `n8n`.
- Les tables PostgreSQL et les capteurs de démonstration sont **recréés automatiquement** (`sql/init.sql`).
- La configuration n8n (compte, credentials, import du workflow, publication) doit être **refaite** — voir *Configuration n8n*.

**Usage :**
```bash
./reset.sh        # Linux / macOS
reset.bat         # Windows
```

---

## Tester la résilience et les alertes

**Scénario 1 — donnée invalide (erreur applicative) :** capturée au niveau du nœud Postgres.
```powershell
Invoke-RestMethod -Uri "http://localhost:5678/webhook/sensor-data" -Method Post -ContentType "application/json" -Body '{"id_capteur":"INVALID","valeur_mesure":999999,"timestamp":"2026-06-17T10:00:00Z"}'
```

**Scénario 2 — panne d'infrastructure (base coupée) :** capturée par l'Error Workflow global.
```powershell
docker compose stop mongodb
Invoke-RestMethod -Uri "http://localhost:5678/webhook/sensor-data" -Method Post -ContentType "application/json" -Body '{"id_capteur":3,"valeur_mesure":22.5,"timestamp":"2026-06-17T10:00:00Z"}'
docker compose start mongodb
```

Dans les deux cas, l'alerte doit apparaître dans Mailpit (http://localhost:8025), et le flux principal ne doit pas rester bloqué.

> Arrêter le générateur de données avant ces tests pour ne pas inonder la boîte d'alertes.

---

## Structure du projet

```
iot-fleet/
├── .env                  # secrets (NON versionné)
├── .env.example          # modèle des variables d'environnement
├── .gitignore
├── docker-compose.yml    # définition des 4 services
├── reset.sh              # remise à zéro (Linux/macOS)
├── reset.bat             # remise à zéro (Windows)
├── generate_data.py      # générateur de mesures
├── README.md
├── sql/
│   └── init.sql          # schéma + données de démo (auto-exécuté)
└── workflows/
    ├── sensor-data.json  # pipeline principal
    └── error-handler.json# workflow d'alerte global
```

---

## Ports exposés

| Service   | Port hôte | Usage                          |
|-----------|-----------|--------------------------------|
| PostgreSQL| 5432      | Connexion SQL (DBeaver)        |
| MongoDB   | 27017     | Connexion NoSQL (Compass)      |
| n8n       | 5678      | Interface + webhook            |
| Mailpit   | 1025      | SMTP (réception des alertes)   |
| Mailpit   | 8025      | Interface web (lecture mails)  |

---

## Sécurité

- Tous les secrets vivent dans `.env`, **gitignored** : rien en dur dans `docker-compose.yml` ni dans le dépôt.
- Les credentials n8n sont **chiffrés** dans le volume `n8n_data`.
- L'export JSON du workflow contient les **références** de credentials, jamais les mots de passe.
- `.env.example` ne contient que des noms de variables et des valeurs non sensibles.
