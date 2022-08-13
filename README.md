# EXODUS

Comprehensive guide and tools to split monolithic database into shards.

You can find most recent version of this tutorial at https://github.com/bbkr/exodus .

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

## Fix your monolithic database

There are few design patterns that are perfectly fine or acceptable in monolithic database design but are no-go in sharding.

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

Those issues are very hard to find, because schema itself is perfectly fine and only data is damaged.

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
Unfortunately paths may be nullable somewhere earlier and several nullable paths may lead to single table,
which will produce bizarre logic to get indistinguishable rows set properly.

To solve this issue make sure there is at least one not nullable path that leads to every client table (does not matter how many tables it goes through).
Extra foreign key should be added between `clients` and `part` in our example.

TL;DR

***Q:*** How many legs does the horse have?

***A1:*** Eight. Two front, two rear, two left and two right.

***A2:*** Four. Those attached to it.

### Foreign key to not unique rows

MySQL specific issue.

```
CREATE TABLE `foo` (
  `id` int(10) unsigned DEFAULT NULL,
  KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `bar` (
  `foo_id` int(10) unsigned NOT NULL,
  KEY `foo_id` (`foo_id`),
  CONSTRAINT `bar_ibfk_1` FOREIGN KEY (`foo_id`) REFERENCES `foo` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

mysql> INSERT INTO `foo` (`id`) VALUES (1);
Query OK, 1 row affected (0.01 sec)

mysql> INSERT INTO `foo` (`id`) VALUES (1);
Query OK, 1 row affected (0.00 sec)

mysql> INSERT INTO `bar` (`foo_id`) VALUES (1);
Query OK, 1 row affected (0.01 sec)
```

Which row from `foo` table is referenced by row in `bar` table?

You don't know because behavior of foreign key constraint is defined as "it there any parent I can refer to?" instead of "do I have exactly one parent?".
There are no direct row-to-row references as in other databases. And it's not a bug, it's a feature.

Of course this causes a lot of weird bugs when trying to locate all rows that belong to given client, because results can be duplicated on JOINs.

To fix this issue just make sure every referenced column (or set of columns) is unique.
They ***must not*** be nullable and ***must*** all be used as primary or unique key.

### Self loops

Rows in the same client table cannot be in direct relation.
Typical case is expressing all kinds of tree or graph structures.

```
+----------+
| clients  |
+----------+
| id       |----------------------+
| login    |                      |
| password |                      |
+----------+                      |
                                  |
          +--------------------+  |
          | albums             |  |
          +--------------------+  |
      +---| id                 |  |
      |   | client_id          |>-+
      +--<| parent_album_id    |
          | name               |
          +--------------------+
```

This causes issues when client data is inserted into target shard.

For example in our photo management software client has album with `id` = 2 as subcategory of album with `id` = 1.
Then he flips this configuration, so that the album with `id` = 2 is on top.
In such scenario if database returned client rows in default, primary key order
then it won't be possible to insert album with `id` = 1 because it requires presence of album with `id` = 2.

Yes, you can disable foreign key constraints to be able to insert self-referenced data in any order.
But by doing so you may mask many errors - for example broken references to context data.

For good sharding experience all relations between rows of the same table should be stored in separate table.

```
+----------+
| clients  |
+----------+
| id       |----------------------+
| login    |                      |
| password |                      |
+----------+                      |
                                  |
          +--------------------+  |
          | albums             |  |
          +--------------------+  |
  +-+=====| id                 |  |
  | |     | client_id          |>-+
  | |     | name               |
  | |     +--------------------+
  | |
  | |    +------------------+
  | |    | album_hierarchy  |
  | |    +------------------+
  | +---<| parent_album_id  |
  +-----<| child_album_id   |
         +------------------+ 
```

### Triggers

Triggers cannot modify rows.
Or roar too loud :)

```
            +----------+
            | clients  |
            +----------+
 +----------| id       |------------------+
 |          | login    |                  |
 |          | password |                  |
 |          +----------+                  |
 |                                        |
 |  +------------+        +------------+  |
 |  | blog_posts |        | activities |  |
 |  +------------+        +------------+  |
 |  | id         |        | id         |  |
 +-<| client_id  |        | client_id  |>-+
    | content    |        | counter    |
    +------------+        +------------+
          :                      :
          :                      :
 (on insert post create or increase activity)
```

This is common usage of a trigger to automatically aggregate some statistics.
Very useful and safe - doesn't matter which part of application adds new blog post,
activities counter will always go up.

However, when sharding this causes a lot of trouble when inserting client data.
Let's say he has 4 blog posts and 4 activities.
If posts are inserted first they bump activity counter through trigger and we have collision in `activties` table due to unexpected row.
When activities are inserted first they are unexpectedly increased by posts inserts later, ending with invalid 8 activities total.

In sharding triggers can only be used if they do not modify data.
For example it is OK to do sophisticated constraints using them.
Triggers that modify data must be removed and their logic ported to application.

### Checkpoint

Check if there are any issues described above in your printed schema and fix them.

And this is probably the most annoying part of sharding process
as you will have to dig through a lot of code.
Sometimes old, untested undocumented and unmaintained.

When you are done your printed schema on the wall should not contain any unclassified tables.

Ready for next step?

## Prepare schema

It is time to dump monolithic database complete schema (tables, triggers, views and functions/procedures) to the `shard_schema.sql` file and prepare for sharding environment initialization.

### Separate neutral tables

Move all tables that are marked as neutral from `shard_schema.sql` file to separate `neutral_schema.sql` file.
Do not forget to also move triggers, views or procedures associated with them.

### Bigints

Every primary key on shard should be of `unsigned bigint` type.
You do not have to modify your existing schema installed on monolithic database.
Just edit `shard_schema.sql` file and massively replace all numeric primary and foreign keys to unsigned big integers.
I'll explain later why this is needed.

### Create schema for dispatcher

Dispatcher tells on which shard specific client is located.
Absolute minimum is to have table where you will keep client id and shard number.
Save it to `dispatch_schema.sql` file.

More complex dispatchers will be described later.

### Dump common data

From monolithic database dump data for neutral tables to `neutral_data.sql` file
and for context tables to `context_data.sql` file.
Watch out for tables order to avoid breaking foreign keys constraints.

### Checkpoint

You should have `shard_schema.sql`, `neutral_schema.sql`, `dispatch_schema.sql`, `neutral_data.sql` and `context_data.sql` files.

At this point you should also freeze all schema and common data changes in your application until sharding is completed.

## Set up environment

Finally you can put all those new, shiny machines to good use.

Typical sharding environment contains of:

* Database for neutral data.
* Database for dispatch.
* Databases for shards.

Each database should of course be replicated.

### Database for neutral data

Nothing fancy, just regular database.
Install `neutral_schema.sql` and feed `neutral_data.sql` to it.

Make separate user for application with read-only grants to read neutral data
and separate user with read-write grants for managing data.

### Database for dispatch

Every time client logs in to your product you will have to find which shard he is located on.
Make sure all data fits into RAM, have a huge connection pool available.
And install `dispatch_schema.sql` to it.

This is a weak point of all sharding designs.
Should be off-loaded by various caches as much as possible.

### Databases for shards

They should all have the same power (CPU/RAM/IO) -
this will speed things up because you can just randomly select shard for your new or migrated client without bothering with different hardware capabilities.

Configuration of shard databases is pretty straightforward.
For every shard just install `shard_schema.sql`, feed `context_data.sql` file and follow two more steps.

### Databases for shards - users

Remember that context tables should be identical on all shards.
Therefore it is a good idea to have separate user with read-write grants for managing context data.
Application user should have read-only access to context tables to prevent accidental context data change.

This ideal design may be too difficult to maintain - every new table will require setting up separate grants.
If you decide to go with single user make sure you will add some mechanism that monitors context data consistency across all shards.

### Databases for shards - mutually exclusive primary keys

Primary keys in client tables ***must be globally unique across whole product***.

First of all - data split is a long process. Just pushing data between databases may take days or even weeks!
And because of that it should be performed without any global downtime.
So during monolithic to shard migration phase new rows will still be created in monolithic database
and already migrated users will create rows on shards. Those rows must never collide.

Second of all - sharding does not end there.
Later on you will have to load balance shards, move client between different physical locations, backup and restore them if needed.
So rows must never collide at any time of your product life.

How to achieve that? Use offset and increment while generating your primary keys.

MySQL has ready to use mechanism: 

* auto_increment_increment - Set this global variable to 100 on all of your shards. That is also the maximum amount of shards you can have. Be generous here, as it will not be possible to change it later! You must have spare slots even if you don't have such amount of shards right now!
* auto_increment_offset - Set this global value differently on all of your shards. First shard should get 1, second shard should get 2, and so on. Of course you cannot exceed value of auto_increment_increment.

Now your first shard for any table will generate 1, 101, 201, 301, ... , 901, 1001, 1101 auto increments and second shard will generate 2, 102, 202, 302, ... , 902, 1002, 1102 auto increments.
And that's all! Your new rows will never collide, doesn't matter which shard they were generated on and without any communication between shards needed.

TODO: add recipes for another database types

Now you should understand why I've told you to convert all numerical primary and foreign keys to unsigned big integers. The sequences will grow really fast, in our example 100x faster than on monolithic database.

***Remember to set the same increment and corresponding offsets on replicas.*** Forgetting to do so will be lethal to whole sharding design.

### Checkpoint

Your database servers should be set up. Check routings from application, check user grants.
And again - remember to have correct configurations (in puppet for example) for shards and their replicas offsets.
Do some failures simulations.

And move to the next step :)

### Q&A

***Q:*** Can I do sharding without dispatch database? When client wants to log in I can just ask all shards for his data and use the one shard that will respond.

***A:*** No. This may work when you start with three shards, but when you have 64 shards in 8 different data centers such fishing queries become impossible. Not to mention you will be very vulnerable to brute-force attacks - every password guess attempt will be multiplied by your application causing instant overload of the whole infrastructure.


***Q:*** Can I use any no-SQL technology for dispatch and neutral databases?

***A:*** Sure. You can use it instead of traditional SQL or as a supplementary cache.

## Adapt code

### Product

There will be additional step in your product. When user logs in then dispatch database must be asked for shard number first. Then you connect to this shard and... it works!
Your code will also have to use separate database connection to access neutral data.
And it will have to roll shard when new client registers and note this selection in dispatch database.

That is the beauty of whole clients sharding - majority of your code is not aware of it.

### Synchronization of common data

If you modify neutral data this change should be propagated to every neutral database (you may have more of those in different physical locations).

Same thing applies to context data on shard, but ***all auto increment columns must be forced***. This is because every shard will generate different sequence. When you execute ```INSERT INTO skins (color) VALUES ('#AA55BC')``` then shard 1 will assign different IDs for them than shard 2. And all client data that reference this language will be impossible to migrate between shards.

### Dispatch

Dispatch serves two purposes. It allows you to find client on shard by some unique attribute (login, email, and so on)
and it also helps to guarantee such uniqueness. So for example when new client is created then dispatch database must be asked if chosen login is available. Take an extra care of dispatch database. Off-load as much as you can by caching and schedule regular consistency checks between it and the shards.

Things get complicated if you have shards in many data centers. Unfortunately I cannot give you universal algorithm of how to keep them in sync, this is too much application specific.

### Analytic tools

Because your clients data will be scattered across multiple shard databases you will have to fix a lot of global queries used in analytical and statistical tools. What was trivial previously - for example `SELECT city.name, COUNT(*) AS amount FROM clients JOIN cities ON clients.city_id = cities.id GROUP BY city.name ORDER BY amount DESC LIMIT 8` - will now require gathering all data needed from shards and performing intermediate materialization for grouping, ordering and limiting.

There are tools that helps you with that. I've tried several solutions, but none was versatile, configurable and stable enough that I could recommend it.

### Make a wish-ard 

We got to the point when you have to switch your application to sharding flow.
To avoid having two versions of code - old one for still running monolithic design and a new one for sharding, we will just connect monolithic database as another "fake" shard.

First you have to deal with auto increments. Set up in the configuration the same increment on your monolithic database as on shards and set up any free offset. Then check what is the current auto increment value for every client or context table and set the same value for this table located on every shard. Now your primary keys won't collide between "fake" and real shards during the migration. But beware: this can easily overflow tiny or small ints in your monolithic database, for example just adding three rows can overflow tiny int unsigned capacity of 255.

After that synchronize data on dispatch database - every client you have should point to this "fake" shard. Deploy your code changes to use dispatch logic.

### Checkpoint

You should be running code with complete sharding logic but on reduced environment - with only one "fake" shard made out of your monolithic database. You may also already enable creating new client accounts on your real shards.

Tons of small issues to fix will pop up at this point. Forgotten pieces of code, broken analytics tools, broken support panels, need of neutral or dispatch databases tune up.

And when you squash all the bugs it is time for grande finale: clients migration.

## Migrate clients to shards

### Downtime semaphore

You do not need any global downtime to perform clients data migration. Disabling your whole product for a few weeks would be unacceptable and would cause huge financial loses. But you need some mechanism to disable access for individual clients while they are migrated. Single flag in dispatch databases should do, but your code should be aware of it and present nice information screen for client when he tries to log in. And of course do not modify clients data.

### Timing

If you have some history of your client habits - use it. For example if client is usually logging in at 10:00 and logging out at 11:00 schedule his migration to another hour. You may also figure out which timezones clients are in and schedule migration for the night for each of them. The migration process should be as transparent to client as possible. One day he should just log in and bam - fast and responsive product all of a sudden.

### UpRooted tool

Ready for some heavy lifting?
[UpRooted](https://github.com/bbkr/UpRooted) tool for [Raku](https://www.raku.org) language allows to read tree of data from relational database and write it directly to another database. Here is example for MySQL:


```
    use DBIish;
    use UpRooted::Schema::MySQL;
    use UpRooted::Tree;
    use UpRooted::Reader::MySQL;
    use UpRooted::Writer::MySQL;
    
    my $monolithic-connection = DBIish.connect( 'mysql', host => ..., port => ..., ... );
    my $shard-connection = DBIish.connect( 'mysql', host => ..., port => ..., ... );
    
    # discover schema
    my $schema = UpRooted::Schema::MySQL.new( connection => $monolithic-connection );
    
    # define which table is root of data tree
    my $tree = UpRooted::Tree.new( root-table => $schema.table( 'clients' ) );
    
    # monolithic database is the source of data
    my $reader = UpRooted::Reader::MySQL.new( connection => $monolithic-connection, :$tree );

    # shard database is destination for data
    my $writer = UpRooted::Writer::MySQL.new( connection => $shard-connection );
    
    # start cloning client of id = 1
    $writer.write( :$reader, id => 1 );
```

Update dispatch shard for this client, check that product works for him and remove his rows from monolithic database.

Repeat for every client.

### MySQL issues

Do not use user with SUPER grant to perform migration. Not because it is unsafe, but because they do not have locales loaded by default. You may end up with messed character encodings if you do so.

MySQL is quite dumb when it comes to cascading DELETE operations. If you have such schema

```
            +----------+
            | clients  |
            +----------+
 +----------| id       |----------------+
 |          | login    |                |
 |          | password |                |
 |          +----------+                |
 |                                      |
 |  +-----------+        +-----------+  |
 |  | foo       |        | bar       |  |
 |  +-----------+        +-----------+  |
 |  | id        |----+   | id        |  |
 +-<| client_id |    |   | client_id |>-+
    +------------+   +--<| foo_id    |
                         +----------+
```

and all relations are ON DELETE CASCADE then sometimes it cannot resolve proper order and may try to delete data from `foo` table before data from `bar` table, causing constraint error. In such cases you must help it a bit and manually delete clients data from `bar` table before you will be able to delete row from `clients` table.


## Cleanup

When all of your clients are migrated simply remove your "fake" shard from infrastructure.

## Contact

If you have any questions about database sharding or want to contribute to this guide or Exodus tool contact me in person or on IRC as "bbkr".

# Congratulations

YOU'VE PROVEN TOO TOUGH FOR [monolithic database design] HELL TO CONTAIN
(DOOM quote)
