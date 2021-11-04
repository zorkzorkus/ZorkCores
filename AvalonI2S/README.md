# AvalonI2S

Avalon Memory Mapped Slave generating I2S (Sound) signals.  
For an output quickstart, provide approximately 12.5 MHz for **i2s_mclk**, write 0x10 to the **status** register and then write I2S data to the **data** register.

### Files

| File | Description |
| - | - |
| AvalonI2S_vhd | VHDL implementation of the core |
| AvalonI2S_hw.tcl | Quartus Platform Designer component file |
| AvalonI2S.h | C header file for the firmware |
| AvalonI2S.c | C source file for the firmware (currently unused) |

### Generics

| Name | Description |
| - | - |
| BUFFER_BITLENGTH | Number of bits for the length of the FIFOs. The maximum number of elements is 2^LENGTH - 1.

### Port Map

| Port Signal | Description |
| - | - |
| clk_sys | System Clock |
| clk_i2s | I2S Clock |
| resetn | Reset (Active Low) |
| | |
| i2s_mclk | Master Clock (for example Cirrus CS5343) |
| i2s_wclk | Word (LR) Clock |
| i2s_sclk | Serial / Data Clock |
| i2s_dato | Line Out Data |
| i2s_dati | Line In Data |

Core was developed for the [Pmod I2S2](https://digilent.com/reference/pmod/pmodi2s2/start) (Cirrus CS4344 & CS5343). The Cirrus ICs use a master clock to keep everything synchronized, but can also use the clock to generate the data clock itself.  
The core uses a master to data clock ratio of 8:1. The expected clock rate is approximately 12.28 MHz for the master clock, the generated data clock then is 1.535 MHz. The core uses 16 bit words per channel, as such the word clock is at approximately 48 KHz.  
Summarizing the clock ratios are:  
* 256 (mclk) : 32 (sclk) : 1 (wclk)

The system clock domain is used to communicate with the avalon master. Two FIFOs are used to cross clock domains, the read and write pointers use a double synchronizer flip-flop for the target domain.

### Register Map

| Offset | Symbol | Description | RW |
| - | - | - | - |
| 0x00 | status | Control and status register | RW |
| | irq_out_en (1)| Enables the interrupt for output | RW
| | irq_out (2) | Asserted when out_occupancy <= out_mark | R
| | irq_in_en (4) | Enables the interrupt for input | RW
| | irq_in (8) | Asserted when in_occupancy >= in_mark | R
| | enable (10) | Enables or disables generation of I2S signals| RW
| 0x04 | out_occupancy | Number of words in the out-FIFO | R
| 0x08 | in_occupancy | Number of words in the in-FIFO | R
| 0x0C | out_mark| Interrupt mark for output. | RW
| 0x10 | in_mark| Interrupt mark for input | RW
| 0x14 | length | Maximum number of elements in the FIFO | R
| 0x18 | sampleswritten | Number of words written to the out-FIFO | R
| 0x1C | data | Writing puts the 32 bit word into to out-FIFO. Reading retrieves a word from the in-FIFO. If either FIFO cannot service the request, the core stalls | O:W, I:R

The core will only process data and generate signals when the **enable** bit (#4) in **status** is set. When **out_occupancy** is less than or equal to **out_mark**, the **irq_out** bit (#1) is asserted in **status**. Similary the **irq_in** bit (#3) is set when **in_occupancy** is greater then or equal to **in_mark**. If the correspoding input or output interrupt enable bit (#0, #2) is also set, the interrupt signal to the avalon master is asserted.

I like tables.
