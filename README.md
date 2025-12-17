# Monitor de IP Pública con Notificación a Telegram

Este proyecto es la solución ideal para **servidores domésticos, Raspberry Pi o equipos de oficina** que funcionan con conexiones de fibra/ADSL estándar (IP Dinámica).

Si necesitas realizar conexiones remotas a tu equipo (SSH, VPN, Escritorio Remoto) o consultar servicios dentro de tu red local desde el exterior, un cambio inesperado de IP por parte de tu operador te dejaría incomunicado. Este script soluciona ese problema monitorizando tu conexión y enviando una **notificación instantánea a Telegram** con la nueva dirección en cuanto se detecta un cambio, garantizando que siempre sepas "dónde" está tu equipo sin pagar por una IP estática ni depender de servicios DDNS externos.

## 📋 Requisitos Previos

*   **Sistema Operativo:** Linux (Ubuntu, Debian, CentOS, Raspbian, etc.)
*   **Herramientas:** `bash`, `curl`.
*   **Telegram:** Un Bot de Telegram y tu Chat ID.

## 📂 Estructura de Archivos

*   `install.sh`: **Script de Instalación**. Automatiza despliegue y configuración.
*   `NotificarCambioIP.sh`: **Script Principal**. Lógica de detección y envío.
*   `config.cfg`: **Configuración**. Credenciales de Telegram.
*   `ip-monitor.service` / `ip-monitor.timer`: Archivos para la automatización con Systemd.

---

## 🚀 Opción 1: Instalación Automática (Recomendado)

El instalador se encarga de todo: copiar archivos, permisos, servicios Systemd e incluso **configurar tu Bot de Telegram interactivamente**.

1.  **Ejecutar el instalador:**
    ```bash
    chmod +x install.sh
    ./install.sh
    ```
2.  **Asistente de Configuración:**
    Durante la instalación, el script te preguntará si quieres configurar Telegram.
    *   Introduce el **Token** de tu bot (de @BotFather).
    *   El script intentará detectar tu **Chat ID** automáticamente (debes enviar un mensaje "Hola" al bot primero).
    *   Introduce un **Nombre identificador** para el equipo (ej: "Servidor Ubuntu", "PC Casa"). Este aparecerá en el título de las alertas.

*(Por defecto se instalará en `~/Programas/Scripts/IpNotifier`, pero puedes elegir otra ruta durante el proceso).*

### ⚠️ Nota sobre entornos SSH / Sin Entorno Gráfico

Si instalas este script en un servidor remoto vía **SSH** o en un sistema sin escritorio (headless), es posible que veas errores como `Failed to connect to bus` al intentar activar el servicio de usuario.

Esto ocurre porque `systemctl --user` requiere una sesión de D-Bus activa, que a menudo no existe en conexiones remotas puras.

**Solución:**
El instalador detectará esta situación (o te permitirá elegir) y procederá a una **instalación a nivel de sistema**. En este caso:
*   Te pedirá tu contraseña de `sudo`.
*   Los servicios se instalarán en `/etc/systemd/system/`.
*   El servicio se ejecutará con tu usuario (para leer la configuración correctamente) pero gestionado por el sistema global.

---

## 🛠 Opción 2: Instalación Manual

Si deseas tener un control total sobre el proceso:

1.  **Crear directorio y copiar archivos:**
    ```bash
    mkdir -p ~/Programas/Scripts/IpNotifier
    cp NotificarCambioIP.sh config.cfg ip-monitor.service ip-monitor.timer ~/Programas/Scripts/IpNotifier/
    cd ~/Programas/Scripts/IpNotifier
    ```

2.  **Configurar permisos:**
    ```bash
    chmod +x NotificarCambioIP.sh
    chmod 600 config.cfg
    ```

3.  **Configuración de Telegram (Manual):**
    Edita `config.cfg` y rellena `TELEGRAM_TOKEN`, `TELEGRAM_CHAT_ID` y `ALERTA_PREFIJO` manualmente.

4.  **Vincular con Systemd:**
    Asegúrate de que `ip-monitor.service` tiene la ruta correcta en `ExecStart` y ejecuta:
    ```bash
    mkdir -p ~/.config/systemd/user/
    ln -sf $(pwd)/ip-monitor.service ~/.config/systemd/user/
    ln -sf $(pwd)/ip-monitor.timer ~/.config/systemd/user/
    systemctl --user daemon-reload
    systemctl --user enable --now ip-monitor.timer
    ```

---

## 💬 Obtención de Credenciales (Modo Manual)

Si no usaste el asistente automático, aquí tienes cómo obtener los datos:

### 1. Obtener el Token del Bot
1.  Busca a **@BotFather** en Telegram.
2.  Envía el comando `/newbot` y sigue las instrucciones.
3.  Copia el **API Token** en el archivo `config.cfg`.

### 2. Obtener tu Chat ID
1.  Busca tu bot en Telegram e inícialo (`/start`).
2.  Envíale un mensaje (ej. "Hola").
3.  Busca al bot **@userinfobot**, inícialo y te dará tu ID numérico.
4.  Copia este número en `config.cfg`.

---

## 📊 Gestión y Logs

*   **Ver próxima ejecución:** `systemctl --user status ip-monitor.timer`
*   **Ver actividad:** `journalctl --user -u ip-monitor -f`
*   **Pausar:** `systemctl --user stop ip-monitor.timer`
*   **Reanudar:** `systemctl --user start ip-monitor.timer`

---

## 📦 Despliegue en otros equipos

Si dispones del archivo empaquetado `IpNotifier_Installer.tar.gz`:

1.  Cópialo al equipo destino.
2.  Descomprime e instala:
    ```bash
    mkdir InstaladorIP
    tar -xzvf IpNotifier_Installer.tar.gz -C InstaladorIP
    cd InstaladorIP
    chmod +x install.sh
    ./install.sh
    ```
