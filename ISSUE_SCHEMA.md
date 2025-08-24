# Issue Schema

The `Issue` class follows a **strict but extensible schema**.  
- Strict: certain fields are required.  
- Extensible: projects may extend the class with new fields.  
- The pipeline never strips fields — it always forwards the full object by serializing with `toJson()`.

---

## Required Fields
```json
{
  "id": "string - unique identifier",
  "severity": "enum: [low, medium, high, critical]",
  "description": "string - human-readable description of the issue",
  "context": "object - structured metadata about where/why issue occurred",
  "suggestions": ["string - list of suggested resolutions"]
}