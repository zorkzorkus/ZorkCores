#include "Uart.h"

/* Status register */
#define UART_PE   0x0001
#define UART_FE   0x0002
#define UART_BRK  0x0004
#define UART_ROE  0x0008
#define UART_TOE  0x0010
#define UART_TMT  0x0020
#define UART_TRDY 0x0040
#define UART_RRDY 0x0080
#define UART_E    0x0100
#define UART_BIT9 0x0200
#define UART_DCTS 0x0400
#define UART_CTS  0x0800
#define UART_EOP  0x1000

/* Control register */
#define UART_IPE  0x0001

Uart::Uart(uintptr_t address) : m_Register(reinterpret_cast<Register*>(address)) {

}

uint8_t Uart::Get() {
	while (!(m_Register->status & UART_RRDY));
	return m_Register->rxdata;

}

void Uart::Put(uint8_t c) {
	if (c == '\n') {
		while (!(m_Register->status & UART_TRDY));
		m_Register->txdata = '\r';
	}
	while (!(m_Register->status & UART_TRDY));
	m_Register->txdata = c;
}

bool Uart::TryGet(uint8_t &get) {
	if (m_Register->status & UART_RRDY) {
		get = m_Register->rxdata;
		return true;
	}
	return false;
}
