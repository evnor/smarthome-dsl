from http.server import BaseHTTPRequestHandler, HTTPServer
from dataclasses import dataclass
from abc import ABC, abstractmethod
from enum import IntEnum
from typing import Generic, TypeVar
import requests
import json
import xmltodict

hostName = "localhost"
serverPort = 8080

class CarEvent(IntEnum):
    CAR_IN = 0
    CAR_OUT = 1
class SignalEvent(IntEnum):
    LED_GREEN = 0
    LED_RED = 1


T = TypeVar("T")
class Port(Generic[T], ABC):
    name: str
    data: T
    @abstractmethod
    def send(self): ...

class ParkingControllerFROM_BARRIER(Port[CarEvent]):
    name = "FROM_BARRIER"
    data: CarEvent
    def __init__(self, data: CarEvent):
        self.data = data
    def send(self):
        ...

class ParkingControllerTO_SIGNAL(Port[SignalEvent]):
    name = "TO_SIGNAL"
    data: SignalEvent
    def __init__(self, data: SignalEvent):
        self.data = data
    def to_json(self) -> str:
        return json.dumps(self.data)
    def send(self):
        requests.post(
            "http://localhost:8081/barrier",
            data=self.to_json(),
            headers={"Content-Type": "application/json"},
        )


class State(ABC):
    @abstractmethod
    def step(self, event) -> "State": ...


@dataclass
class StateFull(State):
    total: int

    def step(self, event: Port) -> State:
        if isinstance(event, ParkingControllerFROM_BARRIER) and event.data == CarEvent.CAR_OUT:
            if True:
                ParkingControllerTO_SIGNAL(SignalEvent.LED_GREEN).send()
                return StateAvailable(self.total, 1)
        return self


@dataclass
class StateAvailable(State):
    total: int
    available: int

    def step(self, event) -> State:
        if isinstance(event, ParkingControllerFROM_BARRIER) and event.data == CarEvent.CAR_IN:
            def eval_cond(state) -> bool:
                return state.available == 1
            if eval_cond(self):
                ParkingControllerTO_SIGNAL(SignalEvent.LED_GREEN).send()
                return StateFull(self.total)
        if isinstance(event, ParkingControllerFROM_BARRIER) and event.data == CarEvent.CAR_IN:
            if True:
                return StateAvailable(self.total, self.available - 1)
        if isinstance(event, ParkingControllerFROM_BARRIER) and event.data == CarEvent.CAR_OUT:
            if True:
                return StateAvailable(self.total, min(self.available + 1, self.total))
        return self


cur_state: State = StateFull(10)
def handle_event(event: Port):
    global cur_state
    cur_state = cur_state.step(event)


class ParkingController(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == "/barrier":
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            try:
                content_type = self.headers.get("Content-Type")
                if content_type is None:
                    raise KeyError("Content-Type is None")
                if "application/json" in content_type:
                    data = json.loads(body)["IntEnumValue"]
                elif "application/xml" in content_type:
                    data = xmltodict.parse(body)["IntEnumValue"]
                elif "application/x-www-form-urlencoded" in content_type:
                    data = int(body)
                else:
                    raise ValueError(f"Unknown Content-Type {content_type}")
                data = list(CarEvent)[data]
                event = ParkingControllerFROM_BARRIER(data)
                handle_event(event)
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                global cur_state
                self.wfile.write(cur_state.__repr__().encode())

            except json.JSONDecodeError:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b"Invalid JSON")


if __name__ == "__main__":
    webServer = HTTPServer((hostName, serverPort), ParkingController)
    print("Server started http://%s:%s" % (hostName, serverPort))

    try:
        webServer.serve_forever()
    except KeyboardInterrupt:
        pass

    webServer.server_close()
    print("Server stopped.")
