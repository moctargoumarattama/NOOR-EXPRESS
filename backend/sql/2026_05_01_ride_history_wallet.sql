ALTER TABLE ride_requests
  ADD COLUMN distance_km FLOAT NULL AFTER dropoff_longitude,
  ADD COLUMN duration_minutes INT NULL AFTER distance_km,
  ADD COLUMN completed_at DATETIME NULL AFTER created_at;

CREATE TABLE IF NOT EXISTS driver_wallets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  driver_id INT NOT NULL,
  total_completed_rides INT NOT NULL DEFAULT 0,
  total_gross_earnings DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  total_commission DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  total_net_earnings DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_driver_wallets_driver_id UNIQUE (driver_id),
  CONSTRAINT fk_driver_wallets_driver FOREIGN KEY (driver_id) REFERENCES users(id)
);
