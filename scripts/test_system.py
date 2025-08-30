#!/usr/bin/env python3
# test_system.py - Tests automatisés du système embarqué

import requests
import subprocess
import time
import json
import sys
from colorama import init, Fore, Style

init()

class EmbeddedSystemTester:
    def __init__(self, target_ip):
        self.target_ip = target_ip
        self.api_url = f"http://{target_ip}:5000"
        self.dashboard_url = f"http://{target_ip}:3000"
        self.tests_passed = 0
        self.tests_failed = 0
        
    def print_header(self, text):
        print(f"\n{Fore.CYAN}{'='*50}")
        print(f"{text}")
        print(f"{'='*50}{Style.RESET_ALL}")
    
    def print_success(self, text):
        print(f"{Fore.GREEN}✓ {text}{Style.RESET_ALL}")
        self.tests_passed += 1
    
    def print_failure(self, text):
        print(f"{Fore.RED}✗ {text}{Style.RESET_ALL}")
        self.tests_failed += 1
    
    def test_connectivity(self):
        """Test de connectivité réseau"""
        self.print_header("Test de Connectivité")
        
        # Ping
        try:
            result = subprocess.run(
                ['ping', '-c', '3', self.target_ip],
                capture_output=True,
                timeout=10
            )
            if result.returncode == 0:
                self.print_success(f"Ping vers {self.target_ip} réussi")
            else:
                self.print_failure(f"Ping vers {self.target_ip} échoué")
        except Exception as e:
            self.print_failure(f"Erreur ping: {e}")
        
        # SSH
        try:
            result = subprocess.run(
                ['ssh', '-o', 'ConnectTimeout=5', 
                 f'root@{self.target_ip}', 'echo "SSH OK"'],
                capture_output=True,
                timeout=10
            )
            if result.returncode == 0:
                self.print_success("Connexion SSH réussie")
            else:
                self.print_failure("Connexion SSH échouée")
        except Exception as e:
            self.print_failure(f"Erreur SSH: {e}")
    
    def test_api_endpoints(self):
        """Test des endpoints de l'API"""
        self.print_header("Test de l'API REST")
        
        endpoints = [
            ('/', 'Point d\'entrée principal'),
            ('/api/system/info', 'Informations système'),
            ('/api/system/processes', 'Liste des processus'),
            ('/api/system/network', 'Informations réseau'),
            ('/api/gpio/read/17', 'Lecture GPIO')
        ]
        
        for endpoint, description in endpoints:
            try:
                response = requests.get(
                    f"{self.api_url}{endpoint}",
                    timeout=5
                )
                if response.status_code == 200:
                    self.print_success(f"{description}: {endpoint}")
                    
                    # Vérification du contenu JSON
                    try:
                        data = response.json()
                        if 'status' in data:
                            print(f"  Status: {data['status']}")
                    except:
                        pass
                else:
                    self.print_failure(
                        f"{description}: {endpoint} (Code: {response.status_code})"
                    )
            except requests.exceptions.RequestException as e:
                self.print_failure(f"{description}: {endpoint} - {e}")
    
    def test_performance(self):
        """Test de performance"""
        self.print_header("Test de Performance")
        
        # Test de charge API
        try:
            start_time = time.time()
            for _ in range(10):
                requests.get(f"{self.api_url}/api/system/info", timeout=5)
            elapsed = time.time() - start_time
            avg_time = elapsed / 10
            
            if avg_time < 0.5:
                self.print_success(
                    f"Performance API: {avg_time:.3f}s par requête"
                )
            else:
                self.print_failure(
                    f"Performance API lente: {avg_time:.3f}s par requête"
                )
        except Exception as e:
            self.print_failure(f"Erreur test performance: {e}")
    
    def test_services(self):
        """Test des services système"""
        self.print_header("Test des Services")
        
        services = [
            ('sshd', 22),
            ('nginx', 80),
            ('api_server', 5000),
            ('node', 3000)
        ]
        
        for service, port in services:
            try:
                # Test de port
                result = subprocess.run(
                    ['nc', '-zv', self.target_ip, str(port)],
                    capture_output=True,
                    timeout=5
                )
                if result.returncode == 0:
                    self.print_success(f"Service {service} (port {port}) actif")
                else:
                    self.print_failure(f"Service {service} (port {port}) inactif")
            except Exception as e:
                self.print_failure(f"Erreur test {service}: {e}")
    
    def test_resources(self):
        """Test des ressources système"""
        self.print_header("Test des Ressources")
        
        try:
            response = requests.get(f"{self.api_url}/api/system/info", timeout=5)
            if response.status_code == 200:
                data = response.json()['data']
                
                # Vérification CPU
                cpu_usage = data['cpu']['usage_percent']
                if cpu_usage < 80:
                    self.print_success(f"CPU usage: {cpu_usage:.1f}%")
                else:
                    self.print_failure(f"CPU surchargé: {cpu_usage:.1f}%")
                
                # Vérification mémoire
                mem_percent = data['memory']['percent']
                if mem_percent < 90:
                    self.print_success(f"Mémoire utilisée: {mem_percent:.1f}%")
                else:
                    self.print_failure(f"Mémoire saturée: {mem_percent:.1f}%")
                
                # Vérification disque
                disk_percent = data['disk']['percent']
                if disk_percent < 90:
                    self.print_success(f"Disque utilisé: {disk_percent:.1f}%")
                else:
                    self.print_failure(f"Disque presque plein: {disk_percent:.1f}%")
                    
        except Exception as e:
            self.print_failure(f"Erreur récupération ressources: {e}")
    
    def generate_report(self):
        """Génération du rapport de tests"""
        self.print_header("Rapport de Tests")
        
        total_tests = self.tests_passed + self.tests_failed
        success_rate = (self.tests_passed / total_tests * 100) if total_tests > 0 else 0
        
        print(f"\nTotal de tests: {total_tests}")
        print(f"{Fore.GREEN}Tests réussis: {self.tests_passed}{Style.RESET_ALL}")
        print(f"{Fore.RED}Tests échoués: {self.tests_failed}{Style.RESET_ALL}")
        print(f"\nTaux de réussite: {success_rate:.1f}%")
        
        if success_rate == 100:
            print(f"\n{Fore.GREEN}{'='*50}")
            print("TOUS LES TESTS SONT PASSÉS AVEC SUCCÈS!")
            print(f"{'='*50}{Style.RESET_ALL}")
        elif success_rate >= 80:
            print(f"\n{Fore.YELLOW}Système fonctionnel avec quelques avertissements{Style.RESET_ALL}")
        else:
            print(f"\n{Fore.RED}Système nécessite des corrections{Style.RESET_ALL}")
        
        return success_rate
    
    def run_all_tests(self):
        """Exécution de tous les tests"""
        print(f"\n{Fore.CYAN}╔{'═'*48}╗")
        print(f"║{'TESTS DU SYSTÈME EMBARQUÉ'.center(48)}║")
        print(f"║{'Target: ' + self.target_ip:^48}║")
        print(f"╚{'═'*48}╝{Style.RESET_ALL}")
        
        self.test_connectivity()
        self.test_services()
        self.test_api_endpoints()
        self.test_performance()
        self.test_resources()
        
        return self.generate_report()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <target_ip>")
        sys.exit(1)
    
    target_ip = sys.argv[1]
    tester = EmbeddedSystemTester(target_ip)
    success_rate = tester.run_all_tests()
    
    sys.exit(0 if success_rate == 100 else 1)