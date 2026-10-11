# Review a ověření

Review výchozí revize `f80f289` proběhlo 9.–10. 10. 2026. Opravy jsou v `4cabb89`, `45bf1b5`, `e059f51`, `7589e72` a `b39439c`. Testy průběžných úprav textu přidává `cf30bfb`, sestavení pro Release testy upravuje `6ec082b`.

Druhé review proběhlo 10. 10. 2026 nad `92ddf62`. Opravy jsou v `b3f2c5b`, `eadb1b1`, `eaa73bf`, `f5832f9`, `b0b386d`, `8f8ec36` a `82ab271`; tři z nich našel až průchod skutečnou aplikací. Pro přejímku se používají scénáře z [plánu](../PLAN.md).

Celá sada nad `1b8cf91` prošla 11. 10. 2026 v Release na macOS 15.7.4 / Apple Silicon: 143 testů (48 core, 95 AppKit), běh bez přerušení. Stejným postupem s `displayIfNeeded` mělo otevření 50 MiB krátkých ASCII řádků medián 746 ms a maximum 752 ms; vložení znaku 8/8 ms. Vložení znaku do 10 MiB českého textu mělo 24/24 ms. Dřívější měření níže zůstávají přiřazená ke svým revizím.

macOS 14.8.9 (23J631), arm64, Xcode 16.2: revize `49d513c` prošla 143 testy v Release (48 core, 95 AppKit) v [GitHub Actions](https://github.com/nks-hub/nks-macpad/actions/runs/38153467337). Workflow ověřil verzi OS i architekturu a skončil úspěšně. Výsledek dokládá automatickou kompatibilitu nejnižší podporované řady macOS; nejde o opakování ruční přejímky VoiceOveru a fyzických klávesnic na macOS 14.

## Opravené nálezy

Cmd+W nyní pracuje pouze s aktuálním oknem: v editoru zavře kartu, v pomocném okně použije nativní zavření. Příkaz odmítne modální dialog i sheet a sdílí původní ochrany ukládání a obnovy. Cmd+Shift+W používá nativní zavření okna. Prošlo 31 cílených testů editoru. V anglickém GUI se zapnutým VoiceOverem obě zkratky zavřely Nastavení, Cmd+W zavřelo také O aplikaci a ponechalo všech 20 karet. Zrušení zavření rozepsané karty zachovalo celý text; další Cmd+W za potvrzovacím dialogem nic nezavřelo. Zavření uložené karty snížilo počet na 19, znovuotevření jej vrátilo na 20 a soubor měl stejné bajty. VoiceOver byl nakonec vypnutý jako před zkouškou. Tím je uzavřená přejímka jazyka, kontrastu a ovládání bez myši na dostupném Macu; fyzické klávesnice zůstávají samostatně neověřené. Automatické ověření macOS 14 je doložené výše.

Kontrast 11. 10. 2026: původní drobné stavové popisky měly ve světlém motivu poměr 3,82 : 1; červená chybová zpráva 3,00 : 1 ve světlém a 3,76 : 1 v tmavém. Textové popisky, čísla řádků a názvy panelů nyní používají systémovou barvu textu. Chybová zpráva zachovává červený odstín s příměsí barvy textu podle vzhledu. Nový test ověřuje nejméně 4,5 : 1 pro všech pět stavových popisků i chybu obnovy ve světlém, tmavém a obou kontrastních vzhledech; nejde o měření každého pixelu rozhraní. Celá sada revize `5bdc76c` prošla: 141 testů (48 core, 93 AppKit). Hledání ve 20 kartách s 10 MiB mělo medián 341 ms a maximum 350 ms.

Anglický GUI průchod s VoiceOverem: okno 440 bodů, 20 karet a písmo 24 bodů, světlý i tmavý vzhled. Čitelné jsou menu, čísla řádků a stavový řádek. Příkaz Focus mode šel přečíst, spustit a opustit; výsledek hledání otevřel Note 4 s přesným výběrem. Nastavení šlo otevřít zkratkou, přepnout jeho stránky šipkami a mezerníkem, změnit vzhled a projít volby obnovy i historie. Průchod odhalil nefunkční Cmd+W pro pomocné okno; následná oprava je doložená výše.

Další průchod VoiceOverem 11. 10. 2026: po načtení hledání napříč kartami chyběl výsledek v pořadí klávesového fokusu. Tab skončil na Nastavení. Po vyčištění a zveřejnění výsledků se nyní přepočítá rozložení a nativní pořadí fokusu. Regresní test před opravou selhal; po opravě prošlo 28 testů editoru včetně změny a vymazání dotazu, vyřazení starého výsledku a zachování fokusu ve vyhledávacím poli. V GUI se zapnutým VoiceOverem Tab přešel přímo na výsledek „Note 7“ a mezerník otevřel správnou kartu s výběrem 0/6. Relace stále obsahovala 20 karet.

Dialogy s VoiceOverem a bez myši: Uložit jako zapsalo přesné očekávané bajty; Otevřít znovu aktivovalo stejný soubor bez nové karty a Escape další otevření zrušil. V tisku šlo přes Tab dojít na PDF a mezerníkem otevřít uložení. Export měl jednu stránku, přesný text, obecného autora a text u horního okraje. Escape zavřel další tiskový dialog. Přepínač karet přečetl a otevřel dvacátou kartu. Kontrast a anglický průchod jsou doložené výše.

Při průchodu s VoiceOverem 11. 10. 2026 se ukázalo, že po přesunu fokusu do výsledků panelu příkazů Enter příkaz nespustí a Escape panel nezavře. Tlačítko Otevřít nyní používá nativní výchozí klávesu Enter a controller přijímá Escape i z tabulky. Prošlo 27 testů `EditorReviewTests`, včetně skutečné události Escape při fokusu ve výsledcích, bez spuštění akce a se zachovaným textem i návratem fokusu. Enter byl ověřený v běžící aplikaci, také s VoiceOverem.

GUI E08/P23 se stejným kódem: 20 karet, okno široké 440 bodů, písmo 24 bodů, tmavý motiv a spuštěný VoiceOver. Čtečka přečetla nalezené příkazy Soustředění a Okno navrchu; Tab a Enter je spustily bez myši. Soustředění zachovalo psaní a undo, Escape obnovil ovládání. Čtečka přečetla aktivní stav „Okno navrchu“; zapnutí a vypnutí odpovídalo skutečným úrovním okna 3 a 0. Escape z výsledků příkaz zrušil bez změny režimu. Po ukončení se zapnutým oknem navrchu a novém spuštění zůstalo všech 20 karet a okno mělo úroveň 0. VoiceOver, rychlá navigace a volba modifikační klávesy byly vráceny do původního stavu. Tímto průchodem se uzavřelo E08. Navazující průchod VoiceOverem a dialogy je doložený výše; fyzické klávesnice zůstávají neověřené.

Tisk krátké poznámky 11. 10. 2026: systémové svislé centrování umisťovalo text doprostřed stránky. Tisková operace nyní začíná u horního okraje. Nový test před opravou selhal (střed textu 395,8 bodu na stránce vysoké 792 bodů); po opravě prošlo všech 26 testů `EditorReviewTests` v Release. Skutečný export přes systémový dialog vytvořil jednu stránku PDF s přesným textem `První soubor 😀`, středem textu 743,2 bodu na stránce vysoké 841,9 bodu a obecným autorem `Test`. Přetažení souboru přímo do textové plochy otevřelo druhou kartu a zachovalo rozepsaný koncept. Zkouška proběhla na macOS 15.7.4 / Apple Silicon nad zdroji `01eebc7`.

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

- Revize `3206e99`: celá sada 137 testů v Release prošla (48 core + 89 AppKit). Oprava metadat sjednotila skutečný bundle s nastavením projektu: verze `0.1.0`, build `1`; dřívější vývojové kopie kvůli výchozí hodnotě XcodeGenu hlásily `1.0`.
- F/P15: skript `scripts/release.sh` úspěšně sestavil čistý commit `3206e994950061b406535127ee33462b3af8edbd` pro arm64, podepsal aplikaci i framework ověřenou identitou Developer ID, získal notarizaci `Accepted` a připojil i ověřil ticket. Gatekeeper vrátil `accepted`, `source=Notarized Developer ID`. Balíček `MacPad-0.1.0-arm64-3206e9949500.zip` má SHA-256 `7857a9fa2c121fd28a9120163729501bf6b1c42cdfdc7f15c585f33e2cc258bb`; kontrolní součet souhlasil také po stažení archivu.
- Tentýž archiv byl rozbalen do oddělené instalace v uživatelské složce Applications a označen příznakem quarantine. Gatekeeper zobrazil běžné potvrzení otevření s informací o kontrole Apple. Po potvrzení běžela skutečná podepsaná aplikace, včetně App Translocation. Její binární otisk odpovídal instalovanému balíčku a proces používal určenou izolovanou složku obnovy.
- Výměna staršího vývojového sestavení zachovala změněný soubor i nový koncept: celý text, ID, pořadí, aktivní kartu a výběr 3/2. Diskový originál zůstal beze změny. Obě karty byly ověřené v běžícím novém procesu a po řádném ukončení také v nově zapsané relaci. Přesun testovací instalace do Koše ponechal dokument a obě obnovovací kopie byte-for-byte zachované. Test proběhl na macOS 15.7.4 / Apple Silicon, bez změny osobních dokumentů. Balíček je připravený; veřejné vydání čeká na zbývající přejímku.
- Dílčí VoiceOver průchod: skutečný systémový čteč přes titulkový panel přečetl text a výběr emoji s kombinující diakritikou v editoru. Úplné ovládání bez myši tehdy doložené nebylo. Opakované připojování VNC přesměrovávalo čteč na systémové oznámení; záznam zkratky navíc ukázal, že Alt z tohoto VNC vstupu dorazí jako Command. Dočasná schránka byla obnovena a VoiceOver vrácen do vypnutého stavu. Nastavení běžícího nástroje klávesnice se neměnilo.

- GUI P11 a zobrazení na `edae752`: přechod na druhý řádek za `A😀é` skončil na správné UTF-16 pozici 6. Výběr emoji a kombinovaného znaku měl rozsah 1/4 a stavový řádek správně hlásil dva vybrané znaky. Čísla řádků šla zapnout i vypnout; native panel písem změnil písmo na Andale Mono a nastavení přežilo restart. Přepínání zalamování, přiblížení/oddálení a návrat na 100 % neměnily text ani bajty. Světlý, tmavý a systémový vzhled byly ověřené přímo v UI; systém zůstal v tmavém režimu. Po volbě angličtiny a restartu byly nabídky a stavový řádek anglické, dokumenty zůstaly zachované.
- GUI rozšířeného P04: český text se převedl UTF-8 → Windows-1250 → UTF-8 s přesnými očekávanými bajty a CRLF. Pokus o Windows-1250 nad emoji a kombinující diakritikou vyvolal chybu; po návratu k UTF-8 se uložily původní bajty. Smíšené LF/CRLF vyžádaly rozhodnutí. Zrušit zachovalo původní bajty, volba LF zapsala pouze LF a následný výslovný převod na CRLF zapsal pouze CRLF.

- Změna zalamování původně ponechávala sloupec čísel řádků na starých pozicích. Konfigurace editoru nyní vyžádá jeho překreslení také při změně písma a šířky. Po opravě prošlo 25 cílených EditorReviewTests; nový test kontroluje nové souřadnice řádku a zachování textu. Původní vizuální chyba byla ověřena v GUI před opravou i po ní: přepnutí zalamování oběma směry aktualizuje i poslední prázdný řádek. SHA-256 souboru po změně zobrazení a Cmd+S zůstal stejný.

- Další GUI část E01/P16: skutečně registrovaná globální zkratka vyvolala rychlou poznámku nad Finderem; Escape po napsání textu vrátil fokus do Finderu a relace zachovala stejný koncept. Přesun přes příkazy UI přenesl tento dokument se stejným ID do běžného okna a v rychlé poznámce ponechal nový prázdný koncept. Po potvrzeném ukončení procesu zkratka nad Finderem nic neotevřela. S vypnutou obnovou Zrušit ponechalo text a dovolilo pokračovat; Uložit při zavření rychlé poznámky zapsalo celý text a vrátilo fokus do Finderu. Doplnění nad aplikačním kódem `01eebc7`: klik na skutečnou ikonu v liště otevřel rychlou poznámku, opakované kliknutí obnovilo stejný text a ID bez duplikace a Escape vrátil fokus do Finderu. Přeplněná lišta při původním rozlišení ikonu skrývala; pro tento průchod bylo dočasně zvoleno 1920 × 1200 a potom ověřen návrat přesného původního režimu 1512 × 982. Fyzické klávesnice zůstávají samostatným neověřeným bodem.
- Další GUI část E08/P23: dvacet karet v okně širokém 440 bodů, písmo 24 bodů, vzhled podle systému (tmavý). Soustředění zachovalo fokus a psaní/undo; Escape obnovilo ovládání. Okno navrchu ukázalo stav v dolní liště a mělo skutečnou úroveň 3; vypnutí vrátilo úroveň 0. Po opětovném zapnutí, ukončení a novém procesu byla všechna obnovená okna na běžné úrovni 0. VoiceOver tímto průchodem ověřen nebyl; pomocný proces nemá povolené čtení přes Accessibility API.

- E05/P20: devět cílených LifecycleReviewTests prošlo v Release. Nový test zavřel 22 skutečných souborů a ověřil přesné pořadí posledních 20 odkazů, obnovu výběru celého emoji, jedinečnost již otevřeného dokumentu a zachování jeho neuložené změny i diskového originálu. Vymazání odstranilo oba seznamy. GUI doplnilo kurzor na pozici 3 po znovuotevření, zahození neuložených úprav bez jejich návratu, chybu po smazání souboru a zahozený koncept, který se nevrátil přes Cmd+Shift+T. Vymazání přes příkazy UI nechalo prázdný panel nedávných souborů; dvě zbývající uložené karty zůstaly celé.

- GUI E06/P21: dávka změněný soubor → nový koncept → další změněný soubor se po zrušení prostředního ukládacího dialogu zastavila s údajem 1/3. První soubor měl nové bajty, poslední staré a obě zbývající změny byly dostupné. Druhý průchod s neměnným prostředním souborem ohlásil skutečnou chybu oprávnění a opět 1/3; kontrola souborů a relace potvrdila uložený první a změněné zbývající dva. Po odstranění testovacího příznaku další Uložit vše uložilo oba přesně a všechny karty byly čisté. Editaci během jednotlivého zápisu a ochranu zavírání v dávce dokládají dosavadní automatické testy. Příkaz se vyvolával přes panel příkazů; VNC kombinace Cmd+Alt+S v tomto prostředí spustila jen Uložit, takže nedokládá funkčnost fyzické zkratky Option+Cmd+S.

- GUI E02/P17: koncept dostal vlastní název a připnutí přes příkazy UI, přesunul se do druhého okna a přežil ukončení i nový proces se stejným ID, obsahem, názvem a připnutím. Uložit nabídlo vlastní název s `.txt` a uložilo přesný obsah. U uloženého souboru příkaz pojmenování nebyl dostupný a jeho název ani bajty se nezměnily.
- GUI E03/P18: šipky a Enter vybíraly příkazy i karty napříč okny. Enter nad prázdným výsledkem nic nespustil; Escape v obou panelech vrátil fokus a následné psaní změnilo správný dokument. Nedostupné pojmenování uloženého souboru nebylo ani ve výsledcích příkazů. Cmd+P otevřelo systémový tiskový dialog s náhledem vybraného dokumentu; tisk byl zrušen.
- GUI P06: Uložit při Cmd+W zapsalo přesné bajty konceptu a odstranilo jeho kartu z relace; dřívější průchod doložil Zrušit i Zahodit. GUI P10: externí přejmenování uloženého otevřeného souboru vyvolalo při Cmd+S konflikt. Zrušení zachovalo přejmenovaný soubor beze změny a celý text v obnově, původní cesta nebyla potichu znovu vytvořena.

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

### Zrušení otevírání 50 MiB

Na macOS 15.7.4 / Apple Silicon prošly dva samostatné procesy aplikačního kódu `1b8cf91`: zrušení a kontrolní úplné otevření souboru o 52 428 800 bajtech. Izolovaná kopie měla vlastní bundle ID, ad-hoc podpis a pomocnou sondu; produkční zdroje se neměnily. Sonda poslala skutečnému menu klávesovou událost Cmd+. během běžící operace čtení, přibližně 15 ms po požadavku otevřít. Nejde o zkoušku fyzické klávesnice ani měření latence VNC.

Operace se označila za zrušenou. Po jejím doběhnutí byla fronta prázdná, počet čekajících souborů nulový a zůstala jediná karta s celým původním konceptem. V kontrolním běhu vznikla druhá karta s celými 50 MiB textu. Oba procesy skončily řádně, obnovené relace měly očekávané dokumenty a kontrolní součet souboru se nezměnil. Tento průchod uzavírá zrušení velkého souboru; nesplněný cíl studeného startu je popsaný níže.

### Studená disková cache 11. 10. 2026

Aplikační kód `1b8cf91`, Apple M1 Pro, 32 GiB, macOS 15.7.4. Pět dvojic studený/opakovaný start pro prázdnou relaci a dalších pět pro obnovu 20 karet s 10 MiB českého textu. Před studeným během se úspěšně provedlo systémové `purge`; opakovaný běh následoval bez čištění cache. Nešlo o restart operačního systému ani první instalaci. Každý proces běžel pod běžným uživatelem s novou izolovanou relací. Hlídač nezaznamenal přerušení cizí aktivitou.

| Relace a cache | Start medián / maximum | RSS medián / maximum |
| --- | --- | --- |
| Prázdná, po `purge` | 1 775 / 2 046 ms | 84,6 / 84,9 MiB |
| Prázdná, opakovaný start | 201 / 214 ms | 84,8 / 84,9 MiB |
| 20 karet, po `purge` | 1 814 / 2 166 ms | 127,2 / 127,6 MiB |
| 20 karet, opakovaný start | 447 / 462 ms | 127,8 / 129,3 MiB |

Měřený úsek jde od spuštění procesu k viditelnému aktivnímu oknu s editovatelným textovým pohledem, po rozložení a `displayIfNeeded`. Pozorovatel běžel v izolované kopii se změněným bundle ID a ad-hoc podpisem; měření nenahrazuje start distribučního balíčku přes LaunchServices. Čas zahrnuje zjištění kontrolního souboru, VNC nebylo časomírou. RSS je odběr 1,5 s po připravenosti, nikoli maximum. Každý proces skončil řádně a všechny obnovené relace zachovaly všech 20 textů.

Navržený cíl studeného startu do jedné sekundy není splněný; paměť prázdného editoru je pod orientačním limitem 100 MiB. Doplňující diagnostický pár měl 1 608/185 ms pro studený/opakovaný start. Ve studeném průchodu začalo `applicationDidFinishLaunching` v 1 061 ms a skončilo v 1 347 ms; připravenost okna byla zjištěna v 1 596 ms. Jde o rozdělení jednoho běhu, ne o další statistické měření ani důkaz, že cíle nelze dosáhnout. Výkonová přejímka zůstává otevřená.

### Start procesu a vykreslení 11. 10. 2026

Celá sada nad `92cb167` prošla: 134 testů (48 core + 86 AppKit). Poté prošlo devět cílených výkonových testů revize `1cb6037`, včetně dvou nových testů velkého vložení. Pět opakování každého scénáře na stejném Apple M1 Pro / macOS 15.7.4:

| Scénář | Medián / maximum |
| --- | --- |
| Otevření 1 MiB ASCII | 29 / 31 ms |
| Otevření 10 MiB ASCII | 157 / 160 ms |
| Otevření 50 MiB ASCII | 717 / 781 ms |
| Otevření 10 MiB českého textu | 247 / 267 ms |
| Vložení 1 MiB českého textu | 82 / 85 ms |
| Vložení 10 MiB českého textu | 706 / 725 ms |
| Otevření řádku se dvěma miliony znaků | 533 / 540 ms |

Tyto časy zahrnují bezprostřední `displayIfNeeded`, nikoli doručení snímku monitorem ani odložený výpočet počtu znaků. Vložení zachovalo celý text a jedno undo jej odstranilo. Jednoznaková úprava 10 MiB českého textu měla 23/23 ms; 50 MiB ASCII 8/19 ms.

Další samostatné měření používalo stejný aplikační kód v izolované kopii s jiným bundle ID, podpisem a testovacím pozorovatelem. Čas se počítal od přímého spuštění procesu do viditelného aktivního okna s editovatelným `EditorTextView`, po rozložení a `displayIfNeeded`. Zahrnuje zápis a zjištění kontrolního souboru s rozlišením přibližně 2 ms. Každý běh skončil řádně přes ukončení aplikace.

| Nový proces, pět běhů | Start medián / maximum | RSS 1,5 s po připravenosti medián / maximum |
| --- | --- | --- |
| Prázdná relace | 220 / 259 ms | 83,7 / 84,3 MiB |
| Obnova 20 karet s 10 MiB českého textu | 461 / 477 ms | 129,0 / 129,8 MiB |

Po všech pěti obnovách obsahovala nově uložená relace přesně 20 poznámek se správným celým textem. RSS je jednotlivý odběr, nikoli maximum během startu nebo dlouhodobá spotřeba. Cache systému se nečistila; měření neprokazuje start se studenou cache, spuštění přes LaunchServices ani distribuční balíček. První prázdný proces měl 257 ms, následující 202–259 ms. VNC nebylo časomírou.


### Doplnění 11. 10. 2026

Nad zdroji revize `89800eb` prošlo v Release na stejném Macu 102 testů (40 core, 62 AppKit). Běh přes RemoteCmd skončil bez přerušení. Nové testy ověřují UTF-16 pozice hledání za emoji a odmítnutí starého výsledku po editaci, zrušení čekajícího i již běžícího hledání, kolizi a uvolnění globální zkratky, dokončení snímku před skrytím rychlé poznámky a opětovné otevření stejného konceptu. Kolize používá skutečné Carbon API; nejde o zkoušku fyzických kláves.

Pět opakování: hledání ve 20 kartách s celkem 10 MiB českého textu mělo medián 334 ms a maximum 335 ms včetně čekání 150 ms před hledáním, sestavení výsledků, rozvržení a `displayIfNeeded`. Rychlá poznámka měla 1/16 ms včetně `displayIfNeeded`; první vyvolání okno vytvořilo, další znovu zobrazila. Oba cíle (500 a 300 ms) jsou splněné pro tento postup; čas fyzického zobrazení snímku monitorem se neměřil. Jeden řádek se dvěma miliony znaků: otevření 482/485 ms, vložení znaku 2/3 ms. Toto měření nenahrazuje zbývající přejímku P14.

Další fyzický testovací Mac není dostupný. macOS 14 se následně ověřil automatickými testy v CI; fyzické Mac/Windows klávesnice zůstávají neověřené.

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

- Dokončit referenci Windows Notepadu a zbývající výkonovou přejímku P14; starší důkaz se nepřenáší automaticky na změněné funkce.
- Ověřit fyzické klávesnice a IME; vzdálené klávesové události nedokládají fyzický hardware.
- Vyřešit nesplněný cíl studeného startu; ostatní výkonová měření a zrušení otevírání 50 MiB jsou doložené výše.
- Upravený soubor se do relace ukládá celý i s uloženou verzí; velký upravený soubor proto relaci dál zvětšuje.
- Prověřit ACL a rozšířené atributy souborů.
- Intel zůstává nepodporovaný. Automatické testy macOS 14 arm64 a přejímka balíčku na macOS 15.7.4 jsou doložené výše.

## Sdílený testovací Mac

Vzdálené testy používají samostatnou pracovní složku a izolovaná data. Před dávkou se kontrolují cizí buildy a testy, VNC spojení a poslední vstup do stroje. Pro testovací dávku se drží společná rezervace; hlídač ukončí vlastní běh při zjištění cizí aktivity. Samotné označení relay jako idle nestačí. V této relaci kontrola zachytila cizí sestavení a naše testy se tehdy nespustily.

Rezervace sama nezabrání nástroji, který ji nerespektuje, v přístupu k obrazovce. Proto se kontrola aktivity opakuje a cizí procesy se neukončují. Konkrétní přístupy, adresy a soukromé logy nejsou součástí repozitáře.
