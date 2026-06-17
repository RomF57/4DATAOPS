#!/bin/bash
# Remise a zero totale de l'environnement IOT Fleet.
# ATTENTION : -v supprime TOUS les volumes (postgres, mongo ET n8n).
# Les tables PostgreSQL sont recreees automatiquement via sql/init.sql,
# mais la configuration n8n (compte, credentials, workflow) doit etre refaite.

echo ">> Arret des conteneurs et suppression des volumes..."
docker compose down -v

echo ">> Redemarrage de l'environnement..."
docker compose up -d

echo ">> Termine. n8n: http://localhost:5678 | Mailpit: http://localhost:8025"