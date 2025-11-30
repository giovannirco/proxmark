# Contributing to Proxmark

Thank you for your interest in contributing to Proxmark! This tool is built specifically for the Proxmox VE community.

## Code of Conduct

Be respectful, inclusive, and constructive. We're all here to make Proxmox benchmarking better.

## How to Contribute

### Reporting Bugs

1. Check existing issues to avoid duplicates
2. Include:
   - Proxmox VE version (e.g., 9.1.1)
   - How you ran the script (web UI shell vs SSH)
   - Steps to reproduce
   - Error messages or log file contents (`/tmp/proxmark-*.log`)

### Suggesting Features

1. Check existing issues and discussions
2. Focus on features useful for Proxmox users
3. Describe the use case and proposed solution

### Submitting Code

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test on a Proxmox VE node (8.x or 9.x)
5. Commit with conventional commit messages
6. Push and open a Pull Request

## Development Setup

```bash
git clone https://github.com/giovannirco/proxmark.git
cd proxmark

# Test locally (ideally on a Proxmox node)
bash client/proxmark.sh --quick --debug
```

## Project Structure

```
proxmark/
├── client/           # Bash benchmark script
│   └── proxmark.sh   # Main script (v1.0.7)
├── server/           # TypeScript API (future)
├── web/              # Next.js web UI (future)
├── planning/         # Design documents
│   ├── initial-plan.md
│   └── todo.md       # Task tracking
├── README.md
├── CONTRIBUTING.md
├── AGENTS.md         # AI assistant guidelines
└── LICENSE
```

## Guidelines

### Bash Script

- Use `shellcheck` for linting
- Follow existing code style
- Test on Proxmox VE 8.x and 9.x
- Handle edge cases (missing dmidecode, LVM volumes, etc.)
- Avoid dependencies not available in Proxmox repos
- Update help text and README for new CLI options

### Commit Messages

Use conventional commits:
- `feat`: New feature (e.g., `feat: add ZFS pool detection`)
- `fix`: Bug fix (e.g., `fix: handle missing disk model`)
- `refactor`: Code restructuring
- `docs`: Documentation only
- `chore`: Maintenance

### TypeScript (Server/Web) - Future

- Use TypeScript strict mode
- Format with Prettier
- Lint with ESLint
- Write tests for new features

## Testing Checklist

Testing on real Proxmox nodes is essential:

- [ ] Proxmox VE 9.x
- [ ] Proxmox VE 8.x
- [ ] From web UI shell
- [ ] Via SSH
- [ ] With LVM storage
- [ ] With ZFS storage
- [ ] With different memory configurations
- [ ] With clustered nodes

## Pull Request Checklist

- [ ] Tested on Proxmox VE
- [ ] Code follows project style
- [ ] Commit messages follow convention
- [ ] Documentation updated if needed
- [ ] Log files checked for new features

## Areas Where Help is Needed

- Testing on Proxmox VE 8.x
- Testing on different hardware (AMD vs Intel, various NVMe drives)
- ZFS-specific benchmarks
- Ceph cluster detection
- Translations

## Getting Help

- Open a GitHub Discussion for questions
- Check existing issues and docs first
- Include log file output when asking about issues

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for helping make Proxmark better for the Proxmox community! 🎉
