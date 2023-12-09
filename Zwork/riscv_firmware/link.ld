OUTPUT_FORMAT("elf32-littleriscv", "elf32-littleriscv", "elf32-littleriscv")
OUTPUT_ARCH( "riscv" )

MEMORY
{
	RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 24K /* 32 KiB */
}

ENTRY(_start);

SECTIONS
{

	.init : {
		. = 0x00;
		KEEP(*(.init))
		*(.init)
		. = ALIGN(4);
	}

	.init_array : {
		__init_begin__ = .;
		/*KEEP(*(SORT_BY_INIT_PRIORITY( .init_array.* )));*/
		KEEP(*(.init_array))
		__init_end__ = .;
		. = ALIGN(4);
	}

	.text : {
		*(.text*)
		. = ALIGN(4);
	}

	.rodata : {
		*(.rodata*)
		*(.srodata.*)
		. = ALIGN(4);
	}

	__data_vma_begin__ = .;
	.datavma : {
		/* Force 4 bytes into this section. TODO: Figure out how to handle if the section does not exist*/
		LONG(0)
		*(.data*)
		*(.sdata*)
		. = ALIGN(4);
	}
	__data_vma_end__ = .;

	__data_lma_begin__ = .;
	.datalma : {
		/* Fill this section with bogus values and use objcopy later to copy the content of the datavma section. This section will always have a minimun of 4 bytes, even if datavma is empty */
		LONG(0x00000000);
		. += __data_vma_end__ - __data_vma_begin__;
		. = ALIGN(4);
	}
	__data_lma_end__ = .;

	__bss_begin__ = .;
	.bss : {
		*(.bss*)
		*(.sbss*)
		. = ALIGN(4);
	}
	__bss_end__ = .;

	. = ORIGIN(RAM) + LENGTH(RAM);

	__sp = . - 4;

}
