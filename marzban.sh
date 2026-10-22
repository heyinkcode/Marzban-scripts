#!/usr/bin/env bash
set -e

INSTALL_DIR="/opt"
if [ -z "$APP_NAME" ]; then
    APP_NAME="marzban"
fi
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"
# Keep the external-core maintenance command on the same version used by the
# repository Docker image. A deliberate XRAY_CORE_VERSION environment override
# is still possible for an isolated test, but production must use this pin.
XRAY_CORE_VERSION="${XRAY_CORE_VERSION:-v26.3.27}"

colorized_echo() {
    local color=$1
    local text=$2
    
    case $color in
        "red")
        printf "\e[91m${text}\e[0m\n";;
        "green")
        printf "\e[92m${text}\e[0m\n";;
        "yellow")
        printf "\e[93m${text}\e[0m\n";;
        "blue")
        printf "\e[94m${text}\e[0m\n";;
        "magenta")
        printf "\e[95m${text}\e[0m\n";;
        "cyan")
        printf "\e[96m${text}\e[0m\n";;
        *)
            echo "${text}"
        ;;
    esac
}

check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "This command must be run as root."
        exit 1
    fi
}

detect_os() {
    # Detect the operating system
    if [ -f /etc/lsb-release ]; then
        OS=$(lsb_release -si)
    elif [ -f /etc/os-release ]; then
        OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
    elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | awk '{print $1}')
    elif [ -f /etc/arch-release ]; then
        OS="Arch"
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}


detect_and_update_package_manager() {
    colorized_echo blue "Updating package manager"
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        PKG_MANAGER="apt-get"
        $PKG_MANAGER update
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        PKG_MANAGER="yum"
        $PKG_MANAGER update -y
        $PKG_MANAGER install -y epel-release
    elif [ "$OS" == "Fedora"* ]; then
        PKG_MANAGER="dnf"
        $PKG_MANAGER update
    elif [ "$OS" == "Arch" ]; then
        PKG_MANAGER="pacman"
        $PKG_MANAGER -Sy
    elif [[ "$OS" == "openSUSE"* ]]; then
        PKG_MANAGER="zypper"
        $PKG_MANAGER refresh
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

install_package () {
    if [ -z $PKG_MANAGER ]; then
        detect_and_update_package_manager
    fi
    
    PACKAGE=$1
    colorized_echo blue "Installing $PACKAGE"
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        $PKG_MANAGER -y install "$PACKAGE"
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        $PKG_MANAGER install -y "$PACKAGE"
    elif [ "$OS" == "Fedora"* ]; then
        $PKG_MANAGER install -y "$PACKAGE"
    elif [ "$OS" == "Arch" ]; then
        $PKG_MANAGER -S --noconfirm "$PACKAGE"
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

install_docker() {
    # Install Docker and Docker Compose using the official installation script
    colorized_echo blue "Installing Docker"
    curl -fsSL https://get.docker.com | sh
    colorized_echo green "Docker installed successfully"
}

detect_compose() {
    # Check if docker compose command exists
    if docker compose version >/dev/null 2>&1; then
        COMPOSE='docker compose'
    elif docker-compose version >/dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        colorized_echo red "docker compose not found"
        exit 1
    fi
}

install_marzban_script() {
    FETCH_REPO="heyinkcode/Marzban-scripts"
    SCRIPT_URL="https://raw.githubusercontent.com/$FETCH_REPO/master/marzban.sh"
    colorized_echo blue "Installing marzban script"
    local script_file
    script_file=$(mktemp)
    if ! curl -fsSL "$SCRIPT_URL" -o "$script_file"; then
        rm -f "$script_file"
        colorized_echo red "Unable to fetch the Mr.shaw Marzban script."
        return 1
    fi
    install -m 755 "$script_file" /usr/local/bin/marzban
    rm -f "$script_file"
    colorized_echo green "marzban script installed successfully"
}

is_marzban_installed() {
    if [ -d $APP_DIR ]; then
        return 0
    else
        return 1
    fi
}

identify_the_operating_system_and_architecture() {
    if [[ "$(uname)" == 'Linux' ]]; then
        case "$(uname -m)" in
            'i386' | 'i686')
                ARCH='32'
            ;;
            'amd64' | 'x86_64')
                ARCH='64'
            ;;
            'armv5tel')
                ARCH='arm32-v5'
            ;;
            'armv6l')
                ARCH='arm32-v6'
                grep Features /proc/cpuinfo | grep -qw 'vfp' || ARCH='arm32-v5'
            ;;
            'armv7' | 'armv7l')
                ARCH='arm32-v7a'
                grep Features /proc/cpuinfo | grep -qw 'vfp' || ARCH='arm32-v5'
            ;;
            'armv8' | 'aarch64')
                ARCH='arm64-v8a'
            ;;
            'mips')
                ARCH='mips32'
            ;;
            'mipsle')
                ARCH='mips32le'
            ;;
            'mips64')
                ARCH='mips64'
                lscpu | grep -q "Little Endian" && ARCH='mips64le'
            ;;
            'mips64le')
                ARCH='mips64le'
            ;;
            'ppc64')
                ARCH='ppc64'
            ;;
            'ppc64le')
                ARCH='ppc64le'
            ;;
            'riscv64')
                ARCH='riscv64'
            ;;
            's390x')
                ARCH='s390x'
            ;;
            *)
                echo "error: The architecture is not supported."
                exit 1
            ;;
        esac
    else
        echo "error: This operating system is not supported."
        exit 1
    fi
}

send_backup_to_telegram() {
    if [ -f "$ENV_FILE" ]; then
        while IFS='=' read -r key value; do
            if [[ -z "$key" || "$key" =~ ^# ]]; then
                continue
            fi
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            if [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                export "$key"="$value"
            else
                colorized_echo yellow "Skipping invalid line in .env: $key=$value"
            fi
        done < "$ENV_FILE"
    else
        colorized_echo red "Environment file (.env) not found."
        exit 1
    fi

    if [ "$BACKUP_SERVICE_ENABLED" != "true" ]; then
        colorized_echo yellow "Backup service is not enabled. Skipping Telegram upload."
        return
    fi

    local server_ip=$(curl -s ifconfig.me || echo "Unknown IP")
    local latest_backup=$(ls -t "$APP_DIR/backup" | head -n 1)
    local backup_path="$APP_DIR/backup/$latest_backup"

    if [ ! -f "$backup_path" ]; then
        colorized_echo red "No backups found to send."
        return
    fi

    local backup_size=$(du -m "$backup_path" | cut -f1)
    local split_dir="/tmp/marzban_backup_split"
    local is_single_file=true

    mkdir -p "$split_dir"

    if [ "$backup_size" -gt 49 ]; then
        colorized_echo yellow "Backup is larger than 49MB. Splitting the archive..."
        split -b 49M "$backup_path" "$split_dir/part_"
        is_single_file=false
    else
        cp "$backup_path" "$split_dir/part_aa"
    fi


    local backup_time=$(date "+%Y-%m-%d %H:%M:%S %Z")


    for part in "$split_dir"/*; do
        local part_name=$(basename "$part")
        local custom_filename="backup_${part_name}.tar.gz"
        local caption="📦 *Backup Information*\n🌐 *Server IP*: \`${server_ip}\`\n📁 *Backup File*: \`${custom_filename}\`\n⏰ *Backup Time*: \`${backup_time}\`"
        curl -s -F chat_id="$BACKUP_TELEGRAM_CHAT_ID" \
            -F document=@"$part;filename=$custom_filename" \
            -F caption="$(echo -e "$caption" | sed 's/-/\\-/g;s/\./\\./g;s/_/\\_/g')" \
            -F parse_mode="MarkdownV2" \
            "https://api.telegram.org/bot$BACKUP_TELEGRAM_BOT_KEY/sendDocument" >/dev/null 2>&1 && \
        colorized_echo green "Backup part $custom_filename successfully sent to Telegram." || \
        colorized_echo red "Failed to send backup part $custom_filename to Telegram."
    done

    rm -rf "$split_dir"
}

send_backup_error_to_telegram() {
    local error_messages=$1
    local log_file=$2
    local server_ip=$(curl -s ifconfig.me || echo "Unknown IP")
    local error_time=$(date "+%Y-%m-%d %H:%M:%S %Z")
    local message="⚠️ *Backup Error Notification*\n"
    message+="🌐 *Server IP*: \`${server_ip}\`\n"
    message+="❌ *Errors*:\n\`${error_messages//_/\\_}\`\n"
    message+="⏰ *Time*: \`${error_time}\`"


    message=$(echo -e "$message" | sed 's/-/\\-/g;s/\./\\./g;s/_/\\_/g;s/(/\\(/g;s/)/\\)/g')

    local max_length=1000
    if [ ${#message} -gt $max_length ]; then
        message="${message:0:$((max_length - 50))}...\n\`[Message truncated]\`"
    fi


    curl -s -X POST "https://api.telegram.org/bot$BACKUP_TELEGRAM_BOT_KEY/sendMessage" \
        -d chat_id="$BACKUP_TELEGRAM_CHAT_ID" \
        -d parse_mode="MarkdownV2" \
        -d text="$message" >/dev/null 2>&1 && \
    colorized_echo green "Backup error notification sent to Telegram." || \
    colorized_echo red "Failed to send error notification to Telegram."


    if [ -f "$log_file" ]; then
        response=$(curl -s -w "%{http_code}" -o /tmp/tg_response.json \
            -F chat_id="$BACKUP_TELEGRAM_CHAT_ID" \
            -F document=@"$log_file;filename=backup_error.log" \
            -F caption="📜 *Backup Error Log* - ${error_time}" \
            "https://api.telegram.org/bot$BACKUP_TELEGRAM_BOT_KEY/sendDocument")

        http_code="${response:(-3)}"
        if [ "$http_code" -eq 200 ]; then
            colorized_echo green "Backup error log sent to Telegram."
        else
            colorized_echo red "Failed to send backup error log to Telegram. HTTP code: $http_code"
            cat /tmp/tg_response.json
        fi
    else
        colorized_echo red "Log file not found: $log_file"
    fi
}





backup_service() {
    local telegram_bot_key=""
    local telegram_chat_id=""
    local cron_schedule=""
    local interval_hours=""

    colorized_echo blue "====================================="
    colorized_echo blue "      Welcome to Backup Service      "
    colorized_echo blue "====================================="

    if grep -q "BACKUP_SERVICE_ENABLED=true" "$ENV_FILE"; then
        telegram_bot_key=$(awk -F'=' '/^BACKUP_TELEGRAM_BOT_KEY=/ {print $2}' "$ENV_FILE")
        telegram_chat_id=$(awk -F'=' '/^BACKUP_TELEGRAM_CHAT_ID=/ {print $2}' "$ENV_FILE")
        cron_schedule=$(awk -F'=' '/^BACKUP_CRON_SCHEDULE=/ {print $2}' "$ENV_FILE" | tr -d '"')

        if [[ "$cron_schedule" == "0 0 * * *" ]]; then
            interval_hours=24
        else
            interval_hours=$(echo "$cron_schedule" | grep -oP '(?<=\*/)[0-9]+')
        fi

        colorized_echo green "====================================="
        colorized_echo green "Current Backup Configuration:"
        colorized_echo cyan "Telegram Bot API Key: $telegram_bot_key"
        colorized_echo cyan "Telegram Chat ID: $telegram_chat_id"
        colorized_echo cyan "Backup Interval: Every $interval_hours hour(s)"
        colorized_echo green "====================================="
        echo "Choose an option:"
        echo "1. Reconfigure Backup Service"
        echo "2. Remove Backup Service"
        echo "3. Exit"
        read -p "Enter your choice (1-3): " user_choice

        case $user_choice in
            1)
                colorized_echo yellow "Starting reconfiguration..."
                remove_backup_service
                ;;
            2)
                colorized_echo yellow "Removing Backup Service..."
                remove_backup_service
                return
                ;;
            3)
                colorized_echo yellow "Exiting..."
                return
                ;;
            *)
                colorized_echo red "Invalid choice. Exiting."
                return
                ;;
        esac
    else
        colorized_echo yellow "No backup service is currently configured."
    fi

    while true; do
        printf "Enter your Telegram bot API key: "
        read telegram_bot_key
        if [[ -n "$telegram_bot_key" ]]; then
            break
        else
            colorized_echo red "API key cannot be empty. Please try again."
        fi
    done

    while true; do
        printf "Enter your Telegram chat ID: "
        read telegram_chat_id
        if [[ -n "$telegram_chat_id" ]]; then
            break
        else
            colorized_echo red "Chat ID cannot be empty. Please try again."
        fi
    done

    while true; do
        printf "Set up the backup interval in hours (1-24):\n"
        read interval_hours

        if ! [[ "$interval_hours" =~ ^[0-9]+$ ]]; then
            colorized_echo red "Invalid input. Please enter a valid number."
            continue
        fi

        if [[ "$interval_hours" -eq 24 ]]; then
            cron_schedule="0 0 * * *"
            colorized_echo green "Setting backup to run daily at midnight."
            break
        fi

        if [[ "$interval_hours" -ge 1 && "$interval_hours" -le 23 ]]; then
            cron_schedule="0 */$interval_hours * * *"
            colorized_echo green "Setting backup to run every $interval_hours hour(s)."
            break
        else
            colorized_echo red "Invalid input. Please enter a number between 1-24."
        fi
    done

    sed -i '/^BACKUP_SERVICE_ENABLED/d' "$ENV_FILE"
    sed -i '/^BACKUP_TELEGRAM_BOT_KEY/d' "$ENV_FILE"
    sed -i '/^BACKUP_TELEGRAM_CHAT_ID/d' "$ENV_FILE"
    sed -i '/^BACKUP_CRON_SCHEDULE/d' "$ENV_FILE"

    {
        echo ""
        echo "# Backup service configuration"
        echo "BACKUP_SERVICE_ENABLED=true"
        echo "BACKUP_TELEGRAM_BOT_KEY=$telegram_bot_key"
        echo "BACKUP_TELEGRAM_CHAT_ID=$telegram_chat_id"
        echo "BACKUP_CRON_SCHEDULE=\"$cron_schedule\""
    } >> "$ENV_FILE"

    colorized_echo green "Backup service configuration saved in $ENV_FILE."

    local backup_command="$(which bash) -c '$APP_NAME backup'"
    add_cron_job "$cron_schedule" "$backup_command"

    colorized_echo green "Backup service successfully configured."
    if [[ "$interval_hours" -eq 24 ]]; then
        colorized_echo cyan "Backups will be sent to Telegram daily (every 24 hours at midnight)."
    else
        colorized_echo cyan "Backups will be sent to Telegram every $interval_hours hour(s)."
    fi
    colorized_echo green "====================================="
}


add_cron_job() {
    local schedule="$1"
    local command="$2"
    local temp_cron=$(mktemp)

    crontab -l 2>/dev/null > "$temp_cron" || true
    grep -v "$command" "$temp_cron" > "${temp_cron}.tmp" && mv "${temp_cron}.tmp" "$temp_cron"
    echo "$schedule $command # marzban-backup-service" >> "$temp_cron"
    
    if crontab "$temp_cron"; then
        colorized_echo green "Cron job successfully added."
    else
        colorized_echo red "Failed to add cron job. Please check manually."
    fi
    rm -f "$temp_cron"
}

remove_backup_service() {
    colorized_echo red "in process..."


    sed -i '/^# Backup service configuration/d' "$ENV_FILE"
    sed -i '/BACKUP_SERVICE_ENABLED/d' "$ENV_FILE"
    sed -i '/BACKUP_TELEGRAM_BOT_KEY/d' "$ENV_FILE"
    sed -i '/BACKUP_TELEGRAM_CHAT_ID/d' "$ENV_FILE"
    sed -i '/BACKUP_CRON_SCHEDULE/d' "$ENV_FILE"

    local temp_cron=$(mktemp)
    crontab -l 2>/dev/null > "$temp_cron"

    sed -i '/# marzban-backup-service/d' "$temp_cron"

    if crontab "$temp_cron"; then
        colorized_echo green "Backup service task removed from crontab."
    else
        colorized_echo red "Failed to update crontab. Please check manually."
    fi

    rm -f "$temp_cron"

    colorized_echo green "Backup service has been removed."
}

backup_command() {
    local backup_dir="$APP_DIR/backup"
    local temp_dir
    temp_dir=$(mktemp -d /tmp/marzban_backup.XXXXXXXX)
    local timestamp=$(date +"%Y%m%d%H%M%S")
    local backup_file="$backup_dir/backup_$timestamp.tar.gz"
    local error_messages=()
    local log_file="/var/log/marzban_backup_error.log"
    > "$log_file"
    echo "Backup Log - $(date)" > "$log_file"

    if ! command -v rsync >/dev/null 2>&1; then
        detect_os
        install_package rsync
    fi

    mkdir -p -m 700 "$backup_dir"

    if [ -f "$ENV_FILE" ]; then
        while IFS='=' read -r key value; do
            if [[ -z "$key" || "$key" =~ ^# ]]; then
                continue
            fi
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            if [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                export "$key"="$value"
            else
                echo "Skipping invalid line in .env: $key=$value" >> "$log_file"
            fi
        done < "$ENV_FILE"
    else
        error_messages+=("Environment file (.env) not found.")
        echo "Environment file (.env) not found." >> "$log_file"
        send_backup_error_to_telegram "${error_messages[*]}" "$log_file"
        exit 1
    fi

    local db_type=""
    local sqlite_file=""
    if grep -q "image: mariadb" "$COMPOSE_FILE"; then
        db_type="mariadb"
        container_name=$(docker compose -f "$COMPOSE_FILE" ps -q mariadb || echo "mariadb")

    elif grep -q "image: mysql" "$COMPOSE_FILE"; then
        db_type="mysql"
        container_name=$(docker compose -f "$COMPOSE_FILE" ps -q mysql || echo "mysql")

    elif grep -q "SQLALCHEMY_DATABASE_URL = .*sqlite" "$ENV_FILE"; then
        db_type="sqlite"
        sqlite_file=$(grep -Po '(?<=SQLALCHEMY_DATABASE_URL = "sqlite:////).*"' "$ENV_FILE" | tr -d '"')
        if [[ ! "$sqlite_file" =~ ^/ ]]; then
            sqlite_file="/$sqlite_file"
        fi

    fi

    if [ -n "$db_type" ]; then
        echo "Database detected: $db_type" >> "$log_file"
        case $db_type in
            mariadb)
                if ! docker exec "$container_name" mariadb-dump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases --ignore-database=mysql --ignore-database=performance_schema --ignore-database=information_schema --ignore-database=sys --events --triggers > "$temp_dir/db_backup.sql" 2>>"$log_file"; then
                    error_messages+=("MariaDB dump failed.")
                fi
                ;;
            mysql)
                if ! docker exec "$container_name" mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" marzban --events --triggers  > "$temp_dir/db_backup.sql" 2>>"$log_file"; then
                    error_messages+=("MySQL dump failed.")
                fi
                ;;
            sqlite)
                if [ -f "$sqlite_file" ]; then
                    if ! cp "$sqlite_file" "$temp_dir/db_backup.sqlite" 2>>"$log_file"; then
                        error_messages+=("Failed to copy SQLite database.")
                    fi
                else
                    error_messages+=("SQLite database file not found at $sqlite_file.")
                fi
                ;;
        esac
    fi

    cp "$APP_DIR/.env" "$temp_dir/" 2>>"$log_file"
    cp "$APP_DIR/docker-compose.yml" "$temp_dir/" 2>>"$log_file"
    rsync -av --exclude 'xray-core' --exclude 'mysql' "$DATA_DIR/" "$temp_dir/marzban_data/" >>"$log_file" 2>&1

    if ! tar -czf "$backup_file" -C "$temp_dir" .; then
        error_messages+=("Failed to create backup archive.")
        echo "Failed to create backup archive." >> "$log_file"
    fi

    rm -rf "$temp_dir"

    if [ ${#error_messages[@]} -gt 0 ]; then
        send_backup_error_to_telegram "${error_messages[*]}" "$log_file"
        return
    fi
    colorized_echo green "Backup created: $backup_file"
    send_backup_to_telegram "$backup_file"
}



get_xray_core() {
    identify_the_operating_system_and_architecture
    local selected_version="${XRAY_CORE_VERSION}"
    if [[ ! "$selected_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        colorized_echo red "Invalid pinned Xray version: $selected_version"
        exit 1
    fi
    colorized_echo green "Using repository-pinned Xray-core ${selected_version}."

    # Check if the required packages are installed
    if ! command -v unzip >/dev/null 2>&1; then
        echo -e "\033[1;33mInstalling required packages...\033[0m"
        detect_os
        install_package unzip
    fi
    if ! command -v wget >/dev/null 2>&1; then
        echo -e "\033[1;33mInstalling required packages...\033[0m"
        detect_os
        install_package wget
    fi

    mkdir -p $DATA_DIR/xray-core
    cd $DATA_DIR/xray-core

    xray_filename="Xray-linux-$ARCH.zip"
    xray_download_url="https://github.com/XTLS/Xray-core/releases/download/${selected_version}/${xray_filename}"

    echo -e "\033[1;33mDownloading Xray-core version ${selected_version}...\033[0m"
    wget -q --show-progress -O "${xray_filename}" "${xray_download_url}"

    echo -e "\033[1;33mExtracting Xray-core...\033[0m"
    unzip -o "${xray_filename}" >/dev/null 2>&1
    rm "${xray_filename}"

    local actual_version
    actual_version="$("$DATA_DIR/xray-core/xray" -version 2>/dev/null | awk 'NR == 1 { print $2 }')"
    if [[ "$actual_version" != "${selected_version#v}" ]]; then
        colorized_echo red "Downloaded Xray-core version ${actual_version:-unknown} does not match ${selected_version}."
        exit 1
    fi
    colorized_echo green "Verified Xray-core version ${selected_version}."
}

# Function to update the Marzban Main core
update_core_command() {
    check_running_as_root
    get_xray_core
    # Change the Marzban core
    xray_executable_path="XRAY_EXECUTABLE_PATH=\"/var/lib/marzban/xray-core/xray\""
    
    echo "Changing the Marzban core..."
    # Check if the XRAY_EXECUTABLE_PATH string already exists in the .env file
    if ! grep -q "^XRAY_EXECUTABLE_PATH=" "$ENV_FILE"; then
        # If the string does not exist, add it
        echo "${xray_executable_path}" >> "$ENV_FILE"
    else
        # Update the existing XRAY_EXECUTABLE_PATH line
        sed -i "s~^XRAY_EXECUTABLE_PATH=.*~${xray_executable_path}~" "$ENV_FILE"
    fi
    
    # Restart Marzban
    colorized_echo red "Restarting Marzban..."
    if restart_command -n >/dev/null 2>&1; then
        colorized_echo green "Marzban successfully restarted!"
    else
        colorized_echo red "Marzban restart failed!"
    fi
    colorized_echo blue "Installation of Xray-core version ${XRAY_CORE_VERSION} completed."
}

install_marzban() {
    local marzban_version=$1
    local database_type=$2
    # Fetch releases
    FILES_URL_PREFIX="https://raw.githubusercontent.com/heyinkcode/Marzban/master"
    
    mkdir -p "$DATA_DIR"
    mkdir -p "$APP_DIR"
    
    colorized_echo blue "Setting up docker-compose.yml"
    docker_file_path="$APP_DIR/docker-compose.yml"
    
    if [ "$database_type" == "mariadb" ]; then
        # Generate docker-compose.yml with MariaDB content
        cat > "$docker_file_path" <<EOF
services:
  marzban:
    image: ghcr.io/heyinkcode/marzban:${marzban_version}
    restart: always
    env_file: .env
    network_mode: host
    volumes:
      - /var/lib/marzban:/var/lib/marzban
      - /var/lib/marzban/logs:/var/lib/marzban-node
    depends_on:
      mariadb:
        condition: service_healthy

  mariadb:
    image: mariadb:lts
    env_file: .env
    network_mode: host
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      MYSQL_ROOT_HOST: '%'
      MYSQL_DATABASE: \${MYSQL_DATABASE}
      MYSQL_USER: \${MYSQL_USER}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
    command:
      - --bind-address=127.0.0.1                  # Restricts access to localhost for increased security
      - --character_set_server=utf8mb4            # Sets UTF-8 character set for full Unicode support
      - --collation_server=utf8mb4_unicode_ci     # Defines collation for Unicode
      - --host-cache-size=0                       # Disables host cache to prevent DNS issues
      - --innodb-open-files=1024                  # Sets the limit for InnoDB open files
      - --innodb-buffer-pool-size=256M            # Allocates buffer pool size for InnoDB
      - --binlog_expire_logs_seconds=1209600      # Sets binary log expiration to 14 days (2 weeks)
      - --innodb-log-file-size=64M                # Sets InnoDB log file size to balance log retention and performance
      - --innodb-log-files-in-group=2             # Uses two log files to balance recovery and disk I/O
      - --innodb-doublewrite=0                    # Disables doublewrite buffer (reduces disk I/O; may increase data loss risk)
      - --general_log=0                           # Disables general query log to reduce disk usage
      - --slow_query_log=1                        # Enables slow query log for identifying performance issues
      - --slow_query_log_file=/var/lib/mysql/slow.log # Logs slow queries for troubleshooting
      - --long_query_time=2                       # Defines slow query threshold as 2 seconds
    volumes:
      - /var/lib/marzban/mysql:/var/lib/mysql
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      start_period: 10s
      start_interval: 3s
      interval: 10s
      timeout: 5s
      retries: 3
EOF
        echo "----------------------------"
        colorized_echo red "Using MariaDB as database"
        echo "----------------------------"
        colorized_echo green "File generated at $APP_DIR/docker-compose.yml"

        # Modify .env file
        colorized_echo blue "Fetching .env file"
        curl -sL "$FILES_URL_PREFIX/.env.example" -o "$APP_DIR/.env"

        # Comment out the SQLite line
        sed -i 's~^\(SQLALCHEMY_DATABASE_URL = "sqlite:////var/lib/marzban/db.sqlite3"\)~#\1~' "$APP_DIR/.env"


        # Add the MySQL connection string
        #echo -e '\nSQLALCHEMY_DATABASE_URL = "mysql+pymysql://marzban:password@127.0.0.1:3306/marzban"' >> "$APP_DIR/.env"

        sed -i 's/^# \(XRAY_JSON = .*\)$/\1/' "$APP_DIR/.env"
        sed -i 's~\(XRAY_JSON = \).*~\1"/var/lib/marzban/xray_config.json"~' "$APP_DIR/.env"


        prompt_for_marzban_password
        MYSQL_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
        
        echo "" >> "$ENV_FILE"
        echo "" >> "$ENV_FILE"
        echo "# Database configuration" >> "$ENV_FILE"
        echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" >> "$ENV_FILE"
        echo "MYSQL_DATABASE=marzban" >> "$ENV_FILE"
        echo "MYSQL_USER=marzban" >> "$ENV_FILE"
        echo "MYSQL_PASSWORD=$MYSQL_PASSWORD" >> "$ENV_FILE"
        
        SQLALCHEMY_DATABASE_URL="mysql+pymysql://marzban:${MYSQL_PASSWORD}@127.0.0.1:3306/marzban"
        
        echo "" >> "$ENV_FILE"
        echo "# SQLAlchemy Database URL" >> "$ENV_FILE"
        echo "SQLALCHEMY_DATABASE_URL=\"$SQLALCHEMY_DATABASE_URL\"" >> "$ENV_FILE"
        
        colorized_echo green "File saved in $APP_DIR/.env"

    elif [ "$database_type" == "mysql" ]; then
        # Generate docker-compose.yml with MySQL content
        cat > "$docker_file_path" <<EOF
services:
  marzban:
    image: ghcr.io/heyinkcode/marzban:${marzban_version}
    restart: always
    env_file: .env
    network_mode: host
    volumes:
      - /var/lib/marzban:/var/lib/marzban
      - /var/lib/marzban/logs:/var/lib/marzban-node
    depends_on:
      mysql:
        condition: service_healthy

  mysql:
    image: mysql:lts
    env_file: .env
    network_mode: host
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      MYSQL_ROOT_HOST: '%'
      MYSQL_DATABASE: \${MYSQL_DATABASE}
      MYSQL_USER: \${MYSQL_USER}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
    command:
      - --mysqlx=OFF                             # Disables MySQL X Plugin to save resources if X Protocol isn't used
      - --bind-address=127.0.0.1                  # Restricts access to localhost for increased security
      - --character_set_server=utf8mb4            # Sets UTF-8 character set for full Unicode support
      - --collation_server=utf8mb4_unicode_ci     # Defines collation for Unicode
      - --log-bin=mysql-bin                       # Enables binary logging for point-in-time recovery
      - --binlog_expire_logs_seconds=1209600      # Sets binary log expiration to 14 days
      - --host-cache-size=0                       # Disables host cache to prevent DNS issues
      - --innodb-open-files=1024                  # Sets the limit for InnoDB open files
      - --innodb-buffer-pool-size=256M            # Allocates buffer pool size for InnoDB
      - --innodb-log-file-size=64M                # Sets InnoDB log file size to balance log retention and performance
      - --innodb-log-files-in-group=2             # Uses two log files to balance recovery and disk I/O
      - --general_log=0                           # Disables general query log for lower disk usage
      - --slow_query_log=1                        # Enables slow query log for performance analysis
      - --slow_query_log_file=/var/lib/mysql/slow.log # Logs slow queries for troubleshooting
      - --long_query_time=2                       # Defines slow query threshold as 2 seconds
    volumes:
      - /var/lib/marzban/mysql:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1", "-u", "marzban", "--password=\${MYSQL_PASSWORD}"]
      start_period: 5s
      interval: 5s
      timeout: 5s
      retries: 55
      
EOF
        echo "----------------------------"
        colorized_echo red "Using MySQL as database"
        echo "----------------------------"
        colorized_echo green "File generated at $APP_DIR/docker-compose.yml"

        # Modify .env file
        colorized_echo blue "Fetching .env file"
        curl -sL "$FILES_URL_PREFIX/.env.example" -o "$APP_DIR/.env"

        # Comment out the SQLite line
        sed -i 's~^\(SQLALCHEMY_DATABASE_URL = "sqlite:////var/lib/marzban/db.sqlite3"\)~#\1~' "$APP_DIR/.env"


        # Add the MySQL connection string
        #echo -e '\nSQLALCHEMY_DATABASE_URL = "mysql+pymysql://marzban:password@127.0.0.1:3306/marzban"' >> "$APP_DIR/.env"

        sed -i 's/^# \(XRAY_JSON = .*\)$/\1/' "$APP_DIR/.env"
        sed -i 's~\(XRAY_JSON = \).*~\1"/var/lib/marzban/xray_config.json"~' "$APP_DIR/.env"


        prompt_for_marzban_password
        MYSQL_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
        
        echo "" >> "$ENV_FILE"
        echo "" >> "$ENV_FILE"
        echo "# Database configuration" >> "$ENV_FILE"
        echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" >> "$ENV_FILE"
        echo "MYSQL_DATABASE=marzban" >> "$ENV_FILE"
        echo "MYSQL_USER=marzban" >> "$ENV_FILE"
        echo "MYSQL_PASSWORD=$MYSQL_PASSWORD" >> "$ENV_FILE"
        
        SQLALCHEMY_DATABASE_URL="mysql+pymysql://marzban:${MYSQL_PASSWORD}@127.0.0.1:3306/marzban"
        
        echo "" >> "$ENV_FILE"
        echo "# SQLAlchemy Database URL" >> "$ENV_FILE"
        echo "SQLALCHEMY_DATABASE_URL=\"$SQLALCHEMY_DATABASE_URL\"" >> "$ENV_FILE"
        
        colorized_echo green "File saved in $APP_DIR/.env"

    else
        echo "----------------------------"
        colorized_echo red "Using SQLite as database"
        echo "----------------------------"
        colorized_echo blue "Fetching compose file"
        curl -sL "$FILES_URL_PREFIX/docker-compose.yml" -o "$docker_file_path"

        # Install requested version
        if [ "$marzban_version" == "latest" ]; then
            yq -i '.services.marzban.image = "ghcr.io/heyinkcode/marzban:latest"' "$docker_file_path"
        else
            yq -i ".services.marzban.image = \"ghcr.io/heyinkcode/marzban:${marzban_version}\"" "$docker_file_path"
        fi
        echo "Installing $marzban_version version"
        colorized_echo green "File saved in $APP_DIR/docker-compose.yml"


        colorized_echo blue "Fetching .env file"
        curl -sL "$FILES_URL_PREFIX/.env.example" -o "$APP_DIR/.env"

        sed -i 's/^# \(XRAY_JSON = .*\)$/\1/' "$APP_DIR/.env"
        sed -i 's/^# \(SQLALCHEMY_DATABASE_URL = .*\)$/\1/' "$APP_DIR/.env"
        sed -i 's~\(XRAY_JSON = \).*~\1"/var/lib/marzban/xray_config.json"~' "$APP_DIR/.env"
        sed -i 's~\(SQLALCHEMY_DATABASE_URL = \).*~\1"sqlite:////var/lib/marzban/db.sqlite3"~' "$APP_DIR/.env"





        
        colorized_echo green "File saved in $APP_DIR/.env"
    fi
    
    colorized_echo blue "Fetching xray config file"
    curl -sL "$FILES_URL_PREFIX/xray_config.json" -o "$DATA_DIR/xray_config.json"
    colorized_echo green "File saved in $DATA_DIR/xray_config.json"
    
    colorized_echo green "Marzban's files downloaded successfully"
}

up_marzban() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" up -d --remove-orphans
}

follow_marzban_logs() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" logs -f
}

status_command() {
    
    # Check if marzban is installed
    if ! is_marzban_installed; then
        echo -n "Status: "
        colorized_echo red "Not Installed"
        exit 1
    fi
    
    detect_compose
    
    if ! is_marzban_up; then
        echo -n "Status: "
        colorized_echo blue "Down"
        exit 1
    fi
    
    echo -n "Status: "
    colorized_echo green "Up"
    
    json=$($COMPOSE -f $COMPOSE_FILE ps -a --format=json)
    services=$(echo "$json" | jq -r 'if type == "array" then .[] else . end | .Service')
    states=$(echo "$json" | jq -r 'if type == "array" then .[] else . end | .State')
    # Print out the service names and statuses
    for i in $(seq 0 $(expr $(echo $services | wc -w) - 1)); do
        service=$(echo $services | cut -d' ' -f $(expr $i + 1))
        state=$(echo $states | cut -d' ' -f $(expr $i + 1))
        echo -n "- $service: "
        if [ "$state" == "running" ]; then
            colorized_echo green $state
        else
            colorized_echo red $state
        fi
    done
}


prompt_for_marzban_password() {
    colorized_echo cyan "This password will be used to access the database and should be strong."
    colorized_echo cyan "If you do not enter a custom password, a secure 20-character password will be generated automatically."

    # Запрашиваем ввод пароля
    read -p "Enter the password for the marzban user (or press Enter to generate a secure default password): " MYSQL_PASSWORD

    # Генерация 20-значного пароля, если пользователь оставил поле пустым
    if [ -z "$MYSQL_PASSWORD" ]; then
        MYSQL_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
        colorized_echo green "A secure password has been generated automatically."
    fi
    colorized_echo green "This password will be recorded in the .env file for future use."

    # Пауза 3 секунды перед продолжением
    sleep 3
}

install_command() {
    check_running_as_root

    # Default values
    database_type="sqlite"
    marzban_version="latest"
    marzban_version_set="false"

    # Parse options
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            --database)
                database_type="$2"
                shift 2
            ;;
            --dev)
                if [[ "$marzban_version_set" == "true" ]]; then
                    colorized_echo red "Error: Cannot use --dev and --version options simultaneously."
                    exit 1
                fi
                marzban_version="dev"
                marzban_version_set="true"
                shift
            ;;
            --version)
                if [[ "$marzban_version_set" == "true" ]]; then
                    colorized_echo red "Error: Cannot use --dev and --version options simultaneously."
                    exit 1
                fi
                marzban_version="$2"
                marzban_version_set="true"
                shift 2
            ;;
            *)
                echo "Unknown option: $1"
                exit 1
            ;;
        esac
    done

    # Check if marzban is already installed
    if is_marzban_installed; then
        colorized_echo red "Marzban is already installed at $APP_DIR. Use 'marzban adopt' once, then 'marzban update'."
        exit 1
    fi
    detect_os
    if ! command -v jq >/dev/null 2>&1; then
        install_package jq
    fi
    if ! command -v curl >/dev/null 2>&1; then
        install_package curl
    fi
    if ! command -v docker >/dev/null 2>&1; then
        install_docker
    fi
    if ! command -v yq >/dev/null 2>&1; then
        install_yq
    fi
    detect_compose
    install_marzban_script
    # Check fork tags without depending on GitHub Release objects.
    check_version_exists() {
        local version=$1
        if [ "$version" == "latest" ] || [ "$version" == "dev" ]; then
            return 0
        fi
        curl -fsS -o /dev/null "https://api.github.com/repos/heyinkcode/Marzban/git/ref/tags/$version"
    }
    # Check if the version is valid and exists
    if [[ "$marzban_version" == "latest" || "$marzban_version" == "dev" || "$marzban_version" =~ ^mrshaw-v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        if check_version_exists "$marzban_version"; then
            install_marzban "$marzban_version" "$database_type"
            echo "Installing $marzban_version version"
        else
            echo "Version $marzban_version does not exist. Please enter a valid version (e.g. v0.5.2)"
            exit 1
        fi
    else
        echo "Invalid version format. Please enter a valid version (e.g. v0.5.2)"
        exit 1
    fi
    up_marzban
    follow_marzban_logs
}

install_yq() {
    if command -v yq &>/dev/null; then
        colorized_echo green "yq is already installed."
        return
    fi

    identify_the_operating_system_and_architecture

    local base_url="https://github.com/mikefarah/yq/releases/latest/download"
    local yq_binary=""

    case "$ARCH" in
        '64' | 'x86_64')
            yq_binary="yq_linux_amd64"
            ;;
        'arm32-v7a' | 'arm32-v6' | 'arm32-v5' | 'armv7l')
            yq_binary="yq_linux_arm"
            ;;
        'arm64-v8a' | 'aarch64')
            yq_binary="yq_linux_arm64"
            ;;
        '32' | 'i386' | 'i686')
            yq_binary="yq_linux_386"
            ;;
        *)
            colorized_echo red "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    local yq_url="${base_url}/${yq_binary}"
    colorized_echo blue "Downloading yq from ${yq_url}..."

    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        colorized_echo yellow "Neither curl nor wget is installed. Attempting to install curl."
        install_package curl || {
            colorized_echo red "Failed to install curl. Please install curl or wget manually."
            exit 1
        }
    fi


    if command -v curl &>/dev/null; then
        if curl -L "$yq_url" -o /usr/local/bin/yq; then
            chmod +x /usr/local/bin/yq
            colorized_echo green "yq installed successfully!"
        else
            colorized_echo red "Failed to download yq using curl. Please check your internet connection."
            exit 1
        fi
    elif command -v wget &>/dev/null; then
        if wget -O /usr/local/bin/yq "$yq_url"; then
            chmod +x /usr/local/bin/yq
            colorized_echo green "yq installed successfully!"
        else
            colorized_echo red "Failed to download yq using wget. Please check your internet connection."
            exit 1
        fi
    fi


    if ! echo "$PATH" | grep -q "/usr/local/bin"; then
        export PATH="/usr/local/bin:$PATH"
    fi


    hash -r

    if command -v yq &>/dev/null; then
        colorized_echo green "yq is ready to use."
    elif [ -x "/usr/local/bin/yq" ]; then

        colorized_echo yellow "yq is installed at /usr/local/bin/yq but not found in PATH."
        colorized_echo yellow "You can add /usr/local/bin to your PATH environment variable."
    else
        colorized_echo red "yq installation failed. Please try again or install manually."
        exit 1
    fi
}


down_marzban() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" down
}



show_marzban_logs() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" logs
}

follow_marzban_logs() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" logs -f
}

marzban_cli() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" exec -e CLI_PROG_NAME="marzban cli" marzban marzban-cli "$@"
}


is_marzban_up() {
    if [ -z "$($COMPOSE -f $COMPOSE_FILE ps -q -a)" ]; then
        return 1
    else
        return 0
    fi
}

uninstall_command() {
    check_running_as_root
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi
    
    read -p "Do you really want to uninstall Marzban? (y/n) "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo red "Aborted"
        exit 1
    fi
    
    detect_compose
    if is_marzban_up; then
        down_marzban
    fi
    uninstall_marzban_script
    uninstall_marzban
    uninstall_marzban_docker_images
    
    read -p "Do you want to remove Marzban's data files too ($DATA_DIR)? (y/n) "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo green "Marzban uninstalled successfully"
    else
        uninstall_marzban_data_files
        colorized_echo green "Marzban uninstalled successfully"
    fi
}

uninstall_marzban_script() {
    if [ -f "/usr/local/bin/marzban" ]; then
        colorized_echo yellow "Removing marzban script"
        rm "/usr/local/bin/marzban"
    fi
}

uninstall_marzban() {
    if [ -d "$APP_DIR" ]; then
        colorized_echo yellow "Removing directory: $APP_DIR"
        rm -r "$APP_DIR"
    fi
}

uninstall_marzban_docker_images() {
    images=$(docker images | grep marzban | awk '{print $3}')
    
    if [ -n "$images" ]; then
        colorized_echo yellow "Removing Docker images of Marzban"
        for image in $images; do
            if docker rmi "$image" >/dev/null 2>&1; then
                colorized_echo yellow "Image $image removed"
            fi
        done
    fi
}

uninstall_marzban_data_files() {
    if [ -d "$DATA_DIR" ]; then
        colorized_echo yellow "Removing directory: $DATA_DIR"
        rm -r "$DATA_DIR"
    fi
}

restart_command() {
    help() {
        colorized_echo red "Usage: marzban restart [options]"
        echo
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-logs     do not follow logs after starting"
    }
    
    local no_logs=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-logs)
                no_logs=true
            ;;
            -h|--help)
                help
                exit 0
            ;;
            *)
                echo "Error: Invalid option: $1" >&2
                help
                exit 0
            ;;
        esac
        shift
    done
    
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi
    
    detect_compose
    
    down_marzban
    up_marzban
    if [ "$no_logs" = false ]; then
        follow_marzban_logs
    fi
    colorized_echo green "Marzban successfully restarted!"
}
logs_command() {
    help() {
        colorized_echo red "Usage: marzban logs [options]"
        echo ""
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-follow   do not show follow logs"
    }
    
    local no_follow=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-follow)
                no_follow=true
            ;;
            -h|--help)
                help
                exit 0
            ;;
            *)
                echo "Error: Invalid option: $1" >&2
                help
                exit 0
            ;;
        esac
        shift
    done
    
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi
    
    detect_compose
    
    if ! is_marzban_up; then
        colorized_echo red "Marzban is not up."
        exit 1
    fi
    
    if [ "$no_follow" = true ]; then
        show_marzban_logs
    else
        follow_marzban_logs
    fi
}

down_command() {
    
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi
    
    detect_compose
    
    if ! is_marzban_up; then
        colorized_echo red "Marzban's already down"
        exit 1
    fi
    
    down_marzban
}

cli_command() {
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi
    
    detect_compose
    
    if ! is_marzban_up; then
        colorized_echo red "Marzban is not up."
        exit 1
    fi
    
    marzban_cli "$@"
}

up_command() {
    help() {
        colorized_echo red "Usage: marzban up [options]"
        echo ""
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-logs     do not follow logs after starting"
    }
    
    local no_logs=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-logs)
                no_logs=true
            ;;
            -h|--help)
                help
                exit 0
            ;;
            *)
                echo "Error: Invalid option: $1" >&2
                help
                exit 0
            ;;
        esac
        shift
    done
    
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi
    
    detect_compose
    
    if is_marzban_up; then
        colorized_echo red "Marzban's already up"
        exit 1
    fi
    
    up_marzban
    if [ "$no_logs" = false ]; then
        follow_marzban_logs
    fi
}

backup_before_fork_update() {
    if [ ! -f "$COMPOSE_FILE" ] || [ ! -f "$ENV_FILE" ] || [ ! -d "$DATA_DIR" ]; then
        colorized_echo red "Missing compose, .env, or data directory; update aborted."
        return 1
    fi
    $COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" config --quiet || return 1

    # A remote database is not covered by the local data archive.
    if grep -Eq '^[[:space:]]*SQLALCHEMY_DATABASE_URL[[:space:]]*=.*(mysql|postgresql)' "$ENV_FILE" && \
       ! $COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" config --services | grep -Eq '^(mysql|mariadb)$'; then
        colorized_echo red "External database detected. Back it up separately before updating."
        return 1
    fi

    local backup_dir="$APP_DIR/backup"
    local backup_file
    mkdir -p -m 700 "$backup_dir" || return 1
    backup_file=$(mktemp "$backup_dir/upgrade-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXXXX.tar.gz") || return 1

    # Stop SQLite/MySQL/MariaDB cleanly so the data archive is consistent.
    $COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" stop || return 1
    if ! tar -czf "$backup_file" -C "$APP_DIR" .env docker-compose.yml \
        -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")"; then
        $COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" up -d || return 1
        colorized_echo red "Data backup failed; image was not changed."
        return 1
    fi
    if ! tar -tzf "$backup_file" >/dev/null; then
        $COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" up -d || return 1
        colorized_echo red "Backup verification failed; image was not changed."
        return 1
    fi
    $COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" up -d || return 1
    colorized_echo green "Pre-update backup: $backup_file"
}

pull_fork_image() {
    $COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" pull marzban || return 1
    $COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" up -d --no-deps marzban || return 1
}

adopt_command() {
    check_running_as_root
    if ! is_marzban_installed; then
        colorized_echo red "Marzban is not installed. Use 'marzban install' on a new server."
        return 1
    fi
    if ! command -v yq >/dev/null 2>&1; then
        colorized_echo red "yq is required to change only the image field."
        return 1
    fi
    detect_compose
    backup_before_fork_update
    local compose_copy="$APP_DIR/backup/docker-compose-before-fork-$(date -u +%Y%m%dT%H%M%SZ).yml"
    cp -a "$COMPOSE_FILE" "$compose_copy"
    yq -i '.services.marzban.image = "ghcr.io/heyinkcode/marzban:latest"' "$COMPOSE_FILE"
    if ! $COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" config --quiet || ! pull_fork_image; then
        cp -a "$compose_copy" "$COMPOSE_FILE"
        $COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" up -d
        colorized_echo red "Fork image did not start; original compose restored."
        return 1
    fi
    update_marzban_script
    colorized_echo green "Fork adopted. Future updates use 'marzban update'."
}

# Read only Docker Compose's resolved model, never raw YAML or a running
# container. Environment substitutions and anchors have already been resolved.
configured_service_image() {
    local service="$1" rendered image
    if ! rendered=$($COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" config 2>/dev/null); then
        colorized_echo red "Cannot render Compose configuration; update stopped before backup or image changes." >&2
        return 1
    fi
    if ! image=$(printf '%s\n' "$rendered" | awk -v wanted="$service" '
        /^services:[[:space:]]*$/ { services = 1; next }
        services && /^[^[:space:]]/ { services = 0; selected = 0 }
        services && /^  [^[:space:]]/ {
            key = $0
            sub(/^  /, "", key)
            sub(/:[[:space:]]*$/, "", key)
            selected = (key == wanted)
            next
        }
        services && selected && /^    image:[[:space:]]*/ {
            sub(/^    image:[[:space:]]*/, "")
            sub(/[[:space:]]*$/, "")
            print
            count++
        }
        END { if (count != 1) exit 1 }
    '); then
        colorized_echo red "Cannot identify one image for the target Compose service; update stopped without changes." >&2
        return 1
    fi
    # Canonical Compose YAML may quote image scalars. Image references cannot
    # contain quotes or escaped characters, so reject those during validation.
    if [[ "$image" == \"*\" || "$image" == \'*\' ]]; then
        image="${image:1:${#image}-2}"
    fi
    printf '%s\n' "$image"
}

image_from_repository() {
    local image="$1" repository="$2" suffix
    [[ "$image" == "$repository"* ]] || return 1
    suffix="${image#"$repository"}"
    [[ "$suffix" =~ ^(:[A-Za-z0-9_][A-Za-z0-9_.-]{0,127})?(@sha256:[a-f0-9]{64})?$ ]]
}

require_fork_update_image() {
    local service="$1" repository="$2" official="$3" legacy="$4" image
    FORK_NAMESPACE_IMAGE=""
    image=$(configured_service_image "$service") || return 1
    if image_from_repository "$image" "$repository"; then
        return 0
    fi
    if image_from_repository "$image" "$legacy"; then
        if [[ "$image" == "$legacy" || "$image" == "$legacy:latest" ]]; then
            FORK_NAMESPACE_IMAGE="$repository:latest"
            return 0
        fi
        colorized_echo red "Legacy Fork uses a fixed tag/digest. Select and verify a matching heyinkcode artifact explicitly; automatic latest migration was refused."
        return 1
    fi
    if image_from_repository "$image" "$official"; then
        colorized_echo red "The target Compose service uses the official image. Review the migration guide before running '$APP_NAME adopt' once."
    else
        colorized_echo red "The target Compose service does not use this Fork image; update stopped. Review its image configuration; no automatic migration was performed."
    fi
    return 1
}

# Replace only one service image in block-style YAML. Rendered-model comparison
# below rejects unsupported layouts or any accidental change to another field.
rewrite_service_image() {
    local service="$1" image="$2"
    awk -v wanted="$service" -v replacement="$image" '
        function finish() {
            if (selected && !images) print "    image: " replacement
            selected = 0
        }
        /^services:[[:space:]]*(#.*)?$/ { services = 1; print; next }
        services && /^[^[:space:]#]/ { finish(); services = 0 }
        services && /^  [^[:space:]#]/ {
            finish()
            key = $0
            sub(/^  /, "", key)
            sub(/:[[:space:]]*(#.*)?$/, "", key)
            if (substr(key, 1, 1) == sprintf("%c", 34) || substr(key, 1, 1) == sprintf("%c", 39))
                key = substr(key, 2, length(key) - 2)
            selected = (key == wanted)
            if (selected) { targets++; images = 0 }
        }
        services && selected && /^    image:[[:space:]]*/ {
            images++; total_images++
            print "    image: " replacement
            next
        }
        { print }
        END { finish(); if (targets != 1 || total_images > 1) exit 1 }
    '
}

migrate_fork_namespace() {
    local service="$1" image="$2" candidate expected actual original
    if [ -L "$COMPOSE_FILE" ]; then
        colorized_echo red "Symlink Compose requires an explicit namespace migration; nothing changed."
        return 1
    fi
    candidate=$(mktemp "$APP_DIR/.owner-compose-XXXXXXXX.yml") || return 1
    expected=$(mktemp "$APP_DIR/.owner-expected-XXXXXXXX") || { rm -f "$candidate"; return 1; }
    actual=$(mktemp "$APP_DIR/.owner-actual-XXXXXXXX") || { rm -f "$candidate" "$expected"; return 1; }
    original=$(mktemp "$APP_DIR/backup/namespace-compose-XXXXXXXX.yml") || { rm -f "$candidate" "$expected" "$actual"; return 1; }
    if ! cp -p "$COMPOSE_FILE" "$original" ||
       ! rewrite_service_image "$service" "$image" < "$original" > "$candidate" ||
       ! $COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" config > "$actual" 2>/dev/null ||
       ! rewrite_service_image "$service" "$image" < "$actual" > "$expected" ||
       ! $COMPOSE -f "$candidate" -p "$APP_NAME" config > "$actual" 2>/dev/null ||
       ! cmp -s "$expected" "$actual"; then
        rm -f "$candidate" "$expected" "$actual"
        colorized_echo red "Cannot prove an image-only namespace change; original Compose was kept."
        return 1
    fi
    rm -f "$expected" "$actual"
    # Fetch before replacing Compose. A registry/network failure keeps the old
    # namespace and running container intact after the normal pre-update backup.
    if ! $COMPOSE -f "$candidate" -p "$APP_NAME" pull "$service" ||
       ! cmp -s "$original" "$COMPOSE_FILE" ||
       ! chmod --reference="$COMPOSE_FILE" "$candidate" ||
       ! chown --reference="$COMPOSE_FILE" "$candidate" ||
       ! mv -f "$candidate" "$COMPOSE_FILE"; then
        rm -f "$candidate"
        colorized_echo red "Namespace preparation failed; no successful migration was reported."
        return 1
    fi
    if ! pull_fork_image; then
        if cp -p "$original" "$COMPOSE_FILE" && $COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" up -d --no-deps "$service"; then
            colorized_echo red "New namespace failed to start; original Compose and service were restored."
        else
            colorized_echo red "Namespace update and recovery failed; inspect the preserved backup before retrying."
        fi
        return 1
    fi
    colorized_echo green "Image namespace migrated to heyinkcode; original Compose backup: $original"
}


update_command() {
    check_running_as_root
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi
    
    detect_compose
    require_fork_update_image "marzban" "ghcr.io/heyinkcode/marzban" "ghcr.io/gozargah/marzban" "ghcr.io/kissow/marzban" || return 1
    backup_before_fork_update || return 1
    if [ -n "$FORK_NAMESPACE_IMAGE" ]; then
        migrate_fork_namespace "marzban" "$FORK_NAMESPACE_IMAGE" || return 1
    else
        pull_fork_image || return 1
    fi
    update_marzban_script || return 1
    colorized_echo green "Marzban fork updated successfully; existing data and .env were kept."
}

update_marzban_script() {
    FETCH_REPO="heyinkcode/Marzban-scripts"
    SCRIPT_URL="https://raw.githubusercontent.com/$FETCH_REPO/master/marzban.sh"
    colorized_echo blue "Updating marzban script"
    local script_file
    script_file=$(mktemp) || return 1
    if ! curl -fsSL "$SCRIPT_URL" -o "$script_file"; then
        rm -f "$script_file"
        colorized_echo red "Unable to fetch the Mr.shaw Marzban script."
        return 1
    fi
    install -m 755 "$script_file" /usr/local/bin/marzban || { rm -f "$script_file"; return 1; }
    rm -f "$script_file"
    colorized_echo green "marzban script updated successfully"
}

update_marzban() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" pull
}

check_editor() {
    if [ -z "$EDITOR" ]; then
        if command -v nano >/dev/null 2>&1; then
            EDITOR="nano"
            elif command -v vi >/dev/null 2>&1; then
            EDITOR="vi"
        else
            detect_os
            install_package nano
            EDITOR="nano"
        fi
    fi
}


edit_command() {
    detect_os
    check_editor
    if [ -f "$COMPOSE_FILE" ]; then
        $EDITOR "$COMPOSE_FILE"
    else
        colorized_echo red "Compose file not found at $COMPOSE_FILE"
        exit 1
    fi
}

edit_env_command() {
    detect_os
    check_editor
    if [ -f "$ENV_FILE" ]; then
        $EDITOR "$ENV_FILE"
    else
        colorized_echo red "Environment file not found at $ENV_FILE"
        exit 1
    fi
}

usage() {
    local script_name="${0##*/}"
    colorized_echo blue "=============================="
    colorized_echo magenta "           Marzban Help"
    colorized_echo blue "=============================="
    colorized_echo cyan "Usage:"
    echo "  ${script_name} [command]"
    echo

    colorized_echo cyan "Commands:"
    colorized_echo yellow "  up              $(tput sgr0)– Start services"
    colorized_echo yellow "  down            $(tput sgr0)– Stop services"
    colorized_echo yellow "  restart         $(tput sgr0)– Restart services"
    colorized_echo yellow "  status          $(tput sgr0)– Show status"
    colorized_echo yellow "  logs            $(tput sgr0)– Show logs"
    colorized_echo yellow "  cli             $(tput sgr0)– Marzban CLI"
    colorized_echo yellow "  install         $(tput sgr0)– Install Marzban"
    colorized_echo yellow "  update          $(tput sgr0)– Update to latest version"
    colorized_echo yellow "  adopt           $(tput sgr0)– Switch an existing official install to this Fork without resetting data"
    colorized_echo yellow "  uninstall       $(tput sgr0)– Uninstall Marzban"
    colorized_echo yellow "  install-script  $(tput sgr0)– Install Marzban script"
    colorized_echo yellow "  backup          $(tput sgr0)– Manual backup launch"
    colorized_echo yellow "  backup-service  $(tput sgr0)– Marzban Backupservice to backup to TG, and a new job in crontab"
    colorized_echo yellow "  core-update     $(tput sgr0)– Update/Change Xray core"
    colorized_echo yellow "  edit            $(tput sgr0)– Edit docker-compose.yml (via nano or vi editor)"
    colorized_echo yellow "  edit-env        $(tput sgr0)– Edit environment file (via nano or vi editor)"
    colorized_echo yellow "  help            $(tput sgr0)– Show this help message"
    
    
    echo
    colorized_echo cyan "Directories:"
    colorized_echo magenta "  App directory: $APP_DIR"
    colorized_echo magenta "  Data directory: $DATA_DIR"
    colorized_echo blue "================================"
    echo
}

case "$1" in
    up)
        shift; up_command "$@";;
    down)
        shift; down_command "$@";;
    restart)
        shift; restart_command "$@";;
    status)
        shift; status_command "$@";;
    logs)
        shift; logs_command "$@";;
    cli)
        shift; cli_command "$@";;
    backup)
        shift; backup_command "$@";;
    backup-service)
        shift; backup_service "$@";;
    install)
        shift; install_command "$@";;
    update)
        shift; update_command "$@";;
    adopt)
        shift; adopt_command "$@";;
    uninstall)
        shift; uninstall_command "$@";;
    install-script)
        shift; install_marzban_script "$@";;
    core-update)
        shift; update_core_command "$@";;
    edit)
        shift; edit_command "$@";;
    edit-env)
        shift; edit_env_command "$@";;
    help|*)
        usage;;
esac
