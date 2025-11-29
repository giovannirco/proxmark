# Proxmark – TODO

## Legend
- [ ] Not started
- [~] In progress
- [x] Completed

---

## Phase 1 – MVP Script (Proxmox-focused) ✅

### 1.1 Repository Setup
- [x] Initialize git repository
- [x] Create directory structure
- [x] Add LICENSE (MIT)
- [x] Add README.md
- [x] Add CONTRIBUTING.md
- [x] Add AGENTS.md (AI guidelines)
- [x] Set up .gitignore

### 1.2 Script Core (`client/proxmark.sh`)

#### Environment & Dependencies
- [x] Detect OS/distro (Proxmox VE based on Debian)
- [x] Check for required tools (sysbench, fio, jq)
- [x] Auto-install missing dependencies via apt
- [x] Add `--no-install` flag to skip auto-install
- [x] Verify running on Proxmox host (warn if not detected)
- [x] Handle Proxmox enterprise repo errors gracefully
- [ ] Validate tool versions meet minimum requirements

#### System Information Collection
- [x] Hostname
- [x] CPU model, cores, threads, sockets
- [x] CPU base frequency detection
- [x] CPU max/boost frequency detection
- [x] Total RAM
- [x] Memory type detection (DDR4/DDR5)
- [x] Memory speed detection (MT/s)
- [x] Memory channel configuration (Single/Dual/Quad/etc.)
- [x] Memory slot usage (used/total)
- [x] Memory ECC detection
- [x] Kernel version
- [x] OS/distro name
- [x] Root disk device and model
- [x] Disk type detection (nvme/ssd/hdd)
- [x] Disk size
- [x] LVM/device-mapper disk resolution
- [x] Virtualization platform detection
- [x] Proxmox version detection (pveversion)
- [x] Proxmox node name
- [x] Proxmox cluster info (pvecm)
- [x] Proxmox VM and container count (qm, pct)
- [x] Proxmox storage pools (pvesm)
- [x] Proxmox subscription status
- [ ] ZFS pool detection and info
- [ ] Ceph cluster detection

#### CPU Benchmark
- [x] Multi-threaded sysbench cpu test
- [x] Single-threaded sysbench cpu test
- [x] Parse events per second
- [x] Parse total time
- [x] Parse latency metrics (avg, p95)
- [ ] Configurable duration via `--cpu-time`
- [ ] Configurable prime limit via `--cpu-prime`

#### Memory Benchmark
- [x] Write throughput test
- [x] Read throughput test
- [x] Parse MB/s
- [x] Parse total operations
- [ ] Configurable duration via `--mem-time`
- [ ] Configurable block size

#### Disk Benchmark
- [x] Random read/write test (randrw)
- [x] Sequential read test
- [x] Sequential write test
- [x] Parse IOPS (JSON output)
- [x] Parse bandwidth MB/s (JSON output)
- [x] Show both IOPS and MB/s for all tests
- [x] Cleanup test file after run
- [x] Disk space check before fio test
- [x] I/O engine fallback (libaio → sync)
- [x] Auto-detect /var/lib/vz on Proxmox
- [x] Warn when benchmarking tmpfs (RAM disk)
- [ ] Parse latency metrics from fio
- [ ] Direct I/O option (`--disk-direct`)
- [ ] Configurable test file size (`--disk-size`)
- [ ] Benchmark all detected storage paths (`--all-disks`)

### 1.3 Output & UX

#### Terminal Output
- [x] Progress messages
- [x] Summary table with printf
- [x] Show JSON file path
- [x] Colored output
- [x] `--no-color` option
- [x] ASCII art header/banner
- [x] Box-drawing characters
- [x] Verbose mode (`-v`, `--verbose`)
- [x] Quiet mode (`-q`, `--quiet`)
- [x] Debug mode (`--debug`) with system info dump
- [x] Organized sections (System, CPU, Memory, Storage, Results)
- [ ] Progress bar for each test (live update)
- [ ] ETA display
- [ ] Spinner while running tests

#### JSON Output
- [x] Generate result JSON
- [x] Include system info
- [x] Include all benchmark metrics
- [x] Include configuration used
- [x] Include score calculations
- [x] Save to /tmp with timestamp
- [x] Custom output path (`--output`)
- [x] Include run UUID for tracking
- [x] Log file output (proxmark-*.log)
- [x] Debug file output (proxmark-*.debug) with --debug
- [x] Write summary to log file
- [x] Proxmox info in JSON (cluster, VMs, storage)
- [x] Memory info in JSON (type, speed, channels, ECC)
- [ ] Pretty-print option (`--pretty`)

#### Score Calculation
- [x] Define baseline values
- [x] Calculate individual scores
- [x] Calculate composite total score
- [x] Display scores in output
- [x] Weight disk I/O heavily (60%)

### 1.4 CLI Interface
- [x] Basic script execution
- [x] Help text (`-h`, `--help`)
- [x] Version flag (`--version`)
- [x] Quick mode (`--quick`)
- [x] Disk path override (`--disk-path PATH`)
- [x] Tag support (`--tag TAG`)
- [x] Notes support (`--notes "text"`)
- [x] Skip upload (`--no-upload`)
- [x] Force upload (`--upload`)
- [x] JSON-only output (`--json`)
- [x] All-disks flag placeholder (`--all-disks`)

### 1.5 Error Handling
- [x] Basic error handling (set -euo pipefail)
- [x] Disk space check before fio test
- [x] Cleanup on interrupt (trap SIGINT/TERM)
- [x] Handle apt errors from enterprise repos
- [x] Fallback I/O engine for fio
- [ ] Graceful handling of missing permissions
- [ ] Timeout handling for hung benchmarks
- [ ] Retry logic for failed tests

### 1.6 Testing
- [x] Test on Proxmox VE 9.x
- [ ] Test on Proxmox VE 8.x
- [x] Test on fresh Proxmox install
- [x] Test from Proxmox web UI shell
- [x] Test via SSH
- [x] Test with pre-installed dependencies
- [x] Test LVM disk detection
- [x] Test memory detection (DDR4)

---

## Phase 2 – TypeScript API Server

### 2.1 Project Setup
- [ ] Initialize server project (`server/`)
- [ ] Set up TypeScript configuration
- [ ] Choose runtime (Bun recommended)
- [ ] Set up linting and formatting
- [ ] Add development scripts
- [ ] Set up environment variable handling

### 2.2 Database
- [ ] Set up PostgreSQL
- [ ] Set up ORM (Drizzle)
- [ ] Create database schema for results
- [ ] Create migration files
- [ ] Set up connection pooling

### 2.3 API Endpoints
- [ ] `POST /api/v1/results` - Submit results
- [ ] `GET /api/v1/results/:id` - Get single result
- [ ] `GET /api/v1/results` - List results (paginated)
- [ ] `GET /api/v1/compare` - Compare multiple results
- [ ] `GET /api/v1/leaderboard` - Top Proxmox node scores
- [ ] `GET /api/v1/stats` - Aggregate statistics
- [ ] `GET /health` - Health check

### 2.4 Security & Validation
- [ ] Input validation with Zod
- [ ] Rate limiting per IP
- [ ] Request size limits
- [ ] CORS configuration

---

## Phase 3 – Web UI

### 3.1 Project Setup
- [ ] Initialize Next.js project (`web/`)
- [ ] Configure TypeScript and Tailwind
- [ ] Add component library (shadcn/ui)
- [ ] Configure API client

### 3.2 Pages
- [ ] Home page with installation command
- [ ] Result view page (`/r/:id`)
- [ ] Comparison page (`/compare`)
- [ ] Leaderboard page for Proxmox nodes
- [ ] Explore/search page

### 3.3 Features
- [ ] Copy-to-clipboard for commands
- [ ] Score visualization charts
- [ ] Share buttons
- [ ] Dark/light mode
- [ ] Responsive design

---

## Phase 4 – Integration

### 4.1 Script → Server
- [ ] Add upload functionality to script
- [ ] Handle upload success/failure
- [ ] Display result URL after upload
- [ ] Handle network errors gracefully

### 4.2 Deployment
- [ ] Set up domain (proxmark.io)
- [ ] Deploy API server
- [ ] Deploy web UI
- [ ] Host script on CDN
- [ ] Set up monitoring

---

## Phase 5 – Proxmox-Specific Features

### 5.1 Enhanced Detection
- [ ] ZFS pool detection and benchmarks
- [ ] Ceph cluster detection
- [ ] Network storage mounts (NFS, iSCSI)
- [ ] GPU passthrough detection

### 5.2 Additional Benchmarks
- [ ] ZFS-specific benchmarks (sync write, ARC)
- [ ] Network storage benchmarks
- [ ] VM migration speed test (future)

### 5.3 Community Features
- [ ] Proxmox node leaderboard
- [ ] Hardware comparison tool
- [ ] Configuration recommendations

---

## Backlog (Future Ideas)
- [ ] Network benchmark between nodes
- [ ] Grafana dashboard export
- [ ] Prometheus metrics endpoint
- [ ] Slack/Discord notifications
- [ ] Historical tracking per node UUID
- [ ] Multi-node benchmark orchestration
