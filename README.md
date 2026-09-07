# obsidian-vault-sync

Comando `vsync` para sincronizar un vault de Obsidian por git desde cualquier
terminal, sin necesidad de navegar a la carpeta del vault.

## Comandos

- `vsync` (sin argumentos) — corre `pull` y luego `push` en un solo comando.
  Es el caso más común, por eso es el default.
- `vsync pull` — trae los últimos cambios del remoto.
- `vsync push` — agrega y commitea los cambios locales (con un mensaje
  automático que lista los archivos modificados), hace `pull` para evitar que
  el push sea rechazado si otro dispositivo subió cambios primero, y luego
  hace `push`.
- `vsync update` — actualiza esta herramienta (hace `pull` del propio repo
  `obsidian-vault-sync`). Detecta sola desde dónde sourceaste `vsync.sh`, sin
  importar dónde lo hayas clonado — no necesitas configurar nada. Solo
  define `VSYNC_PATH` si esa detección fallara en tu caso. Se recarga sola
  al terminar — no necesitas abrir una terminal nueva.
- `vsync version` — imprime solo el hash corto del último commit de
  `obsidian-vault-sync` (misma detección de ruta que `update`). Sirve para
  comparar entre dispositivos y confirmar que todos corren la misma versión.
- `vsync help` (o `-h` / `--help`) — muestra la ayuda de uso.

Si `vsync push` (o `vsync pull`) encuentra un conflicto al hacer pull, se
detiene y avisa para resolverlo a mano en la carpeta del vault — no intenta
resolverlo solo.

**Recomendación:** antes de empezar a editar notas en un dispositivo, corre
`vsync` a solas primero. Así arrancas con lo último del remoto y bajas el
riesgo de que tus ediciones choquen (conflicto de merge) con cambios hechos
en otro dispositivo mientras tanto.

## Instalación (en cada dispositivo)

1. Clona este repo en cualquier ubicación:

   ```bash
   git clone https://github.com/orfloresti/obsidian-vault-sync.git ~/.obsidian-vault-sync
   ```

2. Corre el instalador:

   ```bash
   cd ~/.obsidian-vault-sync
   make install
   ```

   La ruta del propio repo la detecta sola (de dónde está corriendo el
   script), no hace falta escribirla. Te va a preguntar la ruta de tu vault
   de Obsidian y qué archivo de shell actualizar (`~/.bashrc` por default, o
   `~/.zshrc` si tu shell es zsh). Agrega un bloque delimitado por marcadores
   a ese archivo con `OBSIDIAN_VAULT_PATH`, la ruta del repo a `PATH`, y el
   `source` de `vsync.sh`. Correrlo de nuevo reemplaza el bloque en vez de
   duplicarlo.

   `vsync` es una función de shell, no un binario — lo que realmente lo hace
   disponible es la línea de `source`, no el `PATH` (ese se agrega por si
   más adelante agregas otros scripts sueltos a este repo).

3. Abre una terminal nueva (o corre `source ~/.bashrc`) y prueba:

   ```bash
   vsync
   ```

Cada dispositivo (PC, Termux, tablet) solo necesita apuntar
`OBSIDIAN_VAULT_PATH` a su propio clon de `obsidian-vault` — el script
(`vsync.sh`) es el mismo en todos.

Para quitarlo de un dispositivo:
```bash
make uninstall
```
Busca el bloque en `~/.bashrc` y `~/.zshrc` y lo quita de donde lo encuentre
(guarda una copia `.bak` antes). No borra el repo clonado ni tu vault.

## Tests

```bash
make test
```
Corre `tests/test_vsync.sh`: crea repos git temporales (aislados, se borran
solos al terminar) para probar cada comando de punta a punta — ayuda,
argumentos inválidos, `push`/`pull`/sync sin cambios, con cambios, con
archivos nuevos sin trackear, con ramas divergentes entre "dos
dispositivos", con un conflicto real de merge, y `update`/`version` con
detección automática de ruta. No toca tu vault real ni tu configuración de
shell.
