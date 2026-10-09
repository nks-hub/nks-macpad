# Review a ověření

Review výchozí revize `f80f289` proběhlo 9.–10. 10. 2026. Opravy jsou v `4cabb89`, `45bf1b5`, `e059f51` a `7589e72`. Pro přejímku se používají scénáře z [plánu](../PLAN.md).

## Opravené nálezy

| Oblast | Oprava | Doložení |
| --- | --- | --- |
| Uložit vše | Zavírání nemůže předběhnout dávku a uložit již zahozený dokument; před krokem se kontroluje vlastnictví dokumentu | Regresní test životního cyklu |
| Selhání obnovy při ukončení | Nouzová cesta s ponecháním staré obnovy nenabízí nepravdivé zahození konceptu | Kontrola větve ukončení; úplný GUI scénář ještě zbývá |
| Zápisy relace | Jediný probíhající zápis, sloučený nejnovější stav a čekatelé na dokončení | Opakované požadavky na flush a test poslední revize |
| Odstranění karty | Strukturální změna je označena před čekáním na zápis, takže starší snímek nepotvrdí neprovedené odstranění | Regresní test zavření neaktivní karty během staršího zápisu |
| Otevírání | Zrušené čekající operace neblokují nový požadavek | Regresní test fronty otevírání |
| Kódování | Priorita BOM, zachování jeho absence, správný fallback při reloadu, odmítnutí UTF-32 | Bajtové testy souborů; reload kontrolován i ve zdroji |
| Názvy a oprávnění | Krátký název konfliktní kopie, zachování původního souboru při nedostatečných právech | Skutečné soubory a adresáře pod běžným uživatelem |
| Identita relace | Odmítnutí duplicitních ID a neplatné aktivní karty, obnova z platné zálohy | Testy poškozených snímků |
| Interní nabídky | Zachování fokusu vyhledávacího pole; stabilní vazba nabídek po změně jazyka | Test responderu a nabídky |
| Výběr řádků | Správné hranice posledního vybraného řádku a opakované přesuny | Testy nad skutečným NSTextView a NSString |
| Posun a karty | Zachování posunu při obnově i aktivní karty po zavření jiné karty | Testy AppKitu |
| Klávesnice | Ctrl aliasy fungují i s CapsLock | Testy událostí; fyzická klávesnice dosud neověřena |
| Hledání | Výsledky reagují i na přidané a odstraněné dokumenty | Regresní test |
| Výkon editoru | Cache metadat karet, pozic řádků a počtu znaků; omezení výpočtu názvu konceptu | Funkční testy; cílové časy dosud nezměřené |
| Řazení a číslování | Jazyk UI pro řazení, číslo prázdného posledního řádku | Regresní testy |
| Rychlá poznámka | Nové zachycení původního fokusu při každém vyvolání | Kontrola zdroje; celý přechod mezi aplikacemi ještě zbývá |

## Provedené kontroly

- Sestavení a XCTest na macOS 15.7.4, Apple Silicon, Xcode 26.3 a XcodeGen 2.44.1.
- Celkem 64 testů bez selhání: 37 core a 27 AppKit/životní cyklus. Testované zdroje odpovídají revizi `7589e72`; následná dokumentace a obrázky nemění kód.
- Dřívější GUI průchod: psaní, nová karta, uložení přes systémový dialog, přesné bajty souboru, ukončení a obnova relace, přepnutí karty, hledání příkazu a pojmenování konceptu.
- Aktuální vzhled byl spuštěn a zachycen ve světlém i tmavém režimu. Obrázky obsahují pouze smyšlené poznámky a okno aplikace.

## Zbývající ověření

- Dokončit GUI průchod P01–P14 a P16–P23 nad aktuální revizí; starší důkaz se nepřenáší automaticky na změněné funkce.
- Ověřit fyzické klávesnice, IME a VoiceOver; vzdálený vstup není jejich náhradou.
- Změřit odezvu, paměť, 20 karet a soubory 1/10/50 MiB podle plánu.
- Prověřit ACL, rozšířené atributy a řízená selhání v jednotlivých krocích zápisu relace.
- Otestovat macOS 14, Intel a distribuční balíček před jejich označením za podporované.

## Sdílený testovací Mac

Vzdálené testy používají samostatnou pracovní složku a izolovaná data. Před dávkou se kontrolují cizí buildy a testy, VNC spojení a poslední vstup do stroje. Pro testovací dávku se drží společná rezervace; hlídač ukončí vlastní běh při zjištění cizí aktivity. Samotné označení relay jako idle nestačí. V této relaci kontrola zachytila cizí sestavení a naše testy se tehdy nespustily.

Rezervace sama nezabrání nástroji, který ji nerespektuje, v přístupu k obrazovce. Proto se kontrola aktivity opakuje a cizí procesy se neukončují. Konkrétní přístupy, adresy a soukromé logy nejsou součástí repozitáře.
