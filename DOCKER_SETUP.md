# Docker Setup Guide cho ChromaDB Admin

Hướng dẫn chi tiết về cách setup và chạy ChromaDB Admin bằng Docker và Docker Compose.

## Yêu cầu hệ thống

- Docker >= 20.10
- Docker Compose >= 1.29
- Ít nhất 2GB RAM khả dụng
- Ít nhất 5GB dung lượng ổ cứng

## Kiến trúc

Docker setup này bao gồm 2 services chính:

1. **chromadb**: ChromaDB vector database server (port 8000)
2. **chromadb-admin**: Next.js admin UI (port 3001)

Cả 2 services được kết nối thông qua một Docker network riêng (`chromadb-network`) và ChromaDB data được persist trong Docker volume (`chroma_data`).

## Cách sử dụng

### 1. Build và khởi động tất cả services

```bash
# Build images và start containers ở chế độ detached (chạy nền)
docker-compose up -d

# Hoặc xem logs realtime khi start
docker-compose up
```

### 2. Kiểm tra trạng thái services

```bash
# Xem danh sách containers đang chạy
docker-compose ps

# Xem logs của tất cả services
docker-compose logs

# Xem logs của một service cụ thể
docker-compose logs chromadb
docker-compose logs chromadb-admin

# Theo dõi logs realtime
docker-compose logs -f
```

### 3. Truy cập ứng dụng

- **ChromaDB Admin UI**: http://localhost:3001
- **ChromaDB API**: http://localhost:8000
- **ChromaDB API Docs**: http://localhost:8000/docs

Khi mở Admin UI lần đầu, bạn cần cấu hình connection string:
- Connection String: `http://chromadb:8000` (từ bên trong container)
- Hoặc: `http://localhost:8000` (từ browser của bạn)

### 4. Dừng services

```bash
# Dừng tất cả containers (giữ lại data)
docker-compose stop

# Dừng và xóa containers (giữ lại data)
docker-compose down

# Dừng, xóa containers VÀ XÓA DATA
docker-compose down -v
```

### 5. Rebuild sau khi thay đổi code

```bash
# Rebuild và restart
docker-compose up -d --build

# Rebuild một service cụ thể
docker-compose build chromadb-admin
docker-compose up -d chromadb-admin
```

## Cấu hình nâng cao

### Bật Token Authentication cho ChromaDB

Uncomment các dòng sau trong `docker-compose.yml`:

```yaml
environment:
  - CHROMA_SERVER_AUTHN_CREDENTIALS=test-token
  - CHROMA_AUTH_TOKEN_TRANSPORT_HEADER=AUTHORIZATION
  - CHROMA_SERVER_AUTHN_PROVIDER=chromadb.auth.token_authn.TokenAuthenticationServerProvider
```

Sau đó restart:

```bash
docker-compose down
docker-compose up -d
```

Khi connect từ Admin UI, bạn cần cung cấp token trong phần authentication settings.

### Thay đổi ports

Nếu port 3001 hoặc 8000 đã được sử dụng, bạn có thể thay đổi trong `docker-compose.yml`:

```yaml
ports:
  - "8001:8000"  # Thay vì 8000:8000
  - "3002:3001"  # Thay vì 3001:3001
```

### Mount data directory từ host

Nếu muốn ChromaDB data được lưu ở một thư mục cụ thể trên máy host:

```yaml
volumes:
  - ./chroma-data:/chroma/chroma  # Thay vì named volume
```

## Troubleshooting

### Container không start được

```bash
# Xem logs để tìm lỗi
docker-compose logs chromadb
docker-compose logs chromadb-admin

# Kiểm tra trạng thái health check
docker inspect chromadb-server | grep -A 10 Health
```

### Xóa tất cả và start lại từ đầu

```bash
# Dừng và xóa tất cả (bao gồm volumes)
docker-compose down -v

# Xóa images (nếu cần rebuild từ đầu)
docker rmi chromadb/chroma:latest
docker rmi chromadb-admin-chromadb-admin

# Build và start lại
docker-compose up -d --build
```

### ChromaDB Admin không kết nối được với ChromaDB

1. Kiểm tra ChromaDB service đã chạy chưa:
   ```bash
   docker-compose ps chromadb
   curl http://localhost:8000/api/v1/heartbeat
   ```

2. Kiểm tra network:
   ```bash
   docker network inspect chromadb-admin_chromadb-network
   ```

3. Từ bên trong container chromadb-admin, test connection:
   ```bash
   docker-compose exec chromadb-admin sh
   curl http://chromadb:8000/api/v1/heartbeat
   ```

### Port đã được sử dụng

Nếu gặp lỗi "port already in use":

```bash
# Tìm process đang dùng port
lsof -i :3001
lsof -i :8000

# Kill process (nếu cần)
kill -9 <PID>

# Hoặc thay đổi port trong docker-compose.yml
```

## Development Workflow

### Chạy development mode

Nếu muốn chạy development mode với hot reload:

1. Chỉ start ChromaDB bằng Docker:
   ```bash
   docker-compose up -d chromadb
   ```

2. Chạy Next.js app local:
   ```bash
   npm install
   npm run dev
   ```

3. Connect tới ChromaDB tại: `http://localhost:8000`

### Debug bên trong container

```bash
# Vào shell của container
docker-compose exec chromadb-admin sh
docker-compose exec chromadb sh

# Xem environment variables
docker-compose exec chromadb-admin env

# Xem files
docker-compose exec chromadb-admin ls -la
```

## Backup và Restore

### Backup ChromaDB data

```bash
# Backup volume
docker run --rm -v chromadb-admin_chroma_data:/data -v $(pwd):/backup alpine tar czf /backup/chroma-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .
```

### Restore ChromaDB data

```bash
# Stop services
docker-compose down

# Restore volume
docker run --rm -v chromadb-admin_chroma_data:/data -v $(pwd):/backup alpine tar xzf /backup/chroma-backup-YYYYMMDD-HHMMSS.tar.gz -C /data

# Start services
docker-compose up -d
```

## Production Deployment

Khi deploy lên production, cần lưu ý:

1. **Bật authentication** cho ChromaDB
2. **Sử dụng environment variables** thay vì hardcode
3. **Setup reverse proxy** (nginx/traefik) với SSL
4. **Configure backup** tự động cho ChromaDB data
5. **Monitor resource usage** (RAM, CPU, disk)
6. **Setup logging** với log aggregation tool

## Tài liệu tham khảo

- [ChromaDB Documentation](https://docs.trychroma.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Next.js Deployment](https://nextjs.org/docs/deployment)

