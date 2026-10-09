# MacPad: analýza a návrh

Datum: 9. 10. 2026, aktualizováno 10. 10. 2026. Dokument popisuje cílové chování aplikace. Implementace a testování již běží; aktuální stav je v README, TODO a záznamu ověření. Níže uvedené požadavky nejsou tvrzení o úplně dokončené přejímce.

Revize 2 rozšiřuje původní návrh. Notepad je referencí pro známé ovládání a práci se soubory. Nové funkce se řídí přínosem pro poznámky; nemusí kopírovat Windows.

## Co má uživatel dostat

Malý editor pro rychlé poznámky a běžné textové soubory. Po spuštění lze ihned psát. Více poznámek je v kartách. Uložení má jednoznačný výsledek. Zavření aplikace zachová rozpracovanou relaci a po návratu pokračujeme na stejném místě.

Vzhled vychází z rozložení Notepadu: nahoře karty a tlačítko plus, velká textová plocha, dole nenápadný stavový řádek. Ovládací prvky oken, dialogy a horní systémové menu zůstávají nativní pro macOS. Bez bočního seznamu projektů a bez úvodního průvodce. Nová instalace otevře jednu prázdnou kartu.

První verze zpracovává čistý text. Markdown lze otevřít a upravovat jako text; jeho volitelný náhled je navržený pro verzi 1.1. AI, účty, vlastní cloudová synchronizace, spolupráce a pluginy zatím nejsou v plánu. Běžný soubor lze uložit do uživatelovy synchronizované složky, ale aplikace tím neslibuje souběžné úpravy bez konfliktů.

## Výsledek druhé iterace

Zvažované směry byly lehký editor s funkcemi pro každodenní poznámky, rozsáhlejší správce poznámek se složkami a štítky a vývojářský editor. Pro tento projekt doporučuji první směr: rozšiřuje přímo psaní, hledání a ukládání. Správce poznámek by přidal další knihovnu vedle běžných souborů; vývojářský editor by přesunul pozornost k práci s kódem.

V prvním průchodu byly vybrány časté situace: zachytit myšlenku během jiné práce, najít text mezi mnoha kartami, udržet důležité poznámky nahoře a bezpečně uložit více dokumentů. Ve druhém průchodu se omezil počet trvale viditelných prvků. Ve třetím se prověřily konflikty: rychlá poznámka musí používat stejnou obnovu, vrácení zavřené karty nesmí vracet výslovně zahozený obsah a hromadné uložení nesmí tvrdit, že uložilo soubory, u kterých selhalo.

Verze 1.0 proto dostává osm konkrétních rozšíření E01 až E08. Čtyři náročnější návrhy R01 až R04 jsou oddělené pro verzi 1.1 a nejsou podmínkou prvního veřejného vydání.

## Co je doložené a co ještě změřit

Microsoft popisuje karty včetně přesunu do dalšího okna a názvů odvozených z obsahu v [oznámení z ledna 2023](https://blogs.windows.com/windows-insider/2023/01/19/tabs-in-notepad-begins-rolling-out-to-windows-insiders/). [Obnova relace ze srpna 2023](https://blogs.windows.com/windows-insider/2023/08/31/new-updates-for-snipping-tool-and-notepad-for-windows-insiders/) zachovává neuložený obsah a otevřené karty, aniž by přepsala soubory. Výslovné zavření karty dál řeší uložení nebo zahození změn.

[Přepracování z prosince 2021](https://blogs.windows.com/windows-insider/2021/12/07/redesigned-notepad-for-windows-11-begins-rolling-out-to-windows-insiders/) popisuje tmavý režim, hledání a nahrazování i více kroků zpět. [Formátování z května 2025](https://blogs.windows.com/windows-insider/2025/05/30/text-formatting-in-notepad-begin-rolling-out-to-windows-insiders/) dokládá rozšíření směrem k Markdownu. Tyto články popisují konkrétní vydání, nezaručují chování každé dnešní instalace.

Lokálně byla zjištěna verze Windows Notepadu 11.2607.14.0. Jeho GUI, aktuální nastavení a přesné chování jednotlivých příkazů zatím nebyly prozkoušeny. Před implementací se na umělých poznámkách zaznamená referenční chování pro scénáře P01 až P12 z plánu. Uživatelské poznámky ani nastavení se při tom nesmějí změnit. Nedostupný bezpečný testovací profil znamená neověřený bod, nikoli odhad vydávaný za měření.

## Funkční rozsah

| Oblast | První použitelná verze | Před veřejnou verzí 1.0 |
| --- | --- | --- |
| Psaní | Čistý text, české znaky, emoji, výběr, schránka, undo/redo | IME, dlouhé řádky, větší soubory, přístupnost |
| Karty | Nová, přepnutí, zavření, název z prvního neprázdného řádku, označení změn | Přesouvání pořadí, přesun do druhého okna a zpět |
| Soubory | Otevřít více souborů, uložit, uložit jako, otevření z Finderu | Nedávné soubory, přetažení souborů, tisk |
| Obnova | Rozpracované karty, pořadí, aktivní karta, kurzor a posun | Více oken, poškozená relace, migrace formátu relace |
| Hledání | Najít další/předchozí, rozlišení velikosti písmen, nahradit, nahradit vše | Přechod na řádek, korektní chování nad Unicode |
| Zobrazení | Zalamování, přiblížení, světlý/tmavý/systémový vzhled | Písmo, stavový řádek: řádek, sloupec, znaky, kódování, konce řádků |
| Formát souboru | UTF-8 s BOM i bez BOM, UTF-16 s BOM; CRLF a LF | Ruční Windows-1250, UTF-16 BE/LE, smíšené konce řádků a chyby převodu |
| Ovládání | Klávesnice i myš, macOS zkratky a vybrané místní Ctrl aliasy | Ověřená mapa zkratek včetně externí Windows klávesnice |

Tato tabulka určuje základ editoru. Následující rozšíření patří navíc do verze 1.0; první interní použitelný milník A až D může vzniknout ještě bez nich.

## Rozšíření pro verzi 1.0

| ID | Funkce | Přesné chování a hranice |
| --- | --- | --- |
| E01 | Rychlá poznámka | Volitelná ikona v horní liště macOS otevře malé psací okno. Uživatel si může přiřadit globální zkratku. Koncept se ukládá stejnou cestou jako karty a lze jej přesunout do hlavního okna. |
| E02 | Připnuté a pojmenované karty | Připnutí udrží kartu vlevo; vlastní název konceptu přežije restart bez nutnosti vytvořit soubor. Připnutí nebrání výslovnému zavření. Název souborové karty vychází ze souboru, nikoli z jeho tichého přejmenování. |
| E03 | Rychlý přepínač a nabídka příkazů | Cmd+K hledá kartu podle názvu, Cmd+Shift+P hledá dostupný příkaz. Stejný malý panel má jasně označený režim; výsledky lze vybrat klávesnicí i myší. |
| E04 | Hledání ve všech otevřených kartách | Cmd+Shift+F zobrazí výskyty s názvem karty a krátkým okolím. Výběr přejde na správné místo. Zahrnuje i neuložené texty ve všech oknech, neprohledává celý disk. |
| E05 | Znovu otevřít zavřenou kartu | Cmd+Shift+T vrátí naposledy zavřený soubor a polohu kurzoru. Uchovává nejvýše 20 odkazů v aktuálním běhu aplikace. Výslovně zahozený neuložený text se nearchivuje. |
| E06 | Uložit vše | Cmd+Option+S uloží změněné dokumenty a pro nepojmenované postupně nabídne dialog. Výsledek rozliší uložené, neuložené a chybové dokumenty. |
| E07 | Drobné úpravy textu | Vložit datum a čas, duplikovat řádek, posunout řádek nahoru/dolů, seřadit označené řádky a odstranit přesně duplicitní označené řádky. Každý příkaz tvoří jeden krok zpět. |
| E08 | Soustředění a okno navrchu | Režim soustředění skryje pás karet a stavový řádek. Samostatná volba drží aktuální okno nad běžnými okny. Oba stavy mají dostupný příkaz pro vypnutí. |

Rychlá poznámka funguje, když aplikace běží. Cmd+Q skutečně ukončí i položku v horní liště a zkratku; automatické spouštění po přihlášení se nezapíná. Opakované vyvolání aktivuje již otevřenou rychlou poznámku, nevytváří prázdné kopie. Escape ji skryje až po úspěšném uložení konceptu a vrátí fokus původní aplikaci; chyba zápisu ponechá text viditelný. Přesun do hlavního okna zachová stejnou identitu dokumentu. Při vypnuté obnově se změny řeší dialogem stejně jako v hlavním okně. Globální zkratka pouze vyvolává okno, nesleduje psaný text. Její registraci a kolize je nutné ověřit v technické zkoušce; případnou nepodporovanou kombinaci odmítnout s vysvětlením.

Pojmenování konceptu mění pouze jeho metadata, nikoli obsah. Při prvním uložení se nabídne tento název. Připnutí, vlastní název a pořadí jsou součástí obnovované relace. Znovuotevření zavřeného souboru znovu načte aktuální diskovou verzi a při chybějícím souboru oznámí chybu; nesmí vydávat odkaz za zálohu textu. Zahozený koncept bez souboru se touto funkcí nevrátí. Seznamy nedávných a zavřených souborů lze vymazat.

Hledání napříč kartami běží nad revizemi textů. Změna obsahu zneplatní staré výsledky; před skokem se ověří, že výskyt stále odpovídá. Zavření karty ji odstraní z výsledků. Panel lze zavřít jedním Escape a vrátit fokus do editoru. Hromadné nahrazování napříč kartami do verze 1.0 nepatří; běžné nahrazování je nad aktuálním dokumentem.

Uložit vše je posloupnost bezpečných uložení, nikoli jedna společná transakce. Zrušení dialogu zastaví další ukládání a ponechá již uložené dokumenty uložené. Chyba nabídne zastavit nebo pokračovat; žádný dokument se neoznačí jako uložený před potvrzením zápisu své revize. Funkce nikdy sama neukončuje aplikaci.

Příkazy pro řazení a odstraňování duplicit jsou dostupné jen při výběru textu; pracují s celými řádky, kterých se výběr dotýká. Řazení je stabilní, používá jazyk rozhraní a zachová prázdné řádky. Odstranění duplicit zachová první přesný výskyt a nemění velikost písmen ani mezery. Datum a čas se vloží podle systémového formátu. Žádná úprava se nespouští sama při uložení.

## Podoba aplikace

```text
┌────────────────────────────────────────────────────────────┐
│ ● ● ●   Připnutá poznámka │ Nákup • │ text.txt │ + │ ▾      │
├────────────────────────────────────────────────────────────┤
│                                                            │
│ Sem lze ihned psát.                                         │
│                                                            │
│                                                            │
├────────────────────────────────────────────────────────────┤
│ Ř. 4, sl. 12    238 znaků          100 %   UTF-8   CRLF      │
└────────────────────────────────────────────────────────────┘
```

Jde o schematické rozložení, ne hotový grafický návrh. Horní systémové menu macOS zůstává mimo okno. Titulková oblast respektuje místo pro systémová tlačítka. Tečka u názvu označuje neuloženou změnu; přístupný název karty sdělí totéž slovy.

- Základní pohled tvoří karty, editor a stavový řádek. Bez trvale otevřeného postranního panelu a bez velké lišty ikon.
- Pás karet má plus, připnuté karty vlevo, přesun myší a nabídku všech karet při nedostatku místa. Dlouhé názvy se zkrátí, úplný název je dostupný v přepínači a nápovědě.
- Textová plocha používá systémové neproporcionální písmo, čitelný řádkový odstup a malé okraje. Písmo a velikost lze změnit; výběr textu zůstává nativní.
- Světlý motiv má klidné neutrální pozadí, tmavý respektuje systémový vzhled. Barva zvýraznění vychází ze systému. Materiály a animace respektují omezení průhlednosti a pohybu.
- Hledání v kartě otevře úzký řádek pod kartami. Hledání napříč kartami otevře dočasný boční panel s výsledky. Panel příkazů se zobrazí jen při vyvolání.
- Stavový řádek ukazuje řádek, sloupec, počet znaků nebo rozsah výběru, přiblížení, kódování a konce řádků. Údaje pro celý text nebo výběr jsou jasně rozlišené.
- Při zúžení okna se méně důležité údaje skryjí do nabídky; psací plocha má přednost. Čísla řádků jsou volitelná a ve výchozím stavu vypnutá.
- Rychlá poznámka je kompaktní okno s textem a příkazy Otevřít v hlavním okně a Uložit jako. Nevytváří druhý typ dokumentu ani vlastní knihovnu poznámek.
- Nastavení má tři části: Editor, Vzhled a Obnova a zkratky. Rozšířené volby se nevkládají mezi text a běžné psaní.
- Režim okna navrchu má viditelný přepínač. Neslibuje překrytí zabezpečených systémových oken ani cizích aplikací na celé obrazovce; při obnovení relace je vypnutý.

Prázdná karta obsahuje jen nenápadný název Nová poznámka. Chyba uložení se ukáže u konkrétního dokumentu s volbou Opakovat nebo Uložit jako. U obnovovaných konceptů nesmí stav „koncept zachován“ vypadat jako potvrzení uložení do souboru.

## Navazující rozšíření pro verzi 1.1

| ID | Funkce | Hranice návrhu |
| --- | --- | --- |
| R01 | Dva texty vedle sebe | Rozdělení jednoho okna na dva editory s jasným aktivním panelem. Při dvou pohledech na stejný dokument sdílet text a undo, nikoli vytvořit dvě zapisující kopie. |
| R02 | Volitelný náhled Markdownu | Text zůstává obyčejným .md souborem; náhled ukáže nadpisy, seznamy a úkoly vedle něj. Bez skrytého přepisu syntaxe nebo přepnutí do rich textu. |
| R03 | Lokální historie uložených verzí | Volitelně uchovat předchozí úspěšně uložené verze souboru. Výběr otevře starší verzi jako nový neuložený dokument; nepřepíše aktuální práci. |
| R04 | Porovnání externí změny | Při konfliktu ukázat vlastní text a diskovou verzi s rozdíly po řádcích. Zachovat volby načíst, uložit kopii nebo potvrzeně přepsat; bez automatického slučování. |

Náhled Markdownu nesmí spouštět vložené HTML nebo skripty ani sám načítat vzdálené obrázky a další zdroje. Odkazy otevře systémový prohlížeč až po kliknutí a kontrole schématu. Konkrétní parser vybrat až při implementaci podle podpory syntaxe a licence; omezení běhových závislostí v návrhu platí pro verzi 1.0, případná výjimka pro náhled musí být odůvodněná.

Historie je ve výchozím stavu vypnutá a oddělená od automatické záchrany aktuálních konceptů. Při zapnutí navrhuji nejvýše 20 verzí na soubor, stáří 30 dní a celkově 100 MiB; při dosažení limitu odstranit nejstarší historické verze, nikdy aktuální koncept. Dostupné musí být Vymazat historii souboru a Vymazat vše. Výslovné zahození neuložených změn je do historie nepřidá; již uložené verze se odstraňují příkazem pro historii. Selhání archivace nesmí být skryté za úspěchem uložení souboru a nesmí zablokovat záchranu aktuálního textu.

## Pravidla, která nesmějí porušit data

1. Textový soubor se mění až po úspěšném Uložit nebo Uložit jako. Obnova relace ukládá jinam.
2. Neuloženou změnu odstraní jen výslovné Zahoď změny. Zrušený dialog ponechá obsah, kartu i vazbu na původní soubor.
3. Stav „uloženo“ platí až po dokončeném zápisu dané revize. Další psaní během zápisu zůstane označené jako změna.
4. Selhání zápisu nesmí zničit starý soubor. Před nahrazením se připraví celý obsah a použije bezpečný atomický zápis ve stejném svazku.
5. Neznámé kódování, neplatné bajty a nevyjádřitelný znak nesmějí vést k tichému nahrazení znakem otazníku.
6. Změna souboru jiným programem se nesmí automaticky přepsat. Uživatel volí nové načtení, uložení kopie nebo potvrzené přepsání.
7. Jeden fyzický soubor má v aplikaci jednu sdílenou identitu. Druhé otevření aktivuje existující dokument; alias nebo symlink nevytvoří nezávislou zapisující kopii.
8. Poškozená část obnovy nesmí smazat ostatní poznámky. Původní data zůstanou dostupná pro záchranu.
9. Schránka přenáší čistý text. Automatické chytré uvozovky, pomlčky, opravy a formátování jsou ve výchozím stavu vypnuté.
10. Obsah poznámek a úplné uživatelské cesty nepatří do běžných logů, testovacích reportů ani telemetrie.

## Zavírání a obnova

| Událost | Navržený výsledek při zapnuté obnově |
| --- | --- |
| Zavření nezměněné nebo prázdné nové karty | Karta se odstraní z relace |
| Zavření změněné karty | Uložit / Zahoď změny / Zrušit; nepojmenovaná karta otevře při uložení dialog |
| Zavření okna červeným tlačítkem | Dokončit uložení relace tohoto okna a zavřít jej; otevření z Docku ji obnoví |
| Ukončení aplikace přes Cmd+Q | Dokončit obnovovací zápisy všech oken, potom skončit bez dotazů na jednotlivé soubory |
| Vypnutá obnova | Při zavření okna a ukončení řešit každou změněnou kartu; Zrušit zastaví ukončení |
| Chyba obnovovacího zápisu | Viditelná chyba; nabídnout uložení poznámek nebo zrušit zavírání; žádné předstírání úspěchu |
| Pád nebo násilné ukončení | Obnovit poslední úplnou konzistentní verzi; právě nezapsané změny mohou chybět |
| Chybějící původní soubor při obnově | Obnovit rozepsaný obsah a nabídnout Uložit jako; nic nevytvářet bez volby uživatele |

Rozdíl mezi zavřením karty a okna musí být zřejmý i v menu: Zavřít kartu proti Zavřít okno. Vypnutí obnovy nesmaže existující koncepty bez vyřešení jejich uložení nebo zahození.

Obnovovací zápis má navržené zpoždění 500 ms po poslední editaci, s nejvýše dvousekundovým intervalem při nepřetržitém psaní. Jde o cíl, ne záruku nulové ztráty při výpadku napájení. Při běžném ukončení se čeká na skutečné dokončení zápisu. Verze snímku a dokumentu zabrání tomu, aby pomalejší starší zápis přepsal novější obsah.

## Ukládání a formát

Nový dokument používá UTF-8 bez BOM a CRLF jako návrh výchozího nastavení pro podobnost s Windows. Otevřený dokument zachová zjištěné kódování, BOM i konce řádků. LF lze zvolit při uložení. Samotné zalamování zobrazení nesmí vložit nové konce řádků do souboru.

Detekce začne BOM, potom striktním UTF-8. U neplatného UTF-8 nabídne výběr kódování s náhledem; neodhadne potichu ANSI. Windows-1250 bude výslovná volba pro starší české soubory. Smíšené konce řádků aplikace rozpozná a před jejich sjednocením si vyžádá volbu; do jejího potvrzení nepřepíše soubor. I toto je možné omezení oproti referenci a musí být označené v porovnání.

Uložit jako nabídne název odvozený z obsahu bez neplatných znaků. Výchozí přípona je .txt; uživatel může zachovat jinou. Cíl se změní až po úspěšném zápisu. Pro soubor bez oprávnění nabídnout uložení kopie. Řešit změnu externím programem i v okamžiku zápisu, ne pouze při návratu okna do popředí.

## Klávesnice a vzhled

Navržený základ: Cmd+N a Cmd+T nová karta, Cmd+Shift+N nové okno, Cmd+O otevřít, Cmd+S uložit, Cmd+Shift+S uložit jako, Cmd+W zavřít kartu, Cmd+Shift+W zavřít okno, Cmd+Q ukončit. Cmd+F hledat, Cmd+Option+F nahradit, Cmd+G další výskyt, Cmd+Shift+G předchozí. Zpět Cmd+Z, znovu Cmd+Shift+Z.

Rozšíření přidávají Cmd+K pro přepnutí karty, Cmd+Shift+P pro příkazy, Cmd+Shift+F pro hledání napříč kartami, Cmd+Shift+T pro znovuotevření souboru a Cmd+Option+S pro Uložit vše. Cmd+P zachová nativní tisk. Escape nejprve zavře aktivní panel, v režimu soustředění bez otevřeného panelu vrátí běžné rozhraní; nesmí potvrdit rozpracovaný systémový dialog.

Kvůli návykům z Windows navrhuji místní Ctrl aliasy pro N/T/O/S/W/F/H/A/C/V/X/Z/Y a Ctrl+Tab / Ctrl+Shift+Tab. Ctrl+G přejde na řádek, zatímco Cmd+G ponechá macOS význam dalšího hledání. Alias se zpracuje jen v hlavním editoru a nesmí zachytit systémové dialogy, zadávání přes IME ani kombinace Ctrl+Option používané VoiceOverem. Ctrl+A/E a další emacsové kombinace mohou mít s Windows aliasy jiný význam; tuto odlišnost výslovně ověřit. Žádný globální přepis klávesnice ani požadavek na oprávnění Accessibility pro samotný editor.

Home/End na rozšířené klávesnici mají podle navržené parity přecházet na začátek/konec řádku, Ctrl+Home/End na začátek/konec dokumentu. Shift rozšíří výběr. Výsledek porovnat se skutečným Notepadem, včetně zalomených řádků. Na Mac klávesnici zachovat i Cmd+šipky a Option+šipky. VNC nenahradí fyzické ověření všech kombinací.

Stavový řádek a karty musí být přístupné přes VoiceOver. Změnu neoznačovat pouze barvou. Kontrast, zvětšení písma a vysoký kontrast systému musí fungovat ve světlém i tmavém režimu. První veřejná verze má české a anglické rozhraní.

## Technologie a odpovědnosti

| Varianta | Přínos | Náklad pro tento projekt |
| --- | --- | --- |
| Swift + AppKit, doporučeno | Nativní textový systém, souborové dialogy, menu, undo a přístupnost | Vývoj i testy aplikace vyžadují Mac |
| SwiftUI + vložený NSTextView | Pohodlná deklarace okolního rozhraní | Další synchronizace výběru, fokusu a textového stavu mezi dvěma UI systémy |
| Webový editor v Tauri nebo Electronu | Sdílený webový základ při budoucí jiné platformě | Další běhové vrstvy a více vlastní práce na nativním chování |

Pro verzi 1.0 zvolit Swift a AppKit bez běhových závislostí třetích stran. Použít NSTextView v režimu čistého textu, NSScrollView, UndoManager a nativní dialogy. Využít NSDocument pro čtení, explicitní ukládání a změnový stav; nevytvářet paralelní vlastní souborový framework. [Apple dokumentuje NSDocument](https://developer.apple.com/documentation/appkit/nsdocument) jako základ dokumentových aplikací a [NSTextView](https://developer.apple.com/documentation/appkit/nstextview) jako textový editor.

Výchozí automatické ukládání přímo do souboru nezapínat: [autosavesInPlace](https://developer.apple.com/documentation/appkit/nsdocument/autosavesinplace) by odporovalo požadované obnově bez změny souboru. V první technické zkoušce ověřit NSDocument s kartami a vlastním ukončením aplikace. Obnovu obsahu má vlastnit jediná cesta, plánovaný SessionStore; vedle něj nesmí současně vzniknout nezávislá obnova téhož obsahu přes AppKit. Pokud vestavěné ukládání konceptů splní celý kontrakt, má přednost a SessionStore bude pouze seznam karet. Rozhodnutí uzavřít v první etapě na funkčním pokusu.

Navržené části, vznikající až při implementaci svého úkolu:

- TextDocument: text, identita souboru, revize, kódování, konce řádků, undo a explicitní zápis.
- EditorWindowController: okno, vlastnictví karet, fokus, příkazy menu a editoru.
- SessionStore: konzistentní obnova relace, pořadí, připnutí a vlastní názvy karet a podle výsledku technické zkoušky obsah konceptů.
- TextFileCodec: striktní převod mezi bajty a textem; malé čisté funkce s testovacími soubory.
- Nastavení přes UserDefaults: vzhled, písmo, zalamování a obnova; vlastní text do UserDefaults neukládat.

Rychlé poznámky používají TextDocument a stejnou obnovu jako hlavní okna. Panel příkazů vyvolává stejné akce jako menu včetně jejich povoleného stavu. Hledání sdílí pravidla aktuálního vyhledávání a bere obsah přímo z otevřených dokumentů; první verze nepotřebuje databázi ani trvalý index. Uložit vše používá existující příkaz uložení dokumentu. Rozšíření nezakládají vlastní kopie dokumentového stavu.

UI a změny textu zůstávají na hlavním vlákně. Diskový zápis běží sériově mimo něj nad neměnnou revizí. O dokončení rozhoduje hlavní vlákno porovnáním revize. Pro sledování externích změn použít možnosti NSDocument a koordinovaný přístup k souborům; přístup neopakovat v další vrstvě.

Obnovovací data patří do Application Support aplikace, se soukromými přístupovými právy. Obsah konceptů je lokálně čitelný uživatelským účtem; aplikace neslibuje vlastní šifrovaný trezor. Zahozenou poznámku odstranit i z obnovovacích kopií. Schéma má verzi, neznámá novější verze se nesmí automaticky přepsat. Obnova musí zvládnout přerušení mezi zápisem obsahu a seznamu karet.

Sestavení navrhuji přes projekt generovaný XcodeGen z verzovaného project.yml. Generátor je vývojový nástroj, nikoli součást aplikace. Předpis bude mít pevně určenou ověřenou verzi, sdílené schéma aplikace a XCTest targety. Do Gitu patří zdroje, předpis projektu, testy a umělé vzorky; nikoli sestavená aplikace a místní nastavení.

## Rozhodnutí před vydáním

Bundle identifier je com.nkshub.macpad; společná knihovna používá com.nkshub.macpad.core. Název je MacPad a licence MIT. Podpis musí používat skutečně dostupnou a oprávněnou Developer ID identitu; žádná identita se nepřebírá jen podle toho, že ji používá jiný projekt.

Navrhuji přímou distribuci podepsané a notarizované aplikace, nejprve pro Apple Silicon. App Store, sandbox, Intel a automatické aktualizace nejsou automatickou součástí první verze. Jejich případné doplnění vyžaduje ověření dopadu na přístup k souborům a umístění obnovovacích dat. Nejnižší verze macOS je návrh, dokud na ní neproběhnou testy.
