
# DMG Cold Wallet

> **⚠️ ADVERTENCIA:**  
> Este es un proyecto de demostración técnica. **No implementa cifrado criptográfico** y los datos se almacenan en texto plano en la SRAM.  
> **No debe usarse para almacenar criptomonedas reales.**

Una billetera fría (*cold wallet*) de demostración para la Game Boy (DMG), diseñada con una arquitectura de software moderna y modular.

---

## 📖 Descripción

DMG Cold Wallet es una aplicación *homebrew* para la Game Boy original que explora la viabilidad del hardware clásico para aplicaciones modernas. Permite:

- Gestionar múltiples “wallets” almacenados en la SRAM del cartucho.  
- Crear transacciones mediante una interfaz de texto.  
- Generar dinámicamente códigos QR (Versión 1, Nivel L) para la transacción actual.  
- Comunicarse con otros dispositivos por Cable Link (con CRC y reintentos).  
- Imprimir el código QR con la Game Boy Printer.  
- Verificar la integridad de datos en SRAM usando checksum.  
- Ejecutar pruebas unitarias con la ROM de test incorporada (`test_runner.gb`).

---

## ✨ Características Principales

- **Gestión de Wallets**:  
  - Crear, seleccionar y borrar wallets.  
  - Almacenamiento en SRAM con checksum de integridad.

- **Creación de Transacciones**:  
  - Introducción de direcciones y montos en pantalla de texto.

- **Generación de Códigos QR**:  
  - Versión 1, Nivel L.  
  - Adaptado al display de la DMG.

- **Comunicación por Cable Link**:  
  - Protocolo propio con CRC y reintentos automáticos.

- **Soporte para Game Boy Printer**:  
  - Impresión directa del QR de la transacción.

- **Framework de Pruebas**:  
  - ROM de pruebas (`test_runner.gb`) para asegurar la lógica crítica.

---

## 🗂️ Estructura del Proyecto

```text
DMGCW-main-7/
├── src/           # Módulos de aplicación (orquestadores de alto nivel)
│   ├── main.asm       # Punto de entrada y menú principal
│   ├── input.asm      # Teclado virtual genérico
│   ├── confirm.asm    # Pantalla de confirmación de TX
│   ├── sram.asm       # UI gestión de wallets
│   ├── qr.asm         # Orquestador de generación de QR
│   ├── link.asm       # Orquestador de comunicación Link
│   ├── printer.asm    # Orquestador de impresión
│   └── sound.asm      # Gestión de efectos de sonido
│
├── lib/           # Librerías de lógica reutilizable
│   ├── utils.asm       # Funciones comunes (memoria, I/O, debounce)
│   ├── ui.asm          # Primitivas de dibujo para la UI
│   ├── sram_manager.asm# API de bajo nivel para la SRAM
│   ├── qr_engine.asm   # Lógica para construir la matriz QR
│   ├── rs_ecc.asm      # Algoritmo Reed–Solomon para ECC
│   ├── link_engine.asm # Protocolo de bajo nivel para Cable Link
│   ├── printer_comm.asm# Protocolo de bajo nivel para Game Boy Printer
│   └── debug.asm       # Utilidades para depuración
│
├── inc/           # Archivos de inclusión
│   ├── constants.inc   # Constantes globales
│   ├── hardware.inc    # Definiciones de hardware Game Boy
│   └── assert.inc      # Macros de aserción en compilación
│
├── obj/           # (Generado) Archivos de objeto
├── bin/           # (Generado) ROMs finales
│   ├── dmg-wallet.gb     # ROM principal
│   └── test_runner.gb    # Suite de pruebas
│
└── makefile       # Script de compilación modular
````

---

## ⚙️ Compilación

### Requisitos

* **RGBDS** v0.5.0 o superior
* `make` (Linux, macOS o WSL en Windows)

### Comandos

```bash
# Compilar la ROM principal (bin/dmg-wallet.gb)
make all

# Compilar y lanzar en emulador (configurable en makefile)
make flash

# Limpiar artefactos de compilación
make clean

# Compilar con flags de depuración
make debug

# Ejecutar la suite de pruebas unitarias
make run-test
```

---

## 🎮 Uso

### Controles

* **D-Pad**: Navegar menús y selector de caracteres.
* **A**: Seleccionar / Añadir carácter.
* **B**: Cancelar / Volver / Borrar carácter.
* **Start**: Confirmar / Guardar.
* **Select**: Cambiar campo en entradas de texto.

### Flujo de la Aplicación

1. **Menú Principal**: Elige la funcionalidad deseada.
2. **Gestionar Wallets**: Crea o borra wallets antes de operar.
3. **Nuevo TX**: Introduce dirección y monto.
4. **Confirmar**: Revisa y confirma; se almacena en el log de SRAM.
5. **Mostrar QR / Enviar Link / Imprimir**: Actúa sobre la última transacción.

---

## 🤝 Desarrollo y Contribución

¡Nos encantan las contribuciones! Antes de empezar:

1. Lee la guía [CONTRIBUTING.md](./CONTRIBUTING.md).
2. Sigue las convenciones de [STYLE\_GUIDE.md](./STYLE_GUIDE.md).
3. Asegúrate de que todos los tests pasen (`make run-test`).

---

## 📝 Licencia

Este proyecto está bajo la **Licencia MIT**. Consulta [LICENSE](./LICENSE) para más detalles.

