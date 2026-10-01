# ADR-001 — Platform vs Product Ownership

Status: ACCEPTED  
Date: 2026-10-01

## Decision

Repeated transversal capabilities are classified before implementation:

- `CONSUME_SHARED`
- `DEDICATED_FOR_TEST`
- `SPECIALIZED_PLATFORM`
- `PRODUCT_OWNED`
- `REFERENCE_ONLY`

Argo CD, observability, OIDC and quality gates default to `CONSUME_SHARED`.

Business logic and product integration logic such as Angular, Spring Boot and Apache Camel remain `PRODUCT_OWNED`.

Product Kafka/PostgreSQL may stay `DEDICATED_FOR_TEST` when resilience, recovery, performance or data correctness is the subject of the proof.

## Consequence

The common platform reduces duplication without hiding the component under test or weakening reproducibility.
