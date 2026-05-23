from sqlalchemy import Column, BigInteger, String, DateTime, ForeignKey
from sqlalchemy.sql import func
from app.database import Base


class Guardian(Base):
    __tablename__ = "patient_guardians"

    guardian_id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    patient_id = Column(BigInteger, ForeignKey("patients.patient_id"), unique=True, nullable=False)
    guardian_name = Column(String(100), nullable=False)
    guardian_phone = Column(String(20), nullable=False)
    relationship = Column(String(50), nullable=False)
    created_at = Column(DateTime, nullable=False, server_default=func.now())
    updated_at = Column(DateTime, nullable=False, server_default=func.now(), onupdate=func.now())
