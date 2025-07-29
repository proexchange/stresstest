# stresstest

A bash utility for HTTP load testing and grading website performance using wrk.

## Prerequisites

- [wrk](https://github.com/wg/wrk) (HTTP benchmarking tool)
- Bash shell

## Installation

Clone this repository and make the script executable:

```bash
git clone https://github.com/proexchange/stresstest.git
chmod +x stresstest.sh
```

## Usage

```bash
./stresstest.sh [options] URL1 [URL2 ...]
```

### Options

| Option      | Default | Description                         |
|-------------|---------|-------------------------------------|
| `-t`        | 2       | Number of threads                   |
| `-c`        | 10      | Number of connections               |
| `-d`        | 60      | Duration in seconds                 |
| `-f`        | table   | Output format (table or json)       |
| `--timeout` | 10      | Request timeout in seconds          |

### Examples

Test a single website:
```bash
./stresstest.sh https://example.com
```

Test multiple websites with custom settings:
```bash
./stresstest.sh -t 4 -c 25 -d 30 https://example.com https://example.org
```

Output results in JSON format:
```bash
./stresstest.sh -f json https://example.com
```

## Performance Grading

| Grade | Requirements                                                     |
|-------|------------------------------------------------------------------|
| A     | ≥300 req/sec, ≤100ms latency, 0% timeouts, no connection errors |
| B     | ≥100 req/sec, ≤300ms latency, ≤2% timeouts, no connection errors|
| C     | ≥25 req/sec, ≤750ms latency, ≤5% timeouts                       |
| D     | ≥5 req/sec, ≤1500ms latency, ≤10% timeouts                      |
| F     | Below all other criteria                                         |

## Output Formats

### Table Format (default)

```
URL                                     |    Latency |    Req/sec |    Total | Transfer/sec  | Errors |  Grade
------------------------------------------------------------------------------------------------------------------
https://example.com                     |     68.2ms |     123.45 |    7400  |       1.14MB  |      0 |      A
```

### JSON Format

```json
[
{
    "url": "https://example.com",
    "latency": "68.2ms",
    "requests_per_sec": "123.45",
    "total_requests": "7400",
    "transfer_per_sec": "1.14MB",
    "errors": 0,
    "grade": "A",
    "socket_errors": {
        "connect": 0,
        "read": 0,
        "write": 0,
        "timeout": 0
    }
}
]
```
