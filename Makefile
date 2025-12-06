NASM ?= nasm
LD ?= ld

SRC_DIR := src
BUILD_DIR := build

NASMFLAGS ?= -f elf64
LDFLAGS ?= -m elf_x86_64

DAYS := Day1 Day2 Day3 Day4  Day5  Day6 \
		Day7 Day8 Day9 Day10 Day11 Day12
BINARIES := $(addprefix $(BUILD_DIR)/,$(DAYS))

.PHONY: all clean list
.PHONY: day% run-day%

all: $(BINARIES)

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/Day%.o: $(SRC_DIR)/Day%.asm | $(BUILD_DIR)
	@$(NASM) $(NASMFLAGS) $< -o $@

$(BUILD_DIR)/Day%: $(BUILD_DIR)/Day%.o
	@$(LD) $(LDFLAGS) -o $@ $<

day%: $(BUILD_DIR)/Day%
run-day%: $(BUILD_DIR)/Day%
	@./$<

list:
	@printf "Available days:\n"
	@for day in $(DAYS); do echo "  $$day"; done

clean:
	rm -rf $(BUILD_DIR)
