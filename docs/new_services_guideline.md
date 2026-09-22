# Hướng Dẫn Từng Bước Thêm & Triển Khai Service Mới (New Services Guideline)

Tài liệu này hướng dẫn chi tiết từng bước chuẩn hoá (Step-by-Step) để tích hợp và triển khai một công cụ hoặc dịch vụ mới vào nền tảng `lingoria-platform-deployment`.

Toàn bộ quy trình được thiết kế theo tư duy **Modular Helm Values**, tuân thủ nghiêm ngặt 5 nguyên tắc cốt lõi:
1. **Dịch vụ rỗng & độc lập**: Chỉ triển khai container sạch, không tự động nạp schema ứng dụng hoặc phụ thuộc vào repository khác.
2. **Tách biệt cấu hình & bí mật**: Mọi thông số cấu hình tĩnh (image, port, user, volume) nằm trong `configs/<tool>.json`. File `.env` chỉ chứa project name, network và mật khẩu giao tiếp inter-service (nếu có).
3. **Mật khẩu quản trị tự sinh trong volume**: Mật khẩu admin/superuser được tự động generate bên trong container và lưu vào Volume. Tuyệt đối **không lưu bất kỳ file mật khẩu nào trên máy cá nhân**.
4. **Mạng chia sẻ**: Mọi service kết nối với nhau thông qua Docker network nội bộ `lingoria_network` (`external: true`).
5. **Kiểm soát dung lượng log**: Mọi container đều phải cấu hình giới hạn kích thước log file (`max-size: 10m`, `max-file: 3`).

---

## Ví Dụ Thực Tế: Tích Hợp Dịch Vụ MongoDB (`mongodb`)

Dưới đây là quy trình 7 bước cụ thể để thêm một công cụ mới mang tên `mongodb`.

---

### Bước 1: Tạo File Cấu Hình `configs/<tool_name>.json`

Tạo file mới tại [configs/mongodb.json](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/configs/mongodb.json) để định nghĩa toàn bộ thông số hoạt động của service:

```json
{
  "image": "mongo:7.0",
  "port": 27017,
  "container_name": "lingoria-mongodb",
  "volume_name": "lingoria_mongodb_data",
  "admin": "root",
  "log_max_size": "10m",
  "log_max_file": "3"
}
```

**Giải thích các trường bắt buộc:**
- `image`: Docker Image tag chính thức.
- `port`: Cổng port mở ra máy host để dev truy cập.
- `container_name`: Tên container khi chạy (quy ước: `lingoria-<tool>`).
- `volume_name`: Tên Docker Volume lưu trữ dữ liệu (quy ước: `lingoria_<tool>_data`).
- `admin` (hoặc `superuser`): Tên tài khoản quản trị cao nhất của tool.
- `log_max_size` & `log_max_file`: Giới hạn log stdout của Docker daemon (khuyên dùng `10m` và `3`).

---

### Bước 2: Tạo File Docker Compose Template `values/<tool_name>-compose.yaml`

Tạo file mới tại [values/mongodb-compose.yaml](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/values/mongodb-compose.yaml):

```yaml
name: lingoria

services:
  mongodb:
    image: ${MONGODB_IMAGE:-mongo:7.0}
    container_name: ${MONGODB_CONTAINER_NAME:-lingoria-mongodb}
    restart: unless-stopped
    entrypoint:
      - /bin/bash
      - -c
      - |
        PW_FILE="/data/db/.admin_password"
        if [ ! -f "$$PW_FILE" ]; then
          mkdir -p /data/db
          IFS="-" read -r a b c d e < /proc/sys/kernel/random/uuid
          echo "$${a}$${b}$${c}$${d}" > "$$PW_FILE"
          chmod 600 "$$PW_FILE"
        fi
        export MONGO_INITDB_ROOT_PASSWORD=$$(cat "$$PW_FILE")
        exec docker-entrypoint.sh mongod
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGODB_ADMIN:-root}
    ports:
      - "${MONGODB_PORT:-27017}:27017"
    volumes:
      - ${MONGODB_VOLUME_NAME:-lingoria_mongodb_data}:/data/db
    healthcheck:
      test: ["CMD-SHELL", "echo 'db.runCommand(\"ping\").ok' | mongosh localhost:27017/test --quiet"]
      interval: 10s
      timeout: 5s
      retries: 5
    logging:
      driver: "json-file"
      options:
        max-size: "${LOG_MAX_SIZE:-10m}"
        max-file: "${LOG_MAX_FILE:-3}"
    networks:
      lingoria_network:
        aliases:
          - mongodb

volumes:
  lingoria_mongodb_data:
    name: ${MONGODB_VOLUME_NAME:-lingoria_mongodb_data}

networks:
  lingoria_network:
    name: ${COMPOSE_NETWORK:-lingoria_network}
    external: true
```

**Các điểm kỹ thuật quan trọng cần lưu ý:**
1. **Khối `entrypoint` tự sinh mật khẩu:**
   - Kiểm tra xem file `.admin_password` đã tồn tại trong thư mục dữ liệu của volume chưa (`/data/db/.admin_password`).
   - Nếu chưa có (lần đầu khởi chạy), đọc entropy từ `/proc/sys/kernel/random/uuid` để sinh chuỗi ngẫu nhiên và lưu vào file này.
   - Nạp mật khẩu vào biến môi trường khởi tạo (`MONGO_INITDB_ROOT_PASSWORD`) và gọi entrypoint gốc của image.
2. **Biến môi trường nội suy:** Sử dụng cú pháp `${MONGODB_ADMIN:-root}` để ưu tiên lấy giá trị tự động inject từ `configs/mongodb.json`.
3. **Mạng `lingoria_network`:** Khai báo `external: true` và đặt `aliases` là tên ngắn gọn của tool (ví dụ: `mongodb`) để các service khác có thể gọi tới theo hostname này.

---

### Bước 3: Đăng Ký Tool Vào Bộ Script Quản Lý

#### 3.1 Cập nhật [scripts/deploy.sh](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/scripts/deploy.sh)
Mở file `scripts/deploy.sh`, bổ sung tool vào 2 hàm:
```bash
get_tool_compose_file() {
  local target="$1"
  case "$target" in
    postgres) echo "values/postgres-compose.yaml" ;;
    minio)    echo "values/minio-compose.yaml" ;;
    redis)    echo "values/redis-compose.yaml" ;;
    airflow)  echo "values/airflow-compose.yaml" ;;
    pgadmin)  echo "values/pgadmin-compose.yaml" ;;
    mongodb)  echo "values/mongodb-compose.yaml" ;; # <-- Thêm dòng này
    *)        echo "values/${target}-compose.yaml" ;;
  esac
}

get_available_tools() {
  echo "postgres minio redis airflow pgadmin mongodb" # <-- Thêm mongodb
}
```

#### 3.2 Cập nhật [scripts/stop.sh](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/scripts/stop.sh)
Mở file `scripts/stop.sh`, bổ sung tương tự:
```bash
get_tool_compose_file() {
  ...
    mongodb)  echo "values/mongodb-compose.yaml" ;; # <-- Thêm dòng này
  ...
}

get_available_tools() {
  echo "postgres minio redis airflow pgadmin mongodb" # <-- Thêm mongodb
}
```

---

### Bước 4: Đăng Ký Đọc Mật Khẩu Trong [scripts/show-credentials.sh](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/scripts/show-credentials.sh)

Để lệnh `make show-credentials` hiển thị được thông tin tài khoản của service mới, mở `scripts/show-credentials.sh` và thêm đoạn logic đọc từ container volume:

```bash
# MongoDB
mongo_container="lingoria-mongodb"
mongo_user="$(get_json_prop "configs/mongodb.json" "admin" "root")"
mongo_port="$(get_json_prop "configs/mongodb.json" "port" "27017")"
if is_running "$mongo_container"; then
  mongo_pwd="$(docker exec "$mongo_container" cat /data/db/.admin_password 2>/dev/null || echo '[Not found in volume]')"
  printf "%-14s %-24s %-22s %s\n" "MongoDB" "$mongo_user" "$mongo_pwd" "localhost:${mongo_port}"
else
  printf "%-14s %-24s %-22s %s\n" "MongoDB" "$mongo_user" "[Container stopped]" "localhost:${mongo_port}"
fi
```

---

### Bước 5: Thêm Lệnh Triển Khai Vào [Makefile](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/Makefile) (Tùy Chọn)

Nhờ có generic rule `deploy-%` và `stop-%` trong Makefile, bạn đã có thể chạy ngay `make deploy-mongodb` và `make stop-mongodb`.

Nếu muốn lệnh hiển thị rõ ràng trong menu `make help`, bạn có thể bổ sung vào Makefile:
```makefile
deploy-mongodb: check
	@./scripts/deploy.sh mongodb
```
Đồng thời cập nhật mô tả trong mục `help:` của Makefile.

---

### Bước 6: Viết Tài Liệu Chi Tiết Cho Tool Trong `docs/tools/<tool_name>.md`

Tạo file tài liệu riêng cho tool tại [docs/tools/mongodb.md](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/docs/tools/mongodb.md).

> [!IMPORTANT]
> Nội dung file phải tuân thủ nghiêm ngặt cấu trúc chuẩn được định nghĩa tại [docs/template.md](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/docs/template.md).

---

### Bước 7: Kiểm Thử Toàn Diện (Verification)

Thực hiện chuỗi kiểm thử sau trên terminal để đảm bảo service mới hoạt động ổn định:

1. **Kiểm tra cú pháp cấu hình (Dry-run):**
   ```bash
   ./scripts/deploy.sh --dry-run mongodb
   ```
   *Yêu cầu:* Lệnh kết thúc với exit code `0` và hiển thị đầy đủ cấu hình YAML đã được render.

2. **Khởi chạy container:**
   ```bash
   make deploy-mongodb
   ```
   *Yêu cầu:* Container khởi động thành công và vượt qua kiểm tra readiness/healthcheck.

3. **Kiểm tra mật khẩu tự sinh:**
   ```bash
   make show-credentials
   ```
   *Yêu cầu:* Dòng `MongoDB` hiển thị đúng user `root`, mật khẩu ngẫu nhiên được đọc từ volume và cổng `localhost:27017`.

4. **Kiểm tra nhật ký (Logs):**
   ```bash
   make logs-mongodb
   ```
   *Yêu cầu:* Log hiển thị MongoDB sẵn sàng nhận kết nối (`Waiting for connections`).

5. **Dừng container:**
   ```bash
   make stop-mongodb
   ```
   *Yêu cầu:* Container được gỡ bỏ an toàn, dữ liệu trong volume vẫn nguyên vẹn.
