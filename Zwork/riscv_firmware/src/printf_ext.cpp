#include "printf.h"
#include "FpgaConfig.h"
#include <cstdint>

void _putchar(char character) {
	g_Uart.Put(character);
}
