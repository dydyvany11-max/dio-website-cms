FROM alpine:3.20

RUN apk add --no-cache sqlite tzdata

COPY backup.sh /usr/local/bin/backup.sh
COPY restore.sh /usr/local/bin/restore.sh
COPY start-cron.sh /usr/local/bin/start-cron.sh

RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/restore.sh /usr/local/bin/start-cron.sh

CMD ["sh", "/usr/local/bin/start-cron.sh"]
