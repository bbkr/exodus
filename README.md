# EXODUS

Tools and comprehensive guide to split monolithic database into shards.


## Intro

Most of the companies start their businesses using monolithic database. And when they got successful they quickly become victims of this design.
Single machine cannot be scaled up infinitely and single internet connection becomes overloaded with traffic from whole world.
Also good product attracts big clients who alone can generate significant system load causing slowdowns for the rest.
If this sounds familiar then it is time for database sharding.

Main goal of sharding is to distribute your clients data across multiple database machines, that can also be in different physical locations.

## Understanding your data

Your data can be divided into three groups:

* User data. Rows that belongs to given user. They form a relational tree starting from `users` table (it is such a common naming that it will be used throughout this guide). Those records will be moved together to a single shard,

* Default data. Rows that are referenced by user data. They should be identical on all shards.

* Global data. Tables that are not related to user or default data.

Lets consider following schema.
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



Uwaga: Rekordy, nie tabele. (przykład)

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
