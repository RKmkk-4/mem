#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/sysinfo.h>
#include <sys/statvfs.h>

// Structure pour stocker les informations système
typedef struct {
    long uptime;
    float load_avg[3];
    unsigned long total_ram;
    unsigned long free_ram;
    unsigned long total_swap;
    unsigned long free_swap;
    float cpu_usage;
    float disk_usage;
} SystemInfo;

// Fonction pour obtenir l'utilisation CPU
float get_cpu_usage() {
    static unsigned long long prev_total = 0;
    static unsigned long long prev_idle = 0;
    unsigned long long total = 0, idle = 0;
    float usage = 0.0;
    
    FILE *fp = fopen("/proc/stat", "r");
    if (fp == NULL) return -1;
    
    char line[256];
    if (fgets(line, sizeof(line), fp)) {
        unsigned long long user, nice, system, idle_time, iowait, irq, softirq;
        sscanf(line, "cpu %llu %llu %llu %llu %llu %llu %llu",
               &user, &nice, &system, &idle_time, &iowait, &irq, &softirq);
        
        idle = idle_time + iowait;
        total = user + nice + system + idle_time + iowait + irq + softirq;
        
        if (prev_total != 0) {
            unsigned long long total_diff = total - prev_total;
            unsigned long long idle_diff = idle - prev_idle;
            usage = 100.0 * (1.0 - (float)idle_diff / total_diff);
        }
        
        prev_total = total;
        prev_idle = idle;
    }
    
    fclose(fp);
    return usage;
}

// Fonction pour obtenir l'utilisation disque
float get_disk_usage(const char *path) {
    struct statvfs stat;
    if (statvfs(path, &stat) != 0) {
        return -1;
    }
    
    unsigned long total = stat.f_blocks * stat.f_frsize;
    unsigned long free = stat.f_bfree * stat.f_frsize;
    unsigned long used = total - free;
    
    return (float)used / total * 100.0;
}

// Fonction pour collecter les informations système
void collect_system_info(SystemInfo *info) {
    struct sysinfo si;
    sysinfo(&si);
    
    info->uptime = si.uptime;
    info->load_avg[0] = (float)si.loads[0] / 65536.0;
    info->load_avg[1] = (float)si.loads[1] / 65536.0;
    info->load_avg[2] = (float)si.loads[2] / 65536.0;
    info->total_ram = si.totalram * si.mem_unit;
    info->free_ram = si.freeram * si.mem_unit;
    info->total_swap = si.totalswap * si.mem_unit;
    info->free_swap = si.freeswap * si.mem_unit;
    info->cpu_usage = get_cpu_usage();
    info->disk_usage = get_disk_usage("/");
}

// Fonction pour afficher les informations
void display_info(SystemInfo *info) {
    system("clear");
    printf("╔════════════════════════════════════════════════════╗\n");
    printf("║          EMBEDDED LINUX SYSTEM MONITOR             ║\n");
    printf("╠════════════════════════════════════════════════════╣\n");
    
    // Uptime
    int hours = info->uptime / 3600;
    int minutes = (info->uptime % 3600) / 60;
    printf("║ Uptime: %d hours, %d minutes                      ║\n", hours, minutes);
    
    // Load average
    printf("║ Load Average: %.2f, %.2f, %.2f                    ║\n",
           info->load_avg[0], info->load_avg[1], info->load_avg[2]);
    
    // CPU Usage
    printf("║ CPU Usage: %.1f%%                                  ║\n", info->cpu_usage);
    
    // Memory
    float ram_usage = (1.0 - (float)info->free_ram / info->total_ram) * 100;
    printf("║ RAM: %.1f%% (%.1f MB / %.1f MB)                   ║\n",
           ram_usage,
           (info->total_ram - info->free_ram) / (1024.0 * 1024),
           info->total_ram / (1024.0 * 1024));
    
    // Disk
    printf("║ Disk Usage: %.1f%%                                 ║\n", info->disk_usage);
    
    printf("╚════════════════════════════════════════════════════╝\n");
}

int main() {
    SystemInfo info;
    
    printf("Starting System Monitor...\n");
    printf("Press Ctrl+C to exit\n");
    sleep(2);
    
    while (1) {
        collect_system_info(&info);
        display_info(&info);
        sleep(5); // Mise à jour toutes les 5 secondes
    }
    
    return 0;
}