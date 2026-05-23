from sqlalchemy import Column, BigInteger, Integer, Boolean, DateTime, ForeignKey
from sqlalchemy.sql import func
from app.database import Base


class Settings(Base):
    __tablename__ = "app_settings"

    setting_id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    patient_id = Column(BigInteger, ForeignKey("patients.patient_id"), unique=True, nullable=False)
    low_volume_threshold_ml = Column(Integer, nullable=False, default=100)
    push_enabled = Column(Boolean, nullable=False, default=True)
    vibration_enabled = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, server_default=func.now())
    updated_at = Column(DateTime, nullable=False, server_default=func.now(), onupdate=func.now())
