from __future__ import annotations

from abc import ABC, abstractmethod

from fastapi import WebSocket


class ConnectionRegistry(ABC):
    @abstractmethod
    def set_driver_connection(self, driver_id: int, websocket: WebSocket) -> None:
        raise NotImplementedError

    @abstractmethod
    def get_driver_connection(self, driver_id: int) -> WebSocket | None:
        raise NotImplementedError

    @abstractmethod
    def remove_driver_connection(self, driver_id: int) -> None:
        raise NotImplementedError

    @abstractmethod
    def set_client_connection(self, client_id: int, websocket: WebSocket) -> None:
        raise NotImplementedError

    @abstractmethod
    def get_client_connection(self, client_id: int) -> WebSocket | None:
        raise NotImplementedError

    @abstractmethod
    def remove_client_connection(self, client_id: int) -> None:
        raise NotImplementedError

    @abstractmethod
    def has_driver_connection(self, driver_id: int) -> bool:
        raise NotImplementedError

    @abstractmethod
    def list_client_connections(self) -> list[tuple[int, WebSocket]]:
        raise NotImplementedError


class InMemoryConnectionRegistry(ConnectionRegistry):
    # WebSocket connections stay instance-local until a pub/sub fan-out is added.
    def __init__(self) -> None:
        self._driver_connections: dict[int, WebSocket] = {}
        self._client_connections: dict[int, WebSocket] = {}

    def set_driver_connection(self, driver_id: int, websocket: WebSocket) -> None:
        self._driver_connections[driver_id] = websocket

    def get_driver_connection(self, driver_id: int) -> WebSocket | None:
        return self._driver_connections.get(driver_id)

    def remove_driver_connection(self, driver_id: int) -> None:
        self._driver_connections.pop(driver_id, None)

    def set_client_connection(self, client_id: int, websocket: WebSocket) -> None:
        self._client_connections[client_id] = websocket

    def get_client_connection(self, client_id: int) -> WebSocket | None:
        return self._client_connections.get(client_id)

    def remove_client_connection(self, client_id: int) -> None:
        self._client_connections.pop(client_id, None)

    def has_driver_connection(self, driver_id: int) -> bool:
        return driver_id in self._driver_connections

    def list_client_connections(self) -> list[tuple[int, WebSocket]]:
        return list(self._client_connections.items())


connection_registry: ConnectionRegistry = InMemoryConnectionRegistry()
