# obsidian.sh
#
# Comando `obsidian` para sincronizar un vault de Obsidian por git desde
# cualquier terminal, sin necesidad de navegar a la carpeta del vault.
#
# Requiere: export OBSIDIAN_VAULT_PATH=/ruta/a/tu/vault  (antes de sourcear este archivo)
#
# Uso:
#   obsidian pull   - trae los últimos cambios del remoto
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
            git -C "$OBSIDIAN_VAULT_PATH" pull
            ;;
        push)
            _obsidian_push
            ;;
        sync)
            git -C "$OBSIDIAN_VAULT_PATH" pull || return 1
            _obsidian_push
            ;;
        *)
            echo "Uso: obsidian pull | obsidian push | obsidian sync" >&2
            return 1
            ;;
    esac
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
    if ! git -C "$vault" pull --no-edit; then
        echo "obsidian: conflicto al hacer pull. Resuélvelo manualmente en $vault y vuelve a correr 'obsidian push'." >&2
        return 1
    fi

    git -C "$vault" push
}
