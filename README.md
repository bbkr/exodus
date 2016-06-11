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

In monolithic database design data classification is irrelevant but it is the most crucial part of sharding design. Your data can be divided into three groups:

* Client data - what belongs to given client. Those records will be moved together to a single shard.
* Context data - what is referenced by all clients data or another context data. Those records must be identical on all shards.
* Neutral data - everything else. Should be moved out of shards.

Let's assume your product is car rental software and do a quick exercise:

```

  +----------+      +------------+      +-----------+
  | clients  |      | cities     |      | countries |
  +----------+      +------------+      +-----------+
  | id       |   +--| id         |   +--| id        |
  | city_id  |>--+  | country_id |>--+  | name      |
  | password |   |  | name       |      +-----------+
  | login    |   |  +------------+
  +----------+   |
       |         |
       |         +------+
      / \               |     +-------+
  +---------------+     |     | cars  |
  | rentals       |     |     +-------+
  +---------------+     |  +--| id    |
+-| id            |     |  |  | vin   |
| | user_id       |     |  |  | brand |
| | start_city_id |>----+  |  | model |
| | start_date    |     |  |  +-------+
| | end_city_id   |>----+  |
| | end_date      |        |
| | car_id        |>-------+   +--------------------+
| | cost          |            | anti_fraud_systems |
| +---------------+            +--------------------+
|                              | id                 |--+
|      +-----------+           | name               |  |
|      | tracking  |           +--------------------+  |
|      +-----------+                                   |
+-----<| rental_id |                                   |
       | latitude  |     +--------------------------+  |
       | longitude |     | blacklisted_credit_cards |  |
       | timestamp |     +--------------------------+  |
       +-----------+     | anti_fraud_system_id     |>-+
                         | number                   |
                         +--------------------------+
```

To find client data you must start in some root. In our example this is `clients` table. Then follow every parent-to-child relation as . In this case 

So you start at root of your clients data. That is `clients` table. And 
Lets consider following schemaeverything else.
(MySQL slang is used but the same principles apply for PostrgeSQL and other engines)

```sql
CREATE TABLE countries (
  	id integer unsigned NOT NULL AUTO_INCREMENT,
  	name varchar(128) NOT NULL,
  	PRIMARY KEY (id),
  	UNIQUE KEY (name)
) ENGINE=InnoDB;

CREATE TABLE users (
  	id integer unsigned NOT NULL AUTO_INCREMENT,
  	country_id integer unsigned NOT NULL,
  	login varchar(128) NOT NULL,
  	password varchar(64) NOT NULL,
  	PRIMARY KEY (id),
	FOREIGN KEY (country_id) REFERENCES countries (id)
) ENGINE=InnoDB;

CREATE TABLE visits (
  	user_id integer unsigned NOT NULL,
  	logged_in timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  	logged_out timestamp NULL DEFAULT NULL,
  	FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE skins (
  	id integer unsigned NOT NULL AUTO_INCREMENT,
  	user_id integer unsigned DEFAULT NULL,
  	color bigint unsigned NOT NULL,
  	PRIMARY KEY (id),
  	FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE blacklisted_credit_cards (
	hash char(32) NOT NULL,
	UNIQUE KEY (hash)
) ENGINE=InnoDB;

```

Every row in `users` and `visits` table belongs to user data. They can be identified by descending through every parent-to-child relations starting from main user row.
User data references `countries` table, so rows there will fall into default data category. They can be identified as every remaining rows reachable through any relations starting from main user row.
And `blacklisted_credit_cards` is obviously global data, not reachable through any relation from `users`.

But what about `skins` table? In this example you provide few predefined interface skins to choose from but user can define his own. 

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
