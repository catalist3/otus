#!/bin/bash

# Считаем количество строк в лог-файле и сохраняем в переменную
countlines=$( wc /tmp/access-4560-644067.log | awk '{print $1}')

# Определяем даты начала: 
StartLog=$( awk '{print $4, $5}' /tmp/access-4560-644067.log | sed 's/\[//; s/\]//' | sed -n 1p)
# И соответственно конца лог-файла
EndLog=$( awk '{print $4, $5}' /tmp/access-4560-644067.log | sed 's/\[//; s/\]//' | sed -n "$countlines"p)

# Определяем IP-адреса с количество запросов  
listIP=$(grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" access-4560-644067.log | sort | uniq -c | sort -rn | awk '{if ($1 > 8) print $1, $2}' | awk -f formatfile)

# Определяем успешные запросы 
listAdress=$(awk '($9 ~ /200/)' /tmp/access-4560-644067.log | awk '{print $7, $9}'|sort|uniq -c|sort -rn | awk '($1 > 6) {print $2}')

# Определяем ошибки(события с кодами 4хх,5хх) 
listErrors=$(awk '{print $9}' /tmp/access-4560-644067.log | sort | uniq -c | awk '($2 ~ /^[4-5][0-9][0-9]/)' | sort -rn)

# Общий отчет с имитацией его отсылки на почтовый ящик 
echo -e "Data for period from:" $StartLog "to" $EndLog "\n\n $listIP" "\n\n List address request: \n $listAdress" "\n\n Errors list for 4xx_and_5xx \n $listErrors" | mail -s "Report message" root@localhost
