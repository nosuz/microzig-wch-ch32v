/* 1K = 1 KiBi = 1024 bytes */
MEMORY
{
  /*
  CH32V203x8xx
    Code Flash, 64KB max
    SRAM, 20KB max
  */
	FLASH (rx): ORIGIN = 0x0800 * 0x10000, LENGTH = 64k
	RAM (rwx) : ORIGIN = 0x2000 * 0x10000, LENGTH = 20k
	PMA (rw) : ORIGIN = 0x40006000, LENGTH = 1024 /* valid area is 512 byes */
}

ENTRY(_start);

REGION_ALIAS("REGION_TEXT", FLASH);
REGION_ALIAS("REGION_RODATA", FLASH);
REGION_ALIAS("REGION_DATA", RAM);
REGION_ALIAS("REGION_BSS", RAM);
REGION_ALIAS("REGION_STACK", RAM);
REGION_ALIAS("REGION_ROPMA", FLASH);
REGION_ALIAS("REGION_PMA", PMA);

_stack_start = ORIGIN(REGION_STACK) + LENGTH(REGION_STACK);

SECTIONS
{
  .text :
  {
    /* Put reset handler first in .text section and has default entry point */
    KEEP(*(.init));

    *(.text*);

    /*
    CH32V203 don't need to be aligned on 1024.
    . = ALIGN(4);
    */
    . = ALIGN(1024);
    *(.trap*);
  } > REGION_TEXT

  .rodata : ALIGN(4)
  {
    *(.rodata*);

    /* make sure the end of section is aligned by 4 bytes. */
    . = ALIGN(4);
  } > REGION_RODATA

  .data : ALIGN(4)
  {
    microzig_data_load_start = LOADADDR(.data);
    microzig_data_start = .;
    /* global_pointer can access GP +/-2048(0x800) */
    __global_pointer$ = . + 0x800;
    *(.sdata .sdata.*);
    *(.data .data.*);
    /* make sure the end of section is aligned by 4 bytes. */
    . = ALIGN(4);
    microzig_data_end = .;
  } > REGION_DATA AT > REGION_RODATA

  .bss (NOLOAD) :
  {
    microzig_bss_start = .;
    *(.sbss .sbss.*);
    *(.bss .bss.*);
    /* make sure the end of section is aligned by 4 bytes. */
    . = ALIGN(4);
    microzig_bss_end = .;
  } > REGION_BSS

  .stack (NOLOAD) :
  {
    . = ABSOLUTE(_stack_start);
  } > REGION_STACK

  .pma :
  {
    microzig_pma_load_start = LOADADDR(.pma);
    microzig_pma_start = .;
    *(.pma);
    *(.packet_buffer);
    /* make sure the end of section is aligned by 4 bytes. */
    . = ALIGN(4);
    microzig_pma_end = .;
  } > REGION_PMA AT > REGION_ROPMA
}

ASSERT((microzig_bss_end - microzig_data_start) < 4096, "ERROR(linker): Too many global variables. The total length of data and bss should be less than 4096.");

ASSERT((microzig_pma_end - microzig_pma_start) < 1024, "ERROR(linker): Too many variables in packet buffer memory SRAM. The SRAM area should be less than 1024.");
