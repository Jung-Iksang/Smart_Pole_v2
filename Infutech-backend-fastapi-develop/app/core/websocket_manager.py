from fastapi import WebSocket


class ConnectionManager:
    def __init__(self):
        # device_id -> set of WebSocket connections
        self.active_connections: dict[int, set[WebSocket]] = {}

    async def connect(self, device_id: int, websocket: WebSocket):
        await websocket.accept()
        if device_id not in self.active_connections:
            self.active_connections[device_id] = set()
        self.active_connections[device_id].add(websocket)

    def disconnect(self, device_id: int, websocket: WebSocket):
        if device_id in self.active_connections:
            self.active_connections[device_id].discard(websocket)
            if not self.active_connections[device_id]:
                del self.active_connections[device_id]

    async def broadcast_to_device(self, device_id: int, data: dict):
        connections = self.active_connections.get(device_id, set())
        dead = []
        for ws in connections:
            try:
                await ws.send_json(data)
            except Exception:
                dead.append(ws)
        for ws in dead:
            connections.discard(ws)


# 싱글톤 인스턴스
manager = ConnectionManager()
