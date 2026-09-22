# Lingoria Platform Deployment

Tài liệu quản lý và triển khai hạ tầng cục bộ (local infrastructure) cho Lingoria bằng Docker Compose theo mô hình modular (lấy cảm hứng từ Helm Values trên K8s).

---

## 1. Cấu Trúc Dự Án

- **`configs/`**: Chứa file cấu hình JSON cho từng tool (image tag, exposed port, volume name,...). Không chứa mật khẩu.
- **`values/`**: Chứa file Docker Compose YAML độc lập cho từng tool (`<tool>-compose.yaml`).
- **`scripts/`**: Chứa các reusable shell script (`deploy.sh`, `stop.sh`, `logs.sh`, `wait-for-service.sh`).
- **`docs/`**: Chứa tài liệu vận hành và runbook chi tiết ([docs/runbook.md](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/docs/runbook.md)).
- **`.env` / `.env.example`**: Quản lý tập trung toàn bộ mật khẩu, secret keys và đường dẫn tài nguyên.

---

## 2. Danh Sách Services

| Service | File Compose | Port mặc định | Container Name |
| :--- | :--- | :--- | :--- |
| **PostgreSQL** | `values/postgres-compose.yaml` | `55432` | `lingoria-postgres` |
| **MinIO** | `values/minio-compose.yaml` | `9000` (API), `9001` (Console) | `lingoria-minio` |
| **Redis** | `values/redis-compose.yaml` | `6379` | `lingoria-redis` |
| **Airflow 3** | `values/airflow-compose.yaml` | `8080` (API/Web) | `lingoria-airflow-*` |
| **pgAdmin 4** | `values/pgadmin-compose.yaml` | `5050` | `lingoria-pgadmin` |

> [!NOTE]
> Khi deploy, các service như PostgreSQL và MinIO là **service rỗng** (không tự động tạo database ứng dụng hay MinIO bucket). Xem hướng dẫn chi tiết các bước tạo thủ công tại [docs/runbook.md](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/docs/runbook.md).

---

## 3. Hướng Dẫn Nhanh (Quick Start)

### Bước 1: Khởi tạo biến môi trường & mật khẩu
```bash
make init-config
# Tuỳ chỉnh mật khẩu trong file .env nếu cần
```

### Bước 2: Khởi động PostgreSQL & Tạo Database
```bash
make deploy-postgres
# Tạo thủ công database 'lingoria' và extensions (xem docs/runbook.md)
# Tạo thủ công database 'airflow' và user 'airflow' (xem docs/runbook.md)
```

### Bước 3: Khởi động MinIO & Tạo Bucket
```bash
make deploy-minio
# Mở http://localhost:9001 tạo thủ công các bucket: lingoria-raw, lingoria-media-original, lingoria-media-derived
```

### Bước 4: Khởi động Redis & Airflow
```bash
make deploy-redis
make deploy-airflow
```

---

## 4. Các Lệnh Điều Khiển Chính

```bash
# Triển khai từng công cụ
make deploy-postgres
make deploy-minio
make deploy-redis
make deploy-airflow
make deploy-pgadmin
make deploy-<tool>         # Triển khai bất kỳ tool mới nào có trong values/ và configs/

# Quản lý & Giám sát
make show-credentials      # Hiển thị bảng mật khẩu admin đã auto-generate của tất cả các tools
make ps                    # Kiểm tra trạng thái các container đang chạy
make logs-<tool>           # Xem logs của tool (ví dụ: make logs-postgres)
make stop-<tool>           # Dừng tool đơn lẻ (ví dụ: make stop-minio)
make down                  # Dừng toàn bộ các tool đang chạy
make clean-data CONFIRM=YES# Dừng và xoá sạch volumes dữ liệu cục bộ
```

---

## 5. Tài Liệu Hướng Dẫn Chi Tiết Trong `docs/`

- **[docs/command_guideline.md](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/docs/command_guideline.md)**: Hướng dẫn chi tiết toàn bộ các lệnh Makefile (`make deploy-...`, `make show-credentials`,...) kèm kết quả output thực tế trên terminal.
- **[docs/new_services_guideline.md](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/docs/new_services_guideline.md)**: Hướng dẫn 7 bước chuẩn hoá để tích hợp và triển khai một công cụ mới vào hệ thống.
- **[docs/template.md](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/docs/template.md)**: Bản mẫu chuẩn (Standard Template) dùng để viết tài liệu cấu hình cho từng tool.
- **`docs/tools/`**: Thư mục chứa tài liệu cấu hình và hướng dẫn vận hành chi tiết cho từng công cụ:
  - [PostgreSQL](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/docs/tools/postgres.md)
  - [MinIO](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/docs/tools/minio.md)
  - [Redis](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/docs/tools/redis.md)
  - [Apache Airflow 3](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/docs/tools/airflow.md)
  - [pgAdmin 4](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/docs/tools/pgadmin.md)
