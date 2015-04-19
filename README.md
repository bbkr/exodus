# EXODUS

Tools and comprehensive guide to split monolithic database into shards.


##Intro

Most of the companies start their business using monolithic database. And when they got successful they quickly become victims of this design.
Single machine cannot be scaled up infinitely and single internet connection becomes overloaded with traffic from whole world.
Also good product attracts big clients who alone can generate significant system load causing slowdowns for the rest.
If this sounds familiar then it is time for database sharding.

Main goal of sharding is to distribute your clients data across multiple database machines, that can also be in different physical locations.



##Porzadki

Zanim przejdziesz do shardingu czeka Ciebie mnóstwo przygotowań.
Shardowane środowisko wymaga bardzo klarownego zrozumienia charakteru danych i czasami przeprojektowania schematu.

Dane użytkownika to rekordy w bazie, które będziesz przenosił na różne instancje baz danych.
Dane domyślne to rekordy do których wiążą dane użytkownika.
Dane globalne to wszystkie pozostałe rekordy.

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



jailbreak pomiedzy kontami
dane domyslne i ich synchronizacja
dane pol-domyslne i synchronizacja
relacje drzewa?
hint: named lock
unikac FK do nieunikalnych kolumn, niejednoznacznosc
uzupelnic FK
zapetlenia (nie da sie ich zrzucic w formie dumpa)
trigger

##Zaplanowanie shardow
centralna baza do dispatchu, latwa do przebudowania
unikac podejscia nowi klienci na nowym shardzie (starzy maja historie/retencje/uzycie zaawansowanych funkcji)
zapewnienie wiecznej rozdzielnosci ID
uzycie offsetu i skoku zamiast centralizacji
partycjonowanie tabel
replikacje niezalezne dla kazdego sharda
biginty, 

##Zaplanowanie kodu
rezerwacje procesow
dispatch
randomizacja shardow (nowi userzy, dane defaultowe)

##Migracja
exodus - jak uzywac
dlugo trwa
hint: uzyj historii zeby migrowac poza godzinami logowan przez uzytkownikow
ponowne porzadki

##Niespodzianki
odciazenie powoduje zwiekszenie czestotliwosci niektorych akcji
