#!/usr/bin/env bash

LINES=300
LOG_FILE="access.log"
IP_REGEX='^([0-9]{1,3}\.){3}[0-9]{1,3}'

awk -v n="$LINES" 'BEGIN {
    srand();
    ni = split("192.168.1.10 192.168.1.11 10.0.0.5 10.0.0.6 172.16.0.4 203.0.113.11 203.0.113.13 198.51.100.32 192.0.2.31", ips, " ");
    nm = split("GET POST PUT DELETE", methods, " ");
    np = split("/api/users /api/login /api/orders /api/items /api/health /api/logout", paths, " ");
    ns = split("200 200 200 200 201 204 301 400 401 403 404 404 500 502 503", codes, " ");
    for (i = 0; i < n; i++) {
        ip = ips[int(rand() * ni) + 1];
        m  = methods[int(rand() * nm) + 1];
        p  = paths[int(rand() * np) + 1];
        c  = codes[int(rand() * ns) + 1];
        printf "%s - - [15/Aug/2026:%02d:%02d:%02d] \"%s %s HTTP/1.1\" %s\n",
               ip, int(rand() * 24), int(rand() * 60), int(rand() * 60), m, p, c;
    }
}' > "$LOG_FILE"

echo "$LOG_FILE создан, ($(wc -l < "$LOG_FILE") строк)"
echo

echo "Общее количество запросов: $(grep -c '' "$LOG_FILE")"
echo

echo "Топ-3 IP-адреса с наибольшим числом запросов:"
grep -oE "$IP_REGEX" "$LOG_FILE" | sort | uniq -c | sort -rn | head -3 | awk '{printf "  %s — %s запросов\n", $2, $1}'
echo

echo "Запросов с кодом 4xx: $(awk '$NF ~ /^4[0-9][0-9]$/' "$LOG_FILE" | wc -l)"
echo "Запросов с кодом 5xx: $(awk '$NF ~ /^5[0-9][0-9]$/' "$LOG_FILE" | wc -l)"