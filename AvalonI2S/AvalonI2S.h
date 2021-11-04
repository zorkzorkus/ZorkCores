#ifndef AVALONI2S_H
#define AVALONI2S_H

#include "stdint.h"

typedef volatile struct I2S_t {
	union {
		struct {
			uint32_t irq_out_en : 1;
			uint32_t irq_out : 1;
			uint32_t irq_in_en : 1;
			uint32_t irq_in : 1;
			uint32_t enable : 1;
		};
		uint32_t status;
	};
	uint32_t out_occupancy;
	uint32_t in_occupancy;
	uint32_t out_mark;
	uint32_t in_mark;
	uint32_t length;
	uint32_t sampleswritten;
	uint32_t data;
} I2S;

#endif
