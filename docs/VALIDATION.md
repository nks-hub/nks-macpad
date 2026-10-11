# Review a ověření

Review výchozí revize `f80f289` proběhlo 9.–10. 10. 2026. Opravy jsou v `4cabb89`, `45bf1b5`, `e059f51`, `7589e72` a `b39439c`. Testy průběžných úprav textu přidává `cf30bfb`, sestavení pro Release testy upravuje `6ec082b`.

Druhé review proběhlo 10. 10. 2026 nad `92ddf62`. Opravy jsou v `b3f2c5b`, `eadb1b1`, `eaa73bf`, `f5832f9`, `b0b386d`, `8f8ec36` a `82ab271`; tři z nich našel až průchod skutečnou aplikací. Pro přejímku se používají scénáře z [plánu](../PLAN.md).

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
| Více procesů | Výhradní zámek `session.lock`; druhý proces nad stejnou složkou ohlásí chybu a skončí dřív, než cokoli zapíše | Test zámku a dva skutečné procesy MacPadu: zámek drží jen první |
| Načtení karty na pozadí | Výběr se zkrátí spolu s textem, takže kratší soubor po „Znovu načíst“ už neblokuje zápis celé relace | Regresní test s uloženou relací |
| Ukončení s vypnutou obnovou | Nečitelná stará relace už nebrání ukončení; soubory zůstanou beze změny | Kontrola větve ukončení |
| Externí změna | Windows-1250 a UTF-16 bez BOM se po přepsání souboru nenačtou potichu znovu, karta dostane upozornění | Regresní test s UTF-8 zapsaným do souboru Windows-1250 |
| Zápis relace | Kopie se před přejmenováním zapíší na disk (`synchronize`); nový soubor dostane práva podle umask, nahrazený si nechá svá | Test práv souboru; výpadek napájení neověřen |
| Souběžný zápis | Po zachráněné souběžné změně má karta otisk našeho zápisu, další uložení nehlásí falešný konflikt | Test otisku |
| Ctrl zkratky | Platí jen při fokusu v editoru, ne v hledacím poli; Ctrl+Shift+Tab přepíná zpět | Testy událostí; fyzická klávesnice dosud neověřena |
| Přesun karty | Okno, ze kterého odešla poslední karta, se zavře a nezůstává prázdné v relaci | Regresní test |
| Vložení a datum | Vložení ze schránky a vložení data jsou samostatný krok zpět | Test; původní spojení kroků se testem nepodařilo vyvolat |
| Písmo a panely | Volba z panelu písem se uloží do nastavení; panel příkazů nespadne na prázdném seznamu a nedávné soubory se neotevřou nad skrytým oknem | Kontrola zdroje |
| Klik na kartu | Karta pod průhledným titulkem okna přijímala klik jen ve spodních 8 bodech; vypnuté automatické odsazení posuvníku | Nalezeno v GUI, regresní test skutečnou událostí myši |
| Čísla řádků | Nová karta se zapnutými čísly řádků měla prvních 48 bodů textu pod sloupcem čísel | Nalezeno v GUI, regresní test polohy textu |
| Velikost relace | Neupravené soubory se do relace neukládají, při obnově se načtou z disku (schéma 2, verze 1 se dál načte); sedm souborů po 106 MB dělalo relaci 1,5 GB | Testy schématu a obnovy; relace 4 kB, ukončení 0,8 s |
| Výkon psaní mimo ASCII | Řádky a počet znaků se počítají průběžně i v textu s diakritikou; velké dokumenty počítají znaky mimo hlavní vlákno | Měření 10 MiB českého textu níže |

## Provedené kontroly

- Sestavení a XCTest na macOS 15.7.4, Apple Silicon, Xcode 26.3 a XcodeGen 2.44.1.
- Celkem 89 testů bez selhání v konfiguraci Release: 40 core a 49 AppKit/životní cyklus/výkon. Testované zdroje odpovídají revizi `82ab271`. Nové testy klávesových zkratek, přesunu karty a kliku na kartu bez oprav selžou.
- Devět testů průběžných úprav používá skutečný NSTextView: ASCII, kombinující diakritiku, emoji a ZWJ, dávkové změny, prázdný text, undo/redo, stav změn, metriky a obnovovací JSON.
- Dřívější GUI průchod: psaní, nová karta, uložení přes systémový dialog, přesné bajty souboru, ukončení a obnova relace, přepnutí karty, hledání příkazu a pojmenování konceptu.
- Aktuální vzhled byl spuštěn a zachycen ve světlém i tmavém režimu. Obrázky obsahují pouze smyšlené poznámky a okno aplikace.
- GUI průchod nad zdroji `7589e72`: kliknutí na druhou kartu, hledání „Sobota“ napříč kartami a přechod na správný výběr (UTF-16 pozice 17, délka 6), rychlá poznámka z nabídky příkazů a její skrytí přes Escape. Uložení systémovým dialogem ověřeno přesnými bajty UTF-8 bez BOM s CRLF. Ukončení přes nabídku aplikace potvrzeno zánikem jejího procesu. Tento průchod nepokrývá následné změny výkonu.
- GUI průchod nad zdroji `82ab271` (vstup přes VNC, oddělená datová složka): klik, přetažení a zavření karet včetně voleb Zrušit a Zahodit, kontrola obou kopií relace, nabídka v okně, nedávné soubory, nastavení, světlý a tmavý režim, čísla řádků, záznam globální zkratky ⇧⌘J, rychlá poznámka nad jinou aplikací a návrat fokusu po Escape, vložení textu s CR a CRLF, otevření sedmi souborů po 106 MB, obnova po `kill -9` a ukončení přes ⌘Q. Zrušení otevírání se v GUI nepodařilo načasovat, protože 106 MB se načte zhruba za 0,15 s; frontu pokrývá test.

## Měření výkonu

### Doplnění 11. 10. 2026

Nad zdroji revize `89800eb` prošlo v Release na stejném Macu 102 testů (40 core, 62 AppKit). Běh přes RemoteCmd skončil bez přerušení. Nové testy ověřují UTF-16 pozice hledání za emoji a odmítnutí starého výsledku po editaci, zrušení čekajícího i již běžícího hledání, kolizi a uvolnění globální zkratky, dokončení snímku před skrytím rychlé poznámky a opětovné otevření stejného konceptu. Kolize používá skutečné Carbon API; nejde o zkoušku fyzických kláves.

Pět opakování: hledání ve 20 kartách s celkem 10 MiB českého textu mělo medián 334 ms a maximum 335 ms včetně čekání 150 ms před hledáním, sestavení výsledků, rozvržení a `displayIfNeeded`. Rychlá poznámka měla 1/16 ms včetně `displayIfNeeded`; první vyvolání okno vytvořilo, další znovu zobrazila. Oba cíle (500 a 300 ms) jsou splněné pro tento postup; čas fyzického zobrazení snímku monitorem se neměřil. Jeden řádek se dvěma miliony znaků: otevření 482/485 ms, vložení znaku 2/3 ms. Toto měření nenahrazuje zbývající přejímku P14.

Další testovací Mac není dostupný. macOS 14 a fyzické Mac/Windows klávesnice zůstávají neověřené.

GUI průchod stejné revize přes VNC: běžný editor široký 440 bodů, rychlá poznámka 480 bodů, písmo 24 bodů, 20 karet, světlý i tmavý motiv. Ověřeno psaní a undo, hledání přes Cmd+Shift+F, klik na výsledek za emoji (UTF-16 rozsah 50/6), skrytí výsledků přes Escape, přepínač karet s výběrem 20. karty, příkaz pro rychlou poznámku, její obsah a skrytí přes Escape s návratem fokusu. Cmd+Q ukončil oba testovací procesy. Po novém spuštění se zachovala aktivní karta, výběr a stejná rychlá poznámka bez duplikace; obsah a identita byly ověřené i v uložené relaci. Snímky zůstávají mimo Git. VNC zde mapuje Cmd na `super`; tento vstup nedokazuje fyzickou klávesnici ani VoiceOver.

### Předchozí měření

Apple M1 Pro, 32 GiB RAM, macOS 15.7.4, Xcode 26.3. Release sestavení se zapnutou testovatelností. Každá velikost má pět vzorků nad skutečným AppKitem, souborem a krátkými řádky. Český text má řádky s diakritikou; před opravou v něm vložení znaku trvalo 83 ms. Postup je v `Tests/MacPadAppTests/PerformanceTests.swift`.

| Velikost | Otevření medián / maximum | Vložení znaku medián / maximum | Přechod na konec medián / maximum |
| --- | --- | --- | --- |
| 1 MiB | 27 / 27 ms | 3 / 4 ms | 3 / 4 ms |
| 10 MiB | 147 / 149 ms | 4 / 4 ms | 3 / 3 ms |
| 10 MiB, český text | 246 / 248 ms | 22 / 23 ms | 3 / 4 ms |
| 50 MiB | 687 / 690 ms | 9 / 9 ms | 3 / 4 ms |

Otevření zahrnuje načtení dokumentu a rozvržení viditelné části. Úprava měří vložení znaku na konec včetně synchronizace modelu, ale nezahrnuje následné vykreslení obrazovky. Výsledky nejsou měřením studeného startu, spotřeby paměti ani dlouhých jednotlivých řádků. Neprokazují splnění celé výkonové přejímky.

## Zbývající ověření

- Dokončit GUI průchod P01–P14 a P16–P23 nad aktuální revizí; starší důkaz se nepřenáší automaticky na změněné funkce.
- Ověřit fyzické klávesnice, IME a VoiceOver; vzdálený vstup není jejich náhradou.
- Doplnit měření celkové odezvy včetně vykreslení, paměti, 20 karet a dlouhých řádků podle plánu.
- Upravený soubor se do relace ukládá celý i s uloženou verzí; velký upravený soubor proto relaci dál zvětšuje.
- Prověřit ACL, rozšířené atributy a řízená selhání v jednotlivých krocích zápisu relace.
- Otestovat macOS 14, Intel a distribuční balíček před jejich označením za podporované.

## Sdílený testovací Mac

Vzdálené testy používají samostatnou pracovní složku a izolovaná data. Před dávkou se kontrolují cizí buildy a testy, VNC spojení a poslední vstup do stroje. Pro testovací dávku se drží společná rezervace; hlídač ukončí vlastní běh při zjištění cizí aktivity. Samotné označení relay jako idle nestačí. V této relaci kontrola zachytila cizí sestavení a naše testy se tehdy nespustily.

Rezervace sama nezabrání nástroji, který ji nerespektuje, v přístupu k obrazovce. Proto se kontrola aktivity opakuje a cizí procesy se neukončují. Konkrétní přístupy, adresy a soukromé logy nejsou součástí repozitáře.
