# Apache Airflow 3 - Cấu Hình & Hướng Dẫn Vận Hành

Tài liệu này mô tả chi tiết toàn bộ thiết lập cấu hình, kiến trúc Docker và hướng dẫn vận hành cho dịch vụ **Apache Airflow 3** trong nền tảng `lingoria-platform-deployment`.

---

## 1. Giới Thiệu & Vai Trò (Overview)

- **Mô tả chức năng:** Nền tảng điều phối luồng dữ liệu (Data Workflow Orchestrator) chịu trách nhiệm lập lịch, tự động hoá và giám sát các quy trình ETL/ELT, xử lý audio, trích xuất dữ liệu, embedding vector và cập nhật catalog của Lingoria.
- **Docker Image chính thức:** `apache/airflow:latest-python3.10` (Bản phân phối Airflow 3 hiện đại hỗ trợ API Server độc lập).
- **Nguyên tắc triển khai:** Khởi chạy ở trạng thái **hoàn toàn sạch (clean orchestrator)**. Không tải các DAGs ví dụ (`load_examples: false`), các DAGs tạo mới mặc định tạm dừng (`dags_are_paused_at_creation: true`).

---

## 2. Thông Số Cấu Hình Tĩnh (`configs/airflow.json`)

Toàn bộ thông số cấu hình không nhạy cảm của Airflow được định nghĩa tập trung tại file [configs/airflow.json](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/configs/airflow.json).

### 2.1 Bảng chi tiết các trường cấu hình:

| Tên trường (Key) | Kiểu dữ liệu | Giá trị mặc định | Giải thích chi tiết |
| :--- | :--- | :--- | :--- |
| `image` | string | `"apache/airflow:latest-python3.10"` | Image Docker chính thức của Airflow |
| `api_server_port` | number | `8080` | Cổng Web UI & API Server truy cập trên máy host |
| `scheduler_health_port`| number | `8974` | Cổng kiểm tra sức khoẻ độc lập của Scheduler |
| `admin` | string | `"admin"` | Tên tài khoản Superuser quản trị Airflow |
| `airflow_uid` | number | `50000` | UID của tiến trình chạy bên trong container |
| `executor` | string | `"LocalExecutor"` | Chế độ thực thi tác vụ (LocalExecutor) |
| `fernet_key` | string | `""` | Khoá mã hoá biến nhạy cảm (optional nếu local) |
| `simple_auth_users` | string | `"admin:admin"` | Định nghĩa user:role cho SimpleAuthManager |
| `dags_are_paused_at_creation` | boolean | `true` | Tạm dừng DAG khi mới khởi tạo |
| `load_examples` | boolean | `false` | Tắt hoàn toàn việc nạp các DAG ví dụ mẫu |
| `db_host` | string | `"postgres"` | Hostname của database metadata (nội bộ Docker) |
| `db_port` | number | `5432` | Cổng port kết nối database nội bộ |
| `db_name` | string | `"airflow"` | Tên database metadata trên PostgreSQL |
| `db_user` | string | `"airflow"` | Tên database user của Airflow |
| `minio_endpoint` | string | `"http://minio:9000"` | Endpoint kết nối MinIO nội bộ |
| `minio_access_key` | string | `"minioadmin"` | Access Key kết nối MinIO |
| `logs_volume_name` | string | `"airflow_logs"` | Docker Volume lưu trữ log thực thi DAG |
| `auth_volume_name` | string | `"airflow_auth_data"` | Docker Volume lưu trữ file mật khẩu tự sinh |
| `dags_volume_name` | string | `"airflow_dags"` | Docker Volume lưu trữ mã nguồn DAGs |
| `log_max_size` | string | `"10m"` | Kích thước file log stdout tối đa |
| `log_max_file` | string | `"3"` | Số file log luân phiên tối đa |

### 2.2 Nội dung file cấu hình:

```json
{
  "image": "apache/airflow:latest-python3.10",
  "api_server_port": 8080,
  "scheduler_health_port": 8974,
  "admin": "admin",
  "airflow_uid": 50000,
  "executor": "LocalExecutor",
  "fernet_key": "",
  "simple_auth_users": "admin:admin",
  "dags_are_paused_at_creation": true,
  "load_examples": false,
  "db_host": "postgres",
  "db_port": 5432,
  "db_name": "airflow",
  "db_user": "airflow",
  "minio_endpoint": "http://minio:9000",
  "minio_access_key": "minioadmin",
  "logs_volume_name": "airflow_logs",
  "auth_volume_name": "airflow_auth_data",
  "dags_volume_name": "airflow_dags",
  "log_max_size": "10m",
  "log_max_file": "3"
}
```

---

## 3. Kiến Trúc Docker Compose (`values/airflow-compose.yaml`)

File Docker Compose độc lập của Airflow được lưu tại [values/airflow-compose.yaml](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/values/airflow-compose.yaml). Hệ thống chia thành 4 service riêng biệt:

### 3.1 Danh sách Services:

| Service | Container Name | Port Mapping | Vai trò |
| :--- | :--- | :--- | :--- |
| **`airflow-init`** | *(Ephemeral)* | - | Khởi tạo cấu trúc DB (`airflow db migrate`) và tạo file mật khẩu |
| **`airflow-api-server`** | `lingoria-airflow-api-server` | `8080:8080` | Web UI điều khiển và REST API v2 |
| **`airflow-scheduler`** | `lingoria-airflow-scheduler` | `8974:8974` | Động cơ điều phối và kích hoạt tác vụ |
| **`airflow-dag-processor`** | `lingoria-airflow-dag-processor` | - | Tiến trình độc lập quét và biên dịch mã nguồn DAGs |

### 3.2 Cơ chế Khởi động theo thứ tự (Dependency Chain):
Các tiến trình `airflow-api-server`, `airflow-scheduler`, `airflow-dag-processor` đều có cấu hình:
```yaml
depends_on:
  airflow-init:
    condition: service_completed_successfully
```
Đảm bảo database metadata đã được migrate hoàn tất trước khi các service nền tảng khởi động.

---

## 4. Quản Lý Tài Khoản Quản Trị & Mật Khẩu Tự Sinh Trong Volume

Nhằm tuân thủ nguyên tắc bảo mật **Zero Credential on Host Filesystem**:
- **Tài khoản quản trị:** Được định nghĩa qua `configs/airflow.json` với `"admin": "admin"`.
- **Cơ chế SimpleAuthManager:**
  Khi `airflow-init` chạy lần đầu, nó sẽ tự động sinh mật khẩu ngẫu nhiên cho user `admin` và lưu vào volume `airflow_auth_data`:
  - **Đường dẫn file mật khẩu:** `/opt/airflow/auth/simple_auth_manager_passwords.json.generated`
  - **Cấu trúc nội dung:** `{"admin": "<random_password>"}`
  - **Phân quyền bảo vệ:** `chmod 644`

### Xem mật khẩu quản trị:
Chạy lệnh sau trên terminal:
```bash
make show-credentials
```
Output sẽ hiển thị dòng:
```text
Airflow        admin                    <auto_generated_password>  http://localhost:8080
```

---

## 5. Quản Lý Lưu Trữ Dữ Liệu (Volumes) & Giới Hạn Nhật Ký (Log Limits)

### 5.1 Docker Volumes:
- `airflow_logs`: Lưu trữ toàn bộ runtime task logs (`/opt/airflow/logs`).
- `airflow_auth_data`: Lưu trữ dữ liệu xác thực SimpleAuthManager (`/opt/airflow/auth`).
- `airflow_dags`: Lưu trữ các file định nghĩa DAGs (`/opt/airflow/dags`).

### 5.2 Giới hạn dung lượng Log & Cơ chế Tự Dọn Dẹp:
- Mỗi container đều có giới hạn `max-size: 10m` và `max-file: 3`.
- Nền tảng cung cấp lệnh tiện ích định kỳ:
  ```bash
  make clean-logs
  ```
  Lệnh này sẽ tự động tìm và xoá sạch các file log tác vụ trong volume `airflow_logs` cũ hơn **6 tiếng**, đồng thời truncate stdout log của các container để giải phóng triệt để ổ cứng.

---

## 6. Kết Nối Mạng & Giao Tiếp Nội Bộ (Inter-Service Networking)

- **Docker Network:** `lingoria_network` (`external: true`).
- **Kết nối tới PostgreSQL (Metadata DB):**
  ```text
  postgresql+psycopg2://airflow:${AIRFLOW_DB_PASSWORD}@postgres:5432/airflow
  ```
  *(Mật khẩu `AIRFLOW_DB_PASSWORD` được nạp từ file [.env](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/.env))*
- **Kết nối tới MinIO (Object Storage):**
  ```text
  Endpoint: http://minio:9000
  Access Key: minioadmin
  Secret Key: ${MINIO_SECRET_KEY} (lấy từ .env)
  ```

---

## 7. Hướng Dẫn Vận Hành Thường Nhật

| Thao tác | Câu lệnh thực thi |
| :--- | :--- |
| **Triển khai cụm Airflow** | `make deploy-airflow` |
| **Xem mật khẩu Web UI** | `make show-credentials` |
| **Theo dõi nhật ký realtime** | `make logs-airflow` |
| **Dọn log cũ hơn 6 giờ** | `make clean-logs` |
| **Kiểm tra trạng thái container** | `make ps` |
| **Dừng Airflow (giữ dữ liệu)** | `make stop-airflow` |

---

## 8. Điều Kiện Tiên Quyết Trước Khi Deploy (Pre-Deployment Steps)

Do nền tảng chỉ triển khai service rỗng, trước khi chạy `make deploy-airflow`, bạn **phải đảm bảo PostgreSQL đã được deploy và đã có sẵn database `airflow` cùng user `airflow`**:

```bash
# 1. Khởi chạy PostgreSQL nếu chưa chạy
make deploy-postgres

# 2. Truy cập psql tạo database và user cho Airflow (nếu chưa tạo)
docker exec -it lingoria-postgres psql -U postgres -c "CREATE DATABASE airflow;"
docker exec -it lingoria-postgres psql -U postgres -c "CREATE USER airflow WITH PASSWORD 'airflow_service_change_me';"
docker exec -it lingoria-postgres psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;"
docker exec -it lingoria-postgres psql -U postgres -d airflow -c "GRANT ALL ON SCHEMA public TO airflow;"

# 3. Tiến hành deploy Airflow
make deploy-airflow
```
