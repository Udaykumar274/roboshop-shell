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

cp "$SCRIPT_DIR/rabbitmq.repo" /etc/yum.repos.d/rabbitmq.repo &>>"$LOG_FILE"
VALIDATE $? "Adding RabbitMQ repo"

yum install -y rabbitmq-server &>>"$LOG_FILE"
VALIDATE $? "Installing RabbitMQ Server"

systemctl enable rabbitmq-server &>>"$LOG_FILE"
VALIDATE $? "Enabling RabbitMQ"

systemctl restart rabbitmq-server &>>"$LOG_FILE"
VALIDATE $? "Starting RabbitMQ"

rabbitmqctl add_user roboshop roboshop123 &>>"$LOG_FILE" || true
rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*" &>>"$LOG_FILE"
VALIDATE $? "Setting up roboshop RabbitMQ user and permissions"

echo -e "$G RabbitMQ setup complete $N"
