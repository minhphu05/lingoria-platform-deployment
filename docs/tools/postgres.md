# PostgreSQL (pgvector) - Cấu Hình & Hướng Dẫn Vận Hành

Tài liệu này mô tả chi tiết toàn bộ thiết lập cấu hình, kiến trúc Docker và hướng dẫn vận hành cho dịch vụ **PostgreSQL** trong nền tảng `lingoria-platform-deployment`.

---

## 1. Giới Thiệu & Vai Trò (Overview)

- **Mô tả chức năng:** Hệ quản trị cơ sở dữ liệu quan hệ (RDBMS) chính của nền tảng, tích hợp sẵn extension vector search (`pgvector`) phục vụ lưu trữ embeddings, metadata, tài nguyên ngôn ngữ và cơ sở dữ liệu metadata cho Apache Airflow.
- **Docker Image chính thức:** `pgvector/pgvector:pg16` (PostgreSQL 16 kèm tiện ích pgvector).
- **Nguyên tắc triển khai:** Dịch vụ được khởi chạy ở trạng thái **hoàn toàn rỗng (empty service)**. Chỉ tồn tại database hệ thống mặc định là `postgres`. Các database nghiệp vụ (`lingoria`, `airflow`) và extension không được tự động tạo sẵn để đảm bảo tính độc lập.

---

## 2. Thông Số Cấu Hình Tĩnh (`configs/postgres.json`)

Toàn bộ thông số cấu hình không nhạy cảm của PostgreSQL được định nghĩa tập trung tại file [configs/postgres.json](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/configs/postgres.json).

### 2.1 Bảng chi tiết các trường cấu hình:

| Tên trường (Key) | Kiểu dữ liệu | Giá trị mặc định | Giải thích chi tiết |
| :--- | :--- | :--- | :--- |
| `image` | string | `"pgvector/pgvector:pg16"` | Docker Image chính thức hỗ trợ pgvector |
| `port` | number | `55432` | Cổng port expose ra ngoài máy host (tránh xung đột port 5432 cục bộ) |
| `container_name` | string | `"lingoria-postgres"` | Tên container PostgreSQL khi chạy |
| `volume_name` | string | `"lingoria_postgres_data"` | Docker Volume lưu trữ cơ sở dữ liệu PostgreSQL |
| `superuser` | string | `"postgres"` | Tên tài khoản superuser quản trị cao nhất |
| `default_db` | string | `"postgres"` | Database khởi tạo ban đầu mặc định của engine |
| `log_max_size` | string | `"10m"` | Kích thước file log stdout tối đa |
| `log_max_file` | string | `"3"` | Số file log luân phiên tối đa |

### 2.2 Nội dung file cấu hình:

```json
{
  "image": "pgvector/pgvector:pg16",
  "port": 55432,
  "container_name": "lingoria-postgres",
  "volume_name": "lingoria_postgres_data",
  "superuser": "postgres",
  "default_db": "postgres",
  "log_max_size": "10m",
  "log_max_file": "3"
}
```

---

## 3. Kiến Trúc Docker Compose (`values/postgres-compose.yaml`)

File Docker Compose độc lập của PostgreSQL được lưu tại [values/postgres-compose.yaml](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/values/postgres-compose.yaml).

### 3.1 Bảng ánh xạ cổng & Container:

| Thành phần | Thông tin thiết lập |
| :--- | :--- |
| **Container Name** | `${POSTGRES_CONTAINER_NAME:-lingoria-postgres}` |
| **Port Mapping** | `"${POSTGRES_PORT:-55432}:5432"` |
| **PGDATA Path** | `/var/lib/postgresql/data/pgdata` |
| **Restart Policy** | `unless-stopped` |
| **Healthcheck Test** | `pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}` |

### 3.2 Cơ chế Khởi động & Kiến trúc PGDATA:

- Nhằm tránh lỗi `directory exists but is not empty` khi khởi tạo `initdb` do có sự xuất hiện của file mật khẩu `.admin_password`, biến môi trường `PGDATA` được cấu hình trỏ vào thư mục con: `/var/lib/postgresql/data/pgdata`.
- Entrypoint kiểm tra và tự động đọc mật khẩu từ file `.admin_password` trước khi chuyển giao quyền thực thi cho script gốc `docker-entrypoint.sh postgres`.

---

## 4. Quản Lý Tài Khoản Quản Trị & Mật Khẩu Tự Sinh Trong Volume

Nhằm tuân thủ nguyên tắc bảo mật **Zero Credential on Host Filesystem**:
- **Tên tài khoản quản trị:** Khai báo trực tiếp trong `configs/postgres.json` với trường `"superuser": "postgres"`.
- **Mật khẩu quản trị:** Được sinh ngẫu nhiên bằng `/proc/sys/kernel/random/uuid` trong lần khởi chạy đầu tiên và ghi trực tiếp vào volume:
  - **Đường dẫn file mật khẩu:** `/var/lib/postgresql/data/.admin_password`
  - **Phân quyền bảo vệ:** `chmod 644`

### Xem mật khẩu quản trị:
Chạy lệnh sau trên terminal:
```bash
make show-credentials
```
Output sẽ hiển thị dòng:
```text
Postgres       postgres                 <auto_generated_password>  localhost:55432
```

---

## 5. Quản Lý Lưu Trữ Dữ Liệu (Volumes) & Giới Hạn Nhật Ký (Log Limits)

### 5.1 Docker Volumes:
- Dữ liệu cơ sở dữ liệu được lưu trữ cách ly trong Docker named volume: `lingoria_postgres_data`.
- Điểm mount trong container: `/var/lib/postgresql/data`.
- Dữ liệu được bảo toàn tuyệt đối khi chạy `make stop-postgres` hoặc `make down`.
- Chỉ bị xoá khi chạy `make clean-data CONFIRM=YES`.

### 5.2 Giới hạn dung lượng Log (Log Limits):
- `driver: "json-file"`
- `max-size: "10m"`
- `max-file: "3"`
- Tự động làm rỗng (truncate) khi chạy lệnh định kỳ `make clean-logs`.

---

## 6. Kết Nối Mạng & Giao Tiếp Nội Bộ (Inter-Service Networking)

- **Docker Network:** `lingoria_network` (`external: true`).
- **Network Alias:** `postgres`.
- **Chuỗi kết nối nội bộ giữa các container trong mạng:**
  ```text
  postgresql://postgres:<auto_generated_password>@postgres:5432/postgres
  ```
- **Kết nối từ máy Host (Dành cho DBeaver, TablePlus, psql):**
  ```text
  Host: localhost
  Port: 55432
  User: postgres
  Password: [Lấy từ make show-credentials]
  Database: postgres
  ```

---

## 7. Hướng Dẫn Vận Hành Thường Nhật

| Thao tác | Câu lệnh thực thi |
| :--- | :--- |
| **Triển khai PostgreSQL** | `make deploy-postgres` |
| **Xem mật khẩu admin** | `make show-credentials` |
| **Theo dõi nhật ký realtime** | `make logs-postgres` |
| **Kiểm tra trạng thái container** | `make ps` |
| **Dừng PostgreSQL (giữ dữ liệu)**| `make stop-postgres` |

---

## 8. Khởi Tạo Thủ Công Sau Khi Deploy (Post-Deployment Steps)

Do PostgreSQL được triển khai hoàn toàn rỗng, sau khi container khởi động thành công, bạn có thể thực hiện tạo thủ công các database và user theo nhu cầu:

### 8.1 Truy cập vào PostgreSQL CLI (`psql`):
```bash
docker exec -it lingoria-postgres psql -U postgres
```

### 8.2 Tạo Database Nghiệp Vụ `lingoria` & Extensions:
```sql
CREATE DATABASE lingoria;
\c lingoria;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "vector";
```

### 8.3 Tạo Database và User cho Airflow:
*(Lưu ý: Mật khẩu user `airflow` phải trùng khớp với `AIRFLOW_DB_PASSWORD` trong file `.env`)*
```sql
CREATE DATABASE airflow;
CREATE USER airflow WITH PASSWORD 'airflow_service_change_me';
GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;
\c airflow;
GRANT ALL ON SCHEMA public TO airflow;
```
