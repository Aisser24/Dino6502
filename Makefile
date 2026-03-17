# Define the tools
AS = ca65
LD = ld65

# Define the target name
TARGET = dino_game.bin

# Include paths for .include directives
INCLUDE_DIRS = -I config -I lcd

# List of object files
OBJS = main.o lcd/lcd.o

# The "all" rule - what happens when you just type 'make'
all: $(TARGET)

# How to link the binary
$(TARGET): $(OBJS)
	$(LD) -C config/system.cfg $(OBJS) -o $(TARGET)

# How to assemble .s files into .o files
%.o: %.s
	$(AS) $(INCLUDE_DIRS) $< -o $@

# Include file dependencies (ensures recompile when headers change)
main.o: lcd/lcd.inc config/defs.inc
lcd/lcd.o: config/defs.inc

# A clean rule to start fresh
.PHONY: all clean
clean:
	rm -f main.o lcd/lcd.o $(TARGET)
