# Security Policy

## Supported Versions

The following versions of the **BASH** project are actively supported for security updates:

| Version | Supported          |
|---------|--------------------|
| `v1.x`  | ✅ Fully supported |
| `<v1.0` | ❌ No longer supported |

Please ensure you're using the latest version of the project to receive the most up-to-date security fixes.

---

## Reporting a Vulnerability

If you discover a security vulnerability in the **BASH** project, please follow the steps below:

1. **Do not disclose the vulnerability publicly**.
   - Security issues should be reported directly to the maintainers to ensure a fix is developed before public disclosure.
3. **Wait for acknowledgment**:
   - You should receive an acknowledgment within **3 business days**. If you do not, please follow up to ensure the report has been received.

---

## Vulnerability Disclosure

The **BASH** project adheres to the following vulnerability disclosure timeline:

1. Upon receiving a report, we will:
   - Confirm the vulnerability.
   - Investigate and develop a fix or mitigation.
2. Once a fix is ready, we will:
   - Notify the reporter.
   - Prepare a patch or update for the project.
   - Publish the fix in a new release.
3. Public disclosure:
   - The vulnerability will be disclosed publicly along with the patch after a reasonable grace period to allow users to update.

---

## Security Best Practices for Contributors

Contributors are encouraged to follow these best practices to ensure the security of the **BASH** project:

1. **Validate Inputs**:
   - Sanitize and validate all user inputs to prevent command injection or other vulnerabilities.
2. **Follow the Principle of Least Privilege**:
   - Avoid running scripts with unnecessary privileges.
3. **Secure Environment Variables**:
   - Do not hardcode sensitive information (e.g., credentials, API keys). Use environment variables instead.
4. **Static Analysis**:
   - Run `shellcheck` and `shfmt` to identify potential security issues.
   - Example:
     ```bash
     shellcheck --shell=bash --external-sources -x -S style -f gcc <your-script.sh>
     shfmt -i 4 -ci -bn -kp -sr -ln bash -d .
     ```
5. **Encrypt Sensitive Data**:
   - Ensure any sensitive data stored in files is encrypted or otherwise protected.

---

## Contact

For additional security concerns or questions, please reach out to:
- GitHub Issues: Use the [Issues](https://github.com/tatanus/BASH/issues) tab (for non-sensitive issues).

---
