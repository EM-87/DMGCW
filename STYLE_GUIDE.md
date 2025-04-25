# STYLE_GUIDE.md

## Convenciones de código para DMG Cold Wallet

### 1. Nomenclatura
- Etiquetas públicas: PascalCase (ej: DrawMenu)
- Etiquetas locales: .camelCase (ej: .waitInput)
- Constantes: SNAKE_CASE mayúsculas (ej: MAX_WALLETS)
- Variables: snake_case (ej: cursor_pos)

### 2. Estructuración
- Usar comentarios de sección para bloques lógicos
- Usar indentación de 4 espacios para bloques
- Mantener rutinas por debajo de 50 líneas cuando sea posible

### 3. Banking
- ROM0: Código crítico, entry points, UI común
- ROM1: Módulos específicos, agrupados por funcionalidad

### 4. WRAM/SRAM
- Documentar cada sección con tamaño y propósito
- Alinear estructuras en límites de 16 bytes cuando sea posible

### 5. Manejo de registros
- Preservar registros si se modifican (push/pop)
- Documentar qué registros modifica cada función
- Usar comentarios para explicar uso de registros

### 6. Comentarios
- Encabezado de función: descripción, entradas, salidas
- Comentarios inline para lógica compleja
- Documentar hacks o workarounds

### 7. Macros y constantes
- Definir en archivos .inc apropiados
- Usar nombres descriptivos
- Documentar rangos de valores válidos
