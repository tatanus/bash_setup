# Pull Request Template for the Bash_setup Project

## Description

Please provide a summary of the changes made, including:
- The issue(s) fixed or the enhancement(s) added.
- Relevant motivation and context for the change.
- Any dependencies required for this update.

---

## Type of Change

Please select the type of change by marking the relevant option(s) with `[x]`:
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update (adds or modifies documentation)
- [ ] Third-party dependency update (e.g., new tools, libraries, or resources)

---

## How Has This Been Tested?

Describe the tests you ran to verify your changes, including:
1. Commands executed to validate the script's behavior.
2. Environment details:
   - Operating System and version (e.g., Ubuntu 20.04, macOS Ventura).
   - Bash version (`bash --version`).
   - Any relevant configurations or dependencies used for testing.
3. Test results:
   - Example input and output for the changes.

**Testing Checklist:**
- [ ] Local testing with various edge cases and normal inputs.
- [ ] Verified compatibility with related scripts/modules.
- [ ] Reviewed logging outputs (if applicable).

---

## Screenshots (If Applicable)

If the changes involve user-facing functionality or outputs, please include **before and after screenshots** to help reviewers understand the impact of the change.

---

## Checklist

Please complete the checklist below to ensure your PR meets the project standards:

- [ ] I have run `shellcheck` using the repository's `.shellcheckrc` file to verify linting:
  ```bash
  shellcheck --shell=bash --external-sources -x -S style -f gcc <your-script.sh>
  ```
- [ ] I have formatted all scripts using `shfmt`:
  ```bash
  shfmt -i 4 -ci -bn -kp -sr -ln bash -d .
  ```
- [ ] I have verified that my changes are consistent with the project's [Style Guide](./STYLEGUIDE.md).
- [ ] I have updated or added relevant tests (e.g., unit tests, test scripts).
- [ ] All existing tests pass successfully after my changes.
- [ ] I have added or updated documentation as needed, and linked any relevant PRs in related repositories (e.g., documentation or tools).
- [ ] I have reviewed my own code for clarity and correctness.
- [ ] I have commented on particularly complex or non-obvious parts of the code.

---

## Additional Notes

If your changes rely on external tools or third-party dependencies, please include details about:
1. Why the tool/dependency is required.
2. Links to relevant documentation or PRs in those third-party projects.

---

This PR template is designed to ensure contributions to the **bash_setup** project are clear, well-tested, and maintainable. Thank you for your contribution!

