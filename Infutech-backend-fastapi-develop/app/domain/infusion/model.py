from sqlalchemy import Column, BigInteger, String, Numeric, DateTime, ForeignKey
from sqlalchemy.sql import func
from app.database import Base


class DripSession(Base):
    __tablename__ = "drip_sessions"

    session_id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    patient_id = Column(BigInteger, ForeignKey("patients.patient_id"), nullable=False)
    device_id = Column(BigInteger, ForeignKey("devices.device_id"), nullable=False)
    status = Column(String(20), nullable=False, default="running")  # running / completed / stopped
    fluid_name = Column(String(200), nullable=True)       # 수액 약품명 (선택)
    total_ml = Column(Numeric(10, 2), nullable=True)     # 수액 총량 mL
    initial_weight_g = Column(Numeric(10, 2), nullable=True)  # 세션 첫 측정 무게 (g)
    tare_weight_g = Column(Numeric(10, 2), nullable=True)     # 팩 무게 = initial - total_ml
    started_at = Column(DateTime, nullable=False, server_default=func.now())
    ended_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, nullable=False, server_default=func.now())


class SensorLog(Base):
    __tablename__ = "sensor_logs"

    log_id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    session_id = Column(BigInteger, ForeignKey("drip_sessions.session_id"), nullable=False)
    device_id = Column(BigInteger, ForeignKey("devices.device_id"), nullable=False)
    measured_weight_g = Column(Numeric(10, 2), nullable=True)
    remaining_ml = Column(Numeric(10, 2), nullable=False)
    drop_rate = Column(Numeric(10, 2), nullable=False)
    infusion_status = Column(String(20), nullable=False)
    measured_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, nullable=False, server_default=func.now())
