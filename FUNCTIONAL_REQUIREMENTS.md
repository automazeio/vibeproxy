# Functional Requirements — vibeproxy

## FR-PROXY: Proxy Core

### FR-PROXY-001: HTTP Proxy
The system SHALL proxy HTTP requests to configured backends.
**Traces to:** E1.1
**Code Location:** `Sources/`

### FR-PROXY-002: Request Handling
The system SHALL forward request headers, body, and method.
**Traces to:** E1.2
**Code Location:** `Sources/`

### FR-PROXY-003: Connection Pooling
The system SHALL pool connections to backends for reuse.
**Traces to:** E1.3
**Code Location:** `Sources/`

## FR-ROUTE: Routing

### FR-ROUTE-001: Path Routing
The system SHALL route requests based on URL path patterns.
**Traces to:** E2.1
**Code Location:** `Sources/`

### FR-ROUTE-002: Header Routing
The system SHALL route requests based on header values.
**Traces to:** E2.2
**Code Location:** `Sources/`

### FR-ROUTE-003: Host Routing
The system SHALL route requests based on Host header.
**Traces to:** E2.3
**Code Location:** `Sources/`

## FR-LB: Load Balancing

### FR-LB-001: Round Robin
The system SHALL distribute requests in round-robin order.
**Traces to:** E3.1
**Code Location:** `Sources/`

### FR-LB-002: Least Connections
The system SHALL route to backend with fewest active connections.
**Traces to:** E3.2
**Code Location:** `Sources/`

### FR-LB-003: Health Routing
The system SHALL exclude unhealthy backends from routing.
**Traces to:** E3.3
**Code Location:** `Sources/`
