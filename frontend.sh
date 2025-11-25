#!/bin/bash

set -euo pipefail

USERID=$(id -u)
R="\e[31m"; G="\e[32m"; Y="\e[33m"; N="\e[0m"
LOGS_FOLDER="/var/log/shell-roboshop"
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$(pwd)

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

# Install nginx via amazon-linux-extras
if ! command -v nginx &>/dev/null; then
  amazon-linux-extras install -y nginx1 &>>"$LOG_FILE"
  VALIDATE $? "Installing Nginx"
fi

systemctl enable nginx &>>"$LOG_FILE"
systemctl start nginx &>>"$LOG_FILE"
VALIDATE $? "Starting Nginx"

rm -rf /usr/share/nginx/html/*
VALIDATE $? "Cleaning nginx html"

curl -L -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip &>>"$LOG_FILE"
VALIDATE $? "Downloading frontend artefact"

unzip -o /tmp/frontend.zip -d /usr/share/nginx/html &>>"$LOG_FILE"
VALIDATE $? "Unzipping frontend"

cp "$SCRIPT_DIR/nginx.conf" /etc/nginx/nginx.conf
VALIDATE $? "Copying nginx.conf"

nginx -t &>>"$LOG_FILE"
VALIDATE $? "Nginx config test"

systemctl restart nginx &>>"$LOG_FILE"
VALIDATE $? "Restarting Nginx"

echo -e "$G Frontend setup complete $N"
