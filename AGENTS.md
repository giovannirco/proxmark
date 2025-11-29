# AI Agent Guidelines for Proxmark

This document provides guidance for AI assistants working on the Proxmark codebase.

## Project Overview

**Proxmark** is a benchmarking tool specifically for **Proxmox VE** nodes. It is NOT a general Linux benchmarking tool.

Key points:
- Runs directly on Proxmox VE hosts (not inside VMs/containers)
- Executed from the Proxmox web UI shell or via SSH
- Target: Proxmox VE 8.x and 9.x only
- Uses apt package manager (Proxmox is Debian-based)

## Current Version: 1.0.8

Phase 1 (MVP Script) is complete with:
- CPU, Memory, Disk, Network benchmarks
- Memory latency testing
- Multi-disk discovery and benchmarking
- Proxmark Score (large-scale scoring like Geekbench)
- Rich system detection (CPU freq, memory channels, ECC, etc.)
- Proxmox-specific info (cluster, VMs, storage pools)
- Log file output
- Comprehensive CLI options

## Repository Structure

```
proxmark/
├── client/proxmark.sh    # Main Bash benchmark script (v1.0.8)
├── server/               # TypeScript API (future - Phase 2)
├── web/                  # Next.js web UI (future - Phase 3)
├── planning/
│   ├── initial-plan.md   # Architecture and design
│   └── todo.md           # Task tracking (keep updated!)
├── README.md             # Public documentation
├── CONTRIBUTING.md       # Contributor guidelines
├── AGENTS.md             # This file
└── LICENSE               # MIT License
```

## Working with the Bash Script

### Key Principles

1. **Proxmox-first**: Always consider the Proxmox environment
   - Root access is standard
   - apt is the package manager
   - /var/lib/vz is the default VM storage
   - Use Proxmox CLI tools (pveversion, pvecm, pvesm, qm, pct)

2. **Self-contained**: The script should work with a single curl command
   - Auto-install dependencies via apt
   - No external files or configurations required
   - Cleanup after itself

3. **Non-destructive**: Never modify system state beyond:
   - Installing benchmark dependencies
   - Creating temporary test files (cleaned up)
   - Writing result JSON and logs to /tmp

4. **Robust detection**: Handle edge cases gracefully
   - LVM/device-mapper volumes
   - Missing dmidecode access
   - Enterprise repo apt errors
   - Various memory configurations

### Code Style

- Use `set -euo pipefail` for safety
- Functions should be descriptive: `run_cpu_benchmark`, `collect_sysinfo`
- Use color output but support `--no-color`
- Provide verbose mode for debugging
- Parse benchmark outputs robustly (handle missing data)
- Log to both console and file

### Current Features to Maintain

System detection:
- CPU: model, cores, threads, sockets, base/max frequency
- Memory: total, type (DDR4/DDR5), speed, channels, slots, ECC
- Disk: model, type, size, LVM resolution
- Proxmox: version, node, cluster, VMs, containers, storage pools

Benchmarks:
- CPU: multi-threaded, single-threaded (sysbench)
- Memory: read, write throughput (sysbench)
- Disk: 4K random IOPS, sequential read/write MB/s (fio)

Output:
- Colored terminal with organized sections
- JSON file with all data
- Log file with summary
- Debug file with system dump (--debug)

### Testing Considerations

When modifying the script:
- It must work on Proxmox VE 8.x and 9.x
- It should be runnable from the web UI shell
- Dependencies must be available in Proxmox/Debian repos
- Don't assume specific hardware
- Handle LVM, ZFS, and direct disk paths
- Test with various memory configurations

## Task Management

Check `planning/todo.md` for current status:
- Phase 1 is complete ✅
- Mark items as complete `[x]` when finished
- Add new tasks discovered during development
- Keep phases organized

## Common Tasks

### Adding a CLI Flag

1. Add to flags section at top of script
2. Add to argument parsing in `parse_args()`
3. Update `usage()` help text
4. Implement the behavior
5. Update README.md if user-facing

### Adding System Detection

1. Add variable initialization in `collect_sysinfo()`
2. Use Proxmox CLI tools where available (pvesm, pvecm, etc.)
3. Add fallbacks for when tools aren't available
4. Add to JSON output in `SYSINFO_JSON`
5. Add to terminal display in `print_summary()`
6. Add to log file in `write_summary_to_log()`

### Adding a New Benchmark

1. Create a function like `run_newtest_benchmark()`
2. Parse output into variables
3. Add to `generate_json()` output
4. Add to `print_summary()` table
5. Update scoring if applicable
6. Update documentation

## Do's and Don'ts

### Do

- Focus on Proxmox VE use cases
- Test changes on actual Proxmox nodes when possible
- Keep the script simple and readable
- Preserve backward compatibility in JSON output
- Update documentation with changes
- Update todo.md when completing tasks
- Use conventional commits

### Don't

- Add support for non-Proxmox distributions
- Assume specific hardware or storage types
- Add dependencies not in Proxmox repos
- Modify system configuration
- Store sensitive information
- Break existing JSON schema

## Commit Guidelines

Use conventional commits:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructuring
- `docs`: Documentation only
- `chore`: Maintenance

Examples:
- `feat: add memory channel detection`
- `fix: handle LVM disk resolution`
- `docs: update README with new options`

## Questions to Ask

Before making changes, consider:
1. Does this work on Proxmox VE 8.x and 9.x?
2. Will this run from the Proxmox web UI shell?
3. Are dependencies available via apt?
4. Does this affect existing JSON output?
5. Is the documentation updated?
6. Is todo.md updated?

## Resources

- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [sysbench](https://github.com/akopytov/sysbench)
- [fio](https://github.com/axboe/fio)
- [ShellCheck](https://www.shellcheck.net/)
- [PiBenchmarks](https://github.com/TheRemote/PiBenchmarks) - inspiration
