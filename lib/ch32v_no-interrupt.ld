/* CH32V103R8T6
    CH32V103C8T6 and CH32V103C8T6 have the same memory map.
*/

/* 1K = 1 KiBi = 1024 bytes */
MEMORY
{
  /*
  CH32V203C8T6
    Code Flash, 64KB max
    SRAM, 20KB max
  */
	FLASH (rx): ORIGIN = 0x0800 * 0x10000, LENGTH = 64k
	RAM (rwx) : ORIGIN = 0x2000 * 0x10000, LENGTH = 20k
}

REGION_ALIAS("REGION_TEXT", FLASH);
REGION_ALIAS("REGION_RODATA", FLASH);
REGION_ALIAS("REGION_DATA", RAM);
REGION_ALIAS("REGION_BSS", RAM);
REGION_ALIAS("REGION_HEAP", RAM);
REGION_ALIAS("REGION_STACK", RAM);

_stack_start = ORIGIN(REGION_STACK) + LENGTH(REGION_STACK);
_heap_size = 0;

_data_length = SIZEOF(.data);

SECTIONS
{
  .text :
  {
    /* Put reset handler first in .text section and has default entry point */
    KEEP(*(.init));

    *(.text .text.*);
  } > REGION_TEXT

  .rodata : ALIGN(4)
  {
    *(.srodata .srodata.*);
    *(.rodata .rodata.*);

    /* make sure the end of section is aligned by 4 bytes. */
    . = ALIGN(4);
  } > REGION_RODATA

  .data : ALIGN(4)
  {
    _sdata_lma = LOADADDR(.data);
    _sdata = .;
    /* global_pointer can access GP +/-2048(0x800) */
    __global_pointer$ = . + 0x800;
    *(.sdata .sdata.*);
    *(.data .data.*);
    /* make sure the end of section is aligned by 4 bytes. */
    . = ALIGN(4);
    _edata = .;
    _edata_lma = _sdata_lma + _edata - _sdata;
  } > REGION_DATA AT > REGION_RODATA

  .bss (NOLOAD) :
  {
    _sbss = .;
    *(.sbss .sbss.*);
    *(.bss .bss.*);
    /* make sure the end of section is aligned by 4 bytes. */
    . = ALIGN(4);
    _ebss = .;
  } > REGION_BSS

  .heap (NOLOAD) :
  {
    . += _heap_size;
    . = ALIGN(4);
  } > REGION_HEAP

  .stack (NOLOAD) :
  {
    . = ABSOLUTE(_stack_start);
  } > REGION_STACK
}

ASSERT((_ebss - _sdata) < 4096, "ERROR(linker): Too many global variables. The total length of data and bss must less than 4096.");
