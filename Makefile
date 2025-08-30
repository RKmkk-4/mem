# Makefile pour le projet Système Linux Embarqué

# Variables de configuration
BUILDROOT_VERSION = 2024.02
TARGET_IP ?= 192.168.1.100
CROSS_COMPILE = arm-linux-gnueabihf-
CC = $(CROSS_COMPILE)gcc
BUILD_DIR = build
SRC_DIR = src
SCRIPTS_DIR = scripts

# Couleurs pour l'affichage
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
NC = \033[0m # No Color

# Cibles principales
.PHONY: all clean help install deploy test buildroot monitor api dashboard

all: monitor api dashboard
	@echo "$(GREEN)✓ Compilation terminée$(NC)"

help:
	@echo "$(YELLOW)Utilisation:$(NC)"
	@echo "  make all          - Compiler toutes les applications"
	@echo "  make monitor      - Compiler le moniteur système"
	@echo "  make api          - Préparer l'API Python"
	@echo "  make dashboard    - Préparer le dashboard Node.js"
	@echo "  make deploy       - Déployer sur la cible"
	@echo "  make test         - Tester le système"
	@echo "  make buildroot    - Télécharger et configurer Buildroot"
	@echo "  make clean        - Nettoyer les fichiers générés"
	@echo ""
	@echo "$(YELLOW)Variables:$(NC)"
	@echo "  TARGET_IP=192.168.1.100  - IP de la cible"

# Création du répertoire de build
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Compilation du moniteur système
monitor: $(BUILD_DIR)
	@echo "$(GREEN)Compilation du moniteur système...$(NC)"
	$(CC) -o $(BUILD_DIR)/system_monitor $(SRC_DIR)/system_monitor.c -static
	@echo "$(GREEN)✓ Moniteur système compilé$(NC)"

# Préparation de l'API Python
api: $(BUILD_DIR)
	@echo "$(GREEN)Préparation de l'API Python...$(NC)"
	cp $(SRC_DIR)/api_server.py $(BUILD_DIR)/
	chmod +x $(BUILD_DIR)/api_server.py
	@echo "$(GREEN)✓ API Python préparée$(NC)"

# Préparation du dashboard
dashboard: $(BUILD_DIR)
	@echo "$(GREEN)Préparation du dashboard Node.js...$(NC)"
	@if [ -d "$(SRC_DIR)/dashboard" ]; then \
		cd $(SRC_DIR)/dashboard && npm install --production; \
		tar -czf ../../$(BUILD_DIR)/dashboard.tar.gz .; \
		echo "$(GREEN)✓ Dashboard préparé$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Dossier dashboard non trouvé$(NC)"; \
	fi

# Téléchargement et configuration de Buildroot
buildroot:
	@echo "$(GREEN)Téléchargement de Buildroot $(BUILDROOT_VERSION)...$(NC)"
	@if [ ! -f "buildroot-$(BUILDROOT_VERSION).tar.gz" ]; then \
		wget https://buildroot.org/downloads/buildroot-$(BUILDROOT_VERSION).tar.gz; \
	fi
	@if [ ! -d "buildroot-$(BUILDROOT_VERSION)" ]; then \
		tar -xzf buildroot-$(BUILDROOT_VERSION).tar.gz; \
	fi
	@echo "$(GREEN)Configuration pour Raspberry Pi 4...$(NC)"
	cd buildroot-$(BUILDROOT_VERSION) && make raspberrypi4_defconfig
	@echo "$(GREEN)✓ Buildroot configuré$(NC)"
	@echo "$(YELLOW)Pour personnaliser: cd buildroot-$(BUILDROOT_VERSION) && make menuconfig$(NC)"
	@echo "$(YELLOW)Pour compiler: cd buildroot-$(BUILDROOT_VERSION) && make -j$$(nproc)$(NC)"

# Déploiement sur la cible
deploy: all
	@echo "$(GREEN)Déploiement sur $(TARGET_IP)...$(NC)"
	@if [ -x "$(SCRIPTS_DIR)/deploy.sh" ]; then \
		$(SCRIPTS_DIR)/deploy.sh $(TARGET_IP) all; \
	else \
		echo "$(RED)✗ Script de déploiement non trouvé$(NC)"; \
		exit 1; \
	fi

# Tests du système
test:
	@echo "$(GREEN)Test du système sur $(TARGET_IP)...$(NC)"
	@if [ -f "$(SCRIPTS_DIR)/test_system.py" ]; then \
		python3 $(SCRIPTS_DIR)/test_system.py $(TARGET_IP); \
	else \
		echo "$(RED)✗ Script de test non trouvé$(NC)"; \
		exit 1; \
	fi

# Installation des dépendances
install-deps:
	@echo "$(GREEN)Installation des dépendances...$(NC)"
	@echo "$(YELLOW)Installation des paquets système...$(NC)"
	sudo apt update
	sudo apt install -y \
		sed make binutils build-essential gcc g++ \
		bash patch gzip bzip2 perl tar cpio unzip \
		rsync file bc wget python3 python3-dev \
		libncurses5-dev git \
		gcc-arm-linux-gnueabihf \
		python3-pip nodejs npm
	@echo "$(YELLOW)Installation des modules Python...$(NC)"
	pip3 install flask psutil requests colorama
	@echo "$(GREEN)✓ Dépendances installées$(NC)"

# Vérification de la configuration
check-config:
	@echo "$(GREEN)Vérification de la configuration...$(NC)"
	@echo -n "Cross-compilateur ARM: "
	@which $(CC) > /dev/null 2>&1 && echo "$(GREEN)✓$(NC)" || echo "$(RED)✗$(NC)"
	@echo -n "Python 3: "
	@which python3 > /dev/null 2>&1 && echo "$(GREEN)✓$(NC)" || echo "$(RED)✗$(NC)"
	@echo -n "Node.js: "
	@which node > /dev/null 2>&1 && echo "$(GREEN)✓$(NC)" || echo "$(RED)✗$(NC)"
	@echo -n "Git: "
	@which git > /dev/null 2>&1 && echo "$(GREEN)✓$(NC)" || echo "$(RED)✗$(NC)"

# Nettoyage
clean:
	@echo "$(GREEN)Nettoyage...$(NC)"
	rm -rf $(BUILD_DIR)
	@echo "$(GREEN)✓ Nettoyage terminé$(NC)"

# Nettoyage complet (incluant Buildroot)
distclean: clean
	@echo "$(YELLOW)Nettoyage complet...$(NC)"
	rm -rf buildroot-$(BUILDROOT_VERSION)
	rm -f buildroot-$(BUILDROOT_VERSION).tar.gz
	@echo "$(GREEN)✓ Nettoyage complet terminé$(NC)"

# Création d'une archive du projet
archive:
	@echo "$(GREEN)Création de l'archive...$(NC)"
	tar -czf embedded-linux-project-$$(date +%Y%m%d).tar.gz \
		--exclude='build' \
		--exclude='buildroot-*' \
		--exclude='*.tar.gz' \
		--exclude='.git' \
		.
	@echo "$(GREEN)✓ Archive créée: embedded-linux-project-$$(date +%Y%m%d).tar.gz$(NC)"

# Affichage des informations du projet
info:
	@echo "$(YELLOW)╔════════════════════════════════════════╗$(NC)"
	@echo "$(YELLOW)║   Projet Système Linux Embarqué        ║$(NC)"
	@echo "$(YELLOW)╠════════════════════════════════════════╣$(NC)"
	@echo "$(YELLOW)║$(NC) Target IP: $(TARGET_IP)"
	@echo "$(YELLOW)║$(NC) Buildroot: $(BUILDROOT_VERSION)"
	@echo "$(YELLOW)║$(NC) Cross-compiler: $(CROSS_COMPILE)"
	@echo "$(YELLOW)║$(NC) Build dir: $(BUILD_DIR)"
	@echo "$(YELLOW)╚════════════════════════════════════════╝$(NC)"

# Test de connectivité avec la cible
ping:
	@echo "$(GREEN)Test de connectivité avec $(TARGET_IP)...$(NC)"
	@ping -c 3 $(TARGET_IP) > /dev/null 2>&1 && \
		echo "$(GREEN)✓ Cible accessible$(NC)" || \
		echo "$(RED)✗ Cible inaccessible$(NC)"

# Connexion SSH à la cible
ssh:
	@echo "$(GREEN)Connexion SSH à $(TARGET_IP)...$(NC)"
	ssh root@$(TARGET_IP)

# Surveillance des logs sur la cible
logs:
	@echo "$(GREEN)Surveillance des logs sur $(TARGET_IP)...$(NC)"
	ssh root@$(TARGET_IP) "journalctl -f"

# Redémarrage de la cible
reboot:
	@echo "$(YELLOW)Redémarrage de $(TARGET_IP)...$(NC)"
	ssh root@$(TARGET_IP) "reboot"

.DEFAULT_GOAL := help