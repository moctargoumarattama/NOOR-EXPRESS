SET @schema_name = DATABASE();

SET @profile_photo_exists = (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = @schema_name
    AND table_name = 'users'
    AND column_name = 'profile_photo'
);

SET @sql = IF(
  @profile_photo_exists = 0,
  'ALTER TABLE users ADD COLUMN profile_photo MEDIUMTEXT NULL',
  'SELECT "profile_photo column already exists"'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS ride_reports (
  id INT PRIMARY KEY AUTO_INCREMENT,
  ride_request_id INT NOT NULL,
  reported_by_id INT NOT NULL,
  reason ENUM('comportement','prix','securite','autre') NOT NULL,
  description TEXT NULL,
  status ENUM('ouvert','traite') NOT NULL DEFAULT 'ouvert',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_ride_reports_ride_request_id (ride_request_id),
  INDEX idx_ride_reports_reported_by_id (reported_by_id),
  INDEX idx_ride_reports_status (status),
  CONSTRAINT fk_ride_reports_ride_request
    FOREIGN KEY (ride_request_id) REFERENCES ride_requests(id),
  CONSTRAINT fk_ride_reports_reported_by
    FOREIGN KEY (reported_by_id) REFERENCES users(id)
);
