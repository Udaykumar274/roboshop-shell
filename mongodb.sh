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

SCRIPT_DIR=$(pwd)

cp "$SCRIPT_DIR/mongo.repo" /etc/yum.repos.d/mongo.repo &>>"$LOG_FILE"
VALIDATE $? "Adding MongoDB repo"

yum install -y mongodb-org &>>"$LOG_FILE"
VALIDATE $? "Installing MongoDB"

# Bind to all interfaces
sed -i 's/^\s*bindIp:.*/  bindIp: 0.0.0.0/' /etc/mongod.conf
VALIDATE $? "Configuring mongod bindIp"

mkdir -p /var/log/mongodb
chown mongod:mongod /var/log/mongodb
VALIDATE $? "Ensuring Mongo log dir"

systemctl enable mongod &>>"$LOG_FILE"
VALIDATE $? "Enabling mongod"

systemctl restart mongod &>>"$LOG_FILE"
VALIDATE $? "Starting mongod"

echo -e "$G MongoDB setup complete $N"
