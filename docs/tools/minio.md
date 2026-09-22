# MinIO (Object Storage) - Cấu Hình & Hướng Dẫn Vận Hành

Tài liệu này mô tả chi tiết toàn bộ thiết lập cấu hình, kiến trúc Docker và hướng dẫn vận hành cho dịch vụ **MinIO Object Storage** trong nền tảng `lingoria-platform-deployment`.

---

## 1. Giới Thiệu & Vai Trò (Overview)

- **Mô tả chức năng:** Dịch vụ lưu trữ đối tượng (S3-compatible Object Storage) hiệu năng cao, chịu trách nhiệm lưu trữ các tệp âm thanh (audio), bản ghi phát âm, file hình ảnh, tài liệu thô (raw data) và các artifact dữ liệu của Lingoria.
- **Docker Image chính thức:** `quay.io/minio/minio:latest`.
- **Nguyên tắc triển khai:** Dịch vụ được khởi chạy ở trạng thái **hoàn toàn rỗng (0 bucket)**. Không có bucket nào được tự động tạo ngầm để đảm bảo kiểm soát hoàn toàn theo nhu cầu phát triển.

---

## 2. Thông Số Cấu Hình Tĩnh (`configs/minio.json`)

Toàn bộ thông số cấu hình không nhạy cảm của MinIO được định nghĩa tập trung tại file [configs/minio.json](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/configs/minio.json).

### 2.1 Bảng chi tiết các trường cấu hình:

| Tên trường (Key) | Kiểu dữ liệu | Giá trị mặc định | Giải thích chi tiết |
| :--- | :--- | :--- | :--- |
| `image` | string | `"quay.io/minio/minio:latest"` | Image Docker chính thức của MinIO |
| `port` | number | `9000` | Cổng API S3 (dành cho SDK kết nối) |
| `console_port` | number | `9001` | Cổng Web Console UI để quản trị trực quan |
| `container_name` | string | `"lingoria-minio"` | Tên container MinIO khi chạy |
| `volume_name` | string | `"lingoria_minio_data"` | Docker Volume lưu trữ dữ liệu các buckets |
| `admin` | string | `"minioadmin"` | Tên tài khoản Root User quản trị MinIO |
| `log_max_size` | string | `"10m"` | Kích thước file log stdout tối đa |
| `log_max_file` | string | `"3"` | Số file log luân phiên tối đa |

### 2.2 Nội dung file cấu hình:

```json
{
  "image": "quay.io/minio/minio:latest",
  "port": 9000,
  "console_port": 9001,
  "container_name": "lingoria-minio",
  "volume_name": "lingoria_minio_data",
  "admin": "minioadmin",
  "log_max_size": "10m",
  "log_max_file": "3"
}
```

---

## 3. Kiến Trúc Docker Compose (`values/minio-compose.yaml`)

File Docker Compose độc lập của MinIO được lưu tại [values/minio-compose.yaml](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/values/minio-compose.yaml).

### 3.1 Bảng ánh xạ cổng & Container:

| Thành phần | Thông tin thiết lập |
| :--- | :--- |
| **Container Name** | `${MINIO_CONTAINER_NAME:-lingoria-minio}` |
| **S3 API Port** | `"${MINIO_PORT:-9000}:9000"` |
| **Web Console Port** | `"${MINIO_CONSOLE_PORT:-9001}:9001"` |
| **Restart Policy** | `unless-stopped` |
| **Healthcheck Test** | `curl --fail http://localhost:9000/minio/health/live \|\| exit 1` |

### 3.2 Cơ chế Khởi động & Server Command:

- Khởi chạy lệnh: `minio server /data --console-address ":9001"`.
- Entrypoint kiểm tra và tự động nạp mật khẩu từ file `/data/.minio_admin_password` trước khi khởi chạy tiến trình server.

---

## 4. Quản Lý Tài Khoản Quản Trị & Mật Khẩu Tự Sinh Trong Volume

Nhằm tuân thủ nguyên tắc bảo mật **Zero Credential on Host Filesystem**:
- **Tên tài khoản quản trị:** Khai báo trong `configs/minio.json` với trường `"admin": "minioadmin"`.
- **Mật khẩu quản trị:** Được sinh ngẫu nhiên bằng `/proc/sys/kernel/random/uuid` trong lần khởi chạy đầu tiên và ghi trực tiếp vào volume:
  - **Đường dẫn file mật khẩu:** `/data/.minio_admin_password`
  - **Phân quyền bảo vệ:** `chmod 644`

### Xem mật khẩu quản trị:
Chạy lệnh sau trên terminal:
```bash
make show-credentials
```
Output sẽ hiển thị dòng:
```text
Minio          minioadmin               <auto_generated_password>  http://localhost:9001
```

---

## 5. Quản Lý Lưu Trữ Dữ Liệu (Volumes) & Giới Hạn Nhật Ký (Log Limits)

### 5.1 Docker Volumes:
- Toàn bộ dữ liệu object và metadata của MinIO được lưu trữ trong Docker named volume: `lingoria_minio_data`.
- Điểm mount trong container: `/data`.
- Dữ liệu được bảo toàn tuyệt đối khi chạy `make stop-minio` hoặc `make down`.
- Chỉ bị xoá khi chạy `make clean-data CONFIRM=YES`.

### 5.2 Giới hạn dung lượng Log (Log Limits):
- `driver: "json-file"`
- `max-size: "10m"`
- `max-file: "3"`
- Tự động làm rỗng (truncate) khi chạy lệnh định kỳ `make clean-logs`.

---

## 6. Kết Nối Mạng & Giao Tiếp Nội Bộ (Inter-Service Networking)

- **Docker Network:** `lingoria_network` (`external: true`).
- **Network Alias:** `minio`.
- **Endpoint nội bộ cho các container khác (Airflow, Backend, Ingestion):**
  ```text
  http://minio:9000
  ```
- **Truy cập từ máy Host:**
  - **S3 API:** `http://localhost:9000`
  - **Web Console UI:** `http://localhost:9001`
- **Tài khoản liên lạc Inter-Service:** Nếu dịch vụ khác cần secret key cố định, có thể sử dụng biến `MINIO_SECRET_KEY` trong file [.env](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/.env).

---

## 7. Hướng Dẫn Vận Hành Thường Nhật

| Thao tác | Câu lệnh thực thi |
| :--- | :--- |
| **Triển khai MinIO** | `make deploy-minio` |
| **Xem mật khẩu admin** | `make show-credentials` |
| **Theo dõi nhật ký realtime** | `make logs-minio` |
| **Kiểm tra trạng thái container** | `make ps` |
| **Dừng MinIO (giữ dữ liệu)** | `make stop-minio` |

---

## 8. Khởi Tạo Thủ Công Sau Khi Deploy (Post-Deployment Steps)

Do MinIO được triển khai hoàn toàn rỗng, bạn có thể tạo các bucket theo 2 cách:

### Cách 1: Sử dụng MinIO Web Console UI (Khuyến khích)
1. Mở trình duyệt truy cập: `http://localhost:9001`
2. Đăng nhập với User: `minioadmin` và Password lấy từ `make show-credentials`.
3. Nhấp chọn **Buckets** &rarr; **Create Bucket**, tạo các bucket sau:
   - `lingoria-raw`
   - `lingoria-media-original`
   - `lingoria-media-derived`
   - `lingoria-local`

### Cách 2: Sử dụng MinIO Client CLI (`mc`) bên trong container
```bash
# Đọc mật khẩu
PASSWORD=$(docker exec lingoria-minio cat /data/.minio_admin_password)

# Cấu hình alias cho mc
docker exec lingoria-minio mc alias set local http://localhost:9000 minioadmin "$PASSWORD"

# Tạo các buckets
docker exec lingoria-minio mc mb local/lingoria-raw
docker exec lingoria-minio mc mb local/lingoria-media-original
docker exec lingoria-minio mc mb local/lingoria-media-derived
docker exec lingoria-minio mc mb local/lingoria-local
```
