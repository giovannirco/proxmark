# AI Agent Guidelines for Proxmark

This document provides guidance for AI assistants working on the Proxmark codebase.

## Project Overview

**Proxmark** is a benchmarking tool specifically for **Proxmox VE** nodes. It is NOT a general Linux benchmarking tool.

Key points:
- Runs directly on Proxmox VE hosts (not inside VMs/containers)
- Executed from the Proxmox web UI shell or via SSH
- Target: Proxmox VE 8.x and 9.x only
- Uses apt package manager (Proxmox is Debian-based)

## Repository Structure

```
proxmark/
├── client/proxmark.sh    # Main Bash benchmark script
├── server/               # TypeScript API (future)
├── web/                  # Next.js web UI (future)
├── planning/
│   ├── initial-plan.md   # Architecture and design
│   └── todo.md           # Task tracking
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
   - Proxmox detection should be prominent

2. **Self-contained**: The script should work with a single curl command
   - Auto-install dependencies via apt
   - No external files or configurations required
   - Cleanup after itself

3. **Non-destructive**: Never modify system state beyond:
   - Installing benchmark dependencies
   - Creating temporary test files (cleaned up)
   - Writing result JSON to /tmp

### Code Style

- Use `set -euo pipefail` for safety
- Functions should be descriptive: `run_cpu_benchmark`, `collect_sysinfo`
- Use color output but support `--no-color`
- Provide verbose mode for debugging
- Parse benchmark outputs robustly (handle missing data)

### Testing Considerations

When modifying the script:
- It must work on Proxmox VE 8.x and 9.x
- It should be runnable from the web UI shell
- Dependencies must be available in Proxmox/Debian repos
- Don't assume specific hardware

## Working with TypeScript (Server/Web)

### Tech Stack (Planned)

- **Server**: Bun runtime, Hono framework, Drizzle ORM, PostgreSQL
- **Web**: Next.js 14+, Tailwind CSS, shadcn/ui

### Code Style

- TypeScript strict mode
- Zod for validation
- Explicit return types on exports
- No `any` types

## Task Management

Check `planning/todo.md` for current status:
- Mark items as complete `[x]` when finished
- Update the todo list when adding new features
- Keep phases organized

## Common Tasks

### Adding a CLI Flag

1. Add to argument parsing in `parse_args()`
2. Set default value at top of script
3. Update `usage()` help text
4. Implement the behavior
5. Update README.md if user-facing

### Adding a New Benchmark

1. Create a function like `run_newtest_benchmark()`
2. Parse output into variables
3. Add to `generate_json()` output
4. Add to `print_summary()` table
5. Update scoring if applicable
6. Update documentation

### Modifying Output Format

1. Keep backward compatibility in JSON schema
2. Update `print_summary()` for terminal output
3. Consider `--json` mode implications
4. Update sample output in README.md

## Do's and Don'ts

### Do

- Focus on Proxmox VE use cases
- Test changes on actual Proxmox nodes when possible
- Keep the script simple and readable
- Preserve backward compatibility
- Update documentation with changes

### Don't

- Add support for non-Proxmox distributions
- Assume specific hardware or storage types
- Add dependencies not in Proxmox repos
- Modify system configuration
- Store sensitive information

## Commit Guidelines

Use conventional commits:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructuring
- `docs`: Documentation only
- `chore`: Maintenance

Examples:
- `feat: add ZFS pool detection`
- `fix: handle missing disk model gracefully`
- `docs: update README with new CLI options`

## Questions to Ask

Before making changes, consider:
1. Does this work on Proxmox VE 7.x and 8.x?
2. Will this run from the Proxmox web UI shell?
3. Are dependencies available via apt?
4. Does this affect existing JSON output?
5. Is the documentation updated?

## Resources

- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [sysbench](https://github.com/akopytov/sysbench)
- [fio](https://github.com/axboe/fio)
- [ShellCheck](https://www.shellcheck.net/)

