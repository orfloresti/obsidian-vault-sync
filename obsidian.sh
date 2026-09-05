# obsidian.sh
#
# Comando `obsidian` para sincronizar un vault de Obsidian por git desde
# cualquier terminal, sin necesidad de navegar a la carpeta del vault.
#
# Requiere: export OBSIDIAN_VAULT_PATH=/ruta/a/tu/vault  (antes de sourcear este archivo)
#
# Uso:
#   obsidian pull   - trae los últimos cambios del remoto (guarda cambios locales sin commitear con git stash y los reaplica después)
#   obsidian push   - add + commit (mensaje automático) + pull + push
#   obsidian sync   - pull + push, en un solo comando

obsidian() {
    if [ -z "$OBSIDIAN_VAULT_PATH" ]; then
        echo "obsidian: OBSIDIAN_VAULT_PATH no está definida. Agrega 'export OBSIDIAN_VAULT_PATH=/ruta/a/tu/vault' a tu .bashrc/.zshrc" >&2
        return 1
    fi

    if [ ! -d "$OBSIDIAN_VAULT_PATH/.git" ]; then
        echo "obsidian: '$OBSIDIAN_VAULT_PATH' no es un repositorio git" >&2
        return 1
    fi

    case "$1" in
        pull)
            _obsidian_pull
            ;;
        push)
            _obsidian_push
            ;;
        sync)
            _obsidian_pull || return 1
            _obsidian_push
            ;;
        *)
            echo "Uso: obsidian pull | obsidian push | obsidian sync" >&2
            return 1
            ;;
    esac
}

# Pull explícito con --no-rebase para no depender de la configuración de git
# del dispositivo (algunos git piden "reconcile divergent branches" si
# pull.rebase/pull.ff no están configurados). Si hay cambios locales sin
# commitear, los guarda con git stash antes y los reaplica después, para que
# un pull nunca sea bloqueado ni pierda trabajo.
_obsidian_pull() {
    local vault="$OBSIDIAN_VAULT_PATH"
    local stashed=0

    if ! git -C "$vault" diff --quiet || ! git -C "$vault" diff --cached --quiet; then
        echo "obsidian: guardando cambios locales sin commitear antes del pull (git stash)..."
        git -C "$vault" stash push -u -m "obsidian pull: cambios sin commitear" || return 1
        stashed=1
    fi

    if ! git -C "$vault" pull --no-edit --no-rebase; then
        echo "obsidian: conflicto al hacer pull." >&2
        if [ "$stashed" -eq 1 ]; then
            echo "obsidian: tus cambios locales quedaron guardados con git stash. Resuelve el conflicto en $vault y corre 'git stash pop' ahí." >&2
        fi
        return 1
    fi

    if [ "$stashed" -eq 1 ]; then
        if ! git -C "$vault" stash pop; then
            echo "obsidian: conflicto al reaplicar tus cambios locales (git stash pop). Resuélvelo manualmente en $vault." >&2
            return 1
        fi
    fi
}

_obsidian_push() {
    local vault="$OBSIDIAN_VAULT_PATH"

    git -C "$vault" add -A

    if ! git -C "$vault" diff --cached --quiet; then
        local files count summary
        files=$(git -C "$vault" diff --cached --name-only)
        count=$(printf '%s\n' "$files" | wc -l | tr -d ' ')

        if [ "$count" -le 5 ]; then
            summary=$(printf '%s\n' "$files" | paste -sd, - | sed 's/,/, /g')
        else
            summary="$count archivos modificados"
        fi

        git -C "$vault" commit -m "sync: $summary" || return 1
    else
        echo "obsidian: no hay cambios locales para commitear"
    fi

    echo "obsidian: sincronizando con el remoto..."
    if ! git -C "$vault" pull --no-edit --no-rebase; then
        echo "obsidian: conflicto al hacer pull. Resuélvelo manualmente en $vault y vuelve a correr 'obsidian push'." >&2
        return 1
    fi

    git -C "$vault" push
}
