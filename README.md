# DMG Cold Wallet

Una billetera fría de demostración para Game Boy DMG.

## Descripción

DMG Cold Wallet es una aplicación minimalista que permite gestionar múltiples wallets, generar códigos QR dinámicos, enviar transacciones por cable Link y guardar datos en SRAM. Diseñada como demostración técnica para ilustrar el potencial del hardware Game Boy en aplicaciones modernas.

**ADVERTENCIA**: Esta versión de demostración no implementa cifrado. No utilizar para almacenar valores reales.

## Características

- Interfaz de usuario minimalista en ASCII
- Entrada de direcciones y montos mediante selector virtual
- Gestión de múltiples wallets en SRAM
- Generación de códigos QR (Version 1, EC Level L)
- Comunicación por cable Link (protocolo con ACK/NACK)
- Soporte para Game Boy Printer
- Persistencia en SRAM con verificación de checksum

## Novedades en esta versión

- Mejoras significativas en la robustez del código
- Parámetros configurables para timeouts y debounce
- Validaciones de espacio SRAM en tiempo de compilación
- Mejor manejo de errores y feedback
- Soporte para compilación en modo DEBUG

## Compilación

### Requisitos:
- RGBDS (Rednex Game Boy Development System) v0.5.0 o superior

### Pasos para compilar:
```bash
# Compilación normal
make

# Compilación con modo DEBUG activado
make debug

# Limpiar archivos generados
make clean

# Compilar y cargar en emulador (editar Makefile para tu emulador preferido)
make flash
```

El archivo ROM resultante se generará en `bin/dmg-wallet.gb`

## Instalación

Puedes ejecutar el archivo ROM en:

1. Una Game Boy DMG real usando un cartucho flash como EverDrive-GB o similar
2. Un emulador como BGB, SameBoy, mGBA o Gambatte

## Uso

### Menú Principal

- **Nuevo TX**: Ingresar dirección y monto para una nueva transacción
- **Confirmar**: Revisar y confirmar la transacción actual
- **Gestionar W**: Administrar wallets (crear, borrar, seleccionar)
- **Enviar Link**: Transmitir datos de la transacción por cable Link
- **Mostrar QR**: Generar y mostrar código QR de la transacción
- **Imprimir QR**: Enviar código QR a la Game Boy Printer
- **Salir**: Regresar al inicio

### Controles

- **D-Pad**: Navegación
- **A**: Seleccionar
- **B**: Cancelar/Volver
- **Select**: Cambiar campo (en editor)
- **Start**: Confirmar/Guardar

## Estructura del Proyecto
```
dmg-cold-wallet/
├── inc/              # Archivos de inclusión
│   ├── assert.inc    # Macros para validaciones
│   ├── constants.inc # Constantes globales
│   └── hardware.inc  # Definiciones de hardware
├── lib/              # Librerías reutilizables
│   ├── debug.asm     # Utilidades de depuración
│   ├── sram_manager.asm # Gestor de SRAM
│   ├── ui.asm        # Primitivas de UI
│   └── rs_ecc.asm    # Algoritmo Reed-Solomon
├── src/              # Código fuente principal
│   ├── main.asm      # Punto de entrada y menú
│   ├── input.asm     # Módulo de entrada de datos
│   ├── confirm.asm   # Confirmación de transacción
│   ├── sram.asm      # UI de gestión de wallets
│   ├── link.asm      # Protocolo de comunicación
│   ├── qr.asm        # Generador de QR
│   ├── printer.asm   # Interfaz con Game Boy Printer
│   ├── sound.asm     # Efectos de sonido
│   └── utils.asm     # Utilidades generales
└── makefile          # Script de compilación
```

## Limitaciones

- **Sin cifrado**: Los datos se almacenan sin cifrar en SRAM
- **QR Version 1**: Limitado a aproximadamente 17 bytes de datos
- **Game Boy DMG**: Optimizado para la consola original en blanco y negro
- **Botones limitados**: UI adaptada a los pocos botones disponibles

## Desarrollo y Contribución

Si deseas contribuir al proyecto, por favor consulta:

- [CONTRIBUTING.md](CONTRIBUTING.md) - Guía de contribución
- [STYLE_GUIDE.md](STYLE_GUIDE.md) - Convenciones de código

## Créditos

Desarrollado como demostración técnica.

## Licencia

Este proyecto se distribuye como código abierto bajo la licencia MIT.
