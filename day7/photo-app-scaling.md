# SnapShare Photo-App Scaling Plan

## 1. Assumptions and daily active users

SnapShare is a photo-sharing app where people upload photos and view a feed of photos from accounts they follow. The following assumptions are used for this estimate:

- The app has **10,000,000 registered users**.
- **10% of registered users are active each day**.
- Each daily active user uploads **one photo per day** and views **50 feed pages per day**.
- Each original photo averages **2 MB**, and each photo has one **50 KB thumbnail**.
- A year has **365 days**, and average request rates are calculated across 24 hours (86,400 seconds per day).
- Storage estimates use decimal units (1 TB = 1,000,000 MB). They cover one year's new uploads and thumbnails only; they do not include backups, replicas, metadata, or storage overhead.
- Peak feed traffic is estimated at **5 times the average**. Upload traffic is estimated as an average because no upload peak factor was provided.

Daily active users (DAU):

`10,000,000 × 10% = 1,000,000 daily active users`

Therefore, SnapShare is designed around **1 million active users per day** under these assumptions.

## 2. Traffic and storage estimates

### Uploads per second

Each active user uploads one photo per day:

`1,000,000 users × 1 photo = 1,000,000 uploads/day`

Average uploads per second:

`1,000,000 ÷ 86,400 ≈ 11.6 uploads/second`

### Feed views per second

Each active user views 50 feed pages per day:

`1,000,000 users × 50 pages = 50,000,000 feed views/day`

Average feed views per second:

`50,000,000 ÷ 86,400 ≈ 579 feed views/second`

Peak feed views per second, using a 5× peak factor:

`579 × 5 ≈ 2,895 feed views/second`

| Measurement | Estimate |
|---|---:|
| Daily active users | 1,000,000 |
| Photo uploads per day | 1,000,000 |
| Average uploads per second | 11.6 |
| Feed views per day | 50,000,000 |
| Average feed views per second | 579 |
| Peak feed views per second (5×) | 2,895 |

### Photo storage per year

Original photo storage:

`1,000,000 photos/day × 365 days = 365,000,000 photos/year`

`365,000,000 × 2 MB = 730,000,000 MB = 730 TB/year`

Thumbnail storage:

`365,000,000 × 50 KB = 18,250,000,000 KB = 18.25 TB/year`

Combined storage for original photos and thumbnails:

`730 TB + 18.25 TB = 748.25 TB/year`

SnapShare therefore needs approximately **730 TB per year for original photos**, plus **18.25 TB per year for thumbnails**, or **748.25 TB per year combined**. Actual provisioned capacity will be higher if the system keeps multiple copies, backups, or older versions.

## 3. Read-heavy or write-heavy?

SnapShare is **read-heavy** in terms of application activity. The assumptions give 50 million feed views per day compared with 1 million uploads per day, meaning there are about 50 feed views for every photo upload. Feed reads are therefore likely to put greater pressure on the application and database than upload requests.

The design should scale read traffic efficiently. A cache can serve frequently requested feed data, a database read replica can handle eligible read queries, and a CDN can deliver image files close to users. Uploads still need a reliable write path, and object storage must be able to absorb the large volume of new image data.

## 4. Why photos should not be stored inside the database

The original image files should **not** be stored as database blobs because they are large, consume database capacity, make backups and restores heavier, and can slow down database operations that should focus on structured information. Storing every image in the database also makes it harder to deliver images efficiently through a CDN.

Instead, store original photos and thumbnails in **object storage**. The database should keep metadata such as the photo ID, owner, caption, upload time, object-storage key, thumbnail key, and visibility settings. This keeps database records small while object storage handles large files durably and cost-effectively.

## 5. Text architecture diagram

```text
                         +----------------------+
                         |         Users        |
                         +----------+-----------+
                                    |
                       +------------v------------+
                       |           CDN           |
                       | Cached photos/thumbnails|
                       +------------+------------+
                                    |
                            Cache miss / API
                                    |
                         +----------v-----------+
                         |     Load Balancer    |
                         +----------+-----------+
                                    |
                    +---------------+---------------+
                    |               |               |
              +-----v------+  +-----v------+  +-----v------+
              | App Server |  | App Server |  | App Server |
              +--+------+--+  +--+------+--+  +--+------+--+
                 |      |        |      |        |      |
                 |      +--------+------+--------+      |
                 |               |                     |
          +------v------+  +-----v------+        +-----v------+
          |    Cache    |  |  Database  |------->| Read Replica|
          | Feed/metadata| | (primary)  |        | Read queries|
          +-------------+  +-----+------+        +------------+
                                  |
                           Metadata and keys

 Users upload photo --> App Server --> Object Storage (original)
                              |
                              +----> Queue ----> Thumbnail Worker
                                                   |
                                                   v
                                             Object Storage
                                             (thumbnail)

 CDN serves original photos and thumbnails from object storage
 (or from its own cached copy).
```

## 6. What each component solves

- **CDN:** Delivers frequently viewed photos and thumbnails from locations closer to users, reducing latency and origin-server traffic.
- **Load balancer:** Distributes incoming API requests across healthy app servers so that one server does not become a bottleneck.
- **App servers:** Run the application logic, authenticate users, check permissions, create feed responses, and coordinate uploads.
- **Cache:** Keeps frequently requested feed data and metadata in fast memory so repeated reads do not all reach the database.
- **Primary database:** Stores structured data such as users, follows, captions, photo metadata, and object-storage keys.
- **Database read replica:** Handles suitable read queries separately from the primary database, reducing read pressure on the main write database.
- **Object storage:** Stores the large original photo files and generated thumbnails without filling the database with binary image data.
- **Queue:** Holds thumbnail-generation jobs so that image processing can happen asynchronously instead of making the upload request wait.
- **Thumbnail worker:** Reads queued jobs, creates appropriately sized thumbnails, saves them to object storage, and updates their metadata or processing status.

## 7. Photo upload flow, including thumbnail generation

1. **User selects a photo.** The app checks that the file type and size are within the allowed limits.
2. **Request reaches the application.** The client sends an authenticated upload request through the load balancer to an app server.
3. **App server validates the request.** It verifies the user's identity, permissions, file details, and any applicable upload limits.
4. **Original is stored.** The app server, or a controlled direct-upload flow, sends the original image to object storage under a unique object key.
5. **Metadata is saved.** The primary database records the photo ID, owner, object key, upload time, caption, and a status such as `processing`.
6. **Thumbnail job is queued.** The app adds a message containing the photo ID and object key to the queue. The upload response can now confirm that the photo was accepted without waiting for image processing.
7. **Worker processes the job.** A thumbnail worker consumes the message, retrieves the original image, creates a 50 KB-targeted thumbnail (or the required size/quality variant), and uploads it to object storage.
8. **Processing status is updated.** The worker records the thumbnail key and marks the photo as ready. Failed jobs can be retried, with safeguards against creating duplicate results.
9. **Photo appears in feeds.** Feed requests retrieve photo metadata from the cache or database and return image URLs or keys. The CDN serves the original or thumbnail to viewers, while cache entries are refreshed or invalidated as needed.

## 8. Trade-offs

### Trade-off 1: Cache speed versus data freshness

Caching feed data reduces database load and improves response times, but cached information can be briefly out of date after a user uploads a photo, changes a caption, or unfollows someone. SnapShare can use short cache lifetimes or targeted invalidation for important changes, accepting a small amount of extra complexity to improve read performance.

### Trade-off 2: Read replicas versus consistency and cost

A read replica allows the system to serve more feed queries without putting all read traffic on the primary database. However, replication can lag, so a newly uploaded photo or updated profile may not appear immediately in a read served by the replica. The system can send critical read-after-write requests to the primary database, while using the replica for ordinary feed reads; this adds infrastructure and operational cost.

### Trade-off 3: Asynchronous thumbnails versus processing delay

A queue and worker make uploads faster because the user does not have to wait for a thumbnail to be generated. The downside is that the photo may briefly appear without a thumbnail, and the queue or worker can fail or fall behind. Monitoring, retries, dead-letter handling, and a visible processing state improve reliability but add complexity.

### Trade-off 4: Object storage versus simpler single-system storage

Object storage is better suited to large image files and works well with a CDN, but the application must coordinate object keys, database metadata, permissions, and cleanup. A failed operation could leave an unused image object or a database record that points to a missing file. Reliable upload workflows, periodic cleanup, and access controls reduce these risks but require extra engineering.

## Conclusion

With 1 million daily active users, SnapShare is expected to receive about **11.6 uploads per second** and **579 average feed views per second**, with peak feed traffic near **2,895 views per second** under the 5× assumption. New originals and thumbnails require about **748.25 TB of storage per year** before backups and replication. A CDN, cache, load-balanced app servers, a primary database with a read replica, object storage, and asynchronous thumbnail workers provide a design that prioritizes fast feed reads while keeping photo storage and processing scalable.
