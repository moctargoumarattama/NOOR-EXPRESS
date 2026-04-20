ALTER TABLE pricing_zones
  ADD COLUMN description VARCHAR(255) NULL;

CREATE TABLE IF NOT EXISTS pricing_settings (
  id INT PRIMARY KEY DEFAULT 1,
  active_mode ENUM('distance','zone','mixed') NOT NULL DEFAULT 'mixed',
  price_per_km DECIMAL(10,2) NOT NULL DEFAULT 300.00,
  minimum_price DECIMAL(10,2) NOT NULL DEFAULT 1500.00,
  platform_commission_percent DECIMAL(5,2) NOT NULL DEFAULT 15.00,
  long_ride_threshold_minutes INT NOT NULL DEFAULT 60,
  long_ride_minimum_price DECIMAL(10,2) NOT NULL DEFAULT 5000.00,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO pricing_settings
  (id, active_mode, price_per_km, minimum_price, platform_commission_percent,
   long_ride_threshold_minutes, long_ride_minimum_price)
VALUES
  (1, 'mixed', 300.00, 1500.00, 15.00, 60, 5000.00)
ON DUPLICATE KEY UPDATE id = id;

CREATE TABLE IF NOT EXISTS zone_fares (
  id INT PRIMARY KEY AUTO_INCREMENT,
  origin_zone_id INT NOT NULL,
  destination_zone_id INT NOT NULL,
  fixed_price DECIMAL(10,2) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_zone_fares_origin
    FOREIGN KEY (origin_zone_id) REFERENCES pricing_zones(id),
  CONSTRAINT fk_zone_fares_destination
    FOREIGN KEY (destination_zone_id) REFERENCES pricing_zones(id),
  CONSTRAINT uq_zone_fares_pair UNIQUE (origin_zone_id, destination_zone_id),
  CONSTRAINT chk_zone_fares_price CHECK (fixed_price > 0)
);

CREATE TABLE IF NOT EXISTS time_pricing_rules (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  surcharge_type ENUM('fixed','percent') NOT NULL,
  surcharge_value DECIMAL(10,2) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_time_pricing_surcharge CHECK (surcharge_value >= 0)
);

ALTER TABLE ride_requests
  MODIFY COLUMN estimated_price DECIMAL(10,2) NOT NULL,
  MODIFY COLUMN final_price DECIMAL(10,2) NULL,
  MODIFY COLUMN platform_commission DECIMAL(10,2) NULL,
  MODIFY COLUMN driver_net_earnings DECIMAL(10,2) NULL;

INSERT INTO zone_fares (origin_zone_id, destination_zone_id, fixed_price, is_active)
SELECT origin.id, destination.id, seed.fixed_price, TRUE
FROM (
  SELECT 'Aeroport Diori Hamani' origin_name, 'Plateau' destination_name, 10000.00 fixed_price
  UNION ALL SELECT 'Plateau', 'Aeroport Diori Hamani', 10000.00
  UNION ALL SELECT 'Grand Marche', 'Yantala', 2500.00
  UNION ALL SELECT 'Yantala', 'Grand Marche', 2500.00
  UNION ALL SELECT 'Universite Abdou Moumouni', 'Plateau', 2000.00
  UNION ALL SELECT 'Plateau', 'Universite Abdou Moumouni', 2000.00
) seed
JOIN pricing_zones origin ON origin.name = seed.origin_name
JOIN pricing_zones destination ON destination.name = seed.destination_name
ON DUPLICATE KEY UPDATE fixed_price = VALUES(fixed_price);

INSERT INTO time_pricing_rules (name, start_time, end_time, surcharge_type, surcharge_value, is_active)
SELECT * FROM (
  SELECT 'Soiree Niamey' name, TIME('19:00:00') start_time, TIME('23:59:59') end_time,
         'percent' surcharge_type, 15.00 surcharge_value, TRUE is_active
  UNION ALL SELECT 'Nuit', TIME('00:00:00'), TIME('06:00:00'), 'percent', 20.00, TRUE
) seed
WHERE NOT EXISTS (
  SELECT 1 FROM time_pricing_rules WHERE time_pricing_rules.name = seed.name
);
