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

- E07/P22: 13 cílených EditorTests prošlo v Release na macOS 15.7.4. Nový test nad skutečným NSTextView doplnil duplikaci posledního řádku bez koncového LF, řazení a přesun po psaní. První undo vrátí jen příkaz, druhé předchozí psaní, dvě redo obnoví výsledek. Ve všech šesti kombinacích příkazu a LF/CRLF skutečné `app.save` zapsalo přesné očekávané bajty. Spolu s dosavadními testy českého řazení, duplicit, prázdných řádků, hranic výběru a data je řádková přejímka doložená.

- P07–P10 nad sestavením `336e769`: smazaný otevřený soubor s neuloženou změnou přežil Cmd+Q a nový proces včetně kurzoru; Uložit kopii vytvořilo přesné očekávané bajty. Zápis do skutečného adresáře bez oprávnění ukázal chybu a uložení kopie jinam zachovalo celou změnu i původní soubor.
- S vypnutou obnovou v odděleném nastavení aplikace: Zrušit při zavření okna i Cmd+Q ponechalo rozepsaný text a dovolilo pokračovat. Zrušení následného ukládacího dialogu také zachovalo text. Uložit při zavření okna a při ukončení zapsalo přesné bajty; Zahodit zavřelo okno, respektive ukončilo proces. Nové spuštění zobrazilo prázdnou poznámku, relace měla prázdný seznam oken a uložené dokumenty se nezměnily.
- Skutečné selhání snímku vyvolané příznakem neměnnosti pouze testovací zálohy: zavření okna oznámilo chybu a okno ponechalo otevřené. Cmd+Q dovolilo zůstat a dál psát. Nouzová cesta Uložit poznámky a ukončit nenabídla zahození; výslovné uložení zachovalo celý text v souboru a proces skončil. Stará obnova zůstala beze změny. Testovací příznak byl následně odstraněn.
- Poškození hlavní kopie před novým spuštěním obnovilo úplný text ze zálohy s viditelným upozorněním. Další řádné ukončení vytvořilo dvě platné kopie. Nahrazení hlavní kopie schématem 999 vedlo k viditelné chybě; po nouzovém ukončení zůstala novější hlavní kopie i starší záloha byte-for-byte zachovaná. Odmítnutí dvou poškozených kopií a novějšího schématu v kterékoli kopii navíc pokrývají automatické testy.
- P08: devět samostatných procesů používalo nezměněný Release framework MacPadCore z `336e769`. Testovací knihovna ukončila proces signálem SIGKILL před/po odstranění zálohy, po částečném zápisu do dočasného souboru, před/po synchronizaci a před/po přejmenování hlavní i záložní kopie. Každý zásah potvrdil konkrétní kontrolní bod a návratový stav SIGKILL. Nový proces vždy načetl celou starou relaci před nahrazením hlavní kopie, nebo celou novou po něm. Nejde o zkoušku výpadku napájení.


- Revize `336e769`: výběr kódování v dialogu Otevřít i při chybných bajtech, s viditelným náhledem. Před úpravou velikosti náhledu prošla celá sada 132 testů (48 core + 84 AppKit); po této úpravě všechny tři cílené testy včetně viditelné plochy náhledu a asynchronního načtení uvnitř modálního dialogu. Následný GUI průchod ověřil UTF-16 LE bez BOM a Windows-1250 s ruční volbou a českým náhledem. UTF-8, UTF-8 BOM, UTF-16 LE/BE s BOM, UTF-16 LE bez BOM a Windows-1250 po Cmd+S zachovaly SHA-256 původních bajtů včetně LF/CRLF. Chybné UTF-8 mělo zakázané otevření; Zrušit zachovalo soubor i počet karet.
- GUI P01/P02/P05: český text a emoji vložené současně jako plain text a barevný tučný RTF skončily jako čistý text. Uvozovky a dvě pomlčky zůstaly beze změny, dvě undo/redo a přepínání karet zachovaly oddělené změny. Uložené bajty odpovídaly UTF-8 bez BOM s CRLF. Více souborů včetně souboru bez přípony, symlinku a hardlinku vytvořilo jen dvě identity; skutečný Finder alias přetažený na aplikaci aktivoval původní kartu bez duplikace.
- GUI P03 a část P09: skutečné ENOSPC na omezeném 64 MiB testovacím svazku zachovalo původní soubor a všech 2 162 688 bajtů rozepsaného obsahu v obnově. Uložit kopii mimo plný svazek uložilo přesné bajty. Zrušení následného Uložit jako zachovalo identitu a další neuloženou změnu; potvrzené přepsání existujícího cíle uložilo správné bajty bez změny starší kopie. Testovací svazek byl odpojen. Systémový disk nebyl zaplněn.
- GUI P11 na `336e769`: Nahradit vše změnilo tři výskyty `alpha` na `omega` ve dvou řádcích. Po kliknutí zpět do editoru jediné Cmd+Z obnovilo celý původní text; kontrolováno také v obnovovací relaci.


- Revize `f594ac1`: celá sada 129 testů v Release na macOS 15.7.4 / Apple Silicon (48 core, 81 AppKit) a následně šest cílených testů rozdělení s doplněným ověřením samostatného posunu. R01/P24 pokrývá jediný sdílený text a undo, jednu synchronizaci revize na úpravu, samostatné výběry a posun, zachování undo po zavření rozdělení a přesunu do jiného okna, ukládání podle aktivního panelu, jedinečnost dokumentů v relaci, zamknutí obou pohledů a voličů, stejné názvy dokumentů, reload a souběžný náhled Markdownu.
- GUI P24 stejné revize přes VNC: úprava stejného dokumentu zleva i zprava se ihned zobrazila v obou pohledech. Undo/redo z pravého panelu zachovalo dřívější úpravu vlevo. Pravý panel byl přepnut na jiný soubor a Cmd+S uložilo správný soubor bez změny levého. Po zavření rozdělení přes Escape dál fungovalo undo pravého pohledu; na disku se změna projevila až po výslovném uložení. Relace obsahovala právě dva dokumenty a správnou aktivní kartu, bez duplicit. Cmd+Q ukončil ověřený proces. Rozdělení je dočasné; relace dál obnovuje dokumenty a kurzor naposledy aktivního dokumentu.

- Revize `74fd171`: 123 testů v Release na macOS 15.7.4 / Apple Silicon (48 core, 75 AppKit). Náhled R02/P25 používá vestavěný parser Foundation a vlastní vykreslení do NSTextView, bez další závislosti nebo webového zobrazení. Testy ověřují nadpisy, seznamy, úkoly a řez písma, neaktivní HTML a obrázky, povolená schémata odkazů, průběžnou aktualizaci, přepnutí karty, zachování textu, výběru a undo a vrácení celé šířky po zavření náhledu.
- GUI P25 stejné revize ve světlém i tmavém režimu: skutečný Markdown vedle náhledu, obrázek jen jako popisek, HTML a skript jako neaktivní text. Místní kontrolní HTTP server nedostal žádný požadavek při zobrazení ani po kliknutí na `javascript:`. Až kliknutí na povolený odkaz otevřelo přesnou testovací adresu v prohlížeči; server zaznamenal tuto návštěvu a ikonu prohlížeče, nikoli obrázky nebo skript z dokumentu. Po Cmd+S i restartu zůstal SHA-256 zdrojového souboru stejný. Oba procesy MacPadu ukončené přes Cmd+Q i pomocný server byly uzavřeny; snímky a podrobné logy zůstaly mimo Git.

- Revize `9578ba3`: 120 testů v Release na macOS 15.7.4 / Apple Silicon (48 core, 72 AppKit). R03/P26 pokrývá archivaci skutečných nahrazených bajtů až po úspěšném zápisu, vypnutou historii, počty a stáří verzí, společný limit velikosti, poškozený archiv, úklid přerušeného zápisu při startu, mazání a zrušení čekající obnovy po mazání. Selhání archivace vyvolalo upozornění, ale skutečný soubor byl správně uložen. Obnovená verze vytvořila nový koncept a ponechala novější soubor i další neuložené změny původního dokumentu.
- GUI P26 stejné revize: uložená nová verze vytvořila jeden archiv původního českého textu a emoji s CRLF. Další neuložená změna se zachovala při obnově staré verze do nové karty. Její následné výslovné zahození historii nerozšířilo. Mazání historie souboru i celé historie přes nastavení odstranilo skutečné archivy a zachovalo soubor i obnovený koncept; ověřeny bajty souboru a obsah relace. Nastavení zobrazilo limity a informaci o nešifrovaném uložení. Cmd+Q ukončil testovací proces. Historie byla pro tento izolovaný běh zapnutá argumentem spuštění; fyzické klávesy se tímto neověřují.

- Revize `f212946`: 110 testů v Release na macOS 15.7.4 / Apple Silicon (42 core, 68 AppKit). Nové porovnání R04/P27 má testy českých řádků a různých zápisů Unicode, odlišných konců řádků, původního kódování při plánovaném převodu UTF-8/Windows-1250, odmítnutí zastaralé diskové i vlastní revize, potvrzeného přepsání a načtení zobrazené verze. Zároveň prošly dosavadní testy ukládání a obnovy.
- GUI P27 stejné revize: otevření porovnání z příkazů, dvě verze pouze ke čtení s čísly a značkami řádků, český text a emoji, CRLF proti LF. Další změna skutečného souboru zneplatnila porovnání a zakázala načtení i přepsání. Obnovení zobrazilo novou revizi. Zrušení potvrzení zachovalo obě verze; potvrzené přepsání uložilo přesné bajty UTF-8 s CRLF. Cmd+Q ukončil ověřený testovací proces. Celý průchod používal izolovanou relaci a smyšlený dokument.

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
- Prověřit ACL a rozšířené atributy souborů.
- Otestovat macOS 14, Intel a distribuční balíček před jejich označením za podporované.

## Sdílený testovací Mac

Vzdálené testy používají samostatnou pracovní složku a izolovaná data. Před dávkou se kontrolují cizí buildy a testy, VNC spojení a poslední vstup do stroje. Pro testovací dávku se drží společná rezervace; hlídač ukončí vlastní běh při zjištění cizí aktivity. Samotné označení relay jako idle nestačí. V této relaci kontrola zachytila cizí sestavení a naše testy se tehdy nespustily.

Rezervace sama nezabrání nástroji, který ji nerespektuje, v přístupu k obrazovce. Proto se kontrola aktivity opakuje a cizí procesy se neukončují. Konkrétní přístupy, adresy a soukromé logy nejsou součástí repozitáře.
