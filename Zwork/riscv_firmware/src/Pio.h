#pragma once

#include <cstdint>

class Pio {

public:

	Pio(uintptr_t address);

	void Set(uint32_t value);
	uint32_t Get();
	void SetMask(uint32_t mask);
	void ClearMask(uint32_t mask);

	void SetDirection(uint32_t value);
	uint32_t GetDirection();

private:

	struct Register {
		uint32_t port;
		uint32_t direction;
		uint32_t interruptmask;
		uint32_t edgecapture;
		uint32_t outset;
		uint32_t outclear;
	};

	volatile Register* m_Register;

};
