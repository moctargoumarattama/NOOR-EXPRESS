CREATE TABLE IF NOT EXISTS pricing_zones (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  base_price DECIMAL(10,2) NOT NULL,
  price_per_km DECIMAL(10,2) NOT NULL,
  latitude FLOAT NOT NULL,
  longitude FLOAT NOT NULL,
  radius_km FLOAT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS admins (
  id INT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO pricing_zones
  (name, base_price, price_per_km, latitude, longitude, radius_km, is_active)
SELECT *
FROM (
  SELECT 'Plateau' AS name, 500.00 AS base_price, 280.00 AS price_per_km, 13.5137 AS latitude, 2.1098 AS longitude, 2.0 AS radius_km, TRUE AS is_active
  UNION ALL SELECT 'Plateau Terminus', 500.00, 280.00, 13.5195, 2.1118, 1.5, TRUE
  UNION ALL SELECT 'Universite Abdou Moumouni', 550.00, 300.00, 13.5005, 2.0912, 2.2, TRUE
  UNION ALL SELECT 'Grand Marche', 500.00, 290.00, 13.5162, 2.1168, 1.6, TRUE
  UNION ALL SELECT 'Aeroport Diori Hamani', 700.00, 350.00, 13.4817, 2.1836, 3.0, TRUE
  UNION ALL SELECT 'Nouveau Marche', 500.00, 295.00, 13.5289, 2.1194, 1.8, TRUE
  UNION ALL SELECT 'Talladje', 650.00, 330.00, 13.5541, 2.1038, 2.5, TRUE
  UNION ALL SELECT 'Dar Es Salam', 650.00, 330.00, 13.5494, 2.1291, 2.5, TRUE
  UNION ALL SELECT 'Yantala', 550.00, 300.00, 13.5254, 2.0934, 2.2, TRUE
  UNION ALL SELECT 'Route de Tillaberi', 700.00, 360.00, 13.5576, 2.0607, 3.5, TRUE
) AS seed
WHERE NOT EXISTS (
  SELECT 1 FROM pricing_zones WHERE pricing_zones.name = seed.name
);
