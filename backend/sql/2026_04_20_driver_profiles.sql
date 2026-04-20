CREATE TABLE IF NOT EXISTS driver_profiles (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL UNIQUE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  address TEXT NULL,
  id_card_photo MEDIUMTEXT NULL,
  selfie_photo MEDIUMTEXT NULL,
  verification_status ENUM('pending','verified','rejected') NOT NULL DEFAULT 'pending',
  rejection_reason TEXT NULL,
  submitted_at DATETIME NULL,
  verified_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_driver_profiles_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_driver_profiles_status (verification_status),
  INDEX idx_driver_profiles_submitted_at (submitted_at)
);
