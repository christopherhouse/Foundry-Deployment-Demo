# ADR 0001: Separate Bicep and APIOps ownership

**Status:** Accepted  
**Date:** 2026-09-22

Bicep manages APIM service infrastructure but no APIM configuration children. APIOps manages APIs, backends, named values, products, and policies.

This separation avoids competing writers and allows model infrastructure and API configuration to evolve through independent CD paths.

