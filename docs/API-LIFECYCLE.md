# Public API lifecycle

The LibeR packages are pre-1.0, but their public surface is no longer treated
as one undifferentiated compatibility promise. `api-lifecycle.json` classifies
every exported symbol when `tools/api-inventory.R` runs:

- **stable-contract**: cross-package or commonly scripted interfaces whose
  compatibility is maintained within a consolidated release line;
- **evolving**: supported public pre-1.0 interfaces whose changes require NEWS
  entries and migration guidance;
- **experimental**: explicitly research-only families that may change as their
  numerical contract matures;
- **deprecated**: transitional interfaces with a documented replacement and
  removal target.

The generated CSV/JSON inventory is release evidence. Configuration is checked
against each package's actual NAMESPACE, so renamed or removed classified
symbols fail the inventory build instead of silently disappearing. Feature
validation status remains separate and is reported by
`LibeRation::nm_support_matrix()`.
