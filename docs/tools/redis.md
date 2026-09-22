# Redis - Cấu Hình & Hướng Dẫn Vận Hành

Tài liệu này mô tả chi tiết toàn bộ thiết lập cấu hình, kiến trúc Docker và hướng dẫn vận hành cho dịch vụ **Redis In-Memory Cache** trong nền tảng `lingoria-platform-deployment`.

---

## 1. Giới Thiệu & Vai Trò (Overview)

- **Mô tả chức năng:** Kho lưu trữ dữ liệu dạng key-value trong bộ nhớ (In-memory data store), được sử dụng làm bộ nhớ đệm (caching), message broker, quản lý phiên (session store) và phục vụ các tác vụ xử lý hàng đợi tốc độ cao trong hệ sinh thái Lingoria.
- **Docker Image chính thức:** `redis:7.4-alpine` (Bản Alpine siêu nhẹ, tối ưu tài nguyên và tốc độ khởi động).
- **Nguyên tắc triển khai:** Dịch vụ được khởi chạy ở trạng thái **hoàn toàn rỗng (clean cache)**, cơ chế lưu trữ AOF (Append-Only File) được kích hoạt để đảm bảo dữ liệu ghi vào không bị mất khi container khởi động lại.

---

## 2. Thông Số Cấu Hình Tĩnh (`configs/redis.json`)

Toàn bộ thông số cấu hình không nhạy cảm của Redis được định nghĩa tập trung tại file [configs/redis.json](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/configs/redis.json).

### 2.1 Bảng chi tiết các trường cấu hình:

| Tên trường (Key) | Kiểu dữ liệu | Giá trị mặc định | Giải thích chi tiết |
| :--- | :--- | :--- | :--- |
| `image` | string | `"redis:7.4-alpine"` | Image Docker chính thức tối ưu của Redis |
| `port` | number | `6379` | Cổng kết nối Redis tiêu chuẩn |
| `container_name` | string | `"lingoria-redis"` | Tên container Redis khi chạy |
| `volume_name` | string | `"lingoria_redis_data"` | Docker Volume lưu trữ dữ liệu AOF/RDB |
| `admin` | string | `"default"` | Tên tài khoản mặc định của Redis |
| `log_max_size` | string | `"10m"` | Kích thước file log stdout tối đa |
| `log_max_file` | string | `"3"` | Số file log luân phiên tối đa |

### 2.2 Nội dung file cấu hình:

```json
{
  "image": "redis:7.4-alpine",
  "port": 6379,
  "container_name": "lingoria-redis",
  "volume_name": "lingoria_redis_data",
  "admin": "default",
  "log_max_size": "10m",
  "log_max_file": "3"
}
```

---

## 3. Kiến Trúc Docker Compose (`values/redis-compose.yaml`)

File Docker Compose độc lập của Redis được lưu tại [values/redis-compose.yaml](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/values/redis-compose.yaml).

### 3.1 Bảng ánh xạ cổng & Container:

| Thành phần | Thông tin thiết lập |
| :--- | :--- |
| **Container Name** | `${REDIS_CONTAINER_NAME:-lingoria-redis}` |
| **Port Mapping** | `"${REDIS_PORT:-6379}:6379"` |
| **Command** | `redis-server --appendonly yes` |
| **Restart Policy** | `unless-stopped` |
| **Healthcheck Test** | `redis-cli ping` |

### 3.2 Cơ chế Lưu trữ Bền vững & Kiểm tra Sẵn sàng:

- Sử dụng cờ `--appendonly yes` để bật ghi chép log AOF vào đường dẫn `/data`, đảm bảo tính bền vững của dữ liệu qua các lần restart.
- Healthcheck sử dụng lệnh nội tại `redis-cli ping` với tần suất kiểm tra 5s một lần.

---

## 4. Quản Lý Tài Khoản Quản Trị & Cơ Chế Xác Thực

- **Tài khoản mặc định:** `default` (theo chuẩn mặc định của Redis).
- **Cơ chế xác thực cục bộ:** Trong môi trường phát triển local, Redis hoạt động ở chế độ mở (Open Cache / No Auth) bên trong Docker Network nội bộ để tối ưu hiệu năng và đơn giản hoá kết nối cho các dịch vụ phụ trợ.
- **Hiển thị trên bảng điều khiển:**
  Khi chạy lệnh `make show-credentials`, Redis sẽ hiển thị:
  ```text
  Redis          default                  [No auth / Open cache] localhost:6379
  ```

---

## 5. Quản Lý Lưu Trữ Dữ Liệu (Volumes) & Giới Hạn Nhật Ký (Log Limits)

### 5.1 Docker Volumes:
- Toàn bộ dữ liệu Redis được lưu trong Docker named volume: `lingoria_redis_data`.
- Điểm mount trong container: `/data`.
- Dữ liệu được bảo toàn khi dừng hoặc restart container (`make stop-redis`, `make down`).
- Chỉ bị xoá khi chạy `make clean-data CONFIRM=YES`.

### 5.2 Giới hạn dung lượng Log (Log Limits):
- `driver: "json-file"`
- `max-size: "10m"`
- `max-file: "3"`
- Tự động làm rỗng (truncate) khi chạy lệnh định kỳ `make clean-logs`.

---

## 6. Kết Nối Mạng & Giao Tiếp Nội Bộ (Inter-Service Networking)

- **Docker Network:** `lingoria_network` (`external: true`).
- **Network Alias:** `redis`.
- **Chuỗi kết nối nội bộ giữa các container trong mạng:**
  ```text
  redis://redis:6379/0
  ```
- **Kết nối từ máy Host (Dành cho redis-cli, RedisInsight):**
  ```text
  Host: localhost
  Port: 6379
  Database: 0 (hoặc index từ 0-15)
  ```

---

## 7. Hướng Dẫn Vận Hành Thường Nhật

| Thao tác | Câu lệnh thực thi |
| :--- | :--- |
| **Triển khai Redis** | `make deploy-redis` |
| **Xem thông tin xác thực** | `make show-credentials` |
| **Theo dõi nhật ký realtime** | `make logs-redis` |
| **Kiểm tra trạng thái container** | `make ps` |
| **Dừng Redis (giữ dữ liệu)** | `make stop-redis` |

---

## 8. Khởi Tạo Thủ Công Sau Khi Deploy (Post-Deployment Steps)

Redis sẵn sàng phục vụ ngay sau khi khởi động mà không cần bất kỳ bước cấu hình thủ công nào. Bạn có thể kiểm tra nhanh bằng `redis-cli`:

```bash
# Kiểm tra ping trực tiếp qua Docker exec
docker exec -it lingoria-redis redis-cli ping
# Kết quả trả về: PONG

# Kiểm tra ghi/đọc key
docker exec -it lingoria-redis redis-cli set test_key "hello_lingoria"
docker exec -it lingoria-redis redis-cli get test_key
# Kết quả trả về: "hello_lingoria"
```
