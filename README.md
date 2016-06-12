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
* Create data centers in different countries to reduce network lag for clients and be more compliant with local data processing laws.
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
| | password |   |  | name       |      +-----------+
| | login    |   |  +------------+
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

They put your clients data in context. To find them follow every child-to-parent relation (only in this direction) from every client table as shallow as you can. Stop ascending if table is already classified. In this case we ascend from `clients` to `cities` and from `cities` further to `countries`. Then from `rentals` we can ascend to `clients` (already classified), `cities` (already classified) and `cars`. And from `tracks` we can ascend into `rentals` (already classified). So our context tables are: `cities`, `countries` and `cars`.

Context tables should be synchronized across all shards.

### Neutral tables

Everything else. They must not be reachable from any client or context table through any relation. However there may be relations between them. So our neutral tables are: `anti_fraud_systems` and `blacklisted_credit_cards`.

Neutral tables should be moved outside of shards.







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
