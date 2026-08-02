# Markdown Linting with rumdl

This document describes the markdown linting setup for the IAC repo.

## Overview

All markdown files in the IAC repo are linted and auto-formatted using
[`rumdl`](https://github.com/rvben/rumdl), a fast markdown linter
written in Rust.

## Setup

### Configuration Files

- `.rumdl.toml` - rumdl configuration with rules and exclusions
- `.pre-commit-config.yaml` - pre-commit hook configuration

### Pre-commit Hook

The pre-commit hook runs automatically on every `git commit`:

```bash
rumdl --config .rumdl.toml fmt
```

This will:

- Auto-fix formatting issues (line breaks, spacing, etc.)
- Report issues that need manual attention

## Rules

### MD013 - Line Length

- Maximum: 160 characters
- Applies to: Regular text (not code blocks or tables)
- Action: rumdl will wrap long lines automatically

### MD036 - Emphasis Instead of Heading

- Status: Disabled
- Reason: Some docs intentionally use emphasis for emphasis

### MD041 - First Line Should Be Heading

- Status: Disabled
- Reason: Some files (like .env.example) don't need headings

### MD012 - Consecutive Blank Lines

- Maximum: 2 consecutive blank lines
- Action: Auto-reduced to 2

### MD007 - List Indentation

- Indent: 2 spaces
- Action: Auto-corrected

### MD022 - Blank Lines Around Headings

- Required: 1 blank line before and after headings
- Action: Auto-inserted

### MD033 - Inline HTML

- Allowed elements: `code`, `kbd`, `pre`, `samp`, `var`
- Action: Reports disallowed HTML elements

## Usage

### Manual Linting

Check all markdown files:

```bash
rumdl --config .rumdl.toml check .
```

Auto-fix all markdown files:

```bash
rumdl --config .rumdl.toml fmt .
```

### On Commit

Just commit normally - the pre-commit hook will:

1. Run rumdl fmt on all modified markdown files
2. Auto-fix what it can
3. Report issues that need manual attention
4. If issues remain, the commit will fail and you'll need to fix them

### Excluded Files

The following are excluded from linting:

- `.gitignore`, `.pre-commit-config.yaml`
- `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
- `Cargo.lock`
- `CHANGELOG.md` (auto-generated)
- `tests/**/*.md`, `__tests__/**/*.md`

## Common Issues

### Long Lines

If you have lines longer than 160 characters, rumdl will:

1. Try to wrap them automatically
2. If wrapping isn't possible, report the issue

**Solution:** Manually break long lines into shorter ones.

### Code Examples

Long code examples should be in fenced code blocks:

```markdown
Here's an example:

```bash
long-command-with-many-arguments --flag1 --flag2 --flag3
```

This won't trigger MD013.

```text

### URLs

Long URLs should be in angle brackets or wrapped:

```markdown
See [documentation](<https://very-long-url.com/with-many/segments>)
```

## Troubleshooting

### Pre-commit Hook Not Running

1. Ensure pre-commit is installed:

   ```bash
   python -m pre_commit install
   ```

2. Check the hook is present:

   ```bash
   ls -la .git/hooks/pre-commit
   ```

3. Test manually:

   ```bash
   pre-commit run --all-files
   ```

### rumdl Command Not Found

1. Ensure rumdl is installed:

   ```bash
   which rumdl
   ```

2. If not installed, install it:

   ```bash
   cargo install rumdl
   ```

### Configuration Errors

If you see "Unknown option" warnings:

- Check the rumdl version compatibility
- Review `.rumdl.toml` syntax
- Refer to [rumdl documentation](https://github.com/rvben/rumdl)

## Best Practices

1. **Keep lines under 160 characters** when possible
2. **Use code blocks** for long commands or examples
3. **Break long URLs** with angle brackets or links
4. **Review pre-commit output** before fixing manually
5. **Run `rumdl fmt` locally** before committing to catch issues early

## References

- [rumdl GitHub](https://github.com/rvben/rumdl)
- [rumdl Documentation](https://github.com/rvben/rumdl#readme)
- [Markdown Rules Reference](https://github.com/DavidAnson/markdownlint/blob/master/doc/Rules.md)
