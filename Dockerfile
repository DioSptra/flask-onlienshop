FROM python:3.10-slim

WORKDIR /app
COPY . .

RUN apt-get update && apt-get install -y logrotate \
    && pip install flask werkzeug psycopg2-binary

RUN pip install flask werkzeug psycopg2-binary prometheus-flask-exporter

RUN mkdir -p /var/log && touch /var/log/myapp.log
COPY logrotate.conf /etc/logrotate.d/myapp

CMD ["python", "app.py"]
