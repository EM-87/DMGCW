# Makefile para DMG Cold Wallet

# Directorios
SRC_DIR  = src
LIB_DIR  = lib
INC_DIR  = inc
OBJ_DIR  = obj
BIN_DIR  = bin

# Archivos fuente
SRC_FILES = $(wildcard $(SRC_DIR)/*.asm)
LIB_FILES = $(wildcard $(LIB_DIR)/*.asm)
OBJ_FILES = $(patsubst $(SRC_DIR)/%.asm,$(OBJ_DIR)/%.o,$(SRC_FILES)) \
            $(patsubst $(LIB_DIR)/%.asm,$(OBJ_DIR)/lib_%.o,$(LIB_FILES))

# Comandos y flags
RGBASM       = rgbasm
RGBLINK      = rgblink
RGBFIX       = rgbfix
RGBASMFLAGS  = -i$(INC_DIR)/ -p 0xFF
RGBLINKFLAGS = -p 0xFF
RGBFIXFLAGS  = -p 0xFF -v -C

# Destino final
ROM_NAME     = dmg-wallet

# Reglas
.PHONY: all clean

all: $(BIN_DIR)/$(ROM_NAME).gb

# Crear directorios si no existen
$(OBJ_DIR):
	mkdir -p $@

$(BIN_DIR):
	mkdir -p $@

# Compilar archivos del directorio src/
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.asm | $(OBJ_DIR)
	$(RGBASM) $(RGBASMFLAGS) -o $@ $

# Compilar archivos del directorio lib/
$(OBJ_DIR)/lib_%.o: $(LIB_DIR)/%.asm | $(OBJ_DIR)
	$(RGBASM) $(RGBASMFLAGS) -o $@ $

# Enlazar y generar ROM
$(BIN_DIR)/$(ROM_NAME).gb: $(OBJ_FILES) | $(BIN_DIR)
	$(RGBLINK) $(RGBLINKFLAGS) -o $@ $^
	$(RGBFIX) $(RGBFIXFLAGS) $@

clean:
	rm -rf $(OBJ_DIR) $(BIN_DIR)