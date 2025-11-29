# Contributing to Proxmark

Thank you for your interest in contributing to Proxmark! This tool is built specifically for the Proxmox VE community.

## Code of Conduct

Be respectful, inclusive, and constructive. We're all here to make Proxmox benchmarking better.

## How to Contribute

### Reporting Bugs

1. Check existing issues to avoid duplicates
2. Include:
   - Proxmox VE version (e.g., 8.1.3)
   - How you ran the script (web UI shell vs SSH)
   - Steps to reproduce
   - Error messages or unexpected output

### Suggesting Features

1. Check existing issues and discussions
2. Focus on features useful for Proxmox users
3. Describe the use case and proposed solution

### Submitting Code

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test on a Proxmox VE node
5. Commit with clear messages
6. Push and open a Pull Request

## Development Setup

```bash
git clone https://github.com/giovannirco/proxmark.git
cd proxmark

# Test locally (ideally on a Proxmox node)
bash client/proxmark.sh --quick --no-upload
```

## Project Structure

```
proxmark/
├── client/           # Bash benchmark script
│   └── proxmark.sh
├── server/           # TypeScript API (future)
├── web/              # Next.js web UI (future)
├── planning/         # Design documents
├── README.md
├── CONTRIBUTING.md
├── AGENTS.md
└── LICENSE
```

## Guidelines

### Bash Script

- Use `shellcheck` for linting
- Follow existing code style
- Test on Proxmox VE 7.x and 8.x
- Avoid dependencies not available in Proxmox repos

### TypeScript (Server/Web)

- Use TypeScript strict mode
- Format with Prettier
- Lint with ESLint
- Write tests for new features

## Testing

Testing on real Proxmox nodes is essential:

- [ ] Proxmox VE 8.x
- [ ] Proxmox VE 7.x
- [ ] From web UI shell
- [ ] Via SSH
- [ ] With different storage types (local, ZFS, NFS)

## Pull Request Checklist

- [ ] Tested on Proxmox VE
- [ ] Code follows project style
- [ ] Documentation updated if needed
- [ ] Commit messages are clear

## Getting Help

- Open a GitHub Discussion for questions
- Check existing issues and docs first

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for helping make Proxmark better for the Proxmox community! 🎉
