# Contributing to Halo CE Dedicated Server

Thank you for your interest in contributing to the Halo CE Dedicated Server project.

## Development Workflow

1. **Fork and Branch:**
   - Create a feature branch with a descriptive name (`git checkout -b feat/arm64-support` or `fix/scoreboard-ping`).
2. **Commit Style:**
   - Use plain, descriptive commit messages adhering to Conventional Commits:
     - `feat:` for new capabilities.
     - `fix:` for bug fixes.
     - `docs:` for documentation updates.
     - `ci:` for CI/CD workflow changes.
     - `refactor:` for code improvements without behavior changes.
   - Do not include emojis in commits, pull requests, or code comments.
3. **No Secrets:**
   - Never commit tokens, passwords, private keys, or credentials.
4. **Clean Code & Testing:**
   - Before opening a PR, ensure all tests pass and documentation is updated in both English and Spanish (`README.md` and `README.es.md`).
   - Run local validation commands:
     ```sh
     # Test configuration validity
     python3 -c "import tomli; tomli.load(open('server/config.toml', 'rb'))"
     ```
5. **Netcode Compatibility:**
   - Any changes impacting network serialization, protocol definitions, or gametype packet layouts must strictly maintain compatibility with Netcode version 38.
