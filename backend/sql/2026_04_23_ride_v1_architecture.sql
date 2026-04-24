-- Noor Express - Ride V1 architecture hardening
-- A executer sur MySQL avant de lancer la V1 refactoree.

ALTER TABLE ride_requests
  ADD COLUMN agreed_price DECIMAL(10,2) NULL AFTER estimated_price;

ALTER TABLE ride_requests
  MODIFY COLUMN status ENUM(
    'pending',
    'offered',
    'accepted',
    'arrived',
    'started',
    'completed',
    'cancelled',
    'expired'
  ) NOT NULL DEFAULT 'pending';

ALTER TABLE ride_offers
  MODIFY COLUMN status ENUM(
    'pending',
    'accepted',
    'rejected',
    'invalidated',
    'expired'
  ) NOT NULL DEFAULT 'pending';

-- Backfill simple pour conserver un prix verrouille coherent sur les rides existantes.
UPDATE ride_requests
SET agreed_price = COALESCE(final_price, estimated_price)
WHERE agreed_price IS NULL
  AND status IN ('accepted', 'arrived', 'started', 'completed');

UPDATE ride_requests
SET final_price = agreed_price
WHERE status = 'completed'
  AND final_price IS NULL
  AND agreed_price IS NOT NULL;
