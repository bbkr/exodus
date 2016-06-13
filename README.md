# EXODUS

Comprehensive guide and tools to split monolithic database into shards.


## Intro

When you suddenly get this brilliant idea, the revolutionary game-changer, all you want to do is to immediately hack some proof of concept to start small project flame from spark of creativity. So I'll leave you alone for now, with your third mug of coffee and birds chirping first morning songs outside of window...

...Few years later we meet again. Your proof of concept has grown into mature, recognizable product. Congratulations! But why the sad face? Your clients are complaining that your product is slow and unresponsive? They want more features? They generate more data? And you cannot do anything about it despite the fact that you bought most shiny, expensive database server that is available?

When you were hacking your project on day 0 you were not thinking about long term scalability. All you wanted to do is to create working prototype as fast as possible. So single database design was easiest, fastest and most obvious to use. You haven't thought back then, that single machine cannot be scaled up infinitely. And now it is already too late.

LOOKS LIKE YOU'RE STUCK ON THE SHORES OF [monolithic design database] HELL.
THE ONLY WAY OUT IS THROUGH...
(DOOM quote)

## Sharding to the rescue!

Sharding is the process of distributing your clients data across multiple databases (called shards).
By doing so you will be able to:

* Scale your whole system by adding more cheap database machines.
* Add more complex features that uses a lot of database CPU, I/O and RAM resources.
* Load balance your environment by moving clients between shards.
* Handle exceptionally large clients by dedicating resources to them.
* Utilize data centers in different countries to reduce network lag for clients and be more compliant with local data processing laws.
* Reduce risk of global system failures
* Do faster crash recovery due to smaller size of databases.

But if you already have single (monolithic) database this process is like converting your motorcycle into a car... while riding.

## Outline

This is step-by-step guide of a very tricky process. And the worst thing you can do is to panic because your product is collapsing under its own weight and you have a lots of pressure from clients. Whole process may take weeks, even months. Will use significant amount of human and time resources. And will pause new features development. Be prepared for that. And do not rush to the next stage until you are sure absolutely sure the current one is completed.

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

Everything else. They must not be reachable from any client or context table through any relation. However there may be relations between them. So our neutral tables are: `anti_fraud_systems` and `blacklisted_credit_cards`.

Neutral tables should be moved outside of shards.

### Checkpoint

Take any tool that can visualize your database in form of diagram. Print it and pin it on the wall.
Then take markers in 3 different colors - each for every table type -  and start marking tables in your schema.

If you have some tables not connected due to technical reasons (for example MySQL partitioned tables or TokuDB tables do not support foreign keys), draw this relation and assume it is there.

If you are not certain about specific table leave it unmarked for now.

Done? Good :)

### Q&A

***Q:*** Is it a good idea to cut all relations between client and context tables, so only two types - client and neutral - remain?

***A:*** You will save a bit of work because no synchronization of context data across all shards will be required.
But at the same time any analytics will be nearly impossible. For example even simple task to find which car was rented most times will require software script to do the join.
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

Aside from obvious risk of referencing nonexistent records this issue can leave junk when you will migrate clients between shards later for load balancing.
Fix is trivial - add foreign key if there should be one.

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

TODO Exodus tool can help detect those.

### 



Dane użytkowników muszą być rozłączne. Typowym przypadkiem gdzie ta zasada jest naruszona jest afiliacja.

```sql
CREATE TABLE users (
    id bigint unsigned NOT NULL auto_increment,
    PRIMARY KEY (id)
) Engine = InnoDB;

CREATE TABLE affiliation (
    parent_users_id bigint unsigned NOT NULL,
    child_users_id bigint unsigned NOT NULL,
    FOREIGN KEY (parent_users_id) REFERENCES users (id),
    FOREIGN KEY (child_users_id) REFERENCES users (id),
    UNIQUE KEY (parent_users_id, child_users_id)
) Engine = InnoDB;
```

Gdy tak powiązane konta trafią na różne shardy nie będzie możliwa migracja danych z powodu błędów kluczy obcych.
Najprostszym rozwiązaniem jest usunięcie jednej z relacji i przechowywanie danych na shardzie jednego użytkownika.

```
CREATE TABLE affiliation (
    parent_users_id bigint unsigned NOT NULL,
    child_users_id bigint unsigned NOT NULL,
    FOREIGN KEY (parent_users_id) REFERENCES users (id), # zawsze przechowuj na shardzie rodzica
    UNIQUE KEY (parent_users_id, child_users_id)
) Engine = InnoDB;
```

Jednak gdy dane są potrzebne na obu shardach można stworzyć tabele lustrzane i duplikować dane.


Osobnym przypadkiem naruszenia rozłączności danych użytkowników są błędy w aplikacji.
Możesz mieć 

##Schema fixes

###Nullable opaquity
###Not reachable users data
###Connection between users
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
