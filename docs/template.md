# [Tên Tool] - Cấu Hình & Hướng Dẫn Vận Hành

Tài liệu này mô tả chi tiết toàn bộ thiết lập cấu hình, kiến trúc Docker và hướng dẫn vận hành cho dịch vụ **[Tên Tool]** trong nền tảng `lingoria-platform-deployment`.

---

## 1. Giới Thiệu & Vai Trò (Overview)

- **Mô tả chức năng:** [Mô tả ngắn gọn chức năng của tool trong hệ sinh thái Lingoria, ví dụ: RDBMS, Object Storage, Task Orchestrator, In-Memory Cache,...]
- **Docker Image chính thức:** `[Tên image:tag, ví dụ: postgres:16, quay.io/minio/minio:latest]`
- **Nguyên tắc triển khai:** Dịch vụ được khởi chạy ở trạng thái **hoàn toàn rỗng (empty service)**, không tự động nạp cấu trúc database ứng dụng hoặc dữ liệu mẫu từ các repository khác.

---

## 2. Thông Số Cấu Hình Tĩnh (`configs/<tool_name>.json`)

Toàn bộ thông số cấu hình không nhạy cảm của tool được định nghĩa tập trung tại file [configs/<tool_name>.json](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/configs/<tool_name>.json).

### 2.1 Bảng chi tiết các trường cấu hình:

| Tên trường (Key) | Kiểu dữ liệu | Giá trị mặc định | Giải thích chi tiết |
| :--- | :--- | :--- | :--- |
| `image` | string | `[image:tag]` | Image Docker chính thức được sử dụng |
| `port` | number | `[port]` | Cổng port expose ra ngoài máy host |
| `container_name` | string | `lingoria-[tool]` | Tên định danh của container |
| `volume_name` | string | `lingoria_[tool]_data` | Tên Docker Volume lưu trữ dữ liệu bền vững |
| `admin` / `superuser` | string | `[admin_username]` | Tên tài khoản quản trị cao nhất của hệ thống |
| `log_max_size` | string | `"10m"` | Dung lượng tối đa của một file log container |
| `log_max_file` | string | `"3"` | Số lượng file log luân phiên tối đa được giữ lại |
| `[cấu hình khác...]` | ... | ... | [Giải thích các thông số cấu hình đặc thù của tool nếu có] |

### 2.2 Nội dung file cấu hình mẫu:

```json
{
  "image": "[image:tag]",
  "port": 0000,
  "container_name": "lingoria-[tool]",
  "volume_name": "lingoria_[tool]_data",
  "admin": "[admin_user]",
  "log_max_size": "10m",
  "log_max_file": "3"
}
```

---

## 3. Kiến Trúc Docker Compose (`values/<tool_name>-compose.yaml`)

File Docker Compose độc lập của tool được lưu tại [values/<tool_name>-compose.yaml](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/values/<tool_name>-compose.yaml).

### 3.1 Bảng ánh xạ cổng & Container:

| Thành phần | Thông tin thiết lập |
| :--- | :--- |
| **Container Name** | `${[TOOL]_CONTAINER_NAME:-lingoria-[tool]}` |
| **Port Mapping** | `"${[TOOL]_PORT:-[port]}:[container_port]"` |
| **Restart Policy** | `unless-stopped` |
| **Healthcheck Test** | `[Câu lệnh kiểm tra sức khoẻ của service]` |

### 3.2 Cơ chế Khởi động & Kiểm tra Sẵn sàng (Readiness):

- Service được cấu hình healthcheck định kỳ với khoảng thời gian kiểm tra (`interval`), thời gian timeout và số lần thử lại (`retries`).
- Script `./scripts/wait-for-service.sh [tool]` sẽ tự động theo dõi cờ sức khoẻ này khi chạy lệnh deploy.

---

## 4. Quản Lý Tài Khoản Quản Trị & Mật Khẩu Tự Sinh Trong Volume

Nhằm tuân thủ nguyên tắc bảo mật **Zero Credential on Host Filesystem**:
- **Tên tài khoản quản trị:** Khai báo trực tiếp trong `configs/<tool_name>.json` (thông qua trường `superuser` hoặc `admin`).
- **Mật khẩu quản trị:** Được sinh ngẫu nhiên bằng entropy hệ thống (`/proc/sys/kernel/random/uuid`) trong lần khởi chạy đầu tiên và ghi trực tiếp vào đường dẫn nội bộ bên trong volume của container:
  - **Đường dẫn file mật khẩu:** `/[đường_dẫn_mount_volume]/.admin_password`
  - **Phân quyền bảo vệ:** `chmod 600` hoặc `chmod 644`.

### Xem mật khẩu quản trị:
Người dùng chỉ cần chạy lệnh sau trên terminal:
```bash
make show-credentials
```
Lệnh sẽ thực hiện `docker exec` vào container đang chạy và in mật khẩu ra màn hình.

---

## 5. Quản Lý Lưu Trữ Dữ Liệu (Volumes) & Giới Hạn Nhật Ký (Log Limits)

### 5.1 Docker Volumes:
- Dữ liệu được lưu trữ cách ly trong Docker named volume: `lingoria_[tool]_data`.
- Dữ liệu sẽ **không bao giờ bị mất** khi bạn chạy `make stop-[tool]` hoặc `make down`.
- Dữ liệu chỉ bị xoá khi người dùng chủ động chạy lệnh có xác nhận an toàn: `make clean-data CONFIRM=YES`.

### 5.2 Giới hạn dung lượng Log (Log Limits):
Mọi container đều được gắn driver `json-file` với cấu hình:
- `max-size: 10m`
- `max-file: 3`

Tổng dung lượng log stdout của container tối đa không vượt quá 30MB, đảm bảo máy host không bị cạn kiệt dung lượng đĩa.

---

## 6. Kết Nối Mạng & Giao Tiếp Nội Bộ (Inter-Service Networking)

- **Docker Network:** Tham gia vào mạng nội bộ dùng chung `lingoria_network` (`external: true`).
- **Network Alias (Hostname nội bộ):** `[tên_alias_nội_bộ, ví dụ: postgres, minio, redis]`.
- **Chuỗi kết nối nội bộ giữa các container trong mạng:**
  ```text
  [giao thức]://[alias_hostname]:[cổng_nội_bộ]/[database_hoặc_path]
  ```
- **Mật khẩu giao tiếp Inter-Service:** Nếu dịch vụ khác cần mật khẩu cố định để kết nối tới tool này, mật khẩu đó được khai báo trong file [.env](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment/.env).

---

## 7. Hướng Dẫn Vận Hành Thường Nhật

| Thao tác | Câu lệnh thực thi |
| :--- | :--- |
| **Triển khai dịch vụ** | `make deploy-[tool]` |
| **Xem mật khẩu admin** | `make show-credentials` |
| **Theo dõi nhật ký realtime** | `make logs-[tool]` |
| **Kiểm tra trạng thái container** | `make ps` |
| **Dừng dịch vụ (giữ dữ liệu)** | `make stop-[tool]` |

---

## 8. Khởi Tạo Thủ Công Sau Khi Deploy (Post-Deployment Steps)

*Mục này liệt kê các bước người dùng cần tự cấu hình thủ công (nếu có) do nền tảng chỉ triển khai service rỗng:*
1. **[Bước 1...]**
2. **[Bước 2...]**
