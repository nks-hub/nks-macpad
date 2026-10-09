# MacPad

MacPad je nativní textový editor pro macOS s ovládáním inspirovaným Poznámkovým blokem ve Windows 11. Vývojová verze 0.1.0 používá Swift a AppKit.

## Rozhraní a funkce

- Dokumentové karty v horní části okna, ikony, označení změn, zavírání a přesun mezi okny.
- Nabídky Soubor, Úpravy a Zobrazení přímo v okně, tlačítko nastavení a oddělený stavový řádek.
- Připnutí karet, vlastní názvy konceptů a rychlé vyhledání karty nebo příkazu.
- Čistý text, undo/redo, hledání a nahrazování, hledání napříč otevřenými kartami.
- Uložit, Uložit jako, Uložit vše a ochrana před nechtěným přepsáním externí změny.
- Obnova rozepsaných poznámek bez přepisování původních souborů.
- Rychlá poznámka, volitelná položka v horní liště macOS a nastavitelná globální zkratka.
- Zalamování, přiblížení, písmo, čísla řádků, soustředění a okno navrchu.
- UTF-8, UTF-16 a Windows-1250, zachování BOM a konců řádků.
- České a anglické rozhraní, světlý, tmavý a systémový vzhled.

Jde o stav implementace, nikoli potvrzení dokončené verze 1.0. Novější úpravy rozhraní, nastavení, schránky a otevírání souborů zatím nebyly sestavené ani otestované. Testování je nyní odložené.

## Sestavení

Použité vývojové nástroje: Xcode 26.3 a XcodeGen 2.44.1. XcodeGen musí být v PATH, případně proměnná XCODEGEN ukazuje na jeho spustitelný soubor.

```sh
bash scripts/build.sh build
open build/DerivedData/Build/Products/Debug/MacPad.app
```

Pro pozdější spuštění testů:

```sh
bash scripts/build.sh test
```

Projekt MacPad.xcodeproj se generuje z project.yml a není verzovaný. Sestavení je vývojové a nepodepsané; není určené k veřejné distribuci.

Bundle identifier aplikace je `com.nkshub.macpad`, společné knihovny `com.nkshub.macpad.core`. Cílové minimum je macOS 14. Dosavadní běh byl ověřován pouze na macOS 15.7.4 na Apple Silicon; podporu jiných verzí a Intel Maců nelze zatím potvrdit.

## Stav ověření

Před odložením testování prošel běh 41 automatických testů. Přes skutečné GUI proběhlo psaní, vytvoření karty, uložení do souboru, ukončení a obnova relace, přepnutí karty, vyhledání příkazu a pojmenování konceptu. Byl zobrazen upravený tmavý vzhled.

Zdrojové soubory se po tomto běhu dále změnily. Uvedené výsledky proto nepotvrzují aktuální revizi. Zbývá ověřit nové změny, dokončit průchod funkcí, světlý vzhled, přístupnost, fyzické klávesnice, větší soubory a výkonové cíle.

## Data

Rozepsané koncepty se ukládají lokálně do `~/Library/Application Support/MacPad`. Vývoj a testy mohou použít oddělenou složku přes proměnnou `MACPAD_SESSION_DIR`. Koncepty nejsou vlastní šifrovaný trezor.

Soubory na disku se mění až po příkazu k uložení. Vzácný souběžný zápis jiného programu může vytvořit obnovovací soubor s jeho verzí; aplikace ukáže jeho cestu. Zahození konceptu jej odstraní z obou obnovovacích kopií.

## Další práce

- [Analýza a návrh chování](docs/plans/2026-10-09-macpad-design.md)
- [Plán implementace a ověření](PLAN.md)
- [Seznam úkolů](TODO.md)

Rozdělený pohled, Markdown náhled, historie uložených verzí a porovnání změn jsou návrhy pro verzi 1.1. Licence, podepisování, notarizace a veřejné vydání zůstávají otevřené.

Přístupy, osobní poznámky, místní konfigurace, podpisové klíče, logy a snímky testovací plochy nepatří do Gitu. Testovací soubory obsahují pouze umělá data.
