BIN_NAME=firmware.bin

INIT = libinit.a

all: ${INIT}
	zig build -Doptimize=ReleaseSmall

init:
	zig build-lib -target riscv32-freestanding -mcpu=baseline_rv32-d \
	--name init lib/init_interrupt.S && \
	cp lib/ch32v_interrupt.ld ./ch32v.ld

init_no-int:
	zig build-lib -target riscv32-freestanding -mcpu=baseline_rv32-d \
	--name init lib/init_no-interrupt.S && \
	cp lib/ch32v_no-interrupt.ld ./ch32v.ld

blinky: all
	riscv64-unknown-elf-objcopy -O binary zig-out/bin/blinky zig-out/${BIN_NAME} && \
	riscv64-unknown-elf-objdump --disassemble-all zig-out/bin/blinky > zig-out/blinky.s

blinky2: all
	riscv64-unknown-elf-objcopy -O binary zig-out/bin/blinky2 zig-out/${BIN_NAME} && \
	riscv64-unknown-elf-objdump --disassemble-all zig-out/bin/blinky2 > zig-out/blinky2.s

blinky_sleep: all
	riscv64-unknown-elf-objcopy -O binary zig-out/bin/blinky_sleep zig-out/${BIN_NAME} && \
	riscv64-unknown-elf-objdump --disassemble-all zig-out/bin/blinky_sleep > zig-out/blinky_sleep.s

blinky_clocks: all
	riscv64-unknown-elf-objcopy -O binary zig-out/bin/blinky_clocks zig-out/${BIN_NAME} && \
	riscv64-unknown-elf-objdump --disassemble-all zig-out/bin/blinky_clocks > zig-out/blinky_clocks.s

serial: all
	riscv64-unknown-elf-objcopy -O binary zig-out/bin/serial zig-out/${BIN_NAME} && \
	riscv64-unknown-elf-objdump --disassemble-all zig-out/bin/serial > zig-out/serial.s

serial_log: all
	riscv64-unknown-elf-objcopy -O binary zig-out/bin/serial_log zig-out/${BIN_NAME} && \
	riscv64-unknown-elf-objdump --disassemble-all zig-out/bin/serial_log > zig-out/serial_log.s

timer_interrupt: all
	riscv64-unknown-elf-objcopy -O binary zig-out/bin/timer_interrupt zig-out/${BIN_NAME} && \
	riscv64-unknown-elf-objdump --disassemble-all zig-out/bin/timer_interrupt > zig-out/timer_interrupt.s

ring_buffer: all
	riscv64-unknown-elf-objcopy -O binary zig-out/bin/ring_buffer zig-out/${BIN_NAME} && \
	riscv64-unknown-elf-objdump --disassemble-all zig-out/bin/ring_buffer > zig-out/ring_buffer.s

flash:
	#wchisp flash zig-out/${BIN_NAME}
	wch-isp -pr flash zig-out/${BIN_NAME}

clean:
	rm -r zig-out zig-cache
