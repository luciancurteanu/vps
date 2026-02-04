# Copilot Instructions:

## 1. Folder Path Management
Copilot should remember and recall frequently used file paths:
  - Ensure that the documentation is always updated ex: "README.md" and everything else related to it.
  - Ensure that when i click Apply button from Editor chat, it will auto update the file automatically to the right file path location.
  - When you ask to provide the content of files do a auto scan to find them.
  - When i ask to read the log or check this log, read the log from beginning for any issues, including errors and warnings.
  - When you ask for a specific file, ensure that you autoscan the file to find the right file path.
  - When you ask to provide the content of files do a auto scan to find them.
  - Add test or temp files into temp folder.

### 2. Automated File Updates
When generating code:
- I give you permission to access ssh admin@localhost with sudo without password for file operations.
- I also grant explicit permission for Copilot to initiate SSH connections to `localhost` and run the necessary `sudo` commands on my behalf when performing workspace modifications, so you may connect and apply changes without me running the commands manually.
 - I also grant explicit permission for Copilot to initiate SSH connections to `localhost` and run the necessary `sudo` commands on my behalf when performing workspace modifications, so you may connect and apply changes without me running the commands manually.
 - I authorize Copilot to automatically execute diagnostic or maintenance commands on `localhost` over SSH (using `sudo`) when needed, without requiring me to run them interactively each time.
- Clearly indicate the file that needs modification.
- Display the corresponding file path.
- Ensure that new code is inserted into the correct section of the file without overwriting unrelated parts.
- When modifying an existing function, append or replace only the relevant logic.
- Do not restart the file from the beginning unless explicitly requested.
- Maintain the structure and indentation of the existing file.
- Ensure modifications apply correctly across **all file types**.
- **Always display the file path where the generated code should be applied.**
- If multiple files need modification, list them separately and specify the changes for each.
- **Specify the exact location within the file** where modifications should be applied, using contextual markers such as function names, component sections, or code comments.
- Ensure that code changes remain within reasonable length limits to avoid exceeding response constraints.

## 3. Code Review & Optimization
When reviewing a file or folder:
- **General File Checks:**
  - Ensure code follows best practices and standards.
  - Detect redundancy or duplication.
  - Identify opportunities for refactoring and improvement.
  - Provide structured reports highlighting issues and improvement suggestions.
  - Ensure documentation and comments are included where needed.
  - If the response exceeds output limits, provide updates in batches.
  - **Explicitly mention the file being reviewed and the recommended changes per file.**
  - **Provide suggestions for maintaining consistent formatting and indentation across the codebase.**

## 4. AI-Assisted Refactoring
### Goals:
- Suggest improvements to enhance code maintainability.
- Identify redundant code and propose refactored solutions.
- Ensure refactoring does not impact existing functionality.
- Ensure that each update also updates the documentation if need it.
### Procedure:
- Provide explanations for proposed improvements.
- Break large tasks into manageable steps, requiring user approval before applying changes.
- Don't generate code until I ask for it.
- All terminal commands for VS Code should use PowerShell syntax, not bash. When suggesting commands to run in the VS Code terminal, ensure they are PowerShell compatible.