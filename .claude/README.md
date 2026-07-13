# Claude Code scope enforcement

`.claude/settings.json` mirrors the writable, forbidden, and review-required
boundaries in the root `AGENTS.md`. The prose rule remains authoritative for all
agents; this file gives Claude Code the same boundary mechanically.

When `AGENTS.md` scope changes, update both files in the same slice. Deny rules
must continue to cover signing material, credentials, and build output; push and
destructive operations remain review-required.
