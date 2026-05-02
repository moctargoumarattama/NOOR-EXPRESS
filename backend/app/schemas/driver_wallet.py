from datetime import datetime

from pydantic import BaseModel


class EarningsWindowRead(BaseModel):
    rides_count: int
    gross_amount: float
    commission_amount: float
    net_amount: float


class DriverWalletSummaryRead(BaseModel):
    driver_id: int
    today: EarningsWindowRead
    week: EarningsWindowRead
    total: EarningsWindowRead
    updated_at: datetime | None = None


class CommissionLedgerItemRead(BaseModel):
    ride_id: int
    client_phone_number: str
    driver_id: int
    driver_phone_number: str
    completed_at: datetime | None
    gross_amount: float
    commission_amount: float
    net_amount: float


class CommissionLedgerRead(BaseModel):
    total_count: int
    total_gross_amount: float
    total_commission_amount: float
    total_net_amount: float
    items: list[CommissionLedgerItemRead]


class DriverRevenueStatsRead(BaseModel):
    today: float
    week: float
    month: float
    total: float


class DriverRideStatusStatsRead(BaseModel):
    completed: int
    cancelled: int
    refused: int


class DriverPeakHourStatsRead(BaseModel):
    hour: int
    completed_rides: int
    average_revenue: float


class DriverZoneProfitabilityRead(BaseModel):
    zone_name: str
    rides_count: int
    average_revenue: float


class DriverReputationStatsRead(BaseModel):
    last_30_days: float
    global_average: float


class DriverDashboardStatsRead(BaseModel):
    driver_id: int
    revenue: DriverRevenueStatsRead
    rides: DriverRideStatusStatsRead
    peak_hours: list[DriverPeakHourStatsRead]
    profitable_zones: list[DriverZoneProfitabilityRead]
    reputation: DriverReputationStatsRead
