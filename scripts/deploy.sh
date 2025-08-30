#!/bin/bash

# Script de déploiement automatisé pour système embarqué
# Usage: ./deploy.sh <target_ip> <application>

set -e

# Configuration
TARGET_IP="${1:-192.168.1.100}"
APP_NAME="${2:-all}"
TARGET_USER="root"
TARGET_DIR="/opt/embedded-apps"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction d'affichage
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Vérification de la connectivité
check_connectivity() {
    log_info "Vérification de la connectivité avec $TARGET_IP..."
    
    if ping -c 1 -W 2 $TARGET_IP > /dev/null 2>&1; then
        log_info "Cible accessible"
    else
        log_error "Impossible de joindre la cible $TARGET_IP"
    fi
    
    # Test SSH
    if ssh -o ConnectTimeout=5 $TARGET_USER@$TARGET_IP "echo 'SSH OK'" > /dev/null 2>&1; then
        log_info "Connexion SSH établie"
    else
        log_error "Connexion SSH impossible"
    fi
}

# Compilation des applications
build_applications() {
    log_info "Compilation des applications..."
    
    # Compilation du moniteur système
    if [ "$APP_NAME" == "all" ] || [ "$APP_NAME" == "monitor" ]; then
        log_info "Compilation du moniteur système..."
        arm-linux-gnueabihf-gcc -o build/system_monitor src/system_monitor.c -static
    fi
    
    # Préparation de l'API Python
    if [ "$APP_NAME" == "all" ] || [ "$APP_NAME" == "api" ]; then
        log_info "Préparation de l'API Python..."
        cp src/api_server.py build/
        chmod +x build/api_server.py
    fi
    
    # Préparation du dashboard Node.js
    if [ "$APP_NAME" == "all" ] || [ "$APP_NAME" == "dashboard" ]; then
        log_info "Préparation du dashboard..."
        cd src/dashboard
        npm install --production
        tar -czf ../../build/dashboard.tar.gz .
        cd ../..
    fi
}

# Déploiement sur la cible
deploy_to_target() {
    log_info "Déploiement sur la cible..."
    
    # Création du répertoire de destination
    ssh $TARGET_USER@$TARGET_IP "mkdir -p $TARGET_DIR"
    
    # Copie des fichiers
    if [ "$APP_NAME" == "all" ] || [ "$APP_NAME" == "monitor" ]; then
        log_info "Déploiement du moniteur système..."
        scp build/system_monitor $TARGET_USER@$TARGET_IP:$TARGET_DIR/
    fi
    
    if [ "$APP_NAME" == "all" ] || [ "$APP_NAME" == "api" ]; then
        log_info "Déploiement de l'API..."
        scp build/api_server.py $TARGET_USER@$TARGET_IP:$TARGET_DIR/
    fi
    
    if [ "$APP_NAME" == "all" ] || [ "$APP_NAME" == "dashboard" ]; then
        log_info "Déploiement du dashboard..."
        scp build/dashboard.tar.gz $TARGET_USER@$TARGET_IP:$TARGET_DIR/
        ssh $TARGET_USER@$TARGET_IP "cd $TARGET_DIR && tar -xzf dashboard.tar.gz -C dashboard/"
    fi
}

# Installation des services
install_services() {
    log_info "Installation des services..."
    
    # Script d'installation distant
    cat << 'REMOTE_SCRIPT' | ssh $TARGET_USER@$TARGET_IP bash
#!/bin/bash

# Installation des dépendances Python
if command -v pip3 &> /dev/null; then
    pip3 install flask psutil
fi

# Configuration des services systemd
if [ -d /etc/systemd/system ]; then
    # Service pour le moniteur système
    cat > /etc/systemd/system/system-monitor.service << EOF
[Unit]
Description=System Monitor
After=network.target

[Service]
Type=simple
ExecStart=/opt/embedded-apps/system_monitor
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Service pour l'API
    cat > /etc/systemd/system/api-server.service << EOF
[Unit]
Description=API Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/embedded-apps/api_server.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Rechargement et démarrage
    systemctl daemon-reload
    systemctl enable system-monitor.service
    systemctl enable api-server.service
    systemctl restart system-monitor.service
    systemctl restart api-server.service
else
    # Utilisation d'init.d pour les systèmes non-systemd
    echo "Configuration pour init.d..."
fi

echo "Services installés avec succès"
REMOTE_SCRIPT
}

# Vérification post-déploiement
verify_deployment() {
    log_info "Vérification du déploiement..."
    
    # Test de l'API
    if curl -s http://$TARGET_IP:5000/ > /dev/null 2>&1; then
        log_info "API Server opérationnel"
    else
        log_warning "API Server non accessible"
    fi
    
    # Test du dashboard
    if curl -s http://$TARGET_IP:3000/ > /dev/null 2>&1; then
        log_info "Dashboard opérationnel"
    else
        log_warning "Dashboard non accessible"
    fi
    
    # Vérification des processus
    ssh $TARGET_USER@$TARGET_IP "ps aux | grep -E 'system_monitor|api_server|node' | grep -v grep"
}

# Programme principal
main() {
    echo "========================================="
    echo "   Déploiement Système Embarqué"
    echo "========================================="
    echo "Cible: $TARGET_IP"
    echo "Application: $APP_NAME"
    echo "========================================="
    
    # Création du répertoire de build
    mkdir -p build
    
    # Étapes de déploiement
    check_connectivity
    build_applications
    deploy_to_target
    install_services
    verify_deployment
    
    log_info "Déploiement terminé avec succès!"
    echo "========================================="
    echo "URLs d'accès:"
    echo "  - SSH: ssh $TARGET_USER@$TARGET_IP"
    echo "  - API: http://$TARGET_IP:5000/"
    echo "  - Dashboard: http://$TARGET_IP:3000/"
    echo "  - Web Server: http://$TARGET_IP/"
    echo "========================================="
}

# Exécution
main