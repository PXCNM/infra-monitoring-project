#!/usr/bin/env bash

url="$1"

code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$url")

if [ "$code" = "200" ]; then
    echo "API доступен"
    exit 0
else
    echo "API недоступен, код ответа: $code"
    exit 1
fi