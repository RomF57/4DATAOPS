@echo off
echo Remise a zero totale (supprime postgres, mongo ET n8n)...
docker compose down -v
docker compose up -d
echo Termine. n8n: http://localhost:5678  Mailpit: http://localhost:8025