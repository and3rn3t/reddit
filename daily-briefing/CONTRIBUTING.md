# Contributing to Daily Briefing

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/daily-briefing.git`
3. Install pre-commit hooks: `pip install pre-commit && pre-commit install`
4. Create a branch: `git checkout -b feature/your-feature`

## Development Setup

### Requirements

- **bash** (4.0+)
- **jq** — JSON processing
- **curl** — HTTP requests
- **yq** (optional) — YAML parsing, install with `brew install yq` or `pip install yq`
- **shellcheck** — Shell script linting

### Running Scripts

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Generate a sample briefing
./scripts/generate-sample.sh output.md

# Generate with all features
./scripts/generate-briefing.sh --verbose output.md

# Validate feeds
./scripts/validate-feeds.sh

# Run with custom config
./scripts/generate-briefing.sh --config config.local.yaml
```

### Running Linters

```bash
# Shell scripts
shellcheck -x scripts/*.sh

# YAML validation
python3 -c "import yaml; yaml.safe_load(open('config.yaml'))"

# JSON validation
jq '.' evals/evals.json > /dev/null
```

## Making Changes

### Code Style

- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `set -euo pipefail` in all scripts
- Add comments for non-obvious logic
- Use meaningful variable names
- Quote all variables: `"$var"` not `$var`

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add BBC RSS feed support
fix: handle rate limiting gracefully
docs: update README with new options
test: add eval for JSON output format
chore: update pre-commit hooks
```

### Adding New Features

1. **New RSS Feed**: Add to `config.yaml` under `news.feeds`
2. **New Output Format**: Add formatter function in `generate-briefing.sh`
3. **New Filter**: Add to config and implement in `filter_reddit_items()`
4. **New Eval Case**: Add to `evals/evals.json` with appropriate category

## Pull Request Process

1. Ensure all pre-commit hooks pass
2. Update `CHANGELOG.md` with your changes
3. Update `README.md` if adding user-facing features
4. Add/update evals in `evals/evals.json` if changing behavior
5. Test your changes manually:
   ```bash
   ./scripts/generate-briefing.sh --verbose /tmp/test.md
   cat /tmp/test.md
   ```
6. Submit PR with clear description of changes

## Reporting Issues

When reporting bugs, please include:

- OS and shell version (`bash --version`)
- Full error output (with `LOG_LEVEL=DEBUG`)
- Steps to reproduce
- Expected vs actual behavior

## Adding Evals

Evaluation cases help ensure the skill works correctly. Add new cases to `evals/evals.json`:

```json
{
  "id": 21,
  "category": "your-category",
  "prompt": "User prompt that triggers behavior",
  "expected_output": "Description of expected output",
  "expected_behavior": [
    "Specific behavior point 1",
    "Specific behavior point 2"
  ]
}
```

Categories: `basic`, `customization`, `trigger-recognition`, `partial-content`, `filtering`, `specific-subreddits`, `error-handling`, `edge-case`, `output-format`, `deduplication`, `caching`, `time-filtering`, `multiple-sources`, `negative`

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
