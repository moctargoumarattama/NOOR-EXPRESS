CREATE TABLE ride_offers (
  id INT PRIMARY KEY AUTO_INCREMENT,
  ride_request_id INT NOT NULL,
  driver_id INT NOT NULL,
  proposed_price DECIMAL(10,2) NOT NULL,
  status ENUM('pending','accepted','rejected') NOT NULL DEFAULT 'pending',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  responded_at DATETIME NULL,
  CONSTRAINT fk_ride_offers_ride_request
    FOREIGN KEY (ride_request_id) REFERENCES ride_requests(id),
  CONSTRAINT fk_ride_offers_driver
    FOREIGN KEY (driver_id) REFERENCES users(id),
  CONSTRAINT uq_ride_offers_ride_driver UNIQUE (ride_request_id, driver_id)
);
