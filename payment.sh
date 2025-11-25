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

yum install -y python3 gcc python3-devel &>>"$LOG_FILE"
VALIDATE $? "Installing Python3 & build tools"

id roboshop &>>"$LOG_FILE" || useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>"$LOG_FILE"
VALIDATE $? "Ensuring roboshop user"

rm -rf /app
mkdir -p /app
chown roboshop:roboshop /app
VALIDATE $? "Preparing /app"

curl -L -o /tmp/payment.zip https://roboshop-artifacts.s3.amazonaws.com/payment-v3.zip &>>"$LOG_FILE"
VALIDATE $? "Downloading payment artefact"

unzip -o /tmp/payment.zip -d /app &>>"$LOG_FILE"
VALIDATE $? "Unzipping payment"

cd /app
pip3 install --upgrade pip &>>"$LOG_FILE"
pip3 install -r requirements.txt &>>"$LOG_FILE"
VALIDATE $? "Installing Python dependencies"

cp "$SCRIPT_DIR/payment.service" /etc/systemd/system/payment.service
VALIDATE $? "Copying payment.service"

systemctl daemon-reload
systemctl enable payment &>>"$LOG_FILE"
VALIDATE $? "Enabling payment"

systemctl restart payment &>>"$LOG_FILE"
VALIDATE $? "Starting payment"

echo -e "$G Payment service setup complete $N"
