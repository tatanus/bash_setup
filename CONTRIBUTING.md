# Contributing to BASH

Welcome to the **BASH** project! We're excited to have you contribute. Whether you're fixing a bug, improving documentation, or proposing a new feature, your contributions are greatly appreciated. Follow the guidelines below to ensure a smooth and productive collaboration.

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [How to Contribute](#how-to-contribute)
   - [Reporting Issues](#reporting-issues)
   - [Submitting Code Changes](#submitting-code-changes)
   - [Improving Documentation](#improving-documentation)
4. [Style Guide](#style-guide)
5. [Pull Request Process](#pull-request-process)
6. [Contact](#contact)

---

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/0/code_of_conduct/). By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainer.

---

## Getting Started

1. **Fork the repository** to your own GitHub account.
2. **Clone your fork**:
   ```bash
   git clone https://github.com/<your-username>/BASH.git
   cd BASH
   ```
3. **Set up the project**:
   - Ensure you have the latest version of Bash installed.
   - Install `shellcheck` and `shfmt`:
     ```bash
     sudo apt install shellcheck shfmt  # For Ubuntu/Debian
     ```
4. **Explore the codebase**:
   ```bash
   tree -L 2  # Displays the directory structure
   ```

---

## How to Contribute

### Reporting Issues

If you’ve found a bug or have a feature request, please open an issue on GitHub:

1. Click on **Issues**.
2. Select **New Issue**.
3. Provide a clear and concise description of the problem or feature, including:
   - Steps to reproduce (if it’s a bug).
   - Expected behavior versus actual behavior.
   - Any error messages or logs.

### Submitting Code Changes

1. **Create a new branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. **Make your changes**. Follow the [Style Guide](#style-guide).
3. **Run tests**:
   - Use `shellcheck` with the included `.shellcheckrc` file:
     ```bash
     shellcheck --shell=bash --external-sources -x -S style -f gcc <your-script.sh>
     ```
   - Format your scripts with `shfmt`:
     ```bash
     shfmt -i 4 -ci -bn -kp -sr -ln bash -d .
     ```
4. **Commit your changes**:
   ```bash
   git commit -m "Add description of your change"
   ```
5. **Push the branch**:
   ```bash
   git push origin feature/your-feature-name
   ```
6. Open a **Pull Request (PR)** on the main repository.

### Improving Documentation

Documentation improvements are highly valued! If you see errors or areas to enhance, follow the steps under "Submitting Code Changes" to update `.md` files in the repository.

---

## Style Guide

- **Shellcheck and Shfmt**:
  - Run `shellcheck` with the repository's `.shellcheckrc` file to ensure consistent linting:
    ```bash
    shellcheck --shell=bash --external-sources -x -S style -f gcc <your-script.sh>
    ```
  - Format all scripts with the following `shfmt` options:
    ```bash
    shfmt -i 4 -ci -bn -kp -sr -ln bash -d .
    ```
- **Comments**: Use the following template for functions:
  ```bash
  ###############################################################################
  # FUNCTION_NAME
  # ==============================
  # Description:
  # ------------------------------
  # Usage: FUNCTION_NAME <arg1> <arg2>
  # Returns: <expected return values>
  ###############################################################################
  ```
- **Naming**: Use descriptive, lowercase function and variable names. Use underscores for multi-word names.
- **Error Handling**: Always use `set -euo pipefail` for robust error handling.
- **Modularity**: Break larger scripts into smaller reusable modules.

---

## Pull Request Process

1. Ensure your branch is up-to-date with the `main` branch:
   ```bash
   git fetch origin
   git merge origin/main
   ```
2. Include a detailed PR description outlining:
   - What changes were made.
   - Why the changes were made.
   - Any impact on existing functionality.
3. Address PR comments promptly to keep the review process efficient.

---

## Contact

If you have any questions, feel free to reach out via:

- **Issues**: Use the [Issues](https://github.com/tatanus/BASH/issues) tab.

Thank you for contributing and helping make **BASH** better!
