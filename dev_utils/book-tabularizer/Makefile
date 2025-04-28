CC = cc
CFLAGS = -Wall

BUILD_DIR = build

SUBPROJECTS = polyglot polyglot-operator

all: $(addprefix $(BUILD_DIR)/, $(SUBPROJECTS))

$(BUILD_DIR)/%: %
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) $</*.c -o $@

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean $(SUBPROJECTS)
