# TicketHub: Event Ticketing System Design

## 1. Introduction

TicketHub is an online event ticketing platform where customers can browse events, select seats, reserve tickets, and complete payments. The system must support normal daily traffic and sudden demand during popular ticket sales. Its most important requirement is preventing two customers from purchasing the same seat.

## 2. Requirements

### 2.1 Functional Requirements

1. Users can register, sign in, and manage their accounts.
2. Users can browse events and view event details.
3. Users can view available seats and ticket prices.
4. Users can temporarily hold available seats.
5. Users can purchase tickets and receive order confirmation.
6. The system can process payment results and update order status.
7. Expired seat holds are released so other customers can reserve them.
8. Administrators can create events, configure seats, and manage ticket sales.

### 2.2 Non-Functional Requirements

- **Availability:** The platform should remain available during major ticket sales.
- **Performance:** Event pages and seat information should load quickly under normal conditions.
- **Scalability:** The system should support sudden increases in traffic.
- **Consistency:** A seat must never be sold to two customers.
- **Security:** Authentication, authorization, input validation, and secure payment integration are required.
- **Reliability:** Failed requests and payment retries must not create duplicate orders.
- **Maintainability:** The application should use clear modules and documented APIs.

## 3. Traffic Estimation

TicketHub has 2,000,000 registered users, 50,000 daily visitors, and an average of 10 page views per visitor.

### 3.1 Normal Traffic

Daily page views:

50,000 visitors × 10 pages = 500,000 page views per day.

Average page requests per second:

500,000 ÷ 86,400 ≈ 5.79 requests per second.

The platform sells approximately 5,000 tickets per day. This averages:

5,000 ÷ 86,400 ≈ 0.058 ticket sales per second.

These are daily averages. Actual traffic varies by time and event popularity.

### 3.2 Major Ticket Sale

During a popular sale, 200,000 customers attempt to buy tickets for 20,000 seats in the first 10 minutes.

Average incoming requests, assuming one initial request per customer:

200,000 ÷ 600 seconds ≈ 333 requests per second.

However, if the workload is modelled as 200,000 requests per second, that is a different and much more demanding assumption. For this scenario, the estimated arrival rate is approximately 333 initial customer requests per second.

The 20,000 seats are fewer than the 200,000 interested customers. Therefore, many customers will be unable to obtain a seat. The system must reject unavailable-seat requests safely and avoid overselling.

Compared with the baseline average page-request rate:

333 ÷ 5.79 ≈ 57.5 times the normal average.

This comparison is approximate because it compares the sale's initial-request rate with the average daily page-request rate. Real capacity planning must also account for retries, browsing, seat-map requests, payment calls, and traffic bursts.

## 4. API Design

The backend exposes REST APIs over HTTPS. Authentication is required for operations involving a customer's account, seat holds, and orders.

### 4.1 Browse Events

GET /api/events

Returns a paginated list of published events.

Example response:

```json
{
  "events": [
    {
      "event_id": "event-123",
      "event_name": "Summer Festival",
      "venue": "Nairobi Arena",
      "status": "on_sale"
    }
  ],
  "page": 1
}
```

### 4.2 Get Event Details and Seats

GET /api/events/{event_id}

Returns event details, including venue, date, and ticket information.

GET /api/events/{event_id}/seats

Returns seat labels, prices, and display availability. This availability is informational and may change before a customer requests a hold.

### 4.3 Hold a Seat

POST /api/seats/{seat_id}/holds

Requires authentication and an Idempotency-Key header.

Example request:

```json
{
  "event_id": "event-123"
}
```

If the seat is available, the API creates a temporary hold, such as one lasting 10 minutes, and returns a hold identifier and expiry time. If the seat is already held or sold, the API returns a conflict response such as HTTP 409.

The idempotency key identifies a logical client request. Repeating the same request with the same key must return the original result instead of creating another hold. The backend should store the key, request identity, and result durably.

### 4.4 Create an Order

POST /api/orders

Requires authentication, a valid active hold, and an Idempotency-Key header.

The API validates the hold and creates an order in a pending-payment state. It does not trust the client to declare that a seat is available or that payment has succeeded.

### 4.5 Get an Order

GET /api/orders/{order_id}

Returns the order status, purchased items, total, and payment state. The backend checks that the authenticated user is allowed to view the order.

### 4.6 Payment Webhook

POST /api/payments/webhook

Receives payment-provider notifications. The endpoint verifies the provider's signature, validates the event, and processes it idempotently so repeated webhook deliveries do not create duplicate purchases.

## 5. Database Design

PostgreSQL is the primary database because TicketHub needs relational integrity, transactions, and reliable concurrent updates. The following tables form the core data model.

### 5.1 Users

| Column | Type | Description |
|---|---|---|
| user_id | UUID PRIMARY KEY | Unique user identifier |
| full_name | VARCHAR(100) | User's name |
| email | VARCHAR(255) UNIQUE | Login/contact email |
| created_at | TIMESTAMPTZ | Account creation time |

### 5.2 Events

| Column | Type | Description |
|---|---|---|
| event_id | UUID PRIMARY KEY | Unique event identifier |
| event_name | VARCHAR(200) | Event name |
| venue | VARCHAR(200) | Event location |
| event_date | TIMESTAMPTZ | Event date and time |
| status | VARCHAR(20) | Draft, on sale, or closed |

### 5.3 Seats

| Column | Type | Description |
|---|---|---|
| seat_id | UUID PRIMARY KEY | Unique seat identifier |
| event_id | UUID REFERENCES Events | Event containing the seat |
| seat_number | VARCHAR(20) | Label such as A12 |
| price | NUMERIC(10,2) | Ticket price |
| status | VARCHAR(20) | Available, held, or sold |

A UNIQUE constraint on (event_id, seat_number) ensures that a seat label is not duplicated within the same event.

### 5.4 Seat_Holds

| Column | Type | Description |
|---|---|---|
| hold_id | UUID PRIMARY KEY | Unique hold identifier |
| seat_id | UUID REFERENCES Seats | Seat being held |
| user_id | UUID REFERENCES Users | Customer holding the seat |
| expires_at | TIMESTAMPTZ | Hold expiry time |
| status | VARCHAR(20) | Active, expired, or converted |
| created_at | TIMESTAMPTZ | Time the hold was created |

A seat can have historical hold records, but only one active hold may be valid for a seat at a time. The implementation must enforce this rule through transactional seat locking and appropriate database constraints.

### 5.5 Orders

| Column | Type | Description |
|---|---|---|
| order_id | UUID PRIMARY KEY | Unique order identifier |
| user_id | UUID REFERENCES Users | Customer who placed the order |
| idempotency_key | VARCHAR(100) | Client request identifier |
| status | VARCHAR(20) | Pending, paid, failed, or cancelled |
| total_amount | NUMERIC(10,2) | Order total |
| created_at | TIMESTAMPTZ | Order creation time |

A UNIQUE constraint on (user_id, idempotency_key) prevents a customer from creating multiple orders for the same logical request. The backend must also verify that a reused key has the same request details.

### 5.6 Order_Items

| Column | Type | Description |
|---|---|---|
| order_item_id | UUID PRIMARY KEY | Unique item identifier |
| order_id | UUID REFERENCES Orders | Parent order |
| seat_id | UUID REFERENCES Seats | Purchased seat |
| price_at_purchase | NUMERIC(10,2) | Price at purchase time |

A UNIQUE constraint on seat_id prevents the same seat from appearing in multiple successful order items. Cancelled orders and refunds need an explicit policy if tickets may later be resold; a production system may instead enforce uniqueness only for active completed allocations.

### 5.7 Relationships

- One user can place many orders.
- One event has many seats.
- One seat can have multiple historical holds.
- One order contains one or more order items.
- Each order item refers to one seat.
- Foreign keys maintain valid relationships between records.

## 6. Preventing Double-Booking

The main concurrency problem occurs when two customers request the same seat at nearly the same time. Checking availability only in application code is unsafe: both requests could read "available" before either one updates the database.

TicketHub uses PostgreSQL transactions and row-level locks to serialize allocation of a particular seat. Database constraints provide an additional safeguard.

### 6.1 Seat-Hold Transaction

The backend starts a transaction and locks the seat row using SELECT ... FOR UPDATE. A competing transaction requesting the same seat must wait until the first transaction commits or rolls back.

Simplified SQL:

```sql
BEGIN;

SELECT seat_id, status
FROM seats
WHERE seat_id = :seat_id
FOR UPDATE;

-- Application checks the seat status and handles
-- any expired hold while still in this transaction.

UPDATE seats
SET status = 'held'
WHERE seat_id = :seat_id
  AND status = 'available';

-- The application must check that exactly one row
-- was updated and create the hold in this transaction.

COMMIT;
```

The example illustrates the locking idea; the production implementation must insert the Seat_Holds record in the same transaction, verify that exactly one seat was updated, and roll back if the seat is no longer available. Expired holds must be handled under the same locking rules before the seat can be released.

### 6.2 Example of Concurrent Requests

Assume Customer A and Customer B both request seat A12.

1. Customer A's transaction locks the seat row.
2. Customer B's transaction waits for the lock.
3. Customer A checks availability, creates a hold, updates the seat, and commits.
4. Customer B obtains the lock and sees that the seat is no longer available.
5. Customer B's request receives HTTP 409 Conflict.

Only one customer receives the active hold. If the first transaction fails, its changes are rolled back, allowing another request to proceed safely.

### 6.3 Completing a Purchase

When payment is initiated, the order begins in a pending state. After verified payment confirmation, the backend starts a short database transaction, locks the relevant seat and hold records, verifies that the hold is valid and belongs to the customer, creates the order items, marks the seat as sold, and converts the hold to a completed state.

The unique constraint on Order_Items.seat_id acts as a final database safeguard against selling the same seat twice. If a conflicting insert occurs, the transaction fails instead of creating a duplicate allocation.

The system must not keep a database transaction open while waiting for an external payment provider. Payment initiation, signed webhooks, idempotent processing, and explicit order states handle the gap between database operations and external payment confirmation. Expired or failed purchases must follow a defined process to release seats safely.

## 7. System Architecture

```text
                 Customers
                     |
                     v
               Web Frontend
                     |
                     v
            Load Balancer / API
                 Gateway
                     |
                     v
              TicketHub Backend
              /       |       \
             v        v        v
          Events    Seat      Orders and
          Module   Module     Payments
             \       |        /
              \      |       /
                     v
              PostgreSQL DB
          Users, Events, Seats,
          Holds, Orders, Items
                     |
            +--------+--------+
            |                 |
            v                 v
       Background          Monitoring
        Workers             and Logs
            |
            v
    Expiry Jobs, Notifications,
       Payment Event Handling

 Redis Cache: event details and other
 relatively stable, non-authoritative data
```

### 7.1 Component Responsibilities

- **Web frontend:** Displays events, seats, checkout forms, and order results.
- **Load balancer/API gateway:** Distributes requests and applies rate limits and routing rules.
- **Backend API:** Authenticates users, validates requests, enforces business rules, and coordinates transactions.
- **PostgreSQL:** Stores authoritative seat allocation, holds, orders, and payment states.
- **Redis:** Caches frequently read event information to reduce database load. It is not the final authority for seat availability.
- **Background workers:** Expire holds, process asynchronous events, and send notifications.
- **Monitoring and logs:** Track latency, errors, database contention, payment failures, and traffic spikes.

## 8. Architectural Trade-Offs

### 8.1 Row-Level Locks vs. Optimistic Concurrency

Row-level locking is easy to reason about for seat allocation because requests for the same seat are processed in sequence. However, highly popular seats may experience lock contention and waiting. Optimistic concurrency can improve performance in some situations, but conflicting requests require retries. TicketHub prioritizes correctness for seat allocation.

### 8.2 Caching vs. Consistency

Redis reduces database load for frequently viewed event pages. However, cached seat information can become stale. TicketHub therefore caches stable event information but uses PostgreSQL transactions to make final hold and purchase decisions.

### 8.3 Synchronous vs. Asynchronous Processing

Synchronous checkout is simpler to implement and understand, but processing notifications and other secondary work during checkout can increase response time. Background queues allow notifications, expiry jobs, and payment events to be processed asynchronously. This improves responsiveness but introduces retry handling and eventual consistency.

### 8.4 Single Database vs. Distributed Services

A modular backend using one PostgreSQL database simplifies transactions and consistency. Splitting the application into multiple services can allow independent scaling, but it introduces network failures and distributed coordination challenges. TicketHub should begin with clear modules and scale components when real performance measurements justify the added complexity.

## 9. Conclusion

TicketHub must handle both ordinary browsing and sudden demand during popular ticket sales. Traffic estimates help guide capacity planning, while the API design separates browsing, holding seats, placing orders, and processing payment results.

PostgreSQL transactions, row-level locks, and unique constraints protect seat allocation from concurrent requests. Idempotency keys help prevent duplicate operations when clients retry requests. Caching and background workers improve performance, while PostgreSQL remains the authoritative source for seat availability and purchases.
