# Washing Machine Controller — SystemVerilog FSM

A synthesizable **SystemVerilog Moore finite-state-machine (FSM)** for a coin-operated washing machine.  
The project includes a self-checking testbench and a GitHub Actions workflow that automatically compiles and runs the simulation.

## Features

- Three selectable wash modes: **SHORT, MEDIUM, LONG**
- Moore FSM control of the complete wash sequence
- Timed phases:
  - `SOAK`
  - `WASH`
  - `DRAIN`
  - `RINSE`
  - `SPIN`
- Cancellation handling:
  - Cancellation during `READY` or `SOAK` returns to `IDLE` and generates a one-clock `refund_coin` pulse.
  - Cancellation after the paid cycle starts does **not** refund the coin.
  - If cancellation occurs during `WASH`, `RINSE`, or `SPIN`, the machine drains before returning to `IDLE`.
- Mode-dependent phase durations
- Door lock while the machine is in an active phase
- Separate motor modes for washing and spinning
- Self-checking SystemVerilog testbench
- GitHub Actions CI using Icarus Verilog

## FSM

```text
                         coin_inserted
                              |
                              v
                           +-------+
                           | IDLE  |
                           +---+---+
                               |
                               v
                           +-------+
                           | READY |
                           +---+---+
                               |
                               v
                           +-------+
                           | SOAK  |
                           +---+---+
                               |
                               v
                           +-------+
                           | WASH  |
                           +---+---+
                               |
                               v
                           +-------+
                           | DRAIN |
                           +---+---+
                               |
                               v
                           +-------+
                           | RINSE |
                           +---+---+
                               |
                               v
                           +-------+
                           | SPIN  |
                           +---+---+
                               |
                               v
                           +-------+
                           | DONE  |
                           +-------+
```

### Cancellation behavior

```text
READY / SOAK
    |
 cancel
    v
  IDLE + refund_coin pulse

WASH / RINSE / SPIN
    |
 cancel
    v
  DRAIN
    |
    v
  IDLE
```

## Wash-mode timings

The durations below are measured in clock cycles.

| Phase | SHORT | MEDIUM | LONG |
|---|---:|---:|---:|
| SOAK | 3 | 6 | 9 |
| WASH | 6 | 12 | 18 |
| DRAIN | 1 | 3 | 4 |
| RINSE | 3 | 6 | 9 |
| SPIN | 2 | 3 | 5 |

These intentionally small values make simulation fast while preserving the same control structure that can be scaled for hardware.

## Module interface

### Inputs

| Signal | Width | Description |
|---|---:|---|
| `clk` | 1 | System clock |
| `rst_n` | 1 | Active-low asynchronous reset |
| `coin_inserted` | 1 | Starts a new cycle |
| `cancel` | 1 | Requests cancellation |
| `mode_select` | 2 | `00=SHORT`, `01=MEDIUM`, `10=LONG` |

### Outputs

| Signal | Width | Description |
|---|---:|---|
| `water_inlet` | 1 | Opens water inlet |
| `water_outlet` | 1 | Opens drain outlet |
| `motor_enable` | 1 | Enables motor |
| `motor_mode` | 1 | `0=wash`, `1=spin` |
| `detergent_release` | 1 | Releases detergent |
| `door_lock` | 1 | Locks the door |
| `refund_coin` | 1 | One-clock refund pulse |
| `busy` | 1 | Machine is processing a cycle |
| `done` | 1 | Cycle completed |

## Repository structure

```text
washing-machine-controller/
├── .github/
│   └── workflows/
│       └── simulation.yml
├── src/
│   └── washing_machine_controller.sv
├── tb/
│   └── washing_machine_tb.sv
├── .gitignore
├── LICENSE
├── Makefile
└── README.md
```

## Run locally

### Option 1 — Make

Install Icarus Verilog, then run:

```bash
make test
```

Clean simulation artifacts:

```bash
make clean
```

### Option 2 — Direct commands

```bash
mkdir -p build
iverilog -g2012 -Wall -o build/washing_machine.vvp     src/washing_machine_controller.sv     tb/washing_machine_tb.sv

vvp build/washing_machine.vvp
```

A successful simulation ends with:

```text
All washing-machine tests passed.
```

## Testbench coverage

The included testbench verifies:

1. Reset places the FSM in `IDLE`.
2. SHORT mode completes successfully.
3. MEDIUM mode completes successfully.
4. LONG mode completes successfully.
5. Cancellation during `SOAK` returns to `IDLE` and refunds the coin.
6. Cancellation during `WASH` does not refund the coin and forces a drain before returning to `IDLE`.

The testbench is intentionally self-checking: failures terminate simulation with `$fatal`.

## CI

Every push and pull request runs the simulation automatically through:

```text
.github/workflows/simulation.yml
```

The workflow installs Icarus Verilog, compiles the RTL and testbench, and runs the resulting simulation.

## Design notes

### Moore FSM

The actuator outputs depend only on the current FSM state. This keeps the control behavior easy to reason about and avoids direct combinational dependence of actuator outputs on external inputs.

### Mode capture

The selected mode is captured while the controller is in `READY`. After that point, the cycle uses the stored mode even if `mode_select` changes.

### Cancellation safety

Once washing has started, cancellation does not immediately return the machine to `IDLE`. The controller first enters `DRAIN`, allowing water to be removed safely.

## License

MIT License. See [LICENSE](LICENSE).
