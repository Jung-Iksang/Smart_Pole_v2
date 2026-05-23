from __future__ import annotations

import logging
from functools import lru_cache

from app.core.config import get_settings

logger = logging.getLogger(__name__)

_firebase_initialized = False


def _init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return

    settings = get_settings()
    if not settings.FCM_CREDENTIALS_PATH:
        logger.warning("FCM_CREDENTIALS_PATH not set, push notifications disabled")
        return

    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(settings.FCM_CREDENTIALS_PATH)
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("Firebase Admin initialized")
    except Exception as e:
        logger.error(f"Firebase init failed: {e}")


async def send_push_notification(fcm_token: str, title: str, body: str, data: dict | None = None):
    if not _firebase_initialized:
        _init_firebase()
        if not _firebase_initialized:
            logger.warning("Firebase not initialized, skipping push notification")
            return

    try:
        from firebase_admin import messaging
        import asyncio

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            token=fcm_token,
        )

        # firebase-admin은 동기 라이브러리이므로 스레드풀에서 실행
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, messaging.send, message)
        logger.info(f"Push notification sent: {title}")
    except Exception as e:
        logger.error(f"Failed to send push notification: {e}")
