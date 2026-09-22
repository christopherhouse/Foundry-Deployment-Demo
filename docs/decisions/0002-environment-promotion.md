# ADR 0002: Promote one reviewed commit

**Status:** Accepted  
**Date:** 2026-09-22

Changes deploy to dev first. Production deploys the same commit and shared artifacts after GitHub Environment approval, with only reviewed parameter or override values varying by environment.

This preserves auditability and prevents rebuilding or editing release content between environments.

