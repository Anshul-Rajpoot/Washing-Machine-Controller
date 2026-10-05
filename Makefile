SIM ?= iverilog
VVP ?= vvp
BUILD_DIR := build
TARGET := $(BUILD_DIR)/washing_machine.vvp
SOURCES := src/washing_machine_controller.sv tb/washing_machine_tb.sv

.PHONY: all test clean

all: test

test: $(TARGET)
	$(VVP) $(TARGET)

$(TARGET): $(SOURCES)
	mkdir -p $(BUILD_DIR)
	$(SIM) -g2012 -Wall -o $(TARGET) $(SOURCES)

clean:
	rm -rf $(BUILD_DIR)
