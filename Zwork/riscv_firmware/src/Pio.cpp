#include "Pio.h"

Pio::Pio(uintptr_t address) : m_Register((volatile Register*)address) {

}

void Pio::Set(uint32_t value) {
	m_Register->port = value;
}

uint32_t Pio::Get() {
	return m_Register->port;
}

void Pio::SetMask(uint32_t mask) {
	m_Register->outset = mask;
}

void Pio::ClearMask(uint32_t mask) {
	m_Register->outclear = mask;
}

void Pio::SetDirection(uint32_t value) {
	m_Register->direction = value;
}

uint32_t Pio::GetDirection() {
	return m_Register->direction;
}
