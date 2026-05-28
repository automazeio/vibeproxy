# PRD — vibeproxy

## Overview

`vibeproxy` is a reverse proxy service for managing API traffic, providing routing, load balancing, and middleware support.

## Goals

- HTTP/HTTPS reverse proxy
- Request routing based on rules
- Load balancing strategies
- Middleware pipeline
- Connection pooling

## Epics

### E1 — Proxy Core
- E1.1 HTTP/HTTPS proxy functionality
- E1.2 Request/response handling
- E1.3 Connection management

### E2 — Routing
- E2.1 Path-based routing
- E2.2 Header-based routing
- E2.3 Host-based routing

### E3 — Load Balancing
- E3.1 Round-robin strategy
- E3.2 Least connections strategy
- E3.3 Health-based routing

## Acceptance Criteria

- Requests are proxied correctly
- Routing rules are applied
- Load balancing distributes traffic
- Middleware transforms requests/responses
