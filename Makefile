BIN_NAME=firmware.bin

INIT = libinit.a

all: ${INIT}
	zig build

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

flash:
	wchisp flash zig-out/${BIN_NAME}
	#wch-isp -pr flash zig-out/${BIN_NAME}

clean:
	rm -r zig-out zig-cache
