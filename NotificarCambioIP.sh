#!/bin/bash

# Directorio base del script
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$BASE_DIR/config.cfg"
IP_FILE="$BASE_DIR/.last_ip"

# --- Funciones de Utilidad ---

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_permissions() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local perms=$(stat -c "%a" "$file")
        if [[ "$perms" != "600" ]]; then
            log "Aviso: Permisos inseguros en $file ($perms). Cambiando a 600."
            chmod 600 "$file"
        fi
    fi
}

# --- Inicio del Script ---

# 1. Cargar Configuración
if [[ ! -f "$CONFIG_FILE" ]]; then
    log "Error: No se encuentra el archivo de configuración $CONFIG_FILE"
    exit 1
fi

check_permissions "$CONFIG_FILE"
source "$CONFIG_FILE"

# Validar variables críticas
if [[ -z "$TELEGRAM_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
    log "Error: Faltan variables en config.cfg (TOKEN o CHAT_ID)."
    exit 1
fi

# 2. Obtener IP Pública Actual
CURRENT_IP=$(curl -s --connect-timeout 10 https://api.ipify.org)

if [[ -z "$CURRENT_IP" ]]; then
    log "Error: No se pudo obtener la IP pública."
    exit 1
fi

# 3. Leer IP Anterior
OLD_IP=""
if [[ -f "$IP_FILE" ]]; then
    check_permissions "$IP_FILE"
    OLD_IP=$(cat "$IP_FILE")
fi

# 4. Comparar y Actuar
if [[ "$CURRENT_IP" != "$OLD_IP" ]]; then
    log "Cambio detectado: IP anterior ($OLD_IP) -> Nueva IP ($CURRENT_IP)"
    
    # Preparar el mensaje para Telegram
    # Usamos printf para manejar saltos de línea y caracteres especiales básicos
    MENSAJE="🔔 *${ALERTA_PREFIJO:-"Aviso de IP"}*
━━━━━━━━━━━━━━━━━━
⚠️ *Cambio detectado*
📍 *IP Nueva:* \`$CURRENT_IP\`
🔙 *IP Anterior:* 
\`${OLD_IP:-"Ninguna"}\`
⏰ *Fecha:* $(date '+%Y-%m-%d %H:%M:%S')
━━━━━━━━━━━━━━━━━━"

    # Enviar mensaje vía Telegram API (Usamos HTML por simplicidad y robustez)
    HTML_MSG="<b>${ALERTA_PREFIJO:-"Aviso de IP"}</b>
━━━━━━━━━━━━━━━━━━
⚠️ <b>Cambio detectado</b>
📍 <b>IP Nueva:</b> <code>$CURRENT_IP</code>
🔙 <b>IP Anterior:</b> <code>${OLD_IP:-"Ninguna"}</code>
⏰ <b>Fecha:</b> $(date '+%Y-%m-%d %H:%M:%S')
━━━━━━━━━━━━━━━━━━"

    RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d "chat_id=$TELEGRAM_CHAT_ID" \
        -d "parse_mode=HTML" \
        -d "text=$HTML_MSG")

    # Verificar si Telegram aceptó la petición
    if [[ "$RESPONSE" == *"\"ok\":true"* ]]; then
        log "Mensaje de Telegram enviado exitosamente."
        echo "$CURRENT_IP" > "$IP_FILE"
        chmod 600 "$IP_FILE"
    else
        log "Error al enviar a Telegram. Respuesta: $RESPONSE"
    fi

else
    log "Sin cambios. La IP sigue siendo $CURRENT_IP."
fi