# Example Context: Color Theme Generation From an Image

This file is **NOT production code**.  
It is an illustrative example designed to show how tool call steps, audits, and issues might be defined and connected.  
The GitHub Agent can use this as a reference for understanding *how and why* the workflow is structured.

---

## Example Workflow: Generate Base Colors From an Image

Imagine we have a pipeline that extracts base colors from an uploaded image.  
The workflow might consist of multiple **tool call steps**, each with defined **inputs, outputs, audits, and potential issues**.

### Step 1: Extract Colors

```yaml
step: extract_colors
tool: propose_base_colors
inputs:
  - image: <uploaded image file>
outputs:
  - colors: [ "#ff0000", "#00ff00", "#0000ff" ]
audits:
  - name: ensure_minimum_colors
    description: "Verify that at least 3 colors are extracted from the image."
    severity: "warning"
issues:
  - code: "FEW_COLORS"
    message: "Only {count} colors extracted. Expected at least 3."
step: generate_variants
tool: expand_theme_variants
inputs:
  - baseColors: <from extract_colors step>
outputs:
  - lightTheme
  - darkTheme
  - highContrastTheme
audits:
  - name: validate_contrast
    description: "Ensure generated themes meet accessibility contrast requirements."
    severity: "error"
issues:
  - code: "LOW_CONTRAST"
    message: "Generated theme does not meet WCAG contrast guidelines."
step: output_package
tool: package_themes
inputs:
  - lightTheme
  - darkTheme
  - highContrastTheme
outputs:
  - theme.json
audits: []
issues: []