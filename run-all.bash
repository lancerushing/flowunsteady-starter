#!/bin/bash

FIDELITY=$1

time make run-step-1 FIDELITY=${FIDELITY}
time make run-step-2 FIDELITY=${FIDELITY}
time make run-step-3 FIDELITY=${FIDELITY}
time make run-step-4 FIDELITY=${FIDELITY}
