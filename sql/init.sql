-- Schema initial IOT Fleet
-- Execute automatiquement au premier demarrage de PostgreSQL (volume vide)

CREATE TABLE IF NOT EXISTS capteurs (
    id_capteur        SERIAL PRIMARY KEY,
    type              VARCHAR(100) NOT NULL,
    localisation      VARCHAR(255),
    date_installation DATE
);

CREATE TABLE IF NOT EXISTS evenements (
    id_evenement  SERIAL PRIMARY KEY,
    id_capteur    INTEGER,
    valeur_mesure NUMERIC(6,2),
    timestamp     TIMESTAMPTZ
);

-- Capteurs de demonstration (id 1 a 5)
INSERT INTO capteurs (id_capteur, type, localisation, date_installation) VALUES
  (1, 'temperature', 'Entrepot A',   '2026-01-10'),
  (2, 'temperature', 'Entrepot B',   '2026-01-12'),
  (3, 'temperature', 'Quai 3',       '2026-02-01'),
  (4, 'temperature', 'Salle Froide', '2026-02-15'),
  (5, 'temperature', 'Exterieur',    '2026-03-01')
ON CONFLICT (id_capteur) DO NOTHING;

-- Realigne la sequence du SERIAL apres les inserts manuels
SELECT setval('capteurs_id_capteur_seq', (SELECT COALESCE(MAX(id_capteur), 1) FROM capteurs));