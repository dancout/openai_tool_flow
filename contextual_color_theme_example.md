# Contextual Example: Color Theme Generation from an Image

This file provides an illustrative example of how tool call steps, audits, and issues might be defined in practice.  
It is not complete or executable code. Instead, it acts as **guidance for the GitHub agent** to understand how inputs, outputs, and validations may be structured for real workflows.

---

## Example Workflow: Generate a Color Theme from an Image

**Goal:** Given an uploaded image, generate a set of base colors, validate their quality, and produce a finalized color theme.

---

### Tool Call Steps

Each step can be thought of as a structured pipeline stage.  
Inputs and outputs should be explicitly defined (even if loosely typed here).  
Audits may be applied at any step to validate the intermediate results.

#### Step 1: Extract Base Colors
- **Tool:** `propose_base_colors`
- **Inputs:**  
  - `imageUrl: string` → The uploaded image location
- **Outputs:**  
  - `baseColors: string[]` → Array of proposed base colors in hex format

- **Audits:**  
  - `NonEmptyArrayAudit` → Ensure at least one color was extracted  
  - `ColorFormatAudit` → Ensure each string is a valid hex color  

- **Issues (if audits fail):**  
  - `EmptyResultIssue` → No colors extracted  
  - `InvalidColorFormatIssue` → Colors are not valid hex codes

---

#### Step 2: Refine Colors
- **Tool:** `refine_colors`
- **Inputs:**  
  - `baseColors: string[]`
- **Outputs:**  
  - `refinedColors: string[]` → Array of improved colors (contrast adjusted, redundant removed, etc.)

- **Audits:**  
  - `DiversityAudit` → Ensure enough variation between colors  
  - `ContrastAudit` → Ensure adequate contrast ratios  

- **Issues:**  
  - `LowDiversityIssue` → Colors too similar  
  - `PoorContrastIssue` → Contrast too low

---

#### Step 3: Generate Final Theme
- **Tool:** `generate_theme`
- **Inputs:**  
  - `refinedColors: string[]`
- **Outputs:**  
  - `theme: { primary: string, secondary: string, accent: string }`

- **Audits:**  
  - `ThemeCompletenessAudit` → Ensure primary, secondary, and accent are populated  
  - `ThemeAccessibilityAudit` → Validate against accessibility standards (e.g., WCAG)

- **Issues:**  
  - `MissingThemeFieldIssue` → Theme fields not populated  
  - `AccessibilityFailureIssue` → Theme fails accessibility requirements

---

### Example Issue Representation

All issues should extend from the base `Issue` schema.  
They can be step-specific but are defined in a reusable way.

For example:

```ts
class EmptyResultIssue extends Issue {
  constructor(details: string) {
    super({ code: "EMPTY_RESULT", message: "No colors extracted", details });
  }
}

class PoorContrastIssue extends Issue {
  constructor(details: string) {
    super({ code: "POOR_CONTRAST", message: "Contrast ratio too low", details });
  }
}