ALTER TABLE driver_profiles
  ADD COLUMN driver_license_file MEDIUMTEXT NULL AFTER selfie_photo,
  ADD COLUMN driver_license_expires_at DATE NULL AFTER driver_license_file,
  ADD COLUMN driver_license_status ENUM('en_attente','validé','expiré','rejeté') NOT NULL DEFAULT 'en_attente' AFTER driver_license_expires_at,
  ADD COLUMN vehicle_registration_file MEDIUMTEXT NULL AFTER driver_license_status,
  ADD COLUMN vehicle_registration_expires_at DATE NULL AFTER vehicle_registration_file,
  ADD COLUMN vehicle_registration_status ENUM('en_attente','validé','expiré','rejeté') NOT NULL DEFAULT 'en_attente' AFTER vehicle_registration_expires_at,
  ADD COLUMN vehicle_insurance_file MEDIUMTEXT NULL AFTER vehicle_registration_status,
  ADD COLUMN vehicle_insurance_expires_at DATE NULL AFTER vehicle_insurance_file,
  ADD COLUMN vehicle_insurance_status ENUM('en_attente','validé','expiré','rejeté') NOT NULL DEFAULT 'en_attente' AFTER vehicle_insurance_expires_at,
  ADD COLUMN technical_inspection_file MEDIUMTEXT NULL AFTER vehicle_insurance_status,
  ADD COLUMN technical_inspection_expires_at DATE NULL AFTER technical_inspection_file,
  ADD COLUMN technical_inspection_status ENUM('en_attente','validé','expiré','rejeté') NOT NULL DEFAULT 'en_attente' AFTER technical_inspection_expires_at;
