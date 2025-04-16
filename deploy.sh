#!/bin/bash

echo "🚀 Mulai proses deployment..."

cd /home/ubuntu/flask_shop_postgres || exit 1

# === INSTALL DOCKER ===
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
else
    echo "✅ Docker sudah terinstall."
fi
echo "🧹 Cek dan hapus container lama kalau ada..."

# Daftar service yang mau lo bersihin
SERVICES=("web" "db" "prometheus" "grafana")

for SERVICE in "${SERVICES[@]}"; do
    CONTAINER_NAME="flask_shop_postgres_${SERVICE}_1"
    if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
        echo "🛑 Stop & remove container: $CONTAINER_NAME"
        docker stop $CONTAINER_NAME
        docker rm $CONTAINER_NAME
    fi
done

# --- Install docker-compose ---
if ! command -v docker-compose &> /dev/null; then
    echo "🔧 Installing docker-compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# --- Git pull update ---
echo "📥 Menarik update dari git..."
git pull origin staging

# --- Database & init ---
echo "🗃️ Menyalakan database..."
docker-compose up -d db
sleep 5

echo "🛠️ Menjalankan init.sql..."
docker exec -i $(docker ps -qf "ancestor=postgres:13") psql -U user -d mydatabase < init.sql

# --- Build dan run app ---
echo "🐳 Membangun container..."
docker-compose up --build -d

# === NODE EXPORTER INSTALL ===
if ! command -v node_exporter &> /dev/null; then
    echo "📦 Installing Node Exporter..."
    wget https://github.com/prometheus/node_exporter/releases/download/v1.8.0/node_exporter-1.8.0.linux-amd64.tar.gz
    tar xvfz node_exporter-1.8.0.linux-amd64.tar.gz
    sudo mv node_exporter-1.8.0.linux-amd64/node_exporter /usr/local/bin/
    sudo useradd -rs /bin/false nodeusr

    sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=nodeusr
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOF

    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl enable node_exporter
    sudo systemctl start node_exporter
else
    echo "✅ Node Exporter sudah terinstall."
fi

# === PROMETHEUS INSTALL ===
if ! command -v prometheus &> /dev/null; then
    echo "📦 Installing Prometheus..."
    wget https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz
    tar xvfz prometheus-2.52.0.linux-amd64.tar.gz
    sudo mv prometheus-2.52.0.linux-amd64 /opt/prometheus
    sudo ln -s /opt/prometheus/prometheus /usr/local/bin/prometheus
    sudo ln -s /opt/prometheus/promtool /usr/local/bin/promtool

    sudo useradd --no-create-home --shell /bin/false prometheus

    sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/opt/prometheus/prometheus.yml \\
  --storage.tsdb.path=/opt/prometheus/data

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable prometheus
    sudo systemctl start prometheus
else
    echo "✅ Prometheus sudah terinstall."
fi

echo "✅ SEMUA BERHASIL DIPASANG!"
