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

NODE_TARBALL_URL="https://nodejs.org/dist/v16.20.2/node-v16.20.2-linux-x64.tar.xz"
NODE_DIR="/usr/local/node-v16.20.2-linux-x64"

if ! command -v node &>/dev/null; then
  curl -L -o /tmp/node-v16.20.2-linux-x64.tar.xz "$NODE_TARBALL_URL" &>>"$LOG_FILE"
  VALIDATE $? "Downloading NodeJS 16 tarball"

  mkdir -p /usr/local
  tar -xJf /tmp/node-v16.20.2-linux-x64.tar.xz -C /usr/local &>>"$LOG_FILE"
  VALIDATE $? "Extracting NodeJS 16"

  for bin in node npm npx; do
    ln -sf "$NODE_DIR/bin/$bin" "/usr/bin/$bin"
  done
  VALIDATE $? "Creating NodeJS symlinks"
fi

id roboshop &>>"$LOG_FILE" || useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>"$LOG_FILE"
VALIDATE $? "Ensuring roboshop user"

rm -rf /app
mkdir -p /app
chown roboshop:roboshop /app
VALIDATE $? "Preparing /app"

curl -L -o /tmp/cart.zip https://roboshop-artifacts.s3.amazonaws.com/cart-v3.zip &>>"$LOG_FILE"
VALIDATE $? "Downloading cart artefact"

unzip -o /tmp/cart.zip -d /app &>>"$LOG_FILE"
VALIDATE $? "Unzipping cart"

cd /app
sudo -u roboshop npm install &>>"$LOG_FILE"
VALIDATE $? "Installing Node dependencies"

cp "$SCRIPT_DIR/cart.service" /etc/systemd/system/cart.service
VALIDATE $? "Copying cart.service"

systemctl daemon-reload
systemctl enable cart &>>"$LOG_FILE"
VALIDATE $? "Enabling cart"

systemctl restart cart &>>"$LOG_FILE"
VALIDATE $? "Starting cart"

echo -e "$G Cart service setup complete $N"
