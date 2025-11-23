# Axiom Hive Protocol Specification v1.0

## Overview

The Axiom Hive Protocol defines the communication contracts and operational procedures for the Guardian Hive architecture. This specification ensures provable safety, legal compliance, and auditability across all microservices.

## Core Principles

1. **Zero-Trust Architecture**: No service trusts any other by default
2. **Contract-First Design**: All inter-service communication via gRPC/protobuf contracts
3. **Immutable Audit Trail**: Every transaction is cryptographically logged
4. **Fail-Safe Defaults**: Any uncertainty results in request rejection
5. **Isolation by Design**: Inference models have zero external network access

## Service Definitions

### Service-Gateway (Apiary)

**Purpose**: Unified entry point for all user requests

**Responsibilities**:
- Authentication and authorization
- Rate limiting and DDoS protection
- Request ingestion and initial validation
- Routing to Guardian services

**gRPC Contracts**:
- `AxiomGateway.IngestRequest(Request) -> Response`
- `AxiomGateway.GetHealth() -> HealthStatus`

**Security**:
- TLS 1.3 mandatory
- JWT-based authentication
- Request size limits (max 1MB)

### Service-Guardians (Sentinels)

#### Guardian-Legal (P_AEGIS)

**Purpose**: Legal compliance and intellectual property protection

**Checks Performed**:
- ASL-1.0 license compliance
- PII (Personal Identifiable Information) detection
- Intellectual property contamination scanning
- Data privacy regulation compliance (GDPR, CCPA, etc.)

**gRPC Contracts**:
- `GuardianLegal.CheckCompliance(Request) -> ComplianceResult`

**Response Codes**:
- `COMPLIANT`: Request passes all legal checks
- `PII_DETECTED`: Personal data found
- `IP_VIOLATION`: Intellectual property contamination
- `LICENSE_VIOLATION`: ASL-1.0 terms breached

#### Guardian-Safety (P_Zero-Harm)

**Purpose**: AI safety and security validation

**Checks Performed**:
- Toxicity and harmful content analysis
- Prompt injection detection
- Adversarial attack mitigation
- Bias and fairness assessment
- Output safety validation

**gRPC Contracts**:
- `GuardianSafety.ValidatePrompt(Request) -> ValidationResult`
- `GuardianSafety.ValidateResponse(Request, Response) -> ValidationResult`

**Response Codes**:
- `SAFE`: Content passes all safety checks
- `TOXIC`: Harmful content detected
- `INJECTION`: Prompt injection attempt
- `BIASED`: Unacceptable bias levels

#### Guardian-Audit (P_Trace)

**Purpose**: Immutable transaction logging

**Responsibilities**:
- Write complete transaction lifecycle to QLDB
- Generate cryptographic hashes for verification
- Provide audit trail export functionality
- Ensure tamper-proof record keeping

**Logged Data**:
- Original prompt
- Legal check results
- Safety check results (pre/post)
- Inference response
- Timestamps and service versions
- Cryptographic signatures

**gRPC Contracts**:
- `GuardianAudit.LogTransaction(Transaction) -> LogResult`
- `GuardianAudit.ExportAuditTrail(Query) -> AuditData`

### Service-Drones (Inference Fleet)

**Purpose**: Isolated AI model execution

**Characteristics**:
- No external network access
- Receive requests only from Guardian-Safety
- Send responses only to Guardian-Safety
- Hot-swappable model architecture

**Supported Models**:
- Llama series
- GPT series
- Claude/Anthropic models
- Custom/proprietary models

**gRPC Contracts**:
- `DroneFleet.Infer(Request) -> Response`

## Communication Protocol

### Request Flow

1. **Ingress**: User request → Service-Gateway
2. **Legal Check**: Service-Gateway → Guardian-Legal
3. **Safety Check**: Guardian-Legal → Guardian-Safety (if compliant)
4. **Inference**: Guardian-Safety → Service-Drones
5. **Response Validation**: Service-Drones → Guardian-Safety
6. **Audit Logging**: All steps → Guardian-Audit
7. **Egress**: Guardian-Safety → Service-Gateway → User

### Error Handling

- Any service failure results in request rejection
- Errors are logged to audit trail
- Users receive sanitized error messages
- Full error details available in audit logs

### Timeouts

- Inter-service calls: 30 seconds
- Total request processing: 120 seconds
- Audit logging: 10 seconds

## Data Structures

### Request
```protobuf
message Request {
  string id = 1;
  string prompt = 2;
  map<string, string> metadata = 3;
  google.protobuf.Timestamp timestamp = 4;
}
```

### Response
```protobuf
message Response {
  string id = 1;
  string content = 2;
  ValidationResult validation = 3;
  google.protobuf.Timestamp timestamp = 4;
}
```

### Transaction
```protobuf
message Transaction {
  Request original_request = 1;
  ComplianceResult legal_check = 2;
  ValidationResult safety_check_pre = 3;
  Response inference_response = 4;
  ValidationResult safety_check_post = 5;
  string audit_hash = 6;
  google.protobuf.Timestamp completed_at = 7;
}
```

## Security Considerations

- All gRPC communication over mTLS
- Service mesh with mutual authentication
- Regular security audits and penetration testing
- Automated vulnerability scanning in CI/CD

## Compliance

This protocol is designed to comply with:
- ASL-1.0 Sovereign License
- EU AI Act (proposed)
- NIST AI Risk Management Framework
- ISO 42001 AI Management Systems

## Version History

- **v1.0** (2025-11-23): Initial protocol specification
  - Guardian microservice architecture
  - QLDB-based immutable audit
  - gRPC contract-first design

---

**This specification establishes the technical foundation for provably safe and legal AI systems.**
