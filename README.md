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

2. Agrega estas dos líneas a tu `.bashrc` (o `.zshrc`), ajustando la ruta
   donde tengas clonado tu vault en ese dispositivo:

   ```bash
   export OBSIDIAN_VAULT_PATH="$HOME/obsidian-vault"
   source "$HOME/.obsidian-vault-sync/vsync.sh"
   ```

3. Abre una terminal nueva (o corre `source ~/.bashrc`) y prueba:

   ```bash
   vsync
   ```

Cada dispositivo (PC, Termux, tablet) solo necesita apuntar
`OBSIDIAN_VAULT_PATH` a su propio clon de `obsidian-vault` — el script
(`vsync.sh`) es el mismo en todos.
