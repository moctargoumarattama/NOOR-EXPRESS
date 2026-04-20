-- Noor Express - ride tracking support
-- A executer sur MySQL avant de lancer le backend avec le tracking live.

ALTER TABLE ride_requests
ADD COLUMN pickup_latitude FLOAT NULL,
ADD COLUMN pickup_longitude FLOAT NULL,
ADD COLUMN dropoff_latitude FLOAT NULL,
ADD COLUMN dropoff_longitude FLOAT NULL;

-- Important :
-- Garder les statuts deja existants. Ici on ajoute "arrived" sans perdre "expired".
ALTER TABLE ride_requests
MODIFY COLUMN status ENUM(
  'pending',
  'accepted',
  'arrived',
  'started',
  'completed',
  'cancelled',
  'expired'
) NOT NULL DEFAULT 'pending';
