# ====================================================================
# Makefile para DMG Cold Wallet (Versión Final Modular y Robusta)
# ====================================================================

# --- Herramientas ---
RGBASM  ?= rgbasm
RGBLINK ?= rgblink
RGBFIX  ?= rgbfix
EMULATOR ?= bgb # Cambia esto a tu emulador (ej. mgba-qt)

# --- Directorios ---
SRC_DIR  := src
LIB_DIR  := lib
INC_DIR  := inc
OBJ_DIR  := obj
BIN_DIR  := bin

# --- Archivos Fuente (Única fuente de verdad) ---
# Módulos de la aplicación principal (orquestadores)
APP_SOURCES := \
    main.asm \
    input.asm \
    confirm.asm \
    sram.asm \
    qr.asm \
    link.asm \
    printer.asm \
    sound.asm

# Librerías de lógica y utilidades
LIB_SOURCES := \
    utils.asm \
    ui.asm \
    sram_manager.asm \
    qr_engine.asm \
    rs_ecc.asm \
    link_engine.asm \
    printer_comm.asm \
    debug.asm

# Archivo de pruebas
TEST_SOURCE := test_main.asm

# --- Generación de Archivos de Objeto ---
APP_OBJECTS := $(patsubst %.asm,$(OBJ_DIR)/app_%.o,$(APP_SOURCES))
LIB_OBJECTS := $(patsubst %.asm,$(OBJ_DIR)/lib_%.o,$(LIB_SOURCES))
TEST_OBJECT := $(patsubst %.asm,$(OBJ_DIR)/%.o,$(TEST_SOURCE))
ALL_OBJECTS := $(APP_OBJECTS) $(LIB_OBJECTS)

# --- Destino Final ---
ROM_NAME     := dmg-wallet
ROM_PATH     := $(BIN_DIR)/$(ROM_NAME).gb
TEST_ROM_PATH := $(BIN_DIR)/test_runner.gb

# --- Flags de Compilación ---
RGBASMFLAGS  := -I$(INC_DIR)/ -p 0xFF
RGBLINKFLAGS := -p 0xFF -n $(BIN_DIR)/$(ROM_NAME).sym
RGBFIXFLAGS  := -p 0xFF -v -C

# ====================================================================
# Reglas de Compilación
# ====================================================================

# Target por defecto
all: $(ROM_PATH)

# Crear directorios si no existen
$(OBJ_DIR) $(BIN_DIR):
	@echo "Creating directory: $@"
	@mkdir -p $@

# Regla para compilar módulos de la aplicación (desde src/)
$(OBJ_DIR)/app_%.o: $(SRC_DIR)/%.asm | $(OBJ_DIR)
	@echo "Compiling app: $<"
	@$(RGBASM) $(RGBASMFLAGS) -o $@ $<

# Regla para compilar librerías (desde lib/)
$(OBJ_DIR)/lib_%.o: $(LIB_DIR)/%.asm | $(OBJ_DIR)
	@echo "Compiling lib: $<"
	@$(RGBASM) $(RGBASMFLAGS) -o $@ $<

# Regla para compilar el archivo de pruebas
$(TEST_OBJECT): $(SRC_DIR)/$(TEST_SOURCE) | $(OBJ_DIR)
	@echo "Compiling test runner: $<"
	@$(RGBASM) $(RGBASMFLAGS) -o $@ $<

# Enlazar ROM principal
$(ROM_PATH): $(ALL_OBJECTS) | $(BIN_DIR)
	@echo "Linking ROM: $@"
	@$(RGBLINK) $(RGBLINKFLAGS) -o $@ $^
	@$(RGBFIX) $(RGBFIXFLAGS) $@
	@echo "ROM successfully built: $(ROM_PATH)"

# Enlazar ROM de pruebas
$(TEST_ROM_PATH): $(TEST_OBJECT) $(LIB_OBJECTS) | $(BIN_DIR)
	@echo "Linking Test Runner: $@"
	@$(RGBLINK) -o $@ $^
	@$(RGBFIX) $(RGBFIXFLAGS) $@
	@echo "Test runner successfully built: $(TEST_ROM_PATH)"

# ====================================================================
# Comandos Adicionales (Phony Targets)
# ====================================================================
.PHONY: all clean flash debug test run-test

# Limpiar todos los archivos generados
clean:
	@echo "Cleaning generated files..."
	@rm -rf $(OBJ_DIR) $(BIN_DIR)

# Compilar con flags de depuración
debug:
	@$(MAKE) all RGBASMFLAGS="$(RGBASMFLAGS) -D DEBUG=1" RGBFIXFLAGS="$(RGBFIXFLAGS) -d"

# Compilar y ejecutar la ROM principal
flash: all
	@echo "Launching ROM in emulator..."
	@$(EMULATOR) $(ROM_PATH)

# Compilar la ROM de pruebas
test: $(TEST_ROM_PATH)

# Compilar y ejecutar la ROM de pruebas
run-test: test
	@echo "Launching Test Runner in emulator..."
	@$(EMULATOR) $(TEST_ROM_PATH)
