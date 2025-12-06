NASM ?= nasm
LD ?= ld

SRC_DIR := src
BUILD_DIR := build

NASMFLAGS ?= -f elf64
LDFLAGS ?= -m elf_x86_64

DAYS := Day1 Day2 Day3
ASM_SRCS := $(addprefix $(SRC_DIR)/,$(addsuffix .asm,$(DAYS)))
OBJ_FILES := $(addprefix $(BUILD_DIR)/,$(addsuffix .o,$(DAYS)))
BINARIES := $(addprefix $(BUILD_DIR)/,$(DAYS))

.PHONY: all clean \
	    day1 day2 day3 \
		list run-day%

all: $(BINARIES)

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/Day%.o: $(SRC_DIR)/Day%.asm | $(BUILD_DIR)
	$(NASM) $(NASMFLAGS) $< -o $@

$(BUILD_DIR)/Day%: $(BUILD_DIR)/Day%.o
	$(LD) $(LDFLAGS) -o $@ $<

day1: $(BUILD_DIR)/Day1
day2: $(BUILD_DIR)/Day2
day3: $(BUILD_DIR)/Day3

run-day%: $(BUILD_DIR)/Day%
	./$(BUILD_DIR)/Day$*

list:
	@printf "Available days:\n"
	@for day in $(DAYS); do echo "  $$day"; done

clean:
	rm -rf $(BUILD_DIR)
