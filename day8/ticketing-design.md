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

PostgreSQL is the primary database because ticket sales require transactions, referential integrity, and safe concurrent updates.

### 5.1 Users

| Column | Type | Purpose |
|---|---|---|
| user_id | UUID PRIMARY KEY | Unique customer |
| full_name | VARCHAR(100) | Customer name |
| email | VARCHAR(255) UNIQUE | Customer email |
| created_at | TIMESTAMPTZ | Account creation time |

### 5.2 Events

| Column | Type | Purpose |
|---|---|---|
| event_id | UUID PRIMARY KEY | Unique event |
| event_name | VARCHAR(200) | Event name |
| venue | VARCHAR(200) | Event location |
| event_date | TIMESTAMPTZ | Event date |
| status | VARCHAR(20) | Draft, on sale, or closed |

### 5.3 Seats

| Column | Type | Purpose |
|---|---|---|
| seat_id | UUID PRIMARY KEY | Unique seat |
| event_id | UUID REFERENCES Events | Event containing the seat |
| seat_number | VARCHAR(20) | Label such as A12 |
| price | NUMERIC(10,2) | Ticket price |
| status | VARCHAR(20) | Available, held, or sold |

A UNIQUE constraint on (event_id, seat_number) prevents duplicate seat labels within an event.

### 5.4 Seat_Holds

| Column | Type | Purpose |
|---|---|---|
| hold_id | UUID PRIMARY KEY | Unique hold |
| seat_id | UUID REFERENCES Seats | Reserved seat |
| user_id | UUID REFERENCES Users | Customer holding the seat |
| expires_at | TIMESTAMPTZ | Hold expiry time |
| status | VARCHAR(20) | Active, expired, or converted |

A seat may have historical holds, but only one active hold can be valid at a time. The backend must enforce this using transactions and seat locks.

### 5.5 Orders

| Column | Type | Purpose |
|---|---|---|
| order_id | UUID PRIMARY KEY | Unique order |
| user_id | UUID REFERENCES Users | Customer placing the order |
| idempotency_key | VARCHAR(100) | Identifies a retried request |
| status | VARCHAR(20) | Pending, paid, failed, or cancelled |
| total_amount | NUMERIC(10,2) | Order total |
| created_at | TIMESTAMPTZ | Order creation time |

A UNIQUE constraint on (user_id, idempotency_key) prevents the same customer request from creating duplicate orders. Reusing a key with different request details must be rejected.

### 5.6 Order_Items

| Column | Type | Purpose |
|---|---|---|
| order_item_id | UUID PRIMARY KEY | Unique order item |
| order_id | UUID REFERENCES Orders | Parent order |
| seat_id | UUID REFERENCES Seats | Purchased seat |
| price_at_purchase | NUMERIC(10,2) | Price when purchased |

The database must prevent a seat from being allocated to multiple successful orders. This can be enforced with a unique constraint on seat_id when each seat is permanently sold only once. If cancelled tickets can be resold, the implementation must instead enforce uniqueness for active allocations.

### 5.7 Relationships

- One user can place many orders.
- One event contains many seats.
- One seat can have multiple historical holds.
- One order contains one or more order items.
- Each order item refers to one seat.
- Foreign keys maintain valid relationships between records.

## 6. Preventing Double-Booking

Two customers may request the same seat at almost the same time. Checking availability only in application code is unsafe because both requests could read an available seat before either updates it.

TicketHub uses PostgreSQL transactions and row-level locks. The database also enforces uniqueness constraints as a final safeguard.

### 6.1 Holding a Seat

The backend begins a transaction and locks the seat row using SELECT FOR UPDATE. Another transaction attempting to lock that same seat must wait.

Simplified SQL:

```sql
BEGIN;

SELECT seat_id, status
FROM seats
WHERE seat_id = :seat_id
FOR UPDATE;

-- Check availability and handle an expired hold
-- while the seat remains locked.

UPDATE seats
SET status = 'held'
WHERE seat_id = :seat_id
  AND status = 'available';

-- Application checks that exactly one row changed.
-- Insert the Seat_Holds record in this transaction.
-- If unavailable, roll back and return HTTP 409.

COMMIT;
```

The actual implementation must insert the hold in the same transaction, check the update count, and roll back if the seat is no longer available. Expired holds must be handled under the same locking rules before a seat is released.

### 6.2 Concurrent Request Example

Suppose Customer A and Customer B both request seat A12.

1. Customer A locks the seat row.
2. Customer B waits for the lock.
3. Customer A creates the hold, updates the seat, and commits.
4. Customer B acquires the lock and sees that the seat is no longer available.
5. Customer B receives HTTP 409 Conflict.

Only one customer obtains the hold. If Customer A's transaction fails, its changes are rolled back.

### 6.3 Completing the Purchase

When a customer checks out, the backend verifies that the hold is active and belongs to that customer. After payment confirmation, a short transaction locks the relevant records, creates the order items, marks the seat as sold, and converts the hold.

A unique constraint on the seat allocation prevents a second successful order from claiming the same seat. Idempotency keys ensure that client retries do not create duplicate orders.

The system must not hold a database transaction open while waiting for an external payment provider. Instead, it uses pending order states, verified payment webhooks, idempotent event processing, and a defined process for failed or expired payments.

## 7. System Architecture

```text
                    Customers
                        |
                        v
                  Web Frontend
                        |
                        v
              Load Balancer / API Gateway
              - Distributes incoming requests
              - Applies rate limits
                        |
                        v
                  TicketHub API
                 /      |       \
                v       v        v
             Events   Seat     Orders and
             Module  Module    Payments
                \      |        /
                 \     |       /
                        v
                 PostgreSQL
             Users, Events, Seats,
             Holds, Orders, Items
                        |
                 +------+------+
                 |             |
                 v             v
           Background      Monitoring
            Workers        and Logs
                 |
                 v
          Hold Expiry Jobs,
          Payment Events,
          Notifications

     Redis Cache: Frequently read event information
```

### 7.1 Component Responsibilities

- **Web frontend:** Displays events, seat maps, and checkout information.
- **Load balancer:** Distributes incoming requests across backend instances.
- **API gateway:** Routes requests and applies rate limits.
- **Backend API:** Authenticates users, validates requests, and applies business rules.
- **PostgreSQL:** Stores authoritative seat allocation, holds, orders, and payment states.
- **Redis:** Caches frequently read event details to reduce database load. Cached availability is not the final authority for a purchase.
- **Background workers:** Expire old holds and process notifications and asynchronous events.
- **Monitoring:** Tracks latency, errors, traffic, payment failures, and database contention.

During a major sale, additional backend instances and rate limits help absorb traffic. Caching reduces repeated reads, while PostgreSQL transactions protect seat allocation.

## 8. Architectural Trade-Offs

### 8.1 Row-Level Locking vs. Optimistic Concurrency

Row-level locks make seat allocation straightforward and safe because requests for the same seat are serialized. However, popular seats may experience lock contention. Optimistic concurrency may reduce waiting in some workloads, but conflicting requests need retries. TicketHub prioritizes correctness for seat allocation.

### 8.2 Caching vs. Consistency

Redis reduces database load for frequently requested event pages. However, cached data can become stale. TicketHub caches relatively stable event details but uses PostgreSQL transactions for authoritative seat holds and purchases.

### 8.3 Synchronous vs. Asynchronous Processing

Synchronous processing is simpler, but doing all work during checkout can increase response times. Background queues allow notifications and other secondary tasks to run asynchronously. This improves responsiveness but introduces retry handling and eventual consistency.

### 8.4 Single Database vs. Distributed Services

A modular backend with one PostgreSQL database simplifies transactions and consistency. Multiple independent services can scale separately but add network failures and distributed coordination. TicketHub should start with clear modules and introduce additional services when measurements justify the complexity.

## 9. Conclusion

TicketHub must support normal browsing and sudden demand during popular ticket sales. Its REST APIs separate event browsing, seat holds, order creation, and payment processing.

PostgreSQL transactions, row-level locks, and uniqueness constraints prevent duplicate seat allocation. Idempotency keys protect against retries, caching reduces read load, and background workers handle asynchronous tasks. Together, these design decisions improve reliability while keeping the initial architecture manageable.
