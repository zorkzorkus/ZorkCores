#ifndef UART_H
#define UART_H

#include <cstdint>
#include <cstdbool>

class Uart {

public:

	Uart(uintptr_t address);
	uint8_t Get();
	void Put(uint8_t c);
	bool TryGet(uint8_t& get);

private:

	struct Register {
		uint32_t rxdata;
		uint32_t txdata;
		uint32_t status;
		uint32_t control;
		uint32_t divisor;
		uint32_t eop;
	};

	volatile Register*  m_Register;

};

#endif
