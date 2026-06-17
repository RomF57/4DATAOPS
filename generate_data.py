#!/usr/bin/env python3
"""Generateur de donnees capteurs pour le webhook n8n IOT Fleet."""

import random
import time
from datetime import datetime, timezone

import requests

# --- Configuration de l'URL ---
# 1er test (workflow NON active) : decommentez la ligne -test ci-dessous,
#    cliquez "Listen for test event" dans n8n, puis lancez le script.
# WEBHOOK_URL = "http://localhost:5678/webhook-test/sensor-data"
#
# Ingestion EN CONTINU (workflow ACTIVE) : utilisez l'URL de production.
WEBHOOK_URL = "http://localhost:5678/webhook/sensor-data"

INTERVAL_SECONDS = 2            # delai entre deux envois
SENSOR_IDS = [1, 2, 3, 4, 5]   # doivent exister dans la table capteurs


def generer_evenement():
    return {
        "id_capteur": random.choice(SENSOR_IDS),
        # Plage large pour produire parfois des valeurs hors limites [-10, 50]
        "valeur_mesure": round(random.uniform(-20, 60), 2),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


def main():
    print(f"Envoi vers {WEBHOOK_URL} (Ctrl+C pour arreter)")
    while True:
        evenement = generer_evenement()
        try:
            reponse = requests.post(WEBHOOK_URL, json=evenement, timeout=5)
            print(f"{evenement['valeur_mesure']} C -> HTTP {reponse.status_code}")
        except requests.exceptions.RequestException as erreur:
            print(f"Erreur d'envoi : {erreur}")
        time.sleep(INTERVAL_SECONDS)


if __name__ == "__main__":
    main()