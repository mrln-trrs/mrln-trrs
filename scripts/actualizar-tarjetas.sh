#!/usr/bin/env bash
# Descarga las tarjetas del perfil y las guarda en assets/tarjetas/.
# Una tarjeta solo se reemplaza si la descarga es un SVG válido y no es una tarjeta de error;
# así el README nunca muestra una imagen rota aunque un servicio externo falle.
set -uo pipefail
cd "$(dirname "$0")/.."
DEST=assets/tarjetas
mkdir -p "$DEST"
ERRORES='Something went wrong|Could not resolve|Bad credentials|rate limit|Rate limit|Not Found|Payment Required|DEPLOYMENT_|Internal Server Error|Error fetching'
fallos=0
while IFS='|' read -r nombre url; do
  [[ -z "$nombre" || "$nombre" == \#* ]] && continue
  tmp=$(mktemp)
  codigo=$(curl -sSL --retry 3 --retry-delay 5 -m 60 -A "perfil-mrln-trrs" -o "$tmp" -w '%{http_code}' "$url" || echo 000)
  if [[ "$codigo" == 200 ]] && head -c 300 "$tmp" | grep -qiE '<svg|<\?xml' \
     && [[ $(wc -c < "$tmp") -gt 300 ]] && ! grep -qE "$ERRORES" "$tmp"; then
    mv "$tmp" "$DEST/$nombre.svg"
    echo "ok     $nombre"
  else
    rm -f "$tmp"
    fallos=$((fallos+1))
    if [[ -f "$DEST/$nombre.svg" ]]; then
      echo "::warning::$nombre: descarga inválida (HTTP $codigo); se conserva la copia anterior"
    else
      echo "::error::$nombre: descarga inválida (HTTP $codigo) y no hay copia previa"
    fi
  fi
done < tarjetas.txt
echo "Tarjetas con fallo: $fallos"
# Solo falla si falta alguna tarjeta referenciada (sin copia previa).
for n in $(grep -v '^#' tarjetas.txt | cut -d'|' -f1); do [[ -f "$DEST/$n.svg" ]] || exit 1; done
exit 0
