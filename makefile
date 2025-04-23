# Makefile para DMG Cold Wallet

# Directorios parametrizados
SRC_DIR  ?= src
LIB_DIR  ?= lib
INC_DIR  ?= inc
OBJ_DIR  ?= obj
BIN_DIR  ?= bin

# Herramientas parametrizadas
RGBASM  ?= rgbasm
RGBLINK ?= rgblink
RGBFIX  ?= rgbfix

# Archivos fuente
SRC_FILES = $(wildcard $(SRC_DIR)/*.asm)
LIB_FILES = $(wildcard $(LIB_DIR)/*.asm)
OBJ_FILES = $(patsubst $(SRC_DIR)/%.asm,$(OBJ_DIR)/%.o,$(SRC_FILES)) \
            $(patsubst $(LIB_DIR)/%.asm,$(OBJ_DIR)/lib_%.o,$(LIB_FILES))

# Flags parametrizados
RGBASMFLAGS  = -i$(INC_DIR)/ -p 0xFF
RGBLINKFLAGS = -p 0xFF
RGBFIXFLAGS  = -p 0xFF -v -C

# Destino final
ROM_NAME     = dmg-wallet

# Definir phony targets
.PHONY: all clean flash debug

# Target principal
all: $(BIN_DIR)/$(ROM_NAME).gb

# Crear directorios si no existen
$(OBJ_DIR):
	mkdir -p $@

$(BIN_DIR):
	mkdir -p $@

# Compilar archivos del directorio src/
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.asm | $(OBJ_DIR)
	$(RGBASM) $(RGBASMFLAGS) -o $@ $<

# Compilar archivos del directorio lib/
$(OBJ_DIR)/lib_%.o: $(LIB_DIR)/%.asm | $(OBJ_DIR)
	$(RGBASM) $(RGBASMFLAGS) -o $@ $<

# Enlazar y generar ROM
$(BIN_DIR)/$(ROM_NAME).gb: $(OBJ_FILES) | $(BIN_DIR)
	$(RGBLINK) $(RGBLINKFLAGS) -o $@ $^
	$(RGBFIX) $(RGBFIXFLAGS) $@

# Target para limpiar archivos generados
clean:
	rm -rf $(OBJ_DIR) $(BIN_DIR)

# Target para flashear en cartucho/emulador (ejemplo con BGB)
flash: all
	@echo "ROM lista para flashear en $(BIN_DIR)/$(ROM_NAME).gb"
	@# Uncomment for your preferred emulator:
	@# bgb $(BIN_DIR)/$(ROM_NAME).gb
	@# mgba-qt $(BIN_DIR)/$(ROM_NAME).gb

# Target para compilar con información de debug
debug: RGBASMFLAGS += -D DEBUG=1
debug: RGBFIXFLAGS += -d
debug: all
