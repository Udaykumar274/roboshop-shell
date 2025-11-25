#!/bin/bash

set -euo pipefail

USERID=$(id -u)
R="\e[31m"; G="\e[32m"; Y="\e[33m"; N="\e[0m"
LOGS_FOLDER="/var/log/shell-roboshop"
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$(pwd)
MYSQL_HOST="54.82.26.35"   # replace with your MySQL public IP

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

yum install -y maven &>>"$LOG_FILE"
VALIDATE $? "Installing Maven"

id roboshop &>>"$LOG_FILE" || useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>"$LOG_FILE"
VALIDATE $? "Ensuring roboshop user"

rm -rf /app
mkdir -p /app
chown roboshop:roboshop /app
VALIDATE $? "Preparing /app"

curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip &>>"$LOG_FILE"
VALIDATE $? "Downloading shipping artefact"

unzip -o /tmp/shipping.zip -d /app &>>"$LOG_FILE"
VALIDATE $? "Unzipping shipping"

cd /app
sudo -u roboshop mvn clean package &>>"$LOG_FILE"
VALIDATE $? "Building shipping.jar"

mv target/shipping-1.0.jar shipping.jar &>>"$LOG_FILE"
VALIDATE $? "Moving shipping.jar"

cp "$SCRIPT_DIR/shipping.service" /etc/systemd/system/shipping.service
VALIDATE $? "Copying shipping.service"

systemctl daemon-reload

yum install -y mysql &>>"$LOG_FILE"
VALIDATE $? "Installing MySQL client"

mysql -h "$MYSQL_HOST" -uroot -pRoboShop@1 -e 'USE cities;' &>>"$LOG_FILE" || {
  mysql -h "$MYSQL_HOST" -uroot -pRoboShop@1 < /app/db/schema.sql &>>"$LOG_FILE"
  mysql -h "$MYSQL_HOST" -uroot -pRoboShop@1 < /app/db/app-user.sql &>>"$LOG_FILE"
  mysql -h "$MYSQL_HOST" -uroot -pRoboShop@1 < /app/db/master-data.sql &>>"$LOG_FILE"
}
VALIDATE $? "Loading shipping DB data"

systemctl enable shipping &>>"$LOG_FILE"
VALIDATE $? "Enabling shipping"

systemctl restart shipping &>>"$LOG_FILE"
VALIDATE $? "Starting shipping"

echo -e "$G Shipping service setup complete $N"
