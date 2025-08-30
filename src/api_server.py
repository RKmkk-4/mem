#!/usr/bin/env python3
"""
API REST pour système embarqué
Fournit des endpoints pour monitorer et contrôler le système
"""

from flask import Flask, jsonify, request
import os
import psutil
import subprocess
import json
from datetime import datetime
import logging

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/api_server.log'),
        logging.StreamHandler()
    ]
)

app = Flask(__name__)
logger = logging.getLogger(__name__)

# Configuration
APP_CONFIG = {
    'version': '1.0.0',
    'device_name': 'embedded-linux',
    'api_port': 5000
}

@app.route('/')
def index():
    """Point d'entrée principal de l'API"""
    return jsonify({
        'status': 'online',
        'message': 'Embedded Linux API Server',
        'version': APP_CONFIG['version'],
        'endpoints': [
            '/api/system/info',
            '/api/system/processes',
            '/api/system/network',
            '/api/gpio/read/<pin>',
            '/api/gpio/write/<pin>/<value>',
            '/api/services/<action>'
        ]
    })

@app.route('/api/system/info')
def system_info():
    """Retourne les informations système"""
    try:
        # CPU info
        cpu_percent = psutil.cpu_percent(interval=1)
        cpu_freq = psutil.cpu_freq()
        
        # Memory info
        memory = psutil.virtual_memory()
        
        # Disk info
        disk = psutil.disk_usage('/')
        
        # Network info
        net_io = psutil.net_io_counters()
        
        # Boot time
        boot_time = datetime.fromtimestamp(psutil.boot_time())
        
        return jsonify({
            'status': 'success',
            'data': {
                'cpu': {
                    'usage_percent': cpu_percent,
                    'frequency_mhz': cpu_freq.current if cpu_freq else 0,
                    'cores': psutil.cpu_count()
                },
                'memory': {
                    'total_mb': memory.total / (1024 * 1024),
                    'available_mb': memory.available / (1024 * 1024),
                    'percent': memory.percent
                },
                'disk': {
                    'total_gb': disk.total / (1024 * 1024 * 1024),
                    'used_gb': disk.used / (1024 * 1024 * 1024),
                    'free_gb': disk.free / (1024 * 1024 * 1024),
                    'percent': disk.percent
                },
                'network': {
                    'bytes_sent': net_io.bytes_sent,
                    'bytes_recv': net_io.bytes_recv,
                    'packets_sent': net_io.packets_sent,
                    'packets_recv': net_io.packets_recv
                },
                'boot_time': boot_time.isoformat()
            }
        })
    except Exception as e:
        logger.error(f"Error getting system info: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/system/processes')
def list_processes():
    """Liste les processus en cours"""
    try:
        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']):
            try:
                processes.append({
                    'pid': proc.info['pid'],
                    'name': proc.info['name'],
                    'cpu_percent': proc.info['cpu_percent'],
                    'memory_percent': proc.info['memory_percent']
                })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        
        # Trier par utilisation CPU
        processes.sort(key=lambda x: x['cpu_percent'], reverse=True)
        
        return jsonify({
            'status': 'success',
            'data': {
                'count': len(processes),
                'processes': processes[:20]  # Top 20 processus
            }
        })
    except Exception as e:
        logger.error(f"Error listing processes: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/system/network')
def network_info():
    """Retourne les informations réseau"""
    try:
        interfaces = {}
        for interface, addrs in psutil.net_if_addrs().items():
            interface_info = {
                'addresses': []
            }
            for addr in addrs:
                if addr.family == 2:  # IPv4
                    interface_info['addresses'].append({
                        'type': 'ipv4',
                        'address': addr.address,
                        'netmask': addr.netmask
                    })
                elif addr.family == 10:  # IPv6
                    interface_info['addresses'].append({
                        'type': 'ipv6',
                        'address': addr.address
                    })
            
            # Statistiques de l'interface
            stats = psutil.net_if_stats().get(interface)
            if stats:
                interface_info['is_up'] = stats.isup
                interface_info['speed_mbps'] = stats.speed
            
            interfaces[interface] = interface_info
        
        return jsonify({
            'status': 'success',
            'data': interfaces
        })
    except Exception as e:
        logger.error(f"Error getting network info: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/gpio/read/<int:pin>')
def gpio_read(pin):
    """Lit l'état d'une broche GPIO"""
    try:
        # Simulation de lecture GPIO
        # Dans un vrai système, utiliser RPi.GPIO ou équivalent
        gpio_path = f"/sys/class/gpio/gpio{pin}/value"
        
        if os.path.exists(gpio_path):
            with open(gpio_path, 'r') as f:
                value = f.read().strip()
            return jsonify({
                'status': 'success',
                'data': {
                    'pin': pin,
                    'value': int(value)
                }
            })
        else:
            # Simulation
            import random
            value = random.choice([0, 1])
            return jsonify({
                'status': 'success',
                'data': {
                    'pin': pin,
                    'value': value,
                    'simulated': True
                }
            })
    except Exception as e:
        logger.error(f"Error reading GPIO {pin}: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/gpio/write/<int:pin>/<int:value>', methods=['POST'])
def gpio_write(pin, value):
    """Écrit sur une broche GPIO"""
    try:
        if value not in [0, 1]:
            return jsonify({
                'status': 'error',
                'message': 'Value must be 0 or 1'
            }), 400
        
        # Simulation d'écriture GPIO
        gpio_path = f"/sys/class/gpio/gpio{pin}/value"
        
        if os.path.exists(gpio_path):
            with open(gpio_path, 'w') as f:
                f.write(str(value))
        
        logger.info(f"GPIO {pin} set to {value}")
        
        return jsonify({
            'status': 'success',
            'data': {
                'pin': pin,
                'value': value,
                'timestamp': datetime.now().isoformat()
            }
        })
    except Exception as e:
        logger.error(f"Error writing GPIO {pin}: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/services/<action>', methods=['POST'])
def manage_services(action):
    """Gère les services système"""
    try:
        data = request.get_json()
        service_name = data.get('service')
        
        if not service_name:
            return jsonify({
                'status': 'error',
                'message': 'Service name required'
            }), 400
        
        if action not in ['start', 'stop', 'restart', 'status']:
            return jsonify({
                'status': 'error',
                'message': 'Invalid action'
            }), 400
        
        # Exécution de la commande
        cmd = f"/etc/init.d/{service_name} {action}"
        result = subprocess.run(
            cmd.split(),
            capture_output=True,
            text=True
        )
        
        return jsonify({
            'status': 'success',
            'data': {
                'service': service_name,
                'action': action,
                'output': result.stdout,
                'return_code': result.returncode
            }
        })
    except Exception as e:
        logger.error(f"Error managing service: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.errorhandler(404)
def not_found(error):
    """Gestion des erreurs 404"""
    return jsonify({
        'status': 'error',
        'message': 'Endpoint not found'
    }), 404

if __name__ == '__main__':
    logger.info("Starting Embedded Linux API Server")
    app.run(
        host='0.0.0.0',
        port=APP_CONFIG['api_port'],
        debug=False
    )