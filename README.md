# Proxmark

<div align="center">

**Fast benchmarking for Proxmox VE nodes**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Proxmox VE](https://img.shields.io/badge/Proxmox%20VE-8.x%20%7C%209.x-orange.svg)](https://www.proxmox.com/)
[![Version](https://img.shields.io/badge/version-1.0.8-green.svg)](https://github.com/giovannirco/proxmark/releases)

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
curl -sL https://raw.githubusercontent.com/giovannirco/proxmark/master/client/proxmark.sh | bash
```

The script auto-detects Proxmox and benchmarks `/var/lib/vz` (your VM storage) by default.

**Quick mode** (~2 minutes):

```bash
curl -sL https://raw.githubusercontent.com/giovannirco/proxmark/master/client/proxmark.sh | bash -s -- --quick
```

**Custom storage path**:

```bash
curl -sL https://raw.githubusercontent.com/giovannirco/proxmark/master/client/proxmark.sh | bash -s -- --disk-path /mnt/nvme-storage
```

**Debug mode** (troubleshooting):

```bash
curl -sL https://raw.githubusercontent.com/giovannirco/proxmark/master/client/proxmark.sh | bash -s -- --debug
```

**Benchmark all storage** (discovers and tests all Proxmox storage):

```bash
curl -sL https://raw.githubusercontent.com/giovannirco/proxmark/master/client/proxmark.sh | bash -s -- --all-disks
```

**With network benchmark** (requires an iperf3 server):

```bash
curl -sL https://raw.githubusercontent.com/giovannirco/proxmark/master/client/proxmark.sh | bash -s -- --iperf 192.168.1.100
```

### Download and Inspect First

If you prefer to review the script before running:

```bash
curl -sL https://raw.githubusercontent.com/giovannirco/proxmark/master/client/proxmark.sh -o proxmark.sh
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

### 📊 Comprehensive Benchmarks
- **CPU**: Multi-threaded and single-threaded performance
- **Memory**: Read/write throughput and latency
- **Disk**: Random I/O (IOPS), sequential read/write (MB/s)
- **Network**: Bandwidth and latency via iperf3 (optional)

### 🎯 Rich System Detection
- CPU model, cores, threads, base/max frequency
- Memory type (DDR4/DDR5), speed, channel config, ECC status
- Disk model, type (NVMe/SSD/HDD), size
- Proxmox version, cluster info, VM/container count
- Storage pools and configuration

### 📈 Proxmark Score
Large-scale scoring system (like Geekbench) with:
- Individual scores for every metric
- Category subtotals (CPU, Memory, Disk, Network)
- Weighted composite score optimized for Proxmox workloads

### 📁 Detailed Output
- Beautiful terminal output with organized sections
- JSON export for automation
- Log files for historical tracking

### 🌐 Cloud Comparison (Coming Soon)
Upload results and compare with other Proxmox nodes in the community.

## Sample Output

```
╭──────────────────────────────────────────────────────────────────────────╮
│                         BENCHMARK RESULTS                                │
╰──────────────────────────────────────────────────────────────────────────╯

SYSTEM INFORMATION
────────────────────────────────────────────────────────────────────────────
  Hostname:     pve-node-01
  OS:           Debian GNU/Linux 13 (trixie)
  Kernel:       6.17.2-1-pve
  Proxmox:      pve-manager/9.1.1/...
  Cluster:      my-cluster (3 nodes)
  Workloads:    5 VMs, 3 containers
  Storage:      local(dir) local-lvm(lvmthin)

CPU
────────────────────────────────────────────────────────────────────────────
  Model:        AMD Ryzen 7 PRO 4750GE with Radeon Graphics
  Cores:        16 cores / 16 threads
  Sockets:      1
  Max Freq:     4367 MHz

MEMORY
────────────────────────────────────────────────────────────────────────────
  Total:        64 GB (65536 MB)
  Type:         DDR4 ECC
  Speed:        3200 MT/s
  Config:       Dual Channel (2/4 slots)

STORAGE
────────────────────────────────────────────────────────────────────────────
  Test Path:    /var/lib/vz
  Device:       /dev/mapper/pve-root
  Model:        Samsung SSD 970 EVO Plus
  Type:         NVME
  Size:         500 GB

BENCHMARK RESULTS
────────────────────────────────────────────────────────────────────────────

┌────────────┬─────────────────────┬──────────────┬──────────────┬──────────┐
│ Component  │ Test                │ IOPS         │ Throughput   │ Score    │
├────────────┼─────────────────────┼──────────────┼──────────────┼──────────┤
│ CPU        │ Multi-thread        │              │ 6743.83 e/s  │     6743 │
│ CPU        │ Single-thread       │              │  818.42 e/s  │      818 │
├────────────┼─────────────────────┼──────────────┼──────────────┼──────────┤
│ Memory     │ Write               │              │ 13343.45 MB/s│    13343 │
│ Memory     │ Read                │              │ 86520.68 MB/s│    86520 │
│ Memory     │ Latency             │              │    0.02 ms   │    50000 │
├────────────┼─────────────────────┼──────────────┼──────────────┼──────────┤
│ Disk       │ 4K Random R/W       │        17688 │   68.56 MB/s │    17688 │
│ Disk       │ Sequential Read     │          922 │  922.92 MB/s │     9229 │
│ Disk       │ Sequential Write    │          317 │  317.91 MB/s │     3179 │
└────────────┴─────────────────────┴──────────────┴──────────────┴──────────┘

Category Scores: CPU: 7561 | Memory: 1049 | Disk: 18917

╭──────────────────────────────────────────────────────────────────────────╮
│                         PROXMARK SCORE: 12847                            │
╰──────────────────────────────────────────────────────────────────────────╯

📁 JSON saved: /tmp/proxmark-result-20251129T170738Z.json
📋 Log file: /tmp/proxmark-20251129T170738Z.log
🌐 Result URL: (coming soon - proxmark.io)
```

## Usage

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
  --all-disks         Benchmark all detected storage paths
  --iperf HOST[:PORT] Run network benchmark against iperf3 server
  --output FILE       Custom output path for JSON results
  --tag TAG           Add a tag to results (can use multiple times)
  --notes "TEXT"      Add notes to the benchmark result
  --non-interactive   Don't prompt for additional disks

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
- **Latency**: Random access latency (lower is better)

### Disk Benchmark

Uses `fio` to measure (critical for Proxmox VM performance):
- **Random Read/Write**: 4K block size IOPS and MB/s (VM disk pattern)
- **Sequential Read**: 1M block size throughput
- **Sequential Write**: 1M block size throughput

**Tip**: The script auto-detects `/var/lib/vz` to benchmark your actual VM storage!

### Network Benchmark (Optional)

Uses `iperf3` when `--iperf` is specified:
- **Bandwidth**: Network throughput in Mbps
- **Latency**: Round-trip time via ping

Useful for testing network storage performance or cluster interconnects.

## Proxmark Score

The **Proxmark Score** uses a large-scale scoring system (like Geekbench) where every metric gets an individual score, then combined into category totals and a weighted overall score.

**Score Weights** (optimized for Proxmox workloads):
- **CPU**: 20% (multi + single-thread combined)
- **Memory**: 20% (throughput + latency)
- **Disk**: 60% (disk I/O is typically the VM bottleneck)

Higher scores = better performance for running VMs and containers.

## Roadmap

- [x] Benchmark script with Proxmox detection
- [x] CPU, Memory, Disk benchmarks
- [x] Memory latency benchmark
- [x] Network benchmark (iperf3)
- [x] Multi-disk discovery and testing
- [x] JSON output and Proxmark Score
- [x] Detailed system info (CPU freq, memory channels, etc.)
- [x] Proxmox cluster and workload info
- [x] Log file output
- [ ] Central API server for result storage
- [ ] Web UI for viewing and comparing results
- [ ] Community leaderboard for Proxmox nodes
- [ ] ZFS-specific benchmarks
- [ ] Ceph/network storage benchmarks

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
