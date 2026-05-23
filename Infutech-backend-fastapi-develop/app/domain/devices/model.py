from sqlalchemy import Column, BigInteger, String, Integer, DateTime
from sqlalchemy.sql import func
from app.database import Base


class Device(Base):
    __tablename__ = "devices"

    device_id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    device_uid = Column(String(100), unique=True, nullable=False, index=True)
    qr_code_value = Column(String(255), unique=True, nullable=False)
    device_name = Column(String(100), nullable=False)
    mac_address = Column(String(50), nullable=True)
    device_key = Column(String(255), nullable=True)  # ESP32 인증용
    device_type = Column(String(20), nullable=False, default="iv_fluid")  # iv_fluid / urine
    battery_level = Column(Integer, nullable=True)
    network_status = Column(String(20), nullable=False, default="offline")
    last_seen_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, nullable=False, server_default=func.now())
    updated_at = Column(DateTime, nullable=False, server_default=func.now(), onupdate=func.now())
