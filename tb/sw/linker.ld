/* linker.ld */
OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
  /* core currently has 1K of RAM */
  ram (rwx) : ORIGIN = 0x00000000, LENGTH = 1K
}

SECTIONS
{
  .text :
  {
    *(.text)
  } > ram
}
