# pgAdmin 4 - Cấu Hình & Hướng Dẫn Vận Hành

Tài liệu này mô tả chi tiết toàn bộ thiết lập cấu hình, kiến trúc Docker và hướng dẫn vận hành cho dịch vụ **pgAdmin 4 Web GUI** trong nền tảng `lingoria-platform-deployment`.

---

## 1. Giới Thiệu & Vai Trò (Overview)

- **Mô tả chức năng:** Công cụ giao diện quản trị đồ hoạ trên nền web (Web-based Administration GUI) dành riêng cho PostgreSQL. Cho phép trực quan hoá lược đồ cơ sở dữ liệu (schema), thực thi truy vấn SQL, phân tích hiệu năng query, xem dữ liệu bảng và quản trị người dùng.
- **Docker Image chính thức:** `dpage/pgadmin4:8`.
- **Nguyên tắc triển khai:** Dịch vụ được khởi chạy ở trạng thái **hoàn toàn sạch (clean GUI)**. Chưa có server PostgreSQL nào được lưu sẵn trong danh mục kết nối nhằm đảm bảo tính độc lập.

---

## 2. Thông Số Cấu Hình Tĩnh (`configs/pgadmin.json`)

Toàn bộ thông số cấu hình không nhạy cảm của pgAdmin được định nghĩa tập trung tại file [configs/pgadmin.json](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/configs/pgadmin.json).

### 2.1 Bảng chi tiết các trường cấu hình:

| Tên trường (Key) | Kiểu dữ liệu | Giá trị mặc định | Giải thích chi tiết |
| :--- | :--- | :--- | :--- |
| `image` | string | `"dpage/pgadmin4:8"` | Docker Image chính thức phiên bản pgAdmin 4 v8 |
| `port` | number | `5050` | Cổng Web UI truy cập trên trình duyệt máy host |
| `container_name` | string | `"lingoria-pgadmin"` | Tên container pgAdmin khi chạy |
| `volume_name` | string | `"lingoria_pgadmin_data"` | Docker Volume lưu trữ phiên đăng nhập, cấu hình server |
| `admin` | string | `"admin@lingoria.local"` | Địa chỉ Email quản trị dùng để đăng nhập Web UI |
| `log_max_size` | string | `"10m"` | Kích thước file log stdout tối đa |
| `log_max_file` | string | `"3"` | Số file log luân phiên tối đa |

### 2.2 Nội dung file cấu hình:

```json
{
  "image": "dpage/pgadmin4:8",
  "port": 5050,
  "container_name": "lingoria-pgadmin",
  "volume_name": "lingoria_pgadmin_data",
  "admin": "admin@lingoria.local",
  "log_max_size": "10m",
  "log_max_file": "3"
}
```

---

## 3. Kiến Trúc Docker Compose (`values/pgadmin-compose.yaml`)

File Docker Compose độc lập của pgAdmin được lưu tại [values/pgadmin-compose.yaml](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/values/pgadmin-compose.yaml).

### 3.1 Bảng ánh xạ cổng & Container:

| Thành phần | Thông tin thiết lập |
| :--- | :--- |
| **Container Name** | `${PGADMIN_CONTAINER_NAME:-lingoria-pgadmin}` |
| **Port Mapping** | `"${PGADMIN_PORT:-5050}:80"` |
| **Restart Policy** | `unless-stopped` |

### 3.2 Cơ chế Khởi động & Nạp Mật khẩu:

- Entrypoint kiểm tra và tự động nạp mật khẩu từ file `/var/lib/pgadmin/.admin_password` trước khi khởi chạy `/entrypoint.sh` gốc của pgAdmin.
- Biến môi trường `PGADMIN_DEFAULT_EMAIL` được nạp từ trường `admin` của file `configs/pgadmin.json`.

---

## 4. Quản Lý Tài Khoản Quản Trị & Mật Khẩu Tự Sinh Trong Volume

Nhằm tuân thủ nguyên tắc bảo mật **Zero Credential on Host Filesystem**:
- **Tài khoản email đăng nhập:** Được định nghĩa qua `configs/pgadmin.json` với `"admin": "admin@lingoria.local"`.
- **Mật khẩu quản trị:** Được sinh ngẫu nhiên bằng `/proc/sys/kernel/random/uuid` trong lần khởi chạy đầu tiên và ghi trực tiếp vào volume:
  - **Đường dẫn file mật khẩu:** `/var/lib/pgadmin/.admin_password`
  - **Phân quyền bảo vệ:** `chmod 600`

### Xem mật khẩu quản trị:
Chạy lệnh sau trên terminal:
```bash
make show-credentials
```
Output sẽ hiển thị dòng:
```text
Pgadmin        admin@lingoria.local     <auto_generated_password>  http://localhost:5050
```

---

## 5. Quản Lý Lưu Trữ Dữ Liệu (Volumes) & Giới Hạn Nhật Ký (Log Limits)

### 5.1 Docker Volumes:
- Dữ liệu cấu hình người dùng, preferences và server connections được lưu trong Docker named volume: `lingoria_pgadmin_data`.
- Điểm mount trong container: `/var/lib/pgadmin`.
- Dữ liệu được bảo toàn khi dừng hoặc restart container (`make stop-pgadmin`, `make down`).
- Chỉ bị xoá khi chạy `make clean-data CONFIRM=YES`.

### 5.2 Giới hạn dung lượng Log (Log Limits):
- `driver: "json-file"`
- `max-size: "10m"`
- `max-file: "3"`
- Tự động làm rỗng (truncate) khi chạy lệnh định kỳ `make clean-logs`.

---

## 6. Kết Nối Mạng & Giao Tiếp Nội Bộ (Inter-Service Networking)

- **Docker Network:** `lingoria_network` (`external: true`).
- **Network Alias:** `pgadmin`.
- **Truy cập Web UI từ máy Host:**
  ```text
  http://localhost:5050
  ```
- **Kết nối tới PostgreSQL bên trong mạng Docker:**
  Khi cấu hình thêm Server mới trong pgAdmin:
  - **Host name/address:** `postgres`
  - **Port:** `5432`
  - **Maintenance database:** `postgres`
  - **Username:** `postgres`
  - **Password:** Lấy từ lệnh `make show-credentials` (mục Postgres)

---

## 7. Hướng Dẫn Vận Hành Thường Nhật

| Thao tác | Câu lệnh thực thi |
| :--- | :--- |
| **Triển khai pgAdmin** | `make deploy-pgadmin` |
| **Xem mật khẩu đăng nhập** | `make show-credentials` |
| **Theo dõi nhật ký realtime** | `make logs-pgadmin` |
| **Kiểm tra trạng thái container** | `make ps` |
| **Dừng pgAdmin (giữ dữ liệu)** | `make stop-pgadmin` |

---

## 8. Khởi Tạo Thủ Công Sau Khi Deploy (Post-Deployment Steps)

1. Mở trình duyệt truy cập: `http://localhost:5050`
2. Đăng nhập với:
   - **Email:** `admin@lingoria.local`
   - **Password:** Lấy từ lệnh `make show-credentials`
3. Đăng ký kết nối tới máy chủ PostgreSQL nội bộ:
   - Chuột phải vào **Servers** &rarr; **Register** &rarr; **Server...**
   - Tab **General**: Đặt tên gợi nhớ (ví dụ: `Lingoria Postgres`).
   - Tab **Connection**:
     - **Host name/address:** `postgres`
     - **Port:** `5432`
     - **Maintenance database:** `postgres`
     - **Username:** `postgres`
     - **Password:** Nhập mật khẩu của PostgreSQL lấy từ `make show-credentials`.
     - Tích chọn **Save password?**.
   - Nhấn **Save** để hoàn tất kết nối.
