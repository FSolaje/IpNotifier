#!/bin/bash

# Colores para la salida
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuración por defecto
DEFAULT_INSTALL_DIR="$HOME/Programas/Scripts/IpNotifier"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=== Instalador del Monitor de IP Pública ===${NC}"

# 1. Definir directorio de instalación
read -p "Directorio de instalación [$DEFAULT_INSTALL_DIR]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}

echo -e "${BLUE}-> Instalando en:${NC} $INSTALL_DIR"

# 2. Crear directorios
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    echo "   Directorio creado."
fi

# 3. Copiar archivos
echo -e "${BLUE}-> Copiando archivos...${NC}"
cp "$CURRENT_DIR/NotificarCambioIP.sh" "$INSTALL_DIR/"
cp -n "$CURRENT_DIR/config.cfg" "$INSTALL_DIR/"
cp "$CURRENT_DIR/ip-monitor.service" "$INSTALL_DIR/"
cp "$CURRENT_DIR/ip-monitor.timer" "$INSTALL_DIR/"

# 4. Configurar permisos
echo -e "${BLUE}-> Configurando permisos de seguridad...${NC}"
chmod +x "$INSTALL_DIR/NotificarCambioIP.sh"
chmod 600 "$INSTALL_DIR/config.cfg"

# 4.5 ASISTENTE DE CONFIGURACIÓN TELEGRAM
echo -e "\n${YELLOW}=== Asistente de Configuración de Telegram ===${NC}"
read -p "¿Deseas configurar el Bot de Telegram ahora? (s/n): " CONFIGURE_NOW

if [[ "$CONFIGURE_NOW" =~ ^[Ss]$ ]]; then
    CONFIG_PATH="$INSTALL_DIR/config.cfg"
    
    while true; do
        read -p "Introduce el TOKEN del Bot (dado por @BotFather): " USER_TOKEN
        
        if [[ -z "$USER_TOKEN" ]]; then
            echo -e "${RED}El token no puede estar vacío.${NC}"
            continue
        fi

        echo -e "Comprobando conexión con Telegram..."
        
        # Intentamos obtener actualizaciones para buscar el Chat ID
        RESPONSE=$(curl -s "https://api.telegram.org/bot$USER_TOKEN/getUpdates")
        
        # Verificamos si el token es válido
        if [[ "$RESPONSE" == *"Unauthorized"* ]]; then
             echo -e "${RED}Error: Token inválido. Inténtalo de nuevo.${NC}"
             continue
        fi

        # Extraemos el ID del chat
        CHAT_ID=$(echo "$RESPONSE" | grep -oP '"chat":{"id":\K-?[0-9]+' | head -n 1)

        if [[ -n "$CHAT_ID" ]]; then
            echo -e "${GREEN}¡Conexión exitosa! ID de Chat detectado: $CHAT_ID${NC}"
            
            # 1. Guardar TOKEN
            sed -i "s|TELEGRAM_TOKEN=".*"|TELEGRAM_TOKEN=\"$USER_TOKEN\"|" "$CONFIG_PATH"
            
            # 2. Guardar CHAT ID
            sed -i "s|TELEGRAM_CHAT_ID=".*"|TELEGRAM_CHAT_ID=\"$CHAT_ID\"|" "$CONFIG_PATH"
            
            # 3. Solicitar y Guardar PREFIJO (Nueva funcionalidad)
            echo ""
            read -p "Nombre para identificar este equipo en las alertas (Default: 'Servidor Linux'): " USER_PREFIX
            USER_PREFIX=${USER_PREFIX:-"Servidor Linux"}
            sed -i "s|ALERTA_PREFIJO=".*"|ALERTA_PREFIJO=\"$USER_PREFIX\"|" "$CONFIG_PATH"
            
            echo -e "${GREEN}Configuración guardada en $CONFIG_PATH${NC}"
            break
        else
            echo -e "${YELLOW}Token válido, pero no se encontró ningún mensaje reciente.${NC}"
            echo "Para obtener tu ID, necesitas enviar un mensaje (ej: 'Hola') a tu bot en Telegram."
            echo "1. Abre tu bot en Telegram."
            echo "2. Dale a Iniciar o escribe 'Hola'."
            read -p "Presiona ENTER cuando lo hayas hecho para reintentar..."
        fi
    done
else
    echo "Saltando configuración. Recuerda editar $INSTALL_DIR/config.cfg manualmente."
fi


# 5. Configurar y Activar Servicio Systemd
echo -e "\n${BLUE}-> Configurando servicio Systemd...${NC}"
SERVICE_FILE="$INSTALL_DIR/ip-monitor.service"
TIMER_FILE="$INSTALL_DIR/ip-monitor.timer"

# Ajustar ruta en el archivo .service
sed -i "s|ExecStart=.*|ExecStart=$INSTALL_DIR/NotificarCambioIP.sh|" "$SERVICE_FILE"

# Función para finalizar
show_success() {
    local cmd="$1"
    echo -e "\n${GREEN}=== ¡Instalación Completada! ===${NC}"
    echo -e "El servicio se ha instalado y activado."
    echo -e "Verifica el estado con: ${YELLOW}$cmd${NC}"
}

# Intentar instalación
if systemctl --user list-units >/dev/null 2>&1; then
    # Modo Usuario (Original)
    echo "   Modo detectado: Usuario (Standard)"
    SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SYSTEMD_USER_DIR"

    ln -sf "$SERVICE_FILE" "$SYSTEMD_USER_DIR/"
    ln -sf "$TIMER_FILE" "$SYSTEMD_USER_DIR/"

    echo -e "${BLUE}-> Activando servicio (Usuario)...${NC}"
    systemctl --user daemon-reload
    systemctl --user enable --now ip-monitor.timer
    
    show_success "systemctl --user status ip-monitor.timer"

else
    # Fallo en modo usuario, ofrecer modo sistema
    echo -e "${YELLOW}   Aviso: No se puede acceder a systemd --user (común en entornos sin sesión gráfica).${NC}"
    read -p "¿Intentar instalar como servicio del sistema (requiere sudo)? (s/n): " INSTALL_SYSTEM
    
    if [[ "$INSTALL_SYSTEM" =~ ^[Ss]$ ]]; then
        echo -e "${BLUE}-> Solicitando permisos de superusuario...${NC}"
        
        # Añadir User=current_user al servicio para que pueda leer la config (que es 600)
        # Solo si no existe ya
        if ! grep -q "User=" "$SERVICE_FILE"; then
            sed -i "/\[Service\]/a User=$USER" "$SERVICE_FILE"
        fi
        
        sudo cp "$SERVICE_FILE" /etc/systemd/system/
        sudo cp "$TIMER_FILE" /etc/systemd/system/
        
        echo -e "${BLUE}-> Activando servicio (Sistema)...${NC}"
        sudo systemctl daemon-reload
        sudo systemctl enable --now ip-monitor.timer
        
        show_success "systemctl status ip-monitor.timer"
    else
        echo -e "${RED}Instalación automática cancelada.${NC}"
        echo -e "Alternativa manual (Crontab):"
        echo -e "1. Ejecuta: crontab -e"
        echo -e "2. Añade la línea: */5 * * * * $INSTALL_DIR/NotificarCambioIP.sh"
    fi
fi
