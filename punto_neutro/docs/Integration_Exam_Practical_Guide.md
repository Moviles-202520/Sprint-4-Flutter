# Integration Exam: Practical Decision Guide
## 100% Actionable Content for Exam Success

---

## PART 1: DECISION FRAMEWORKS — WHEN TO USE WHAT

### 1.1 Integration Pattern Selection Matrix

**Use this table to justify your choice in exams:**

| Scenario | Best Choice | Why | Alternative |
|----------|------------|-----|-------------|
| Real-time updates needed across services | **Event Streaming (Kafka)** | Low latency, multiple consumers, replay capability | WebSockets if simple |
| User clicks button, needs immediate response | **Synchronous API (REST)** | User waiting, needs confirmation | Async if can show "processing" |
| Nightly data warehouse load | **Batch ETL** | Large volumes, no real-time need, resource optimization | Streaming if near-real-time needed |
| Database changes must propagate immediately | **CDC (Change Data Capture)** | Captures all changes, low overhead on source | Triggers if simple |
| 1000s of microservices need to communicate | **Event-Driven (EDA)** | Loose coupling, scalability | API mesh gets complex |
| Legacy system has no APIs | **ETL or File-based** | No other option | RPA if UI automation needed |
| Need audit trail of all state changes | **Event Sourcing** | Complete history, replay, debugging | Regular DB + audit table |
| Third-party SaaS integration | **REST API** | Standard, documented, rate-limited | Webhooks if they offer |
| IoT devices sending sensor data | **MQTT or Kafka** | Lightweight, handles intermittent connections | HTTP if always connected |
| B2B partner integration | **EDI or API Gateway** | Standards-based, partner requirements | Managed file transfer |

---

### 1.2 Synchronous vs Asynchronous — The Decision Tree

```
START: Does the client need an immediate response?
  │
  ├─ YES: Is the response time < 3 seconds?
  │   │
  │   ├─ YES: Use SYNCHRONOUS (REST API, gRPC)
  │   │       Example: Login, search, read operations
  │   │
  │   └─ NO: Use ASYNC with callback
  │           Example: Video processing, report generation
  │
  └─ NO: Can client check status later?
      │
      ├─ YES: Use ASYNCHRONOUS (Message Queue, Events)
      │       Example: Order processing, email sending
      │
      └─ NO: Use WebSocket or SSE
              Example: Live chat, stock prices, notifications
```

**Exam Tip:** If question says "user waits for result" → Synchronous. If "process in background" → Asynchronous.

---

### 1.3 Orchestration vs Choreography

**When to use Orchestration (Central Controller):**
```
Orchestrator (e.g., Workflow Engine)
     |
     ├──> Service A (execute step 1)
     ├──> Service B (execute step 2)
     ├──> Service C (execute step 3)
     └──> Service D (execute step 4)
```

✅ **Use when:**
- Complex business process with many steps
- Need central visibility and control
- Conditional logic and exception handling
- Rollback/compensation needed
- Example: Order fulfillment (inventory → payment → shipping → notification)

**When to use Choreography (Distributed):**
```
Service A ──[Event]──> Message Broker ──> Service B
                             │
                             ├──> Service C
                             └──> Service D
```

✅ **Use when:**
- Services are independent
- No central point of failure desired
- High scalability needed
- Loose coupling priority
- Example: User registration (send email, update analytics, create profile)

**Exam Answer Template:**
"I choose **[orchestration/choreography]** because:
1. [Control/Autonomy] is priority
2. [Simple/Complex] workflow
3. [Central visibility/Scalability] is needed"

---

### 1.4 API vs Events vs Streaming — Quick Decision

```
Question: How do systems communicate?

Option 1: REST API (Synchronous)
  When: Request-response, immediate result, low volume
  Example: GET /users/123, POST /orders
  Pros: Simple, standard, easy debugging
  Cons: Coupling, point-to-point, no replay

Option 2: Events (Message Queue)
  When: Async processing, fire-and-forget, decoupling
  Example: OrderPlaced event → InventoryService consumes
  Pros: Loose coupling, scalability, retry
  Cons: Eventual consistency, harder debugging

Option 3: Event Streaming (Kafka)
  When: High volume, multiple consumers, replay, real-time
  Example: Click stream, IoT sensors, CDC
  Pros: Durability, multiple consumers, replay history
  Cons: Complexity, operational overhead

Option 4: Batch/ETL
  When: Large datasets, nightly loads, analytics
  Example: Daily sales report, data warehouse sync
  Pros: Efficient for bulk, simple scheduling
  Cons: Not real-time, latency hours/days
```

**Exam Shortcut:**
- "Real-time + multiple consumers" → **Kafka**
- "User waiting for response" → **REST API**
- "Background task, no rush" → **Message Queue**
- "Millions of records overnight" → **Batch ETL**

---

## PART 2: DESIGNING AN INTEGRATION FLOW (EXAM FORMAT)

### 2.1 Step-by-Step Integration Design Process

**Exam Question Format:** "Design an integration for [scenario]. Justify your choices."

**Your Answer Structure (always follow this):**

#### Step 1: Identify Requirements
```
Functional:
- What data moves from A to B?
- What triggers the integration?
- What's the expected frequency?

Non-Functional:
- Latency requirement (real-time, near-real-time, batch)?
- Volume (requests/sec, records/day)?
- Availability (24/7, business hours)?
- Data consistency (strong, eventual)?
```

#### Step 2: Choose Integration Style
```
Based on requirements → Select pattern from matrix (Section 1.1)
Document: "I choose [pattern] because [requirement] demands [capability]"
```

#### Step 3: Design the Flow (Draw ASCII Diagram)
```
[Source System] → [Integration Layer] → [Target System]
      ↓                    ↓                   ↓
   (Trigger)          (Transform)         (Consume)
```

#### Step 4: Handle Errors and Edge Cases
```
- Retry strategy (exponential backoff)
- Dead letter queue (DLQ)
- Idempotency (de-duplication)
- Monitoring and alerts
```

#### Step 5: Security and Governance
```
- Authentication (OAuth, API Key)
- Encryption (TLS in-transit, encryption at-rest)
- Rate limiting
- Audit logging
```

---

### 2.2 Complete Exam Example: E-Commerce Order Processing

**Exam Question:**
"Design an integration flow for an e-commerce platform where:
- User places order on website
- Inventory must be checked
- Payment must be processed
- Shipping label must be generated
- User receives email confirmation
Justify all decisions."

**Your Complete Answer:**

#### Requirements Analysis
```
Functional:
- Order placement triggers workflow
- 4 downstream services: Inventory, Payment, Shipping, Notification
- All steps must complete for order success

Non-Functional:
- User waits max 5 seconds for confirmation
- 1000 orders/hour peak
- 99.9% availability
- Financial transactions require strong consistency
```

#### Integration Pattern: **Orchestration with Saga Pattern**

**Justification:**
"I choose orchestration because:
1. Complex multi-step workflow requires central coordination
2. Need compensating transactions if payment fails (rollback inventory)
3. User waits for confirmation (synchronous response)
4. Clear audit trail needed for orders"

#### Architecture Diagram
```
┌──────────────┐
│   Web App    │
└──────┬───────┘
       │ POST /orders
       ▼
┌─────────────────────────────────────────┐
│      Order Orchestrator Service         │
│   (Workflow Engine: Temporal/Camunda)   │
└──┬───┬───┬───┬────────────────────────┘
   │   │   │   │
   │   │   │   └──────────────┐
   │   │   │                  │
   ▼   ▼   ▼   ▼              ▼
┌─────┐ ┌──────┐ ┌────────┐ ┌──────────┐
│Inven│ │Paymt │ │Shipping│ │Notificat.│
│tory │ │      │ │        │ │Service   │
└─────┘ └──────┘ └────────┘ └──────────┘
```

#### Detailed Flow with Saga Compensation
```
Step 1: Reserve Inventory
  → Success: Continue
  → Failure: Return error to user

Step 2: Process Payment
  → Success: Continue
  → Failure: COMPENSATE → Release inventory → Return error

Step 3: Create Shipping Label
  → Success: Continue
  → Failure: COMPENSATE → Refund payment → Release inventory → Return error

Step 4: Send Notification
  → Success: Order complete
  → Failure: Log error, retry async (not blocking)

Each step is synchronous (user waits) except notification (fire-and-forget)
```

#### Communication Protocols
```
Orchestrator → Services: Synchronous REST API
  - POST /inventory/reserve
  - POST /payment/charge
  - POST /shipping/create-label
  - POST /notification/send (async queue internally)

Why REST? Need immediate response, low volume per request, standard protocol
```

#### Error Handling
```
1. Retry Strategy:
   - Transient failures (network): 3 retries with exponential backoff (1s, 2s, 4s)
   - Business failures (insufficient inventory): No retry, return error immediately

2. Timeout Configuration:
   - Inventory check: 2s timeout
   - Payment processing: 5s timeout
   - Shipping label: 3s timeout
   - Total max: 12s (within 15s user tolerance)

3. Idempotency:
   - Include idempotency key (order_id) in all requests
   - Payment service de-duplicates using order_id
   - Prevents double-charging on retry

4. Dead Letter Queue (DLQ):
   - Failed notifications go to DLQ
   - Separate worker retries every 5 minutes
```

#### Security
```
1. Authentication: API Gateway validates JWT token from web app
2. Service-to-Service: mTLS or API keys
3. PCI Compliance: Payment service is PCI-DSS certified, tokens used (no raw cards)
4. Encryption: TLS 1.3 for all communication
5. Rate Limiting: 100 req/sec per user to prevent abuse
```

#### Monitoring
```
Metrics:
- Order success rate (target: 99%)
- Average order processing time (target: < 5s)
- Error rate by service

Alerts:
- If inventory service latency > 3s for 5 minutes → PagerDuty
- If payment failure rate > 5% → Slack alert
- If any step fails → Log to Elasticsearch, visualize in Kibana

Distributed Tracing:
- OpenTelemetry trace ID propagates through all services
- Jaeger UI for debugging failed orders
```

#### Scalability
```
- Orchestrator: Horizontally scaled (5 instances), stateless
- Services: Auto-scale based on CPU (min 2, max 10 instances each)
- Database: Connection pooling, read replicas for inventory checks
```

**Exam Scoring:** This answer covers requirements (5pts), pattern justification (10pts), diagram (5pts), error handling (10pts), security (5pts), monitoring (5pts) = 40/40 points.

---

## PART 3: ARCHITECTURAL JUSTIFICATIONS (EXAM TEMPLATES)

### 3.1 How to Justify API Choice

**Template:**
"I recommend **[REST/GraphQL/gRPC/SOAP]** because:

1. **Client Type:** [Web/Mobile/Internal Service]
   - REST: Universal compatibility, caching, stateless
   - GraphQL: Flexible queries, reduce over-fetching (mobile)
   - gRPC: High performance, binary protocol (internal services)
   - SOAP: Legacy enterprise, WS-Security standards

2. **Data Requirements:** [Fixed/Flexible/Large Payloads]
   - REST: Fixed resources, standard CRUD
   - GraphQL: Client specifies exact fields
   - gRPC: Streaming, large data transfers

3. **Performance:** [Latency requirements]
   - gRPC: 50% less latency than REST (binary, HTTP/2)
   - REST: Sufficient for < 100ms requirement

4. **Ecosystem:** [Documentation, tooling]
   - REST: OpenAPI, Swagger, mature ecosystem"

**Example Exam Answer:**
"I choose **GraphQL** for the mobile app API because:
1. Mobile clients have limited bandwidth (reduce over-fetching)
2. iOS and Android apps need different fields (flexibility)
3. Single endpoint simplifies mobile development
4. GraphQL playground provides easy testing"

---

### 3.2 How to Justify Message Broker vs API

**Decision Matrix:**

| Criterion | REST API | Message Broker |
|-----------|----------|----------------|
| **Coupling** | Tight (direct call) | Loose (indirect via broker) |
| **Response** | Synchronous (wait) | Asynchronous (fire-forget) |
| **Scalability** | Limited (point-to-point) | High (multiple consumers) |
| **Reliability** | Caller handles retry | Broker handles retry/DLQ |
| **Use Case** | Read data, user waits | Process in background, events |

**Exam Template:**
"I choose **[API/Message Broker]** because:
- Coupling requirement: [Tight/Loose]
- Response time: [Immediate/Can wait]
- Number of consumers: [One/Many]
- Reliability: [Client retries/Broker guarantees]"

**Example:**
"I choose **RabbitMQ message broker** because:
1. Order placement should not wait for email sending (loose coupling)
2. Multiple consumers need order events (inventory, analytics, CRM)
3. Broker guarantees at-least-once delivery with acknowledgments
4. Scales horizontally to handle 10,000 orders/hour"

---

### 3.3 How to Justify Kafka vs RabbitMQ

**Quick Decision:**

```
Choose Kafka when:
✓ Need to replay events (audit, debugging)
✓ Multiple consumers need same data
✓ High throughput (millions/sec)
✓ Long-term event storage (days/weeks)
Example: Click stream, IoT, CDC

Choose RabbitMQ when:
✓ Traditional message queue semantics
✓ Complex routing (topic, fanout, headers)
✓ Message priority and TTL
✓ Lower operational complexity
Example: Task queues, RPC, job processing
```

**Exam Template:**
"I choose **[Kafka/RabbitMQ]** because:
1. [Replay/No replay] requirement
2. [High/Medium] throughput ([X] messages/sec)
3. [Multiple/Single] consumer patterns
4. [Event log/Message queue] semantics"

**Example Answer:**
"I choose **Kafka** for CDC (Change Data Capture) because:
1. Need to replay database changes for new microservices (replay capability)
2. 100,000 DB updates/sec (high throughput)
3. 5 microservices consume same CDC stream (multiple consumers)
4. Store events for 7 days for debugging (retention policy)"

---

### 3.4 How to Justify Batch vs Streaming

**Decision Tree:**
```
Q: What's the acceptable data freshness?
│
├─ < 1 second → Real-time Streaming (Kafka, Flink)
│
├─ 1-60 seconds → Near-real-time Streaming (micro-batching)
│
├─ 1-60 minutes → Mini-batch (scheduled every 15 min)
│
└─ Hours/Days → Batch ETL (nightly, weekly)
```

**Cost vs Latency Trade-off:**
```
Batch ETL:     $$    (cheap, simple)
Micro-batch:   $$$   (moderate complexity)
Streaming:     $$$$$  (expensive, complex ops)

Choose lowest cost that meets latency SLA
```

**Exam Template:**
"I choose **[Batch/Streaming]** because:
1. Data freshness requirement: [X hours/minutes/seconds]
2. Volume: [X GB/TB per day]
3. Complexity tolerance: [Simple/Complex]
4. Budget: [Limited/Generous]"

**Example:**
"I choose **batch ETL** (nightly at 2 AM) because:
1. Dashboard refreshes once per day (24-hour freshness acceptable)
2. 500 GB data volume (efficient in bulk)
3. Simple Apache Airflow DAG (low operational overhead)
4. Cost: $200/month vs $2000/month for streaming"

---

## PART 4: COMMON EXAM SCENARIOS — SOLVED

### 4.1 Scenario: Microservices Communication

**Question:** "You have 10 microservices that need to share data. How do you integrate them?"

**Answer Structure:**

**Option 1: API Gateway + REST APIs (Synchronous)**
```
    ┌────────────────┐
    │  API Gateway   │
    └────────┬───────┘
             │
    ┌────────┼────────┐
    │        │        │
    ▼        ▼        ▼
 ┌─────┐ ┌─────┐ ┌─────┐
 │Svc A│ │Svc B│ │Svc C│
 └─────┘ └─────┘ └─────┘
```

**Use when:**
- Services expose read operations
- External clients need unified API
- Request-response pattern

**Option 2: Event-Driven with Message Broker (Asynchronous)**
```
 ┌─────┐      ┌─────────────┐      ┌─────┐
 │Svc A│─────>│Event Broker │─────>│Svc B│
 └─────┘      │  (Kafka)    │      └─────┘
              └──────┬──────┘
                     │
                     └────────────> ┌─────┐
                                    │Svc C│
                                    └─────┘
```

**Use when:**
- Services react to state changes
- Loose coupling desired
- Multiple consumers per event

**Best Practice (Hybrid):**
```
External → API Gateway → Sync APIs (reads)
Internal → Event Bus → Async events (writes/state changes)
```

**Exam Answer:**
"I use **hybrid approach**:
1. API Gateway for client requests (REST for queries)
2. Kafka for inter-service events (state changes)
3. Rationale: Decouples services, scales independently, clear read/write separation"

---

### 4.2 Scenario: Legacy System Integration

**Question:** "Integrate a 20-year-old mainframe with no APIs into your cloud platform."

**Options Analysis:**

**Option 1: API Facade / Wrapper**
```
┌──────────┐     ┌─────────────┐     ┌──────────┐
│ Mainframe│────>│ Facade API  │────>│Cloud Apps│
│ (COBOL)  │     │(translates) │     │          │
└──────────┘     └─────────────┘     └──────────┘
```
**Pros:** Clean interface, isolates complexity  
**Cons:** Development effort, another service to maintain  
**Use when:** Mainframe has batch export or stored procedures

**Option 2: File-Based ETL**
```
┌──────────┐  Nightly    ┌─────────┐   Load   ┌──────────┐
│ Mainframe│──CSV────────>│  ETL    │─────────>│Data Lake │
│          │  at 2AM     │(Airflow)│          │          │
└──────────┘              └─────────┘          └──────────┘
```
**Pros:** Simple, proven, low risk  
**Cons:** Not real-time, file transfer overhead  
**Use when:** Data freshness > 24 hours acceptable

**Option 3: Change Data Capture (CDC)**
```
┌──────────┐    ┌──────────┐    ┌────────┐    ┌──────────┐
│Mainframe │───>│CDC Agent │───>│ Kafka  │───>│Cloud Apps│
│ DB2/IMS  │    │(Debezium)│    │        │    │          │
└──────────┘    └──────────┘    └────────┘    └──────────┘
```
**Pros:** Real-time, event-driven, minimal mainframe changes  
**Cons:** Requires DB access, complexity  
**Use when:** Near-real-time needed, DB accessible

**Exam Answer Template:**
"I choose **[option]** because:
1. Latency requirement: [real-time/batch]
2. Mainframe capabilities: [API/DB access/File export]
3. Risk tolerance: [Low → File, High → CDC]
4. Budget: [Limited → File, Generous → CDC]"

---

### 4.3 Scenario: High-Volume Transaction Processing

**Question:** "Process 1 million payment transactions per day. Design integration."

**Answer:**

**Architecture:**
```
┌─────────┐    ┌────────────┐    ┌──────────────┐
│Payment  │───>│Kafka Stream│───>│Processing    │
│Gateway  │    │(partitioned)│    │Workers (x10) │
└─────────┘    └────────────┘    └──────┬───────┘
                                         │
                    ┌────────────────────┼──────────┐
                    ▼                    ▼          ▼
               ┌─────────┐         ┌─────────┐  ┌─────┐
               │Database │         │Analytics│  │Audit│
               │(sharded)│         │         │  │Log  │
               └─────────┘         └─────────┘  └─────┘
```

**Key Decisions:**

1. **Why Kafka?**
   - 1M/day = 12 transactions/sec (peak: 50/sec) → Kafka handles 100K/sec
   - Need audit trail (event log durability)
   - Multiple consumers (DB, analytics, compliance)

2. **Partitioning Strategy:**
   ```
   Key: user_id (hash partitioning)
   Partitions: 10 (supports 500K transactions/sec)
   Ensures same user transactions ordered
   ```

3. **Processing Pattern:**
   - Consumer group with 10 workers (1 per partition)
   - Each worker processes sequentially for ordering
   - Idempotent writes (transaction_id as key)

4. **Database:**
   - Sharded by user_id (aligns with Kafka partitions)
   - Write-optimized (append-only ledger)
   - Read replicas for queries

5. **Error Handling:**
   ```
   Transient errors → Retry 3x with backoff
   Permanent errors → DLQ (manual review)
   Poison pill → Skip message, alert on-call
   ```

**Exam Answer:**
"I use **Kafka + Consumer Groups** because:
1. Volume (1M/day) requires distributed processing
2. Partitioning ensures ordering per user
3. Kafka durability provides audit trail
4. Horizontal scaling (add consumers as volume grows)"

---

### 4.4 Scenario: Real-Time Dashboard

**Question:** "Build a dashboard showing live sales metrics updated every second."

**Architecture Options:**

**Option 1: Polling (Anti-Pattern)**
```
Dashboard ──(HTTP GET every 1s)──> API Server ──> Database
```
**Problems:** Server load, wasted bandwidth, delay  
**Don't use in exam answer unless you explain why it's wrong**

**Option 2: WebSocket (Good)**
```
Dashboard <══WebSocket══> API Server ──> Kafka Consumer
                                              │
                                              └─> Sales Events
```
**Pros:** Bidirectional, real-time, efficient  
**Use when:** < 1000 concurrent dashboards

**Option 3: Server-Sent Events / SSE (Better for dashboards)**
```
Dashboard <══SSE═══ API Server (pushes updates)
                         │
                         └──> Redis Pub/Sub ───> Sales Events Stream
```
**Pros:** One-way push, auto-reconnect, HTTP-based  
**Use when:** 1000s of concurrent viewers

**Complete Flow:**
```
┌──────────┐  Event   ┌───────┐  Stream   ┌────────────┐  Agg   ┌───────┐
│Sales POS │─────────>│ Kafka │──────────>│Flink / KS  │───────>│Redis  │
└──────────┘          └───────┘           │(windowing) │        │(cache)│
                                          └────────────┘        └───┬───┘
                                                                    │ Pub/Sub
                                          ┌─────────────┐           │
                                          │API Server   │<──────────┘
                                          │(SSE endpoint)│
                                          └──────┬──────┘
                                                 │ SSE Push
                                                 ▼
                                          ┌─────────────┐
                                          │  Dashboard  │
                                          │   (Browser) │
                                          └─────────────┘
```

**Calculations:**
```
Sales events: 100/sec
Dashboard updates: 1/sec per metric
Aggregation: 1-second tumbling window
Output: { "total_sales": 1500, "items_sold": 250 }
```

**Exam Answer:**
"I use **Kafka + Flink + Redis + SSE** because:
1. Kafka ingests raw sales events (100/sec)
2. Flink aggregates per-second windows (total, count, avg)
3. Redis Pub/Sub distributes to API servers (horizontal scale)
4. SSE pushes to dashboard (efficient, browser-native)
5. Latency: < 2 seconds end-to-end"

---

## PART 5: COMMON ERRORS AND HOW TO AVOID THEM

### 5.1 Error: Not Considering Idempotency

**Wrong Answer:**
"Service A calls Service B via HTTP POST. If network fails, retry."

**Problem:** Duplicate requests can cause duplicate orders, double charges.

**Correct Answer:**
"Service A includes `idempotency_key` (e.g., order_id) in POST request. Service B checks if key exists before processing. Uses database unique constraint to prevent duplicates."

**Code Example (Exam Pseudocode):**
```python
def process_order(order_id, payload):
    # Check if already processed
    if db.exists(order_id):
        return {"status": "already_processed"}
    
    # Process
    db.insert(order_id, payload)  # Unique constraint on order_id
    return {"status": "success"}
```

**Exam Tip:** Always mention idempotency for any retry scenario.

---

### 5.2 Error: Ignoring Failure Scenarios

**Wrong Answer:**
"API calls Service B. If successful, return success."

**What's Missing:** What if Service B is down? Timeout? Partial failure?

**Correct Answer:**
"Implement circuit breaker pattern:
- After 5 consecutive failures, open circuit (stop calling)
- Wait 30 seconds (half-open), try 1 request
- If success, close circuit (resume normal)
- If failure, open again
- Log all failures for monitoring"

**ASCII Diagram:**
```
States:
  CLOSED ──(5 failures)──> OPEN ──(30s timeout)──> HALF_OPEN
     ▲                                                  │
     └────────────(success)────────────────────────────┘
                 (resume calls)
```

---

### 5.3 Error: Not Handling Eventual Consistency

**Wrong Scenario:**
"User places order. Immediately query order status. Returns 404."

**Problem:** Event hasn't propagated yet (eventual consistency).

**Correct Approach:**
```
1. Order service publishes OrderCreated event
2. Returns order_id immediately to user (202 Accepted)
3. Order query service subscribes to events
4. Eventually consistent (1-5 seconds)
5. UI polls GET /orders/{id} or uses WebSocket for updates
```

**Exam Template:**
"System is eventually consistent because:
1. [Service A] publishes event asynchronously
2. [Service B] processes event with lag ([X] seconds)
3. User experience: Show 'Processing...' state
4. Trade-off: Availability and scalability over immediate consistency"

---

### 5.4 Error: Over-Engineering

**Wrong Answer (Too Complex):**
"Use Kubernetes, Kafka, Redis, Elasticsearch, Prometheus, Jaeger, Istio for a system with 10 users/day."

**Right Answer:**
"For low volume (10 users/day):
- Simple REST API (FastAPI/Express)
- PostgreSQL database
- Hosted on single server (Heroku/Railway)
- CloudWatch for basic monitoring
- Cost: $20/month vs $500/month for over-engineered solution"

**Exam Principle:** Match complexity to scale. Justify every technology choice with volume/requirements.

---

### 5.5 Error: Ignoring Security

**Incomplete Answer:**
"API Gateway forwards requests to microservices."

**What's Missing:** Authentication, authorization, encryption.

**Complete Answer:**
"API Gateway:
1. Authenticates requests (JWT validation)
2. Authorizes access (RBAC - Role-Based Access Control)
3. Rate limits (100 req/min per user)
4. Encrypts in-transit (TLS 1.3)
5. Logs all requests (audit trail)
6. Forwards with service token (mTLS to microservices)"

---

### 5.6 Error: No Monitoring Plan

**Incomplete Answer:**
"Integration flow: A → B → C"

**What's Missing:** How do you know if it works?

**Complete Answer:**
"Monitoring:
1. Metrics: Throughput (req/sec), latency (p50, p95, p99), error rate
2. Logs: Structured JSON logs to ELK stack
3. Traces: OpenTelemetry trace_id propagates A→B→C
4. Alerts: If error rate > 5% for 5 min → PagerDuty
5. Dashboard: Grafana showing real-time health"

---

## PART 6: EXAM ANSWER TEMPLATES

### 6.1 Template: "Design an Integration"

**Structure (use every time):**

```
1. REQUIREMENTS ANALYSIS (2-3 sentences)
   - Functional: What needs to happen?
   - Non-functional: Performance, availability, security?

2. PATTERN SELECTION (1 sentence + justification)
   - "I choose [pattern] because [requirement] needs [capability]."

3. ARCHITECTURE DIAGRAM (ASCII)
   - Show components and data flow

4. COMPONENT JUSTIFICATION (bullet points)
   - Why each technology/component?

5. ERROR HANDLING (3-4 strategies)
   - Retry, timeout, idempotency, DLQ

6. SECURITY (2-3 measures)
   - Auth, encryption, rate limiting

7. MONITORING (2-3 metrics/tools)
   - What to measure, how to alert
```

---

### 6.2 Template: "Compare Two Approaches"

**Structure:**

```
APPROACH 1: [Name]
Pros:
  - [Benefit 1]
  - [Benefit 2]
Cons:
  - [Limitation 1]
  - [Limitation 2]
Best for: [Use case]

APPROACH 2: [Name]
Pros:
  - [Benefit 1]
  - [Benefit 2]
Cons:
  - [Limitation 1]
  - [Limitation 2]
Best for: [Use case]

RECOMMENDATION: [Chosen approach]
Justification:
  - [Requirement 1] → [Approach] provides [capability]
  - [Requirement 2] → [Approach] is better because [reason]
```

---

### 6.3 Template: "Troubleshoot an Integration Issue"

**Structure:**

```
SYMPTOM: [What's broken?]

HYPOTHESIS 1: [Possible cause]
  - Check: [Diagnostic step]
  - Evidence: [What to look for]

HYPOTHESIS 2: [Possible cause]
  - Check: [Diagnostic step]
  - Evidence: [What to look for]

DEBUGGING STEPS:
  1. Check logs for [error pattern]
  2. Verify [component] health
  3. Test [connection/dependency]
  4. Trace request end-to-end

ROOT CAUSE: [Identified issue]

SOLUTION: [Fix]
  - Immediate: [Short-term fix]
  - Permanent: [Long-term fix]

PREVENTION: [How to avoid in future]
```

---

## PART 7: QUICK REFERENCE CHEAT SHEET

### 7.1 Integration Patterns — One-Liner Descriptions

| Pattern | One-Liner | When to Use |
|---------|-----------|-------------|
| **REST API** | Synchronous request-response over HTTP | User waits for result, CRUD operations |
| **GraphQL** | Client-specified queries, single endpoint | Mobile apps, flexible data needs |
| **gRPC** | Binary protocol, high performance | Internal microservices, streaming |
| **WebSocket** | Bidirectional real-time channel | Chat, live updates, gaming |
| **Message Queue** | Async task processing, FIFO | Background jobs, decoupling |
| **Event Stream** | Append-only log, replay capability | High volume, multiple consumers, audit |
| **Batch ETL** | Bulk data transfer, scheduled | Nightly loads, data warehouse |
| **CDC** | Capture database changes in real-time | DB sync, event sourcing |
| **Saga** | Distributed transaction with compensation | Multi-step workflows, rollback needed |
| **API Gateway** | Single entry point, routing, security | Microservices facade, rate limiting |
| **Service Mesh** | Infrastructure for service-to-service | Observability, mTLS, traffic control |

---

### 7.2 Technology Selection Cheat Sheet

| Need | Technology Choices | Default Recommendation |
|------|-------------------|------------------------|
| **Message Broker** | RabbitMQ, Kafka, AWS SQS, Azure Service Bus | Kafka (high volume), RabbitMQ (simpler) |
| **API Gateway** | Kong, Apigee, AWS API Gateway, NGINX | Kong (OSS), AWS API Gateway (cloud-native) |
| **Workflow Engine** | Temporal, Camunda, AWS Step Functions | Temporal (code-first), Camunda (BPMN) |
| **Stream Processing** | Kafka Streams, Flink, Spark Streaming | Kafka Streams (Kafka-native), Flink (complex) |
| **Service Mesh** | Istio, Linkerd, Consul | Istio (features), Linkerd (simplicity) |
| **Observability** | Prometheus+Grafana, Datadog, New Relic | Prometheus+Grafana (OSS), Datadog (SaaS) |
| **ETL Tool** | Apache Airflow, Talend, Informatica | Airflow (code-based), Talend (GUI) |

---

### 7.3 Performance Benchmarks (Exam Reference)

| Metric | Target (Good) | Acceptable | Poor |
|--------|---------------|------------|------|
| API latency (p99) | < 100ms | < 500ms | > 1s |
| Message throughput | > 10K/sec | > 1K/sec | < 100/sec |
| Availability | 99.99% (4 nines) | 99.9% (3 nines) | < 99% |
| Error rate | < 0.1% | < 1% | > 5% |
| Database query | < 10ms | < 100ms | > 1s |

---

### 7.4 Exam Day Checklist

**Before answering, ask yourself:**

✅ Did I identify functional and non-functional requirements?  
✅ Did I justify my pattern/technology choice?  
✅ Did I draw a clear architecture diagram?  
✅ Did I address error handling and retries?  
✅ Did I mention security (auth, encryption)?  
✅ Did I specify monitoring and alerts?  
✅ Did I consider scalability and cost?  
✅ Did I explain trade-offs honestly?

---

## PART 8: PRACTICE EXAM QUESTIONS

### Question 1: Multi-Region Deployment

**Scenario:** Deploy an e-commerce platform in US, EU, and Asia. Users must get low latency. How do you integrate regional databases?

**Your Answer Should Include:**
- Multi-region architecture diagram
- Data replication strategy (eventual consistency)
- Read from local region, write to primary with async replication
- Conflict resolution (last-write-wins or CRDT)
- Latency target: < 50ms regional, < 300ms cross-region
- Tools: AWS Aurora Global Database or CockroachDB

---

### Question 2: Breaking a Monolith

**Scenario:** Break a monolithic app into microservices. How do you handle shared database?

**Your Answer Should Include:**
- Strangler Fig pattern (gradually extract services)
- Database per service (eventual goal)
- Interim: API facade over shared DB
- Event-driven for service-to-service communication
- Saga pattern for distributed transactions
- CDC to sync data between old and new services

---

### Question 3: SLA Requirements

**Scenario:** API must have 99.95% availability. How do you design integration?

**Your Answer Should Include:**
- Redundancy: Multi-AZ deployment (3 zones)
- Load balancer with health checks
- Circuit breaker to isolate failures
- Retry with exponential backoff
- Monitoring: Uptime checks every 60s
- Incident response: Automated failover < 2 minutes
- SLA calculation: 99.95% = 4.38 hours downtime/year

---

## SUMMARY: KEYS TO EXAM SUCCESS

### 1. Always Structure Your Answer
- Requirements → Pattern → Diagram → Justification → Error Handling → Security → Monitoring

### 2. Justify Every Choice
- "I choose X because [requirement] needs [capability]"

### 3. Draw Diagrams (Even ASCII)
- Visual representation = bonus points

### 4. Address Non-Functionals
- Performance, scalability, security, monitoring

### 5. Mention Trade-Offs
- "Approach A is simple but not scalable. Approach B is complex but handles 10x volume."

### 6. Use Real Technologies
- "Kafka" not "message broker", "PostgreSQL" not "database"

### 7. Quantify Everything
- "< 100ms latency", "1000 req/sec", "99.9% availability"

### 8. Acknowledge Limitations
- "This design handles 10K users. For 1M users, we need [changes]."

---

**Good luck on your exam! Follow these frameworks and you'll ace it.** 🚀
