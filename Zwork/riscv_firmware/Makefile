# Zork Makefile for C++ Projects for RISC-V (On-Chip RAM only)
# Compile and link all files in "src"
# Uses all subdirectories in "src" for #include
#   (should be easy to change to "src" only or "include")

# Targets:
# default; debug
#     Create application in subfolder debug with additional flags CFLAGS_DEBUG
# release
#     Create application in subfolder release with additional flags CFLAGS_RELEASE
# clean
#    Remove intermediate directories such as .debug and .release
# distclean
#    Remove directories created by this Makefile (.debug debug .release release)
# print
#    Print variables used in this Makefile

CFLAGS :=  -static -nostartfiles -nostdlib -lgcc -lc -fno-delete-null-pointer-checks -march=rv32im -mabi=ilp32 -Wall -std=c++17 -fno-strict-aliasing -Wl,-gc-sections -Qn
CFLAGS_DEBUG := -O0 -g
CFLAGS_RELEASE := -Os
LDFLAGS := -T link.ld -Wl,--print-memory-usage
TARGET := ocram_zwonk

# |             |
# | Danger Zone |
# v             v

CC := riscv64-unknown-elf-
OBJDUMP := $(CC)objdump
OBJCOPY := $(CC)objcopy

CPPSRC := $(shell find src -name "*.cpp")
CSRC += $(shell find src -name "*.c")
SSRC := $(shell find src -name "*.S")
HDR := $(shell find src -name "*.h")
DIR := $(shell find src -type d)
INC := $(addprefix -I, $(DIR))
DOBJ := $(addprefix .debug/, $(CPPSRC:.cpp=.cpp.o))
DOBJ += $(addprefix .debug/, $(CSRC:.c=.c.o))
DOBJ += $(addprefix .debug/, $(SSRC:.S=.S.o))
ROBJ := $(addprefix .release/, $(CPPSRC:.cpp=.cpp.o))
ROBJ += $(addprefix .release/, $(CSRC:.c=.c.o))
ROBJ += $(addprefix .release/, $(SSRC:.S=.S.o))
DDEPS := $(DOBJ:.o=.d)
RDEPS := $(ROBJ:.o=.d)

CFLAGS += $(INC)

default: release

.debug/%.cpp.o: %.cpp
	@mkdir -p $(@D)
	${CC}g++ -c $(CFLAGS) $(CFLAGS_DEBUG) -MMD -MP $< -o $@

.debug/%.c.o: %.c
	@mkdir -p $(@D)
	${CC}g++ -c $(CFLAGS) $(CFLAGS_DEBUG) -MMD -MP $< -o $@

.debug/%.S.o: %.S
	@mkdir -p $(@D)
	${CC}g++ -c $(CFLAGS) $(CFLAGS_DEBUG) -MMD -MP $< -o $@

.release/%.cpp.o: %.cpp
	@mkdir -p $(@D)
	${CC}g++ -c $(CFLAGS) $(CFLAGS_RELEASE) -MMD -MP $< -o $@

.release/%.c.o: %.c
	@mkdir -p $(@D)
	${CC}g++ -c $(CFLAGS) $(CFLAGS_RELEASE) -MMD -MP $< -o $@

.release/%.S.o: %.S
	@mkdir -p $(@D)
	${CC}g++ -c $(CFLAGS) $(CFLAGS_RELEASE) -MMD -MP $< -o $@


debug_nomif: $(DOBJ) link.ld
	@mkdir -p debug
	${CC}g++ $(DOBJ) $(CFLAGS) $(CFLAGS_DEBUG) $(LDFLAGS) -o debug/$(TARGET).elf
	${CC}objcopy --remove-section .comment debug/${TARGET}.elf
	${CC}objcopy --remove-section .riscv.attributes debug/${TARGET}.elf
	${CC}objcopy --dump-section .datavma=debug/${TARGET}.data debug/${TARGET}.elf
	${CC}objcopy --update-section .datalma=debug/${TARGET}.data debug/${TARGET}.elf || true
	rm debug/${TARGET}.data || true
#	${OBJCOPY} -O ihex debug/${TARGET}.elf debug/${TARGET}.hex
	${OBJCOPY} -O binary debug/${TARGET}.elf debug/${TARGET}.bin
	python3 bin2mif.py debug/${TARGET}.bin 0 > debug/${TARGET}.mif
	${OBJDUMP} -CDS debug/$(TARGET).elf > debug/${TARGET}.dump
	${CC}strip -s debug/${TARGET}.elf
	${CC}size -A debug/${TARGET}.elf

release_nomif: $(ROBJ) link.ld
	@mkdir -p release
	${CC}g++ $(ROBJ) $(CFLAGS) $(CFLAGS_RELEASE) $(LDFLAGS) -o release/$(TARGET).elf
	${CC}objcopy --remove-section .comment release/${TARGET}.elf
	${CC}objcopy --remove-section .riscv.attributes release/${TARGET}.elf
	${CC}objcopy --dump-section .datavma=release/${TARGET}.data release/${TARGET}.elf
	${CC}objcopy --update-section .datalma=release/${TARGET}.data release/${TARGET}.elf || true
	rm release/${TARGET}.data || true
#	${OBJCOPY} -O ihex release/${TARGET}.elf release/${TARGET}.hex
	${OBJCOPY} -O binary release/${TARGET}.elf release/${TARGET}.bin
	python3 bin2mif.py release/${TARGET}.bin 0 > release/${TARGET}.mif
	${OBJDUMP} -CDS release/$(TARGET).elf > release/${TARGET}.dump
	${CC}strip -s release/${TARGET}.elf
	${CC}size -A release/${TARGET}.elf

debug: debug_nomif
	cp debug/${TARGET}.mif ..

release: release_nomif
	cp release/${TARGET}.mif ..


-include $(DDEPS)
-include $(RDEPS)

.PHONY: clean distclean print

clean:
	rm -rf .debug .release

distclean:
	rm -rf .debug .release debug release

print:
	@echo SRC
	@echo $(CPPSRC)
	@echo $(CSRC)
	@echo $(SSRC)
	@echo HDR
	@echo $(HDR)
	@echo DIR
	@echo $(DIR)
	@echo INC
	@echo $(INC)
	@echo DOBJ
	@echo $(DOBJ)
	@echo ROBJ
	@echo $(ROBJ)
	@echo DDEPS
	@echo $(DDEPS)
	@echo RDEPS
	@echo $(RDEPS)
