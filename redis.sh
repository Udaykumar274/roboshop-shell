#!/bin/bash

set -euo pipefail

USERID=$(id -u)
R="\e[31m"; G="\e[32m"; Y="\e[33m"; N="\e[0m"
LOGS_FOLDER="/var/log/shell-roboshop"
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

mkdir -p "$LOGS_FOLDER"
echo "Script started at: $(date)" | tee -a "$LOG_FILE"

if [ "$USERID" -ne 0 ]; then
  echo -e "$R ERROR:: Please run this script as root $N"
  exit 1
fi

VALIDATE() {
  if [ $1 -ne 0 ]; then
    echo -e "$2 ... $R FAILURE $N" | tee -a "$LOG_FILE"
    exit 1
  else
    echo -e "$2 ... $G SUCCESS $N" | tee -a "$LOG_FILE"
  fi
}

yum install -y redis &>>"$LOG_FILE"
VALIDATE $? "Installing Redis"

# Allow remote connections, disable protected mode
if [ -f /etc/redis/redis.conf ]; then
  CONF=/etc/redis/redis.conf
else
  CONF=/etc/redis.conf
fi

sed -i -e 's/^bind .*/bind 0.0.0.0/' \
       -e 's/^protected-mode .*/protected-mode no/' "$CONF"
VALIDATE $? "Configuring Redis for remote access"

systemctl enable redis &>>"$LOG_FILE"
VALIDATE $? "Enabling Redis"

systemctl restart redis &>>"$LOG_FILE"
VALIDATE $? "Starting Redis"

echo -e "$G Redis setup complete $N"
