# Tema: Gestioneare simplificată a dispozitivului de stocare (Assembly)

## Descriere scurtă

Acest proiect implementează o componentă simplificată de management al dispozitivului de stocare (hard-disk/SSD) — parte dintr-un sistem de operare minimalist. Scopul este simularea operațiilor de **ADD**, **GET**, **DELETE** și **DEFRAGMENTATION** pentru două modele de memorie:

* **Unidimensional (linie)** — memorie reprezentată ca un vector de blocuri.
* **Bidimensional (matrice)** — memorie reprezentată ca o matrice de blocuri (stocare pe linii).

Proiectul respectă constrângerile din cerință: capacitate, dimensiuni blocuri, identificatori unici (descriptor între 1 și 255) și reguli de alocare contiguă.

---

## Puncte cheie și convenții

* **Capacitate totală (teoretică):** 8 MB (în cerință). Pentru demonstrații și teste se folosește o versiune redusă (ex.: 8kB → 8B / bloc) — implementarea folosește conversiile indicate în enunț.
* **Dimensiune bloc:** 8 kB (în cerință). Pentru reprezentare demonstrativă se folosește 8 B.
* **Descriptor fișier:** număr natural între `1` și `255`. Valoarea `0` în bloc înseamnă bloc liber.
* **Reguli esențiale:** fișierul trebuie stocat **contigu** (pe un interval de blocuri). Un fișier are nevoie de cel puțin două blocuri.
* **Unități:** 1 MB = 1024 kB, 1 kB = 1024 B.

---

## Funcționalități implementate

Pentru ambele moduri (1D și 2D) programul suportă următoarele operații:

* `ADD` — alocă primul interval liber (parcurgere stânga → dreapta) pentru fișierele cerute; afișează intervalul alocat sau `fd: ((0, 0), (0, 0))` / `fd: (0, 0)` dacă nu se poate aloca.
* `GET` — returnează intervalul în care este stocat descriptorul dat (sau `(0,0)`/`((0,0),(0,0))` dacă nu există).
* `DELETE` — eliberează blocurile ocupate de descriptor (setează blocurile la `0`) și afișează memoria curentă.
* `DEFRAGMENTATION` — rearanjează blocurile astfel încât fișierele să fie stocate compact păstrând ordinea (1D: compactare spre stânga; 2D: compactare liniară pe linii, goluri mutate spre dreapta-jos).

În plus, pentru modul bidimensional:

* `CONCRETE (cod 5)` — parcurge un director specificat, obține fișierele din director, calculează un descriptor (fd real modulo 255 + 1) și dimensiunea în kB și tratează fiecare fișier ca un `ADD`. Dacă descriptorul calculat este duplicat, afișează `fd: ((0, 0), (0, 0))` și nu îl adaugă.

---

## Formatul inputului

Programul citește de la `stdin`. Prima linie: numărul de operații `O`. Pentru fiecare operație, o linie cu codul operației:

* `1` — ADD
* `2` — GET
* `3` — DELETE
* `4` — DEFRAGMENTATION
* `5` — CONCRETE (doar în 2D)

**ADD:** după codul `1` urmează o linie cu `N` (numărul de fișiere), apoi `2*N` linii: pentru fiecare fișier, pe rând, `descriptor` și `dimensiuneîn_kB`.

**GET / DELETE:** după codul operației urmează o linie cu `descriptor`.

**CONCRETE:** după codul `5` urmează o linie cu *path* absolut către folder.

---

## Exemplu de rulare (testare locală)

Creați un fișier `input.txt` cu input-ul dorit, apoi rulați executabilul corespunzător redirecționând `stdin`:

```bash
# Exemplu unidimensional (task00)
./task00 < input.txt

# Exemplu bidimensional (task01)
./task01 < input.txt
```

**NOTĂ:** nu introduceți manual input la fiecare test — folosiți fișiere `input0.txt`, `input1.txt` etc. pentru a automatiza retestarea.

---

## Structură recomandată proiect

(sugestiv — adaptați după cum este structurat codul în repo)

```
/ (root)
├─ src/                # surse (assembly / C helper / scripturi)
├─ build/              # fișiere compilate / executabile
├─ tests/              # fișiere input de test și output așteptat
├─ README.md
└─ Makefile / build.sh  # scripturi de compilare / rulare
```

---

## Note de implementare și optimizări (sugestii)

* **ADD 1D:** parcurgere liniară a vectorului, căutare primul interval de blocuri libere de lungime suficientă.

* **GET 1D:** căutare rapidă a primului bloc cu descriptorul dat sau păstrarea unei tabele (map) descriptor → interval (dacă memorie). Păstrați consistența după DELETE și DEFRAGMENTATION.

* **DELETE 1D:** setare blocuri la `0` pentru descriptorul dat; actualizați structurile auxiliare.

* **DEFRAGMENTATION 1D:** copiați fișierele non-zero în stânga, păstrând ordinea apariției; actualizați intervalele retur.

* **ADD 2D:** pentru fiecare linie încercați să găsiți un interval contigu pe aceeași linie; dacă nu există, treceți la următoarea linie. Returnați coordonatele de start și end `((x1,y1),(x2,y2))`.

* **DEFRAGMENTATION 2D:** „flatten” pe linii (linie-major), mutați blocurile ocupate cât mai mult în sus-stânga, păstrând ordinea de apariție; golurile se vor acumula în dreapta-jos.

---

## Exemple de output (format)

* **ADD 1D:** `%d: (%d, %d)\n` (descriptor, start, end) sau `fd: (0, 0)` dacă nu încape.

* **GET 1D:** `(%d, %d)\n`.

* **DELETE / DEFRAGMENTATION 1D:** afișare memorie (vector) după operație.

* **ADD 2D:** `%d: ((%d, %d), (%%d, %d))\n` (descriptor, (startX,startY), (endX,endY)) sau `fd: ((0,0),(0,0))` dacă nu se poate.

* **GET 2D:** `((%d, %d), (%d, %d))\n`.

---

## Testare și validare

* Pregătiți seturi de fișiere `inputX.txt` care acoperă cazuri: alipire fără spațiu, spații sparte (gap-uri), DELETE la descriptor inexistent, DEFRAGMENTATION după mai multe operații, CONCRETE (folder cu fișiere) etc.
* Verificați corectitudinea intervalelor și consistența memoriei după fiecare operație.

---

## Limitări cunoscute

* Alocarea este *fără* compactare automată — dacă nu există un interval contiguu suficient, `ADD` va eșua; scopul este să evidențieze comportamentul real al unor scheme simple de alocare.
* Implementarea CONCRETE depinde de comportamentul sistemului de fișiere (special pentru calculul descriptorului modul 255 + 1).

---

## Contribuții / Extinderi posibile

* Implementarea unui index (tabel) descriptor → interval pentru operații `GET` rapide.
* Algoritmi de alocare alternativi: `best-fit`, `first-fit` (deja folosit), `worst-fit`.
* Suport pentru fișiere non-contigue (cataring) și o structură de fișiere cu metadate reale.

---

## Autor 

Balaceanu Rafael Gabriel 

---

Doriți să ajustez README (mai multă documentație tehnică, exemple de input/output compacte, sau un model `Makefile` + instrucțiuni de compilare)?
