# obsidian-vault-sync

Comando `obsidian` para sincronizar un vault de Obsidian por git desde cualquier
terminal, sin necesidad de navegar a la carpeta del vault.

## Comandos

- `obsidian pull` — trae los últimos cambios del remoto.
- `obsidian push` — agrega y commitea los cambios locales (con un mensaje
  automático que lista los archivos modificados), hace `pull` para evitar que
  el push sea rechazado si otro dispositivo subió cambios primero, y luego
  hace `push`.
- `obsidian sync` — corre `pull` y luego `push` en un solo comando.
- `obsidian update` — actualiza esta herramienta (hace `pull` del propio
  repo `obsidian-vault-sync`). Por default asume que está clonada en
  `~/.obsidian-vault-sync`; si la clonaste en otro lado, define
  `OBSIDIAN_SYNC_PATH` apuntando ahí. Después de actualizar, abre una
  terminal nueva (o vuelve a sourcear `obsidian.sh`) para que tome el cambio.
- `obsidian help` (o `-h` / `--help`) — muestra la ayuda de uso.

Si `obsidian push` encuentra un conflicto al hacer pull, se detiene y avisa
para resolverlo a mano en la carpeta del vault — no intenta resolverlo solo.

**Recomendación:** antes de empezar a editar notas en un dispositivo, corre
`obsidian sync` primero. Así arrancas con lo último del remoto y bajas el
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
   source "$HOME/.obsidian-vault-sync/obsidian.sh"
   ```

3. Abre una terminal nueva (o corre `source ~/.bashrc`) y prueba:

   ```bash
   obsidian pull
   obsidian push
   ```

Cada dispositivo (PC, Termux, tablet) solo necesita apuntar
`OBSIDIAN_VAULT_PATH` a su propio clon de `obsidian-vault` — el script
(`obsidian.sh`) es el mismo en todos.
