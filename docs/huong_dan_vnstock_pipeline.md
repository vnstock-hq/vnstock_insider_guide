# Hướng dẫn sử dụng gói `vnstock_pipeline`

## 1. Mục tiêu và phạm vi
- Gói `vnstock_pipeline` cung cấp khung xử lý dữ liệu chứng khoán gồm thu thập, kiểm tra, chuyển đổi, lưu trữ và streaming.
- Tài liệu này hướng dẫn người dùng tài trợ hiểu quy trình vận hành, thông số cấu hình và cách tùy biến thư viện khi kết hợp với công cụ AI hỗ trợ lập trình.

## 2. Điều kiện tiên quyết
- Yêu cầu xác thực người dùng có quyền truy cập, nếu thiếu, chương trình sẽ tự động dừng.
- Môi trường Python cần sẵn có các thư viện: `vnstock`, `vnstock_data`, `pandas`, `pyarrow`, `duckdb`, `websockets`, `firebase-admin` (tuỳ chọn), `tqdm`.
- Cấu trúc dữ liệu đầu ra mặc định lưu trong thư mục `./data` cùng cấp dự án hoặc thư mục do người dùng chỉ định.

## 3. Kiến trúc tổng quan
| Thành phần | Vai trò chính                                                                             |
| ---------- | ----------------------------------------------------------------------------------------- |
| `core`     | Khung lớp trừu tượng (Fetcher, Validator, Transformer, Exporter, Scheduler, DataManager). |
| `template` | Lớp nền tảng cho thị trường Việt Nam (`VNFetcher`, `VNValidator`, `VNTransformer`).       |
| `tasks`    | Các quy trình dựng sẵn (intraday, OHLCV, price board, báo cáo tài chính).                 |
| `stream`   | Hệ thống streaming WebSocket, parser, processor và nguồn dữ liệu.                         |
| `schemas`  | Định nghĩa schema linh hoạt và phân loại dữ liệu.                                         |
| `utils`    | Tiện ích môi trường, loại trùng lặp, logger, giờ giao dịch.                               |

Quy trình chuẩn: **Fetch → Validate → Transform → Export → Lưu trữ/Streaming** do `Scheduler` điều phối.

## 4. Quy trình làm việc tiêu chuẩn
1. **Khởi tạo component**: tạo fetcher, validator, transformer, exporter, (tuỳ chọn) data manager.
2. **Cấu hình tham số**: truyền `fetcher_kwargs` và `exporter_kwargs` khi gọi `Scheduler.run`.
3. **Chạy xử lý**: `Scheduler` tự động retry (`retry_attempts`, `backoff_factor`) và ghi nhận lỗi.
4. **Theo dõi kết quả**: báo cáo gồm số mã thành công, thất bại, thời gian trung bình; lỗi ghi vào `error_log.csv`.
5. **Hậu kiểm**: sử dụng `preview` (nếu exporter hỗ trợ) hoặc `DataManager` để rà soát dữ liệu.

## 5. Bộ class cốt lõi (`core`)
### 5.1 `Fetcher`
- Lớp trừu tượng với phương thức `fetch(ticker: str, **kwargs)` và `_vn_call` (ở template VN). Người dùng chỉ cần triển khai `_vn_call` để kết nối nguồn dữ liệu.

### 5.2 `Validator`
- Đảm bảo dữ liệu đúng định dạng. Hàm `validate(data)` trả về `True/False`; có thể raise ngoại lệ khi cần. Các lớp VN mặc định kiểm tra kiểu DataFrame và cột bắt buộc.

### 5.3 `Transformer`
- Chuyển đổi dữ liệu theo chuẩn nội bộ. Lớp VN mặc định chuẩn hoá cột thời gian và sắp xếp dữ liệu. Có thể override `transform(data)` để bổ sung logic riêng.

### 5.4 `Exporter`
- Giao diện `export(data, ticker, **kwargs)` và tuỳ chọn `preview`. Triển khai sẵn:
  - `CSVExport`: ghi đè/ghép CSV, tự loại trùng dựa trên `time` và `id`.
  - `ParquetExport`: tạo thư mục `base_path/data_type/ngày/ticker.parquet`, hỗ trợ nén snappy.
  - `DuckDBExport`: ghi dữ liệu động vào DuckDB với cơ chế mở rộng schema.
  - `flexible_exporter.FlexibleExporter`: hỗ trợ `parquet`, `feather`, `pickle`, và định dạng CSV cho AmiBroker/MT4/MT5.

### 5.5 `DataManager`
- Quản lý dữ liệu parquet theo cấu trúc `base_path/data_type/YYYY-MM-DD/ticker.parquet`.
- Phương thức chính:
  - `get_data_path(data_type, date=None)` trả về thư mục lưu.
  - `save_data(data, ticker, data_type, date=None, partition_cols=None)` ghi parquet với tuỳ chọn phân vùng.
  - `load_data(ticker, data_type, start_date=None, end_date=None, columns=None, filters=None)` đọc parquet qua `pyarrow.dataset`.
  - `list_available_data(data_type=None, date=None)` thống kê dữ liệu sẵn có.
  - `delete_data(data_type, ticker=None, date=None)` xoá linh hoạt (trả `-1` khi xoá toàn bộ).
- Hàm tiện ích `get_data_manager(base_path="data")` giúp khởi tạo nhanh.

### 5.6 `Scheduler`
- Điều phối luồng xử lý với `run(tickers, fetcher_kwargs=None, exporter_kwargs=None)`.
- Với danh sách >10 mã, tự động chuyển sang xử lý song song (async + `ThreadPoolExecutor`).
- `process_ticker` hỗ trợ retry, delay luỹ thừa (`backoff_factor`) và gọi `exporter.preview` để so sánh dữ liệu đã lưu.
- Khi chạy, hiển thị tiến độ qua `tqdm`, kết thúc sẽ in thống kê và lưu lỗi vào CSV.

## 6. Template thị trường Việt Nam (`template.vnstock`)
- `VNFetcher`: định nghĩa `_vn_call` để truy cập thư viện `vnstock` hoặc `vnstock_data`. Tự log số bản ghi.
- `VNValidator`: khai báo `required_columns`; tự động kiểm tra DataFrame và cảnh báo thiếu cột.
- `VNTransformer`: chuẩn hoá cột `time`/`date`, sắp xếp và reset index. Đây là điểm mở rộng chính khi tạo pipeline mới cho thị trường Việt Nam.

## 7. Các nhiệm vụ dựng sẵn (`tasks`)
| Nhiệm vụ    | Mô tả                                                                                 | Hàm khởi chạy        | Tham số chính                                                | Đầu ra                                                              |
| ----------- | ------------------------------------------------------------------------------------- | -------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------- |
| Intraday    | Thu thập giao dịch trong ngày, hỗ trợ `live`/`EOD`, tránh trùng qua `SmartCSVExport`. | `run_intraday_task`  | `mode`, `interval`, `page_size`, `backup`, `max_backups`     | CSV per ticker tại `./data/intraday`.                               |
| OHLCV       | Lấy dữ liệu OHLCV lịch sử.                                                            | `run_task`           | `start`, `end`, `interval`                                   | CSV tại `./data/ohlcv`.                                             |
| Price Board | Lưu biến động bảng giá tổng hợp, hỗ trợ `live`/`EOD`.                                 | `run_price_board`    | `tickers`, `interval`, `mode`                                | CSV duy nhất `price_board_transactions.csv`.                        |
| Financial   | Tải báo cáo tài chính từng loại.                                                      | `run_financial_task` | Các kỳ báo cáo (`balance_sheet_period`...), `lang`, `dropna` | Nhiều CSV đặt tên `<ticker>_<report>.csv` trong `./data/financial`. |

### Hướng dẫn sử dụng chung
1. Chuẩn bị danh sách mã và tham số.
2. Gọi hàm tác vụ tương ứng trong môi trường Python (ví dụ notebook, script).
3. Theo dõi log để biết trạng thái thị trường (`trading_hours`) và tiến trình `Scheduler`.
4. Kiểm tra file đầu ra; sử dụng `exporter.preview` hoặc `DataManager.load_data` để rà soát.

## 8. Streaming thời gian thực (`stream`)
### 8.1 `BaseWebSocketClient`
- Cung cấp kết nối WebSocket cơ bản với ping tự động, xử lý message tuần tự và hệ thống processor dạng bất đồng bộ.
- Yêu cầu lớp con override `_send_initial_messages` và `_parse_message`.
- Hỗ trợ thêm processor qua `add_processor(processor)` nhằm xử lý dữ liệu (ghi file, lưu DB, hiển thị...).

### 8.2 Bộ xử lý dữ liệu (`processors`)
- `ConsoleProcessor`: in dữ liệu dạng JSON (cho debug).
- `CSVProcessor`: ghi dữ liệu theo `data_type`, tự mở file và thêm cột mới khi schema thay đổi.
- `DuckDBProcessor`: ghi dữ liệu vào DuckDB, tự thêm cột khi schema phát sinh.
- `FilteredProcessor`: wrapper lọc dữ liệu theo danh sách `data_type` trước khi chuyển cho processor gốc.
- `FirebaseProcessor`: đồng bộ dữ liệu lên Firestore (cần cấu hình service account).

### 8.3 Parser và nguồn dữ liệu
- `BaseDataParser` và `FinancialDataParser` chuẩn hoá timestamp, tính % thay đổi.
- `stream.sources.vps.WSSClient` cung cấp kết nối tới nguồn VPS với các tính năng:
  - Quản lý phiên giao dịch qua `SessionManager` (tự kết nối/ngắt khi thị trường đóng).
  - Tự phát hiện đóng băng dữ liệu (`data_freeze_threshold`) và thử reconnect.
  - `subscribe_symbols(symbols)` bổ sung danh sách mã đăng ký.
  - Tra cứu thống kê qua `get_connection_stats()`.

## 9. Tiện ích hỗ trợ (`utils`)
- `deduplication.drop_duplicates`: loại trùng dựa trên danh sách cột.
- `market_hours.trading_hours`: trả về trạng thái thị trường (`is_trading_hour`, phiên hiện tại, thời gian đóng/mở tiếp theo) với đa ngôn ngữ.
- `logger`: cấu hình logging chung.
- `env.SystemInfo`: nhận diện môi trường chạy (Terminal, Jupyter, dịch vụ cloud) để tối ưu trải nghiệm.

## 10. Hướng dẫn tùy biến pipeline
1. **Xác định nguồn dữ liệu**: kế thừa `VNFetcher` hoặc `Fetcher` và hiện thực `_vn_call`. Trả về DataFrame hoặc cấu trúc phù hợp exporter.
2. **Kiểm tra dữ liệu**: kế thừa `VNValidator`/`Validator`, đặt `required_columns` hoặc viết logic kiểm tra riêng.
3. **Chuyển đổi**: override `transform` để chuẩn hoá, xử lý cột mới, gom nhóm, loại trùng.
4. **Chọn phương thức lưu**: sử dụng exporter sẵn có hoặc viết lớp mới kế thừa `Exporter`.
5. **Điều phối**: tạo `Scheduler(fetcher, validator, transformer, exporter, retry_attempts, backoff_factor)` và gọi `run` với danh sách mã và tham số phụ.
6. **Quản lý dữ liệu**: nếu cần lưu trữ có cấu trúc, sử dụng `DataManager` để ghi/đọc parquet, hoặc gọi `FlexibleExporter` cho các nền tảng giao dịch.

## 11. Quản lý dữ liệu và lưu trữ
- Khi sử dụng `ParquetExport` hoặc `DataManager`, dữ liệu được phân tách theo `data_type` và ngày. Điều này giúp dễ dàng truy vấn và xoá bỏ dữ liệu cũ.
- `DataManager.load_data` hỗ trợ lọc theo thời gian (`start_date`, `end_date`) và áp dụng bộ lọc điều kiện (`filters`) dựa trên PyArrow Expression.
- `delete_data` có thể xoá toàn bộ một loại dữ liệu (trả `-1`) hoặc chỉ một mã/ngày cụ thể, tiện cho việc dọn dẹp định kỳ.

## 12. Ví dụ triển khai và kiểm thử
- Thư mục `job_examples` chứa kịch bản mẫu (vd. `simple/default_price_board.py`) minh hoạ cách phối hợp `Scheduler` với task dựng sẵn.
- Khi thử nghiệm:
  - Đảm bảo thông tin người dùng hợp lệ (`utils.env.idv`).
  - Kiểm tra log của `Scheduler` và các processor để phát hiện lỗi API hoặc gián đoạn kết nối.
  - Lựa chọn chế độ `live` chỉ khi thị trường mở; theo dõi thông báo từ `trading_hours` để dừng hợp lý.

## 13. Bảng tham số phổ biến
| Thành phần                | Tham số                                                      | Ý nghĩa                                         |
| ------------------------- | ------------------------------------------------------------ | ----------------------------------------------- |
| `Scheduler`               | `retry_attempts`                                             | Số lần thử lại khi thất bại.                    |
| `Scheduler`               | `backoff_factor`                                             | Hệ số nhân thời gian chờ giữa các lần retry.    |
| `ParquetExport`           | `base_path`, `data_type`, `date`                             | Đường dẫn lưu, phân loại dữ liệu và ngày xử lý. |
| `FlexibleExporter.export` | `format`                                                     | Lựa chọn định dạng: `PARQUET`, `CSV`.           |
| `run_intraday_task`       | `mode`, `interval`, `page_size`, `backup`                    | Điều chỉnh tần suất cập nhật và bảo vệ dữ liệu. |
| `run_financial_task`      | `balance_sheet_period`, `lang`, `dropna`                     | Tùy chỉnh kỳ báo cáo và ngôn ngữ dữ liệu.       |
| `WSSClient`               | `market`, `enable_session_manager`, `session_check_interval` | Điều phối theo phiên giao dịch.                 |

## 14. Khuyến nghị vận hành
- Thiết lập logging và giám sát dung lượng lưu trữ định kỳ, đặc biệt với chế độ streaming và chế độ `live` có tần suất cao.
- Trước khi chỉnh sửa hoặc nâng cấp pipeline, thử nghiệm trên thư mục dữ liệu riêng (`base_path` khác) để tránh ghi đè dữ liệu sản xuất.
- Sử dụng `DataManager.list_available_data` và `preview` của exporter để xác nhận dữ liệu đã ghi nhận đầy đủ.

## 15. Mẫu code và pattern dành cho AI Agent
### 15.1 Nguyên tắc chung
- Luôn đặt phần import ở đầu module, ưu tiên import từ các namespace hiện có, ví dụ `vnstock_pipeline.template`, `vnstock_pipeline.core`, `vnstock_pipeline.utils`.
- Khi triển khai lớp mới, kế thừa các lớp nền (`VNFetcher`, `VNValidator`, `VNTransformer`, `Exporter`) để tận dụng logic sẵn có thay vì viết lại từ đầu.
- Hàm public nên nhận tham số qua đối số rõ ràng (`ticker`, `fetcher_kwargs`, `exporter_kwargs`) và truyền tiếp cho `Scheduler` hoặc component liên quan.
- Giữ log ở mức cần thiết bằng logger có sẵn (`logging.getLogger(__name__)`). Tránh in trực tiếp trừ khi phục vụ CLI script.

### 15.2 Ví dụ khởi tạo pipeline tuỳ chỉnh
```python
from vnstock_pipeline.template.vnstock import VNFetcher, VNValidator, VNTransformer
from vnstock_pipeline.core.exporter import CSVExport
from vnstock_pipeline.core.scheduler import Scheduler

class CustomFetcher(VNFetcher):
    def _vn_call(self, ticker: str, **kwargs):
        data_source = kwargs.get("client")
        return data_source.load_quote(ticker)

class CustomValidator(VNValidator):
    required_columns = ["time", "price", "volume"]

class CustomTransformer(VNTransformer):
    def transform(self, data):
        df = super().transform(data)
        return df[df["volume"] > 0]

def run_custom_task(tickers, data_client, base_path="./data/custom"):
    fetcher = CustomFetcher()
    validator = CustomValidator()
    transformer = CustomTransformer()
    exporter = CSVExport(base_path=base_path)
    scheduler = Scheduler(fetcher, validator, transformer, exporter)
    fetcher_kwargs = {"client": data_client}
    scheduler.run(tickers, fetcher_kwargs=fetcher_kwargs)
```

### 15.3 Pattern xây dựng job script
1. **Định nghĩa cấu hình**: gom tham số vào dict hoặc argparse để AI Agent dễ bổ sung tuỳ chọn mới.
2. **Khởi tạo component**: tái sử dụng lớp trong `tasks` hoặc `template`, chỉ override khi cần hành vi mới.
3. **Kiểm thử nhanh**: gọi `exporter.preview` sau khi chạy để xác minh dữ liệu trước khi đưa vào quy trình lớn.
4. **Tự động hoá**: nếu cần chạy định kỳ, bọc hàm `run_custom_task` trong scheduler ngoài (cron, Airflow) nhưng giữ interface hàm gọn gàng.
