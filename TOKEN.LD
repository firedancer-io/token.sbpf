PHDRS
{
  text    PT_LOAD    ;
  data    PT_LOAD    ;
  dynamic PT_DYNAMIC ;
}

SECTIONS
{
  . = SIZEOF_HEADERS;
  .text    : { *(.text*)   } : text
  .rodata  : { *(.rodata*) } : text
  .dynamic : { *(.dynamic) } : dynamic
  .dynstr  : { *(.dynstr)  } : data
  .dynsym  : { *(.dynsym)  } : data
  /DISCARD/ : {
    *(.eh_frame*)
    *(.gnu.hash*)
    *(.hash*)
    *(.comment)
    *(.symtab)
    *(.strtab)
  }
}

ENTRY (entrypoint)
