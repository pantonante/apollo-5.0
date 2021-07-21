#!/usr/bin/env python3

import psutil
from time import sleep
from enum import Enum
import requests
import json
import argparse
import getpass
import sys


CYBER_RECORDER = "cyber_recorder"
WISE_ENDPOINT_LOGIN = "https://wise.svlsimulator.com/api/v1/auth/login"
WISE_ENDPOINT_RUNNING = "https://wise.svlsimulator.com/api/v1/simulations/running"
MAX_ATTEMPTS = 10


class Password:
    DEFAULT = 'Prompt if not specified'
    def __init__(self, value):
        if value == self.DEFAULT:
            value = getpass.getpass('Password: ')
        self.value = value

    def __str__(self):
        return self.value


class State(Enum):
    IDLE = 1
    WAIT = 2
    RUNNING = 3
    STOPPING = 4


# class SimulatorStatus(Enum):
#     IDLE = 1
#     STARTING = 2
#     STOPPING = 3
#     RUNNING = 4


class Actions(Enum):
    NONE = 1
    STOP = 2

def state_description(state:State):
    if state == State.IDLE:
        return "Idle...    "
    elif state == State.WAIT:
        return "Waiting... "
    elif state == State.RUNNING:
        return "Running... "
    elif state == State.STOPPING:
        return "Stopping..."
    else:
        raise RuntimeError("Corrupted state")

def kill_process(process_name:str):
    for proc in psutil.process_iter():
        # Check if process name contains the given name string.
        if process_name.lower() in proc.name.lower():
            proc.kill()
            break
    
def is_process_running(process_name: str):
    """
    Check if there is any running process that contains the given name processName.
    """
    # Iterate over the all the running process
    for proc in psutil.process_iter():
        # Check if process name contains the given name string.
        if process_name.lower() in proc.name.lower():
            return True
    return False


def get_simulator_status(session: requests.Session):
    response = session.get(WISE_ENDPOINT_RUNNING)
    json_data = json.loads(response.text)
    if json_data:
        return True
    else:
        return False


def init_state(session: requests.Session):
    return State.IDLE


def state_update(state: State, session: requests.Session):
    rec = is_process_running(CYBER_RECORDER)
    sim = get_simulator_status(session)
    if state == State.IDLE:
        if sim or rec:
            return State.WAIT, Actions.NONE
    elif state == State.WAIT:
        if sim and rec:
            return State.RUNNING, Actions.NONE
        elif not (sim or rec):
            return State.IDLE, Actions.NONE
    elif state == State.RUNNING:
        if sim and rec:
            return State.RUNNING, Actions.NONE
        elif sim and not rec:
            print("Warning: the recorder stopped during the simulation")
            return State.WAIT, Actions.NONE
        elif not sim and rec:
            return State.STOPPING, Actions.STOP
        elif not sim and not rec:
            return State.IDLE, Actions.NONE
    elif state == State.STOPPING:
        if not sim and not rec:
            return State.IDLE, Actions.NONE
        else:
            return state.STOPPING, Actions.STOP
    else:
        raise RuntimeError("Corrupted state.")
    return state, Actions.NONE


def perform_action(action: Actions):
    if action == Actions.STOP:
        print("Stopping cyber recoder")
        for _ in range(MAX_ATTEMPTS):
            kill_process(CYBER_RECORDER)
            sleep(0.2)
            rec = is_process_running(CYBER_RECORDER)
            if not rec:
                return
        raise RuntimeError("Could not stop the recorder.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="An utility to monitor the state of the LG-SVL simulator and stop the cyber recorder.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument('-u', '--username', type=str, help='LG-SVL username', required=True)
    parser.add_argument('-p', '--password', type=Password, help="LG-SVL password", default=Password.DEFAULT)
    args = parser.parse_args()

    # Login
    payload = {"email": args.username, "password": args.password}
    session = requests.Session()
    response = session.post(WISE_ENDPOINT_LOGIN, data=payload)
    if response.status_code != 200:
        print("Error loggin into LGSVL cloud (WISE)")
        exit(1)
    print("Successfully logged in")

    # Main Loop
    state = init_state(session)
    while True:
        print(state_description(state), end='\r')
        sys.stdout.flush()
        state, action = state_update(state, session=session)
        perform_action(action)
        sleep(1)
