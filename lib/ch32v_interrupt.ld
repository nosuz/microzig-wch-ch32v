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
	PMA (rwx) : ORIGIN = 0x40006000, LENGTH = 512
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

  .data1 :
  {
    microzig_data1_load_start = LOADADDR(.data1);
    microzig_data1_start = .;
    *(.pma);
    *(.packet_buffer);
    /* make sure the end of section is aligned by 4 bytes. */
    . = ALIGN(4);
    microzig_data1_end = .;
  } > REGION_PMA AT > REGION_ROPMA
}

ASSERT((microzig_bss_end - microzig_data_start) < 4096, "ERROR(linker): Too many global variables. The total length of data and bss should be less than 4096.");

ASSERT((microzig_data1_end - microzig_data1_start) < 512, "ERROR(linker): Too many variables in packet buffer memory SRAM. The SRAM area should be less than 512.");