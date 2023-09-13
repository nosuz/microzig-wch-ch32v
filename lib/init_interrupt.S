# define STORE    sw
# define LOAD     lw
# define LOG_REGBYTES 2
#define REGBYTES (1 << LOG_REGBYTES)

/* default entry point */

.section .init, "ax"
.global _start

_start:
    // CH32V103 starts from 0x800_0004 but CH32V203 starts from 0x800_0000.
    nop
    nop
    /*
    Program codes are written from 0x800_0000.
    The PC pointer after reset is 0 and reads codes from alias of flash memory.
    This is not expected PC pointer on init.S. Thus jump to _abs_start is mandatory.
    */
    lui ra, %hi(_abs_start)
    jr %lo(_abs_start)(ra)

_abs_start:
    /* interrupts must be disabled by default
    csrw mie, 0 // interrupt disable
    csrw mip, 0 // no pending interrupts
    */

    // set interrupts trap vec.
    la      t0, _start_trap
    csrw    mtvec, t0

    // set global pointer
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    // set stack pointer
    la sp, _stack_start

/*
copy_data_section:
    // copy data section to RAM
    la a0, _sdata_lma
    la a1, _sdata
    lw a2, _data_length
    beqz a2, copy_data_done

copy_data_loop:
    // copy data
    lw t0, 0(a0)
    sw t0, 0(a1)

    addi a0, a0, 4
    addi a1, a1, 4

    addi a2, a2, -4
    bnez a2, copy_data_loop
copy_data_done:
*/
copy_data_section:
    // copy data section to RAM
    la a0, _sdata_lma
    la a1, _sdata
    la a2, _edata_lma
    beq a0, a2, copy_data_done

copy_data_loop:
    lw t0, 0(a0)
    sw t0, 0(a1)

    addi a0, a0, 4
    addi a1, a1, 4
    bne a0, a2, copy_data_loop
copy_data_done:

/*
  C: un-initialize variables are filled with 0.
  Zig: all variables must be initialized.

clear_bss_section:
    # clear data and bss section
    li t0, 0
    la t1, _sbss
    la t2, _ebss
    beq t1, t2, clear_bss_done
clear_bss_loop:
    sw t0, 0(t1)
    addi t1, t1, 4
    bne t1, t2, clear_bss_loop
clear_bss_done:
*/

    // Set frame pointer
    add s0, sp, zero
    jal zero, microzig_main

/*
default interrupts handler
this instruction is removed if defined interrupts_handler in other part.
*/
.section .trap.handler, "ax"
.weak interrupts_handler
interrupts_handler:
    ret

// trap interrupts
.section .trap, "ax"
.global _start_trap

_start_trap:
    addi sp, sp, -16*REGBYTES

    STORE ra, 0*REGBYTES(sp)
    STORE t0, 1*REGBYTES(sp)
    STORE t1, 2*REGBYTES(sp)
    STORE t2, 3*REGBYTES(sp)
    STORE t3, 4*REGBYTES(sp)
    STORE t4, 5*REGBYTES(sp)
    STORE t5, 6*REGBYTES(sp)
    STORE t6, 7*REGBYTES(sp)
    STORE a0, 8*REGBYTES(sp)
    STORE a1, 9*REGBYTES(sp)
    STORE a2, 10*REGBYTES(sp)
    STORE a3, 11*REGBYTES(sp)
    STORE a4, 12*REGBYTES(sp)
    STORE a5, 13*REGBYTES(sp)
    STORE a6, 14*REGBYTES(sp)
    STORE a7, 15*REGBYTES(sp)

    // set sp vale to a0 or the 1st. arg.
    // add a0, sp, zero
    // interrupts_handler(sp, mcause, mepc);
    // csrr a1, mcause
    // csrr a2, mepc
    // interrupts_handler(mcause: u32);
    csrr a0, mcause
    jal ra, interrupts_handler

    LOAD ra, 0*REGBYTES(sp)
    LOAD t0, 1*REGBYTES(sp)
    LOAD t1, 2*REGBYTES(sp)
    LOAD t2, 3*REGBYTES(sp)
    LOAD t3, 4*REGBYTES(sp)
    LOAD t4, 5*REGBYTES(sp)
    LOAD t5, 6*REGBYTES(sp)
    LOAD t6, 7*REGBYTES(sp)
    LOAD a0, 8*REGBYTES(sp)
    LOAD a1, 9*REGBYTES(sp)
    LOAD a2, 10*REGBYTES(sp)
    LOAD a3, 11*REGBYTES(sp)
    LOAD a4, 12*REGBYTES(sp)
    LOAD a5, 13*REGBYTES(sp)
    LOAD a6, 14*REGBYTES(sp)
    LOAD a7, 15*REGBYTES(sp)

    addi sp, sp, 16*REGBYTES
    mret
