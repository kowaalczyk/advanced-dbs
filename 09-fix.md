# Kontynuacja zadanaia 9

Dzięki wydłużonej ilości czasu na zadanie, udało mi się dostać odpowiedź na swoje issue na GitHubie i zrozumieć dwa
kluczowe błędy które popełniałem korzystając z neo4j:

1. źle rozumiałem filtrowanie wierzchołków przy projekcjach grafu
2. nie korzystałem z wyrażenia `WITH` które pozwala sprytnie agregować wyniki zapytania przed przekazaniem ich do dalszej części wyrażenia

Poprawiłem wszystkie zapytania i teoretycznie jestem w stanie wykonywać wszystkie poprzednie zapytania (np. ranking autorów wg różnych wag).
Teoretycznie, ponieważ ostatnia część zadania, tj. znajdowanie spójnych składowych z jednoczesnym filtrowaniem wg wagi,
wymaga preprocessingu który jeszcze się liczy. Po przejrzeniu planów zapytań jestem jednak przekonany że optymalizacje ktore
wprowadziłem pozwolą na policzenie również tego - kiedy cięzki pre-processing polegający na łączeniu par autorów zostanie zakończony.

Szczegóły swojego podejścia, wraz z konkretnymi zapytaniami, ich wynikami i czasem wykonania umieściłem w pliku `algo.cypher`.


## Projekcje grafu i filtrowanie

Wykonując funkcję `algo.unionFind`, zakładałem początkowo że filtrowanie polega na odrzucaniu wierzchołków i relacji z wyniku.
Na szczęście eksperymentując z projekcjami grafu za pomocą `algo.Graph` zrozumiałem że wybór wierzchołków również definiuje
podgraf na którym sam algorytm jest wykonywany. Problem który definiowałem nie był więc po prostu zgodny z tym co chciałem osiągnąć.


## Użycie WITH

Pozwoliło na znaczące ograniczenie użycia pamięci przy zapytaniu tworzącym krawędzie autor-autor, dzięki czemu udało
się je wykonać w rozsądnie krótkim czasie.


## Podsumowanie

Jak się okazuje, wydajność neo4j potrafi być naprawdę dobra, 
jednak szczerze mówiąc ciężko jest mi się przyzwyczaić do mocno imperatywnej semantyki zapytań (w porównaniu do deklaratywnego SQL). 
Myślę jednak że jest to coś naturalnego, szczególnie że jest to znacznie młodszy produkt niż relacyjne bazy danych i SQL, 
które i tak nie radzą sobie dobrze z optymalizacją zapytań grafowych. Być może specyfika problemów grafowych w ogólności
wymaga bardziej imperatywnego podejścia.

Na ten moment wciąż ciężko mi porównać wydajność obu baz w rzetelny sposób, 
jednak liczę że kiedy jutro zapytania skończą się już liczyć będzie to łatwe do zrobienia.
