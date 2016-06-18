# EXODUS

Comprehensive guide and tools to split monolithic database into shards.


## Intro

When you suddenly get this brilliant idea, the revolutionary game-changer, all you want to do is to immediately hack some proof of concept to start small project flame from spark of creativity. So I'll leave you alone for now, with your third mug of coffee and birds chirping first morning songs outside of the window...

...Few years later we meet again. Your proof of concept has grown into a mature, recognizable product. Congratulations! But why the sad face? Your clients are complaining that your product is slow and unresponsive? They want more features? They generate more data? And you cannot do anything about it despite the fact that you bought most shiny, expensive database server that is available?

When you were hacking your project on day 0 you were not thinking about long term scalability. All you wanted to do was to create working prototype as fast as possible. So single database design was easiest, fastest and most obvious to use. You didn't think back then, that single machine cannot be scaled up infinitely. And now it is already too late.

LOOKS LIKE YOU'RE STUCK ON THE SHORES OF [monolithic design database] HELL.
THE ONLY WAY OUT IS THROUGH...
(DOOM quote)

## Sharding to the rescue!

Sharding is the process of distributing your clients data across multiple databases (called shards).
By doing so you will be able to:

* Scale your whole system by adding more cheap database machines.
* Add more complex features that use a lot of database CPU, I/O and RAM resources.
* Load balance your environment by moving clients between shards.
* Handle exceptionally large clients by dedicating resources to them.
* Utilize data centers in different countries to reduce network lag for clients and be more compliant with local data processing laws.
* Reduce risk of global system failures
* Do faster crash recovery due to smaller size of databases.

But if you already have single (monolithic) database this process is like converting your motorcycle into a car... while riding.

## Outline

This is step-by-step guide of a very tricky process. And the worst thing you can do is to panic because your product is collapsing under its own weight and you have a lots of pressure from clients. Whole process may take weeks, even months. Will use significant amount of human and time resources. And will pause new features development. Be prepared for that. And do not rush to the next stage until you are absolutely sure the current one is completed.

So what is the plan?

* You will have to look at your data and fix a lot of schema design errors.
* Then set up new hardware and software environment components.
* Adapt your product to sharding logic.
* Do actual data migration.
* Adapt your internal tools and procedures.
* Resume product development.

## Understand your data

In monolithic database design data classification is irrelevant but it is the most crucial part of sharding design. Your tables can be divided into three groups: client, context and neutral.

Let's assume your product is car rental software and do a quick exercise:

```

  +----------+      +------------+      +-----------+
  | clients  |      | cities     |      | countries |
  +----------+      +------------+      +-----------+
+-| id       |   +--| id         |   +--| id        |
| | city_id  |>--+  | country_id |>--+  | name      |
| | login    |   |  | name       |      +-----------+
| | password |   |  +------------+
| +----------+   |
|                +------+
+--------------------+  |
                     |  |     +-------+
  +---------------+  |  |     | cars  |
  | rentals       |  |  |     +-------+
  +---------------+  |  |  +--| id    |
+-| id            |  |  |  |  | vin   |
| | client_id     |>-+  |  |  | brand |
| | start_city_id |>----+  |  | model |
| | start_date    |     |  |  +-------+
| | end_city_id   |>----+  |
| | end_date      |        |
| | car_id        |>-------+   +--------------------+
| | cost          |            | anti_fraud_systems |
| +---------------+            +--------------------+
|                              | id                 |--+
|      +-----------+           | name               |  |
|      | tracks    |           +--------------------+  |
|      +-----------+                                   |
+-----<| rental_id |                                   |
       | latitude  |     +--------------------------+  |
       | longitude |     | blacklisted_credit_cards |  |
       | timestamp |     +--------------------------+  |
       +-----------+     | anti_fraud_system_id     |>-+
                         | number                   |
                         +--------------------------+
```

### Client tables

They contain data owned by your clients. To find them you must start in some root table - `clients` in our example. Then follow every parent-to-child relation (only in this direction) as deep as you can. In this case we descend into `rentals` and then from `rentals` further to `tracks`. So our client tables are: `clients`, `rentals` and `tracks`.

Single client owns subset of rows from those tables, and those rows will always be moved together in a single transaction between shards.

### Context tables

They put your clients data in context. To find them follow every child-to-parent relation (only in this direction) from every client table as shallow as you can. Skip if table is already classified. In this case we ascend from `clients` to `cities` and from `cities` further to `countries`. Then from `rentals` we can ascend to `clients` (already classified), `cities` (already classified) and `cars`. And from `tracks` we can ascend into `rentals` (already classified). So our context tables are: `cities`, `countries` and `cars`.

Context tables should be synchronized across all shards.

### Neutral tables

Everything else. They must not be reachable from any client or context table through any relation. However, there may be relations between them. So our neutral tables are: `anti_fraud_systems` and `blacklisted_credit_cards`.

Neutral tables should be moved outside of shards.

### Checkpoint

Take any tool that can visualize your database in the form of a diagram. Print it and pin it on the wall.
Then take markers in 3 different colors - each for every table type -  and start marking tables in your schema.

If you have some tables not connected due to technical reasons (for example MySQL partitioned tables or TokuDB tables do not support foreign keys), draw this relation and assume it is there.

If you are not certain about specific table, leave it unmarked for now.

Done? Good :)

### Q&A

***Q:*** Is it a good idea to cut all relations between client and context tables, so that only two types - client and neutral - remain?

***A:*** You will save a bit of work because no synchronization of context data across all shards will be required.
But at the same time any analytics will be nearly impossible. For example, even simple task to find which car was rented the most times will require software script to do the join.
Also there won't be any protection against software bugs, for example it will be possible to rent a car that does not even exist.

There are two cases when converting context table to neutral table is justified:

* Context data is really huge or takes huge amount of transfer to synchronize. We're talking gigabytes here.
* Reference is "weak". And that means it only exists for some debug purposes and is not used in business logic. For example if we present different version of website to user based on country he is from - that makes "hard" references between `clients`, `cities` and `countries`, so `cities` and `countries` should remain as context tables.

In every other case it is very bad idea to make neutral data out of context data.

***Q:*** Is it a good idea to shard only big tables and leave all small tables together on monolithic database?

***A:*** In our example you have one puffy table - `tracks`. It keeps GPS trail of every car rental and will grow really fast. So if you only shard this data you will save a lot of work because there will be only small application changes required. But in real world you will have 100 puffy tables and that means 100 places in application logic when you have to juggle database handles to locate all client data. That also means you won't be able to split your clients between many data centers. Also you won't be able to reduce downtime costs to 1/nth of the amount of shards if some data corruption in monolithic database occurs and recovery is required. And analytics argument mentioned above also applies here.

It is bad idea to do such sub-sharding. May seem easy and fast - but the sooner you do proper sharding that includes all of your clients data, the better.

## Fix your schema

There are few design patterns that are perfectly fine in monolithic database design but are no-go in sharding.

### Lack of foreign key

Aside from obvious risk of referencing nonexistent records, this issue can leave junk when you will migrate clients between shards later for load balancing.
The fix is simple - add foreign key if there should be one.

The only exception is when it cannot be added due to technical limitations, such as usage of TokuDB or partitioned MySQL tables that simply do not support foreign keys.
Skip those, I'll tell you how to deal with them during data migration later.

### Direct connection between clients

Because clients may be located on different shards their rows may not point at each other.
Typical case where it happens is affiliation.

```
+-----------------------+
| clients               |
+-----------------------+
| id                    |------+
| login                 |      |
| password              |      |
| referred_by_client_id |>-----+
+-----------------------+
```

To fix this issue you must remove foreign key and rely on software instead to match those records.

### Nested connection between clients

Because clients may be located on different shards their rows may not reference another client (also indirectly).
Typical case where it happens is post-and-comment discussion.

```
  +----------+        +------------+
  | clients  |        | blog_posts |
  +----------+        +------------+
+-| id       |---+    | id         |---+
| | login    |   +---<| client_id  |   |
| | password |        | text       |   |
| +----------+        +------------+   |
|                                      |
|    +--------------+                  |
|    | comments     |                  |
|    +--------------+                  |
|    | blog_post_id |>-----------------+
+---<| client_id    |
     | text         |
     +--------------+
```

First client posted something and second client commented it. This comment references two clients at the same time - second one directly and first one indirectly through `blog_posts` table.
That means it will be impossible to satisfy both foreign keys in `comments` table if those clients are not in single database.

To fix this you must choose which relation from table that refers to multiple clients is more important, remove the other foreign keys and rely on software instead to match those records.

So in our example you may decide that relation between `comments` and `blog_posts` remains, relation between `comments` and `clients` is removed and you will use application logic to find which client wrote which comment.

### Accidental connection between clients

This is the same issue as nested connection but caused by application errors instead of intentional design.


```
                    +----------+
                    | clients  |
                    +----------+
+-------------------| id       |--------------------+
|                   | login    |                    |
|                   | password |                    |
|                   +----------+                    |
|                                                   |
|  +-----------------+        +------------------+  |
|  | blog_categories |        | blog_posts       |  |
|  +-----------------+        +------------------+  |
|  | id              |----+   | id               |  |
+-<| client_id       |    |   | client_id        |>-+
   | name            |    +--<| blog_category_id |
   +-----------------+        | text             |
                              +------------------+
```

For example first client defined his own blog categories for his own blog posts.
But lets say there was mess with www sessions or some caching mechanism and blog post of second client was accidentally assigned to category defined by first client.

Those issues are ***extremely hard*** to find, because schema itself is perfectly fine and only data is damaged.

TODO Exodus tool can help to detect those.

### Not reachable clients data

Client tables must be reached exclusively by descending from root table through parent-to-child relations.


```
              +----------+
              | clients  |
              +----------+
+-------------| id       |
|             | login    |
|             | password |
|             +----------+
|
|  +-----------+        +------------+
|  | photos    |        | albums     |
|  +-----------+        +------------+
|  | id        |    +---| id         |
+-<| client_id |    |   | name       |
   | album_id  |>---+   | created_at |
   | file      |        +------------+
   +-----------+
```

So we have photo management software this time and when client synchronizes photos from camera new album is created automatically for better import visualization.
This is obvious issue even in monolithic database - when all photos from album are removed then it becomes zombie row.
Won't be deleted automatically by cascade and cannot be matched with `client` anymore.
In sharding this also causes misclassification of client table as context table.

To fix this issue foreign key should be added from `albums` to `clients`.
This may also fix classification for some tables below `albums`, if any.

### Polymorphic data

Table cannot be classified as two types at the same time.

```
              +----------+
              | clients  |
              +----------+
+-------------| id       |-------------+
|             | login    |             |
|             | password |             |
|             +----------+         (nullable)
|                                      |
|  +-----------+        +-----------+  |
|  | blogs     |        | skins     |  |
|  +-----------+        +-----------+  |
|  | id        |    +---| id        |  |
+-<| client_id |    |   | client_id |>-+
   | skin_id   |>---+   | color     |
   | title     |        +-----------+
   +-----------+
```

In this product client can choose predefined skin for his blog.
But can also define his own skin color and use it as well.

Here single interface of `skins` table is used to access data of both client and context type.
A lot of "let's allow client to customize that" features end up implemented this way.
While being a smart hack - with no table schema duplication and only simple `WHERE client_id IS NULL OR client_id = 123` added to query to present both public and private templates for client - this may cause a lot of trouble in sharding.

The fix is to go with dual foreign key design and separate tables. Create constraint (or trigger) that will protect against assigning blog to public and private skin at the same time. And write more complicated query to get blog skin color.

```
              +----------+
              | clients  |
              +----------+
+-------------| id       |
|             | login    |
|             | password |
|             +----------+
|
|   +---------------+        +--------------+
|   | private_skins |        | public_skins |
|   +---------------+        +--------------+
|   | id            |--+  +--| id           |
+--<| client_id     |  |  |  | color        |
|   | color         |  |  |  +--------------+
|   +---------------+  |  |    
|                      |  |
|                   (nullable)
|                      |  |
|                      |  +------+
|                      +-----+   |
|                            |   |
|       +-----------------+  |   |
|       | blogs           |  |   |
|       +-----------------+  |   |
|       | id              |  |   | 
+------<| client_id       |  |   |
        | private_skin_id |>-+   |
        | public_skin_id  |>-----+
        | title           |
        +-----------------+
```

However - this fix is optional. I'll show you how to deal with maintaining mixed data types in chapter about mutually exclusive IDs.
It will be up to you to decide if you want less refactoring but more complicated synchronization.

***Beware!*** Such fix may also accidentally cause another issue described below.

### Opaque uniqueness (a.k.a. horse riddle)

Every client table without unique constraint must be reachable by not nullable path of parent-to-child relations or at most single nullable path of parent-to-child relations.
This is very tricky issue which may cause data loss or duplication during client migration to database shard.

```
              +----------+
              | clients  |
              +----------+
+-------------| id       |-------------+
|             | login    |             |
|             | password |             |
|             +----------+             |
|                                      |
|  +-----------+        +-----------+  |
|  | time      |        | distance  |  |
|  +-----------+        +-----------+  |
|  | id        |--+  +--| id        |  |
+-<| client_id |  |  |  | client_id |>-+
   | amount    |  |  |  | amount    |
   +-----------+  |  |  +-----------+
                  |  |
               (nullable)
                  |  |
                  |  |
         +--------+  +---------+
         |                     |
         |   +-------------+   |
         |   | parts       |   |
         |   +-------------+   |
         +--<| time_id     |   |
             | distance_id |>--+
             | name        |
             +-------------+
```

This time our product is application that helps you with car maintenance schedule.
Our clients car has 4 tires that must be replaced after 10 years or 100000km
and 4 spark plugs that must be replaced after 100000km.
So 4 indistinguishable rows for tires are added to `parts` table (they reference both `time` and `distance`)
and 4 indistinguishable rows are added for spark plugs (they reference only `distance`).

Now to migrate client to shard we have to find which rows from `parts` table does he own.
By following relations through `time` table we will get 4 tires. But because this path is nullable at some point
we are not sure if we found all records. And indeed, by following relations through `distance` table we found 4 tires and 4 spark plugs.
Since this path is also nullable at some point we are not sure if we found all records.
So we must combine result from time and distance paths, which gives us... 8 tires and 4 spark plugs?
Well, that looks wrong. Maybe let's group it by time and distance pair, which gives us... 1 tire and 1 spark plug?
So depending how you combine indistinguishable rows from many nullable paths to get final row set, you may suffer either data duplication or data loss.

You may say: Hey, that's easy - just select all rows through time path, then all rows from distance path that do not have `time_id`, then union both results.
Unfortunately paths may be nullable somewhere earlier and several nullable paths may lead to table,
which will produce bizarre logic to get indistinguishable rows set properly.

To solve this issue make sure there is at least one not nullable path that leads to every client table.
Extra foreign key should be added between `clients` and `part` in our example.

TL;DR

Q: How many legs does the horse have?
A: Eight. Two front, two rear, two left, two right.

Q: How many legs does the horse have?
A: Four. Those attached to it.




###Tree structure
###Foreign key to not unique columns
###Loops
###Triggers

##Data fixes

###Synchronization of default data
(+pol domyslne)
hint: named lock

##Setting up environment

###Dispatch shard
###User shards
(similiar power, independent replicas, bigints)
###Mutually exclusive PKs
(offsetu i skoku zamiast centralizacji)
###Even distribution of users
(starzy maja historie/retencje/uzycie zaawansowanych funkcji)

##Code changes
rezerwacje procesow
dispatch
nowi userzy
dane defaultowe

##Migracja
exodus - jak uzywac
dlugo trwa
hint: uzyj historii zeby migrowac poza godzinami logowan przez uzytkownikow
ponowne porzadki

##Niespodzianki
odciazenie powoduje zwiekszenie czestotliwosci niektorych akcji
