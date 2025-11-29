# Proxmark – Initial Plan

## Vision

**Proxmark** is a fast, one-line benchmarking tool designed specifically for **Proxmox VE** nodes. Run it directly from the Proxmox shell (web UI or SSH) to get instant insight into how your node will perform for VM and container workloads.

---

## Goals

1. **One-liner execution**: Run benchmarks directly from the Proxmox shell
2. **Quick but meaningful**: Complete CPU, memory, and disk tests in ~10 minutes
3. **Proxmox-aware**: Detect Proxmox version, storage paths, and configuration
4. **Standardized results**: Produce consistent, comparable metrics across nodes
5. **Cloud comparison**: Upload results and compare with other Proxmox nodes
6. **Community leaderboard**: See how your hardware stacks up

---

## Target Environment

**Primary**: Proxmox VE 7.x and 8.x hosts
- Run directly on the Proxmox host (not inside VMs/containers)
- Executed from the web UI shell or via SSH
- Root access (standard for Proxmox shell)
- Debian-based (apt package manager)

**Not supported** (out of scope for MVP):
- Other Linux distributions
- Running inside VMs or containers
- Non-Proxmox hypervisors

---

## Example UX

From the Proxmox web UI, click on your node → Shell, then run:

```bash
curl -sL https://proxmark.io/run | bash
```

Or with options:

```bash
curl -sL https://proxmark.io/run | bash -s -- --disk-path /var/lib/vz --quick
```

**Terminal output:**
```
╭──────────────────────────────────────────────────────────────╮
│                    PROXMARK v0.1.0                           │
│              Proxmox VE Benchmark Suite                      │
╰──────────────────────────────────────────────────────────────╯

[proxmark] Checking dependencies...
[✓] All dependencies satisfied
[proxmark] Collecting system information...
[✓] System info collected
[proxmark] Running CPU benchmark (multi-threaded, 60s)...
[✓] CPU multi-thread: 18235.92 events/sec
[proxmark] Running CPU benchmark (single-threaded, 30s)...
[✓] CPU single-thread: 1892.44 events/sec
...

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
🌐 Result URL: https://proxmark.io/r/abc123xyz
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Proxmox VE Host                            │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  proxmark.sh (run from Proxmox shell)                     │  │
│  │  - Installs dependencies via apt                          │  │
│  │  - Detects Proxmox version and storage                    │  │
│  │  - Runs benchmark suite                                   │  │
│  │  - Generates JSON results                                 │  │
│  │  - Uploads to central API                                 │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS POST /api/v1/results
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      proxmark.io Server                         │
│  ┌────────────────────┐    ┌────────────────────────────────┐  │
│  │   TypeScript API   │────│   PostgreSQL Database          │  │
│  │   (Bun/Hono)       │    │   - results                    │  │
│  │                    │    │   - proxmox_nodes              │  │
│  │   Endpoints:       │    └────────────────────────────────┘  │
│  │   - POST /results  │                                        │
│  │   - GET /results   │    ┌────────────────────────────────┐  │
│  │   - GET /compare   │    │   Web UI (Next.js)             │  │
│  │   - GET /leaders   │    │   - Result viewer              │  │
│  └────────────────────┘    │   - Node comparison            │  │
│                            │   - Leaderboard                │  │
│                            └────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Benchmark Suite

### CPU Benchmark (sysbench)

| Test | Duration | Threads | Purpose |
|------|----------|---------|---------|
| Multi-thread | 60s | nproc | Overall CPU capacity for VMs |
| Single-thread | 30s | 1 | Single-core performance |

### Memory Benchmark (sysbench)

| Test | Duration | Operation | Purpose |
|------|----------|-----------|---------|
| Write | 30s | write | Memory bandwidth |
| Read | 30s | read | Memory bandwidth |

### Disk Benchmark (fio)

| Test | Duration | Block Size | Purpose |
|------|----------|------------|---------|
| Random R/W | 60s | 4K | VM disk pattern simulation |
| Sequential Read | 60s | 1M | Backup/restore performance |
| Sequential Write | 60s | 1M | VM provisioning speed |

**Recommended**: Use `--disk-path /var/lib/vz` to benchmark actual VM storage.

### Quick Mode

Reduced durations for faster results (~2 min total):
- CPU: 20s multi, 10s single
- Memory: 10s each
- Disk: 20s each

---

## Scoring Model

### Baselines (mid-range Proxmox hardware)

| Metric | Baseline | Notes |
|--------|----------|-------|
| CPU multi (ev/s) | 10,000 | ~8-core Xeon |
| CPU single (ev/s) | 1,000 | Single-thread |
| Memory (MB/s) | 5,000 | DDR4-2666 |
| Disk IOPS | 50,000 | NVMe baseline |
| Disk BW (MB/s) | 1,000 | NVMe baseline |

### Composite Score

```
total_score = (cpu_score * 0.25) + (memory_score * 0.15) + (disk_score * 0.60)
```

Disk weighted heavily because it's typically the VM performance bottleneck.

---

## Data Schema

### Result JSON

```json
{
  "version": "0.1.0",
  "run_id": "uuid",
  "timestamp_utc": "2024-01-15T14:30:22Z",
  "system": {
    "hostname": "pve-node-01",
    "cpu_model": "Intel Xeon E5-2680 v4",
    "cpu_cores": 28,
    "cpu_threads": 56,
    "mem_total_mb": 131072,
    "kernel": "6.5.11-7-pve",
    "os": "Proxmox VE 8.1",
    "proxmox_version": "pve-manager/8.1.3/...",
    "disk_model": "Samsung SSD 970 EVO Plus",
    "disk_type": "nvme"
  },
  "benchmarks": {
    "cpu": { ... },
    "memory": { ... },
    "disk": { ... }
  },
  "scores": {
    "cpu_multi": 182,
    "cpu_single": 189,
    "memory": 166,
    "disk_iops": 250,
    "disk_bw": 345,
    "total": 3374
  }
}
```

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/results` | Submit benchmark results |
| GET | `/api/v1/results/:id` | Get result by ID |
| GET | `/api/v1/compare?ids=a,b,c` | Compare multiple results |
| GET | `/api/v1/leaderboard` | Top Proxmox node scores |
| GET | `/api/v1/stats` | Aggregate statistics |

---

## Web UI Pages

1. **Home** (`/`) - Installation command, recent results
2. **Result** (`/r/:id`) - Full result with scores and system info
3. **Compare** (`/compare`) - Side-by-side node comparison
4. **Leaderboard** (`/leaderboard`) - Top Proxmox nodes by score

---

## Project Structure

```
proxmark/
├── client/
│   └── proxmark.sh         # Bash benchmark script
├── server/
│   └── src/                # TypeScript API (future)
├── web/
│   └── src/                # Next.js UI (future)
├── planning/
│   ├── initial-plan.md
│   └── todo.md
├── README.md
├── CONTRIBUTING.md
├── AGENTS.md
└── LICENSE
```

---

## MVP Scope

### Phase 1: Local Script ✓
- [x] Bash script with Proxmox detection
- [x] CPU, Memory, Disk benchmarks
- [x] JSON output with scores
- [x] CLI options (--quick, --disk-path, etc.)

### Phase 2: Server
- [ ] TypeScript API server
- [ ] PostgreSQL database
- [ ] Result submission and retrieval

### Phase 3: Web UI
- [ ] Result viewer
- [ ] Comparison tool
- [ ] Leaderboard

### Phase 4: Polish
- [ ] Custom domain (proxmark.io)
- [ ] Community features
- [ ] Proxmox-specific enhancements

---

## Future Ideas

- **ZFS benchmarks**: Pool-specific tests
- **Ceph benchmarks**: Distributed storage tests
- **Network benchmarks**: Inter-node iperf3
- **VM migration test**: Live migration timing
- **Historical tracking**: Same node over time
- **Cluster view**: All nodes in a cluster
