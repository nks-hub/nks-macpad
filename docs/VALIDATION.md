# Review a ověření

Review výchozí revize `f80f289` proběhlo 9.–10. 10. 2026. Opravy jsou v `4cabb89`, `45bf1b5`, `e059f51`, `7589e72` a `b39439c`. Testy průběžných úprav textu přidává `cf30bfb`, sestavení pro Release testy upravuje `6ec082b`. Pro přejímku se používají scénáře z [plánu](../PLAN.md).

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
| Výkon editoru | Průběžná synchronizace změněného textu, cache metrik ASCII, rozvržení viditelné části a rychlejší detekce konců řádků | Testy Unicode, undo a obnovy; měření 1/10/50 MiB níže |
| Řazení a číslování | Jazyk UI pro řazení, číslo prázdného posledního řádku | Regresní testy |
| Rychlá poznámka | Nové zachycení původního fokusu při každém vyvolání | Kontrola zdroje; celý přechod mezi aplikacemi ještě zbývá |

## Provedené kontroly

- Sestavení a XCTest na macOS 15.7.4, Apple Silicon, Xcode 26.3 a XcodeGen 2.44.1.
- Celkem 76 testů bez selhání v konfiguraci Release: 37 core a 39 AppKit/životní cyklus/výkon. Testované zdroje odpovídají revizi `b39439c`. Běh skončil návratovým kódem 0 bez přerušení hlídačem sdíleného stroje.
- Devět testů průběžných úprav používá skutečný NSTextView: ASCII, kombinující diakritiku, emoji a ZWJ, dávkové změny, prázdný text, undo/redo, stav změn, metriky a obnovovací JSON.
- Dřívější GUI průchod: psaní, nová karta, uložení přes systémový dialog, přesné bajty souboru, ukončení a obnova relace, přepnutí karty, hledání příkazu a pojmenování konceptu.
- Aktuální vzhled byl spuštěn a zachycen ve světlém i tmavém režimu. Obrázky obsahují pouze smyšlené poznámky a okno aplikace.
- GUI průchod nad zdroji `7589e72`: kliknutí na druhou kartu, hledání „Sobota“ napříč kartami a přechod na správný výběr (UTF-16 pozice 17, délka 6), rychlá poznámka z nabídky příkazů a její skrytí přes Escape. Uložení systémovým dialogem ověřeno přesnými bajty UTF-8 bez BOM s CRLF. Ukončení přes nabídku aplikace potvrzeno zánikem jejího procesu. Tento průchod nepokrývá následné změny výkonu.

## Měření výkonu

Apple M1 Pro, 32 GiB RAM, macOS 15.7.4, Xcode 26.3. Release sestavení se zapnutou testovatelností. Každá velikost má pět vzorků nad skutečným AppKitem, souborem a krátkými ASCII řádky. Postup je v `Tests/MacPadAppTests/PerformanceTests.swift`.

| Velikost | Otevření medián / maximum | Vložení znaku medián / maximum | Přechod na konec medián / maximum |
| --- | --- | --- | --- |
| 1 MiB | 23 / 24 ms | 2 / 2 ms | 3 / 3 ms |
| 10 MiB | 136 / 142 ms | 3 / 4 ms | 3 / 3 ms |
| 50 MiB | 643 / 661 ms | 9 / 19 ms | 3 / 3 ms |

Otevření zahrnuje načtení dokumentu a rozvržení viditelné části. Úprava měří vložení znaku na konec včetně synchronizace modelu, ale nezahrnuje následné vykreslení obrazovky. Výsledky nejsou měřením studeného startu, spotřeby paměti, dlouhých jednotlivých řádků ani velkých Unicode dokumentů. Neprokazují splnění celé výkonové přejímky.

## Zbývající ověření

- Dokončit GUI průchod P01–P14 a P16–P23 nad aktuální revizí; starší důkaz se nepřenáší automaticky na změněné funkce.
- Ověřit fyzické klávesnice, IME a VoiceOver; vzdálený vstup není jejich náhradou.
- Doplnit měření celkové odezvy včetně vykreslení, paměti, 20 karet, dlouhých řádků a velkých Unicode dokumentů podle plánu.
- Prověřit ACL, rozšířené atributy a řízená selhání v jednotlivých krocích zápisu relace.
- Otestovat macOS 14, Intel a distribuční balíček před jejich označením za podporované.

## Sdílený testovací Mac

Vzdálené testy používají samostatnou pracovní složku a izolovaná data. Před dávkou se kontrolují cizí buildy a testy, VNC spojení a poslední vstup do stroje. Pro testovací dávku se drží společná rezervace; hlídač ukončí vlastní běh při zjištění cizí aktivity. Samotné označení relay jako idle nestačí. V této relaci kontrola zachytila cizí sestavení a naše testy se tehdy nespustily.

Rezervace sama nezabrání nástroji, který ji nerespektuje, v přístupu k obrazovce. Proto se kontrola aktivity opakuje a cizí procesy se neukončují. Konkrétní přístupy, adresy a soukromé logy nejsou součástí repozitáře.
