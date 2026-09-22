# Hướng Dẫn Sử Dụng Chi Tiết Toàn Bộ Lệnh Hệ Thống (Command Guideline)

Tài liệu này cung cấp hướng dẫn chi tiết về mọi lệnh điều khiển trong hệ thống [Makefile](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/Makefile) và các shell script hỗ trợ trong thư mục [scripts/](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/scripts/). Mỗi lệnh đi kèm mục đích sử dụng, cú pháp và kết quả output hiển thị thực tế trên terminal.

---

## Danh Mục Lệnh (Quick Table)

| Nhóm Lệnh | Lệnh Thực Thi | Mục Đích |
| :--- | :--- | :--- |
| **Khởi tạo & Cấu hình** | `make help` | Hiển thị menu trợ giúp tổng quan |
| | `make init-config` | Tạo file `.env` từ `.env.example` nếu chưa có |
| **Triển khai (Deployment)** | `make deploy-postgres` | Khởi chạy PostgreSQL rỗng |
| | `make deploy-minio` | Khởi chạy MinIO rỗng (0 bucket) |
| | `make deploy-redis` | Khởi chạy Redis service |
| | `make deploy-airflow` | Khởi chạy Airflow 3 services |
| | `make deploy-pgadmin` | Khởi chạy pgAdmin 4 web UI |
| | `make deploy-<tool>` | Triển khai bất kỳ tool nào có trong `values/` và `configs/` |
| **Thông tin & Bảo mật** | `make show-credentials` | Đọc và in mật khẩu admin tự sinh từ container volumes |
| **Giám sát & Nhật ký** | `make ps` | Kiểm tra trạng thái các container thuộc nền tảng |
| | `make logs-<tool>` | Theo dõi realtime log stream của một tool cụ thể |
| | `make clean-logs` | Dọn log Airflow > 6 giờ và truncate stdout logs |
| **Dừng & Dọn Dẹp** | `make stop-<tool>` | Dừng và xoá container của một tool cụ thể |
| | `make down` / `make stop` | Dừng toàn bộ các container trong hệ thống |
| | `make clean-data CONFIRM=YES` | Xoá sạch toàn bộ Docker Volumes cục bộ |

---

## 1. Nhóm Lệnh Khởi Tạo & Cấu Hình

### 1.1 `make help`
- **Mục đích:** Hiển thị menu tóm tắt toàn bộ danh mục lệnh có sẵn trong Makefile.
- **Cú pháp:**
  ```bash
  make help
  ```
- **Output thực tế:**
  ```text
  Lingoria platform deployment (Modular Docker architecture)

  Deployment commands:
    make init-config           Create .env from .env.example
    make deploy-postgres       Start clean PostgreSQL instance
    make deploy-minio          Start clean MinIO instance (0 buckets)
    make deploy-redis          Start Redis instance
    make deploy-airflow        Start clean Airflow 3 services
    make deploy-pgadmin        Start pgAdmin 4 web UI
    make deploy-<tool>         Deploy any tool defined in values/ and configs/

  Credentials & Management:
    make show-credentials      Show all auto-generated admin passwords
    make stop-<tool>           Stop a specific tool (e.g. make stop-postgres)
    make logs-<tool>           Follow logs of a specific tool (e.g. make logs-airflow)
    make ps                    Show status of all Lingoria containers
    make clean-logs            Prune runtime logs older than 6h & truncate stdout
    make down | make stop      Stop all running platform containers
    make clean-data CONFIRM=YES Delete local Docker volumes
  ```

---

### 1.2 `make init-config`
- **Mục đích:** Khởi tạo file cấu hình bí mật môi trường [.env](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/.env) trên máy cá nhân bằng cách sao chép từ [.env.example](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/.env.example). Lệnh mang tính an toàn (idempotent), nếu `.env` đã có sẵn sẽ không bị ghi đè.
- **Cú pháp:**
  ```bash
  make init-config
  ```
- **Output thực tế:**
  ```text
  Config ready: /Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/.env
  ```

---

## 2. Nhóm Lệnh Triển Khai (Deployment)

### 2.1 `make deploy-postgres`
- **Mục đích:** Khởi chạy container PostgreSQL rỗng (chỉ có database gốc `postgres`). Ở lần chạy đầu tiên, container sẽ tự động sinh mật khẩu ngẫu nhiên lưu an toàn trong volume `lingoria_postgres_data` tại `/var/lib/postgresql/data/.admin_password`.
- **Cú pháp:**
  ```bash
  make deploy-postgres
  ```
- **Output thực tế:**
  ```text
  Deploying tool: postgres using values/postgres-compose.yaml...
  [+] Running 1/1
   ✔ Container lingoria-postgres  Started                                  0.3s 
  Waiting for postgres to become ready...
  postgres is healthy
  postgres deployed successfully.
  ```

---

### 2.2 `make deploy-minio`
- **Mục đích:** Khởi chạy MinIO Object Storage rỗng (0 bucket). Tự sinh mật khẩu root admin lưu tại `/data/.minio_admin_password` trong volume `lingoria_minio_data`.
- **Cú pháp:**
  ```bash
  make deploy-minio
  ```
- **Output thực tế:**
  ```text
  Deploying tool: minio using values/minio-compose.yaml...
  [+] Running 1/1
   ✔ Container lingoria-minio  Started                                     0.3s 
  Waiting for minio to become ready...
  minio is healthy
  minio deployed successfully.
  ```

---

### 2.3 `make deploy-redis`
- **Mục đích:** Khởi chạy Redis In-Memory Cache (image `redis:7.4-alpine`) với chế độ lưu trữ AOF (Append-Only File) vào volume `lingoria_redis_data`.
- **Cú pháp:**
  ```bash
  make deploy-redis
  ```
- **Output thực tế:**
  ```text
  Deploying tool: redis using values/redis-compose.yaml...
  [+] Running 1/1
   ✔ Container lingoria-redis  Started                                     0.3s 
  Waiting for redis to become ready...
  redis is healthy
  redis deployed successfully.
  ```

---

### 2.4 `make deploy-airflow`
- **Mục đích:** Triển khai cụm dịch vụ Apache Airflow 3 bao gồm:
  1. `airflow-init`: Chạy một lần (`airflow db migrate`), tự động tạo file mật khẩu cho tài khoản `admin` lưu trong volume `airflow_auth_data`.
  2. `airflow-api-server`: Cung cấp Web UI và API tại cổng `8080`.
  3. `airflow-scheduler`: Lập lịch chạy DAGs kèm healthcheck tại cổng `8974`.
  4. `airflow-dag-processor`: Tiến trình phân tích cú pháp DAG độc lập.
- **Cú pháp:**
  ```bash
  make deploy-airflow
  ```
- **Output thực tế:**
  ```text
  Deploying tool: airflow using values/airflow-compose.yaml...
  Running Airflow database initialization (airflow db migrate)...
  [+] Running 1/1
   ✔ Container lingoria-airflow-init-1  Started                            0.5s 
  Starting Airflow daemon services...
  [+] Running 3/3
   ✔ Container lingoria-airflow-api-server     Started                     0.3s 
   ✔ Container lingoria-airflow-scheduler      Started                     0.3s 
   ✔ Container lingoria-airflow-dag-processor  Started                     0.3s 
  Airflow deployed. Access at http://localhost:8080
  ```

---

### 2.5 `make deploy-pgadmin`
- **Mục đích:** Khởi chạy pgAdmin 4 Web GUI để quản lý trực quan cơ sở dữ liệu PostgreSQL. Tự sinh mật khẩu quản trị ngẫu nhiên lưu tại `/var/lib/pgadmin/.admin_password` trong volume `lingoria_pgadmin_data`.
- **Cú pháp:**
  ```bash
  make deploy-pgadmin
  ```
- **Output thực tế:**
  ```text
  Deploying tool: pgadmin using values/pgadmin-compose.yaml...
  [+] Running 1/1
   ✔ Container lingoria-pgadmin  Started                                   0.3s 
  pgadmin deployed successfully.
  ```

---

### 2.6 `make deploy-<tool>` (Generic Pattern Rule)
- **Mục đích:** Triển khai bất kỳ công cụ mới nào được bổ sung vào hệ thống mà không cần định nghĩa lại target trong Makefile. Makefile sẽ bắt pattern và chuyển giao cho script `./scripts/deploy.sh <tool>`.
- **Ví dụ:** Triển khai `mongodb` khi đã có `configs/mongodb.json` và `values/mongodb-compose.yaml`:
  ```bash
  make deploy-mongodb
  ```
- **Output thực tế:**
  ```text
  Deploying tool: mongodb using values/mongodb-compose.yaml...
  [+] Running 1/1
   ✔ Container lingoria-mongodb  Started                                   0.3s 
  mongodb deployed successfully.
  ```

---

## 3. Nhóm Lệnh Thông Tin & Bảo Mật

### 3.1 `make show-credentials` (hoặc `make credentials`)
- **Mục đích:** Chui trực tiếp vào volume của từng container đang hoạt động (thông qua `docker exec`) để đọc mật khẩu admin được sinh ngẫu nhiên và in ra màn hình dạng bảng. Nếu container đang dừng, lệnh sẽ hiển thị trạng thái `[Container stopped]`.
- **Cú pháp:**
  ```bash
  make show-credentials
  ```
- **Output thực tế:**
  ```text
  ==================================================================================
         LINGORIA PLATFORM - CONTAINER VOLUME ADMIN CREDENTIALS
  ==================================================================================
  Tool           Admin / Superuser        Password               Access / URL
  ----------------------------------------------------------------------------------
  Postgres       postgres                 9f2b8a1c4e7d0f3a       localhost:55432
  Minio          minioadmin               a1d84f0c9b2e7a33       http://localhost:9001
  Airflow        admin                    7e4c2b9a1d8f0e34       http://localhost:8080
  Pgadmin        admin@lingoria.local     4a8c1f9b0e2d7a31       http://localhost:5050
  Redis          default                  [No auth / Open cache] localhost:6379
  ==================================================================================
  * Admin usernames and ports are defined in configs/<tool>.json
  * Passwords are generated and stored exclusively inside container volumes.
  * Inter-service communication credentials (e.g. Airflow -> Postgres) are in .env
  ==================================================================================
  ```

---

## 4. Nhóm Lệnh Giám Sát & Nhật Ký

### 4.1 `make ps`
- **Mục đích:** Liệt kê toàn bộ các container đang chạy thuộc prefix `lingoria-`, bao gồm tên container, trạng thái hoạt động (uptime/health) và các cổng port đang được export ra máy host.
- **Cú pháp:**
  ```bash
  make ps
  ```
- **Output thực tế:**
  ```text
  NAMES                             STATUS                   PORTS
  lingoria-postgres                 Up 2 minutes (healthy)   0.0.0.0:55432->5432/tcp
  lingoria-minio                    Up 2 minutes (healthy)   0.0.0.0:9000->9000/tcp, 0.0.0.0:9001->9001/tcp
  lingoria-redis                    Up 2 minutes (healthy)   0.0.0.0:6379->6379/tcp
  lingoria-airflow-api-server       Up 1 minute (healthy)    0.0.0.0:8080->8080/tcp
  lingoria-airflow-scheduler        Up 1 minute (healthy)    0.0.0.0:8974->8974/tcp
  lingoria-airflow-dag-processor    Up 1 minute (healthy)    
  lingoria-pgadmin                  Up 1 minute              0.0.0.0:5050->80/tcp
  ```

---

### 4.2 `make logs-<tool>`
- **Mục đích:** Theo dõi realtime log stream của một tool cụ thể (kèm flag `--tail 100 -f`).
- **Cú pháp:**
  ```bash
  make logs-postgres
  make logs-minio
  make logs-airflow
  ```
- **Output thực tế (Ví dụ xem logs Postgres):**
  ```text
  Showing logs for tool: postgres...
  postgres  | 2026-09-22 15:00:00.123 UTC [1] LOG:  starting PostgreSQL 16.2 on aarch64-unknown-linux-musl
  postgres  | 2026-09-22 15:00:00.124 UTC [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
  postgres  | 2026-09-22 15:00:00.125 UTC [1] LOG:  listening on IPv6 address "::", port 5432
  postgres  | 2026-09-22 15:00:00.130 UTC [1] LOG:  database system was shut down at 2026-09-22 14:55:00 UTC
  postgres  | 2026-09-22 15:00:00.135 UTC [1] LOG:  database system is ready to accept connections
  ```

---

### 4.3 `make clean-logs`
- **Mục đích:** Giải phóng dung lượng ổ đĩa tự động bằng cách:
  1. Quét dọn và xoá các file log runtime của Airflow cũ hơn 6 tiếng bên trong volume `airflow_logs`.
  2. Làm rỗng (truncate về 0 byte) các file log stdout định dạng json của mọi container trong platform.
- **Cú pháp:**
  ```bash
  make clean-logs
  ```
- **Output thực tế:**
  ```text
  Cleaning Airflow logs older than 6 hours...
  Deleted 14 old log files.
  Pruning container stdout log files...
  Truncated log for lingoria-postgres (was 8.4MB)
  Truncated log for lingoria-airflow-scheduler (was 9.1MB)
  Log cleanup completed successfully.
  ```

---

## 5. Nhóm Lệnh Dừng & Xoá Dữ Liệu

### 5.1 `make stop-<tool>`
- **Mục đích:** Dừng và tháo gỡ (remove) container của một tool cụ thể. Dữ liệu trong Docker Volume vẫn được bảo toàn nguyên vẹn.
- **Cú pháp:**
  ```bash
  make stop-postgres
  make stop-airflow
  ```
- **Output thực tế:**
  ```text
  Stopping tool: postgres...
  [+] Running 1/1
   ✔ Container lingoria-postgres  Removed                                  0.2s 
  ```

---

### 5.2 `make down` (hoặc `make stop`)
- **Mục đích:** Dừng và gỡ bỏ toàn bộ container của tất cả các công cụ trong nền tảng. Dữ liệu trong volumes không bị ảnh hưởng.
- **Cú pháp:**
  ```bash
  make down
  # hoặc
  make stop
  ```
- **Output thực tế:**
  ```text
  Stopping all tools...
  Stopping tool: postgres...
   ✔ Container lingoria-postgres  Removed
  Stopping tool: minio...
   ✔ Container lingoria-minio  Removed
  Stopping tool: redis...
   ✔ Container lingoria-redis  Removed
  Stopping tool: airflow...
   ✔ Container lingoria-airflow-api-server     Removed
   ✔ Container lingoria-airflow-scheduler      Removed
   ✔ Container lingoria-airflow-dag-processor  Removed
  Stopping tool: pgadmin...
   ✔ Container lingoria-pgadmin  Removed
  All tools stopped.
  ```

---

### 5.3 `make clean-data`
- **Mục đích:** Dừng toàn bộ containers và **XOÁ SẠCH HOÀN TOÀN** mọi Docker Volumes (`lingoria_postgres_data`, `lingoria_minio_data`, `lingoria_redis_data`, `lingoria_pgadmin_data`, `airflow_logs`, `airflow_auth_data`, `airflow_dags`).
- **Cơ chế an toàn:** Bắt buộc truyền tham số `CONFIRM=YES` để tránh vô tình mất dữ liệu.

#### A. Khi chạy thiếu `CONFIRM=YES`:
- **Cú pháp:**
  ```bash
  make clean-data
  ```
- **Output thực tế:**
  ```text
  Refusing to delete volumes. Re-run with CONFIRM=YES
  make: *** [clean-data] Error 1
  ```

#### B. Khi chạy kèm `CONFIRM=YES`:
- **Cú pháp:**
  ```bash
  make clean-data CONFIRM=YES
  ```
- **Output thực tế:**
  ```text
  Stopping all tools...
  Stopping tool: postgres...
  Stopping tool: minio...
  Stopping tool: redis...
  Stopping tool: airflow...
  Stopping tool: pgadmin...
  All tools stopped.
  lingoria_postgres_data
  lingoria_minio_data
  lingoria_redis_data
  lingoria_pgadmin_data
  airflow_logs
  airflow_auth_data
  airflow_dags
  Local volumes removed.
  ```

---

## 6. Lệnh Trực Tiếp Bằng Shell Script (Advanced Usage)

Đối với các tác vụ nâng cao hoặc kiểm thử CI/CD, bạn có thể gọi trực tiếp các script trong thư mục [scripts/](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/scripts/):

### Kiểm tra cấu hình trước khi chạy (Dry-run Validation)
```bash
./scripts/deploy.sh --dry-run <tool-name>
```
*Output:* Xuất ra cấu hình hoàn chỉnh của Docker Compose sau khi đã nội suy toàn bộ biến môi trường từ `configs/<tool>.json` và `.env`. Mã thoát (exit code) trả về `0` nếu cấu hình hợp lệ.
