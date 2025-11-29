# Proxmark

<div align="center">

**Fast benchmarking for Proxmox VE nodes**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Proxmox VE](https://img.shields.io/badge/Proxmox%20VE-8.x%20%7C%209.x-orange.svg)](https://www.proxmox.com/)

[Getting Started](#getting-started) •
[Features](#features) •
[Usage](#usage) •
[Benchmarks](#benchmarks) •
[Contributing](#contributing)

</div>

---

## What is Proxmark?

**Proxmark** is a benchmarking tool designed specifically for **Proxmox VE** nodes. Run a single command from the Proxmox shell (via the web UI or SSH) and get instant, comparable metrics for CPU, memory, and disk performance.

Perfect for:
- 🖥️ **Homelabbers** comparing hardware before building a Proxmox cluster
- 🏢 **Sysadmins** validating new Proxmox node deployments
- 📊 **Enthusiasts** tracking Proxmox node performance over time
- 🔄 **Teams** standardizing Proxmox benchmark procedures

## Getting Started

### One-Liner from Proxmox Shell

Open the shell from your Proxmox web UI (Node → Shell) or SSH into your node and run:

```bash
curl -sL https://raw.githubusercontent.com/giovannirco/proxmark/v1.0.4/client/proxmark.sh | bash
```

The script auto-detects Proxmox and benchmarks `/var/lib/vz` (your VM storage) by default.

**Quick mode** (~2 minutes):

```bash
curl -sL https://raw.githubusercontent.com/giovannirco/proxmark/v1.0.4/client/proxmark.sh | bash -s -- --quick
```

**Custom storage path**:

```bash
curl -sL https://raw.githubusercontent.com/giovannirco/proxmark/v1.0.4/client/proxmark.sh | bash -s -- --disk-path /mnt/nvme-storage
```

**Debug mode** (troubleshooting):

```bash
curl -sL https://raw.githubusercontent.com/giovannirco/proxmark/v1.0.4/client/proxmark.sh | bash -s -- --debug
```

> **Tip**: Replace `v1.0.4` with `master` to always get the latest development version.

### Download and Inspect First

If you prefer to review the script before running:

```bash
curl -sL https://raw.githubusercontent.com/giovannirco/proxmark/v1.0.4/client/proxmark.sh -o proxmark.sh
less proxmark.sh
bash proxmark.sh
```

### Clone Repository

```bash
git clone https://github.com/giovannirco/proxmark.git
cd proxmark
bash client/proxmark.sh
```

### Requirements

- **Proxmox VE 8.x or 9.x** (runs directly on the host, not inside a VM/container)
- Root access (you're already root in the Proxmox shell)
- ~2GB free disk space for benchmark test files

Dependencies are installed automatically via `apt`:
- `sysbench` - CPU and memory benchmarks
- `fio` - Disk I/O benchmarks  
- `jq` - JSON processing

## Features

### 🚀 One-Liner Execution
Run directly from the Proxmox web UI shell. No installation needed.

### 📊 Proxmox-Optimized Benchmarks
- **CPU**: Multi-threaded and single-threaded performance
- **Memory**: Read and write throughput
- **Disk**: Random I/O, sequential read/write (benchmark your VM storage!)

### 🎯 Proxmox Detection
Automatically detects Proxmox version, node name, and storage paths.

### 📈 Standardized Scoring
Comparable scores across different Proxmox nodes and hardware.

### 📁 JSON Export
Results saved as JSON for automation and historical tracking.

### 🌐 Cloud Comparison (Coming Soon)
Upload results and compare with other Proxmox nodes in the community.

## Usage

### Basic Usage

From the Proxmox shell:

```bash
bash proxmark.sh
```

The script auto-detects `/var/lib/vz` on Proxmox systems. If running on non-Proxmox, it defaults to `/tmp`.

### Quick Mode (~2 minutes)

```bash
bash proxmark.sh --quick
```

### Benchmark Custom Storage Path

Test a specific storage path:

```bash
bash proxmark.sh --disk-path /mnt/nvme-storage
```

Or a specific storage mount:

```bash
bash proxmark.sh --disk-path /mnt/pve/nvme-storage
```

### Tag Your Results

```bash
bash proxmark.sh --tag "production" --tag "nvme" --notes "New NVMe install"
```

### JSON Output Only

```bash
bash proxmark.sh --json --no-upload > results.json
```

### All Options

```
Usage: proxmark.sh [OPTIONS]

Options:
  -h, --help          Show help message
  -V, --version       Show version number
  -q, --quiet         Minimal output
  -v, --verbose       Verbose output
  --debug             Debug mode (shows commands and system info)
  --json              Output JSON only (for scripting)
  --quick             Run quick benchmarks (~2 min instead of ~10 min)
  --no-color          Disable colored output
  --no-upload         Don't upload results to server
  --upload            Force upload results
  --no-install        Don't auto-install missing dependencies

Configuration:
  --disk-path PATH    Directory for disk benchmarks (default: /var/lib/vz on Proxmox)
  --all-disks         Benchmark all detected storage paths (coming soon)
  --output FILE       Custom output path for JSON results
  --tag TAG           Add a tag to results (can use multiple times)
  --notes "TEXT"      Add notes to the benchmark result

Environment Variables:
  PROXMARK_DISK_PATH   Same as --disk-path
  PROXMARK_CPU_TIME    CPU benchmark duration (default: 60)
  PROXMARK_MEM_TIME    Memory benchmark duration (default: 30)
  PROXMARK_DISK_RUNTIME Disk benchmark duration (default: 60)
```

## Benchmarks

### CPU Benchmark

Uses `sysbench cpu` to measure:
- **Multi-threaded**: Events per second using all CPU cores
- **Single-threaded**: Single-core performance (important for VM responsiveness)

### Memory Benchmark

Uses `sysbench memory` to measure:
- **Write throughput**: MB/s writing to memory
- **Read throughput**: MB/s reading from memory

### Disk Benchmark

Uses `fio` to measure (critical for Proxmox VM performance):
- **Random Read/Write**: 4K block size, 32 queue depth (VM disk pattern)
- **Sequential Read**: 1M block size, maximum throughput
- **Sequential Write**: 1M block size, maximum throughput

**Tip**: Use `--disk-path /var/lib/vz` to benchmark your actual VM storage!

## Sample Output

```
╭──────────────────────────────────────────────────────────────╮
│                   BENCHMARK RESULTS                          │
╰──────────────────────────────────────────────────────────────╯

System: pve-node-01 | Intel Xeon E5-2680 v4 (28 cores) | 128GB RAM
OS: Proxmox VE 8.1 | Kernel: 6.5.11-7-pve
Proxmox: pve-manager/8.1.3/b46aac3b42da5d15
Disk: Samsung SSD 970 EVO Plus (nvme)

┌────────────┬──────────────────────┬──────────────┬─────────┐
│ Test       │ Metric               │ Value        │ Score   │
├────────────┼──────────────────────┼──────────────┼─────────┤
│ CPU        │ multi-thread (ev/s)  │     18235.92 │     182 │
│ CPU        │ single-thread (ev/s) │      1892.44 │     189 │
│ Memory     │ write (MB/s)         │      8341.77 │     166 │
│ Memory     │ read (MB/s)          │      9102.33 │         │
│ Disk       │ rand r/w IOPS        │       125000 │     250 │
│ Disk       │ seq read (MB/s)      │      3450.00 │     345 │
│ Disk       │ seq write (MB/s)     │      2890.00 │         │
└────────────┴──────────────────────┴──────────────┴─────────┘

                            TOTAL SCORE: 3374

📁 JSON saved: /tmp/proxmark-result-20240115T143022Z.json
🌐 Result URL: (upload not yet implemented)
```

## Scoring

Scores are weighted for Proxmox virtualization workloads:
- **CPU**: 25% (split between multi and single-thread)
- **Memory**: 15%
- **Disk**: 60% (disk I/O is typically the bottleneck for VMs)

Higher scores = better performance for running VMs and containers.

## Roadmap

- [x] Benchmark script with Proxmox detection
- [x] CPU, Memory, Disk benchmarks
- [x] JSON output and scoring
- [ ] Central API server for result storage
- [ ] Web UI for viewing and comparing results
- [ ] Community leaderboard for Proxmox nodes
- [ ] ZFS-specific benchmarks
- [ ] Ceph/network storage benchmarks
- [ ] Historical tracking per node

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Testing on different Proxmox versions and hardware configurations is especially helpful.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

When forking or redistributing, please reference the original repository:
- GitHub: https://github.com/giovannirco/proxmark

## Acknowledgments

- Built for the [Proxmox VE](https://www.proxmox.com/) community
- Inspired by [PiBenchmarks](https://pibenchmarks.com/)
- Uses [sysbench](https://github.com/akopytov/sysbench) and [fio](https://github.com/axboe/fio)

---

<div align="center">

**[⬆ Back to top](#proxmark)**

Made with ❤️ for the Proxmox community

</div>
