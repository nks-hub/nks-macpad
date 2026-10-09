# Plán implementace a ověření

Probíhá implementace vývojové verze 0.1.0. Návrh funkcí a pravidel je v [analýze](docs/plans/2026-10-09-macpad-design.md); stav jednotlivých úkolů je v [TODO](TODO.md). Níže jsou cíle pro dokončení verze 1.0, nikoli prohlášení o jejich splnění.

Testování bylo znovu zahájeno společně s úplným code review. Na macOS 15.7.4 prošlo 64 testů zdrojů odpovídajících revizi 7589e72. Rozsah důkazů a zbývající mezery jsou v [záznamu ověření](docs/VALIDATION.md). Sdílený Mac se používá jen po kontrole cizí aktivity; volný relay sám o sobě není důkaz volné obrazovky.

Ve zdrojích jsou připravené editor, bezpečné souborové operace, obnova relace i rozšíření E01 až E08. Rozhraní má dokumentové karty, nabídku uvnitř okna, stavový řádek a samostatné části nastavení. Nově je otevírání souborů přesunuté mimo hlavní vlákno a má příkaz ke zrušení. Dokončení těchto bodů závisí na jejich ověření, ne pouze na přítomnosti kódu.

Revize 2: verze 1.0 má vedle známého ovládání Notepadu zahrnout rozšíření E01 až E08. Interní použitelný milník končí etapou D, veřejné vydání vyžaduje A až F. Návrhy R01 až R04 patří do samostatné etapy G pro verzi 1.1. Veřejné vydání a etapa G nyní nejsou zahájené.

## A. Reference a technická zkouška

Zaznamenat chování referenčního Windows Notepadu na umělých souborech: karty, zavření, ukončení, uložení, obnova, zkratky a kódování. U každého výsledku uvést verzi, nastavení a rozdíl proti návrhu. Rozpor vyřešit před implementací dotčené funkce.

Na Macu připravit nejmenší spustitelný AppKit projekt a ověřit NSTextView, undo, NSDocument a dvě karty v jednom okně. Vyzkoušet ukončení bez přepsání souboru a následnou obnovu. Rozhodnout mezi využitím AppKit konceptů a vlastní obnovou obsahu; neponechat dva nezávislé zdroje pravdy. Příkazy sestavení zapsat až podle skutečně fungujícího projektu.

Krátkou zkouškou ověřit také položku v horní liště, registraci globální zkratky bez sledování vstupu a návrat fokusu po skrytí rychlé poznámky. Ověřit dostupnost těchto možností na minimální cílové verzi macOS. Než vznikne jejich plné UI, zaznamenat případné omezení; nepřidávat kvůli tomu plošná oprávnění pro zachytávání kláves.

Hotovo: aplikace se skutečně spustí, český text projde uložením a načtením, dva dokumenty mají oddělené undo a původní soubor se při pouhé obnově nemění. Výsledky jsou přiřazené ke konkrétní revizi Gitu.

## B. Editor a soubory

Dokončit psaní, schránku, karty, menu, otevření a uložení včetně Uložit jako. Doplnit TextFileCodec a testy reálných bajtů. Zachovat kódování a konce řádků, otevřít více souborů a tutéž identitu neopakovat. Pokrýt zrušené dialogy, soubor bez oprávnění a změnu během ukládání.

Hotovo: P01 až P05 a P09 projdou pro formáty implementované v této etapě na běžícím Macu; Windows-1250 a ostatní odložené části P04 zůstávají výslovně netestované do etapy E. Souborové testy porovnávají bajty, ne pouze zobrazený text. Rozpracovaný text zůstane dostupný po každém neúspěšném uložení.

## C. Obnova a ochrana rozepsaných poznámek

Implementovat a ověřit chování zavření karty, okna a ukončení aplikace podle návrhu. Doplnit periodické snímky, dokončení při ukončení, verze relace, poškozené snímky a odstranění zahozených konceptů. Řešit chybějící nebo externě změněný soubor při obnově.

Hotovo: P06 až P08 a P10 projdou včetně skutečného ukončení procesu a nového spuštění. Ukončuje se jen ověřený PID testovací aplikace. Ověřit obsah na disku samostatně; otevřené okno nestačí jako důkaz obnovy.

## D. První použitelná verze

Doplnit hledání a nahrazování, základní zkratky, zalamování, přiblížení a motivy. Projít souvislou práci: vytvořit poznámky, upravit soubor, uložit kopii, ukončit a pokračovat. První použitelná verze vzniká až po etapách A až D, nikoli po pouhém zobrazení editoru.

Hotovo: základní scénáře P01 až P11 v rozsahu A až D; odložené formáty P04 a přechod na řádek z P11 označit jako netestované. Žádná známá ztráta dat, blokující chyba ukládání ani nefunkční obnova. Výkon je alespoň orientačně změřený podle stejného postupu jako níže.

## E. Rozšířená verze 1.0

Doplnit přesun a pořadí karet, více oken, nedávné soubory, přetažení, tisk, přechod na řádek, stavový řádek, písmo a další kódování. Dokončit české a anglické UI, VoiceOver, ovládání klávesnicí a testy externí Windows klávesnice. Ověřit všechny navržené výjimky vůči Notepadu.

Rozšíření přidávat v tomto pořadí: E02 připnutí a názvy karet, E03 přepínač a příkazy, E04 hledání napříč kartami, E05 znovuotevření, E06 Uložit vše, E07 textové příkazy, E08 soustředění a okno navrchu, nakonec E01 rychlá poznámka nad již ověřenou obnovou. Každé rozšíření musí zachovat stejné příkazy menu, dokumentový stav a pravidla ochrany dat.

Pro podobu projít čtyři konkrétní obrazovky: běžné psaní, 20 otevřených karet, hledání napříč kartami a rychlou poznámku. U všech ověřit malou šířku okna, velké písmo, světlý a tmavý motiv. Volitelné panely nesmějí zmenšovat editor, když nejsou otevřené. Ukázky vzhledu připravovat až nad skutečným UI; nynější schéma v návrhu je pouze rozmístění prvků.

Hotovo: P01 až P14 a P16 až P23 projdou v úplném rozsahu podporované konfigurace. Kritické scénáře ukládání, obnovy a přístupu k příkazům nesmějí zůstat neověřené. Zbývající omezení musí mít rozhodnutí o opravě nebo o zúžení deklarované podpory. Chybějící fyzická klávesnice není úspěšný test kláves. Neověřená platforma se neuvádí jako podporovaná.

## F. Příprava veřejného vydání

Bundle identifier je com.nkshub.macpad, název MacPad a licence MIT. Veřejný repozitář je nks-hub/nks-macpad. Distribuční vydání je samostatný krok: připravit opakovatelný release build, podpis, notarizaci a balíček. Ověřit čistou instalaci i aktualizaci s existujícími poznámkami a stabilním umístěním dat. Spuštění staženého balíčku musí projít běžnou kontrolou Gatekeeperu.

Před prvním zveřejněním zkontrolovat celý dosud neveřejný Git včetně historie na přístupy, soukromé adresy a nechtěné soubory. Zkontrolovat licence použitých závislostí a vlastní grafiku. Zveřejnění repozitáře ani release není součástí současného zadání.

Hotovo: P15 projde na skutečném distribučním balíčku; archiv má verzi, commit a kontrolní součet. Nestačí úspěšné sestavení nebo nahrání. Neověřený Intel nebo starší macOS uvést jako nepodporovaný, dokud nebude otestovaný.

## G. Navazující verze 1.1

Návrhy R01 až R04 implementovat jako samostatné celky: dva editory vedle sebe, volitelný náhled Markdownu, lokální historie uložených verzí a porovnání externích změn. Rozdělené zobrazení musí sdílet existující dokumenty; Markdown nesmí změnit ukládaný čistý text; historie musí mít limity a mazání; porovnání nesmí samo sloučit nebo přepsat obsah.

Hotovo každého celku: jeho scénář P24 až P27 a dotčené testy ukládání a obnovy projdou na skutečné aplikaci. Výběr parseru, licence a další závislosti se řeší až pro konkrétní funkci. Tato etapa nesmí zdržet samostatné vydání dokončené verze 1.0.

## Scénáře přijetí

| ID | Scénář | Co musí být doložené |
| --- | --- | --- |
| P01 | Spuštění bez relace, psaní českého textu a emoji | Fokus v editoru, čistý text, beze změn uvozovek a pomlček |
| P02 | Vložení formátovaného textu, undo/redo, přepínání karet | Jen text; undo patří správné kartě, kurzor a výběr se neztratí |
| P03 | Uložit, Uložit jako, Zrušit, existující cíl | Správné bajty a název; zrušení nemění identitu ani nezahazuje změny |
| P04 | UTF-8, BOM, UTF-16, CRLF/LF, chybné bajty a Windows-1250 | Zachování formátu; ruční volba u nejistoty; žádná tichá ztráta znaků |
| P05 | Stejný soubor dvakrát, alias, otevření z Finderu, soubor bez přípony | Jedna identita, správná aktivace, očekávaný způsob otevření |
| P06 | Zavření změněné karty všemi volbami dialogu | Uložení, výslovné zahození, nebo beze změny po Zrušit |
| P07 | Zavření okna, Cmd+Q, znovuspuštění, vypnutá obnova | Obsah i pořadí karet a kurzor; původní soubory beze změny |
| P08 | Pád po snímku i během zápisu, poškozený snímek | Poslední úplná relace; zdravé poznámky zůstávají, chyba je viditelná |
| P09 | Zákaz zápisu, plný disk, ztracený cíl a editace během ukládání | Starý soubor zůstane celý, změny zůstanou označené, lze uložit kopii |
| P10 | Externí změna, přejmenování či smazání souboru | Žádné tiché přepsání; uživatel zvolí načtení nebo zachování své verze |
| P11 | Hledat, nahradit vše, přechod na řádek, Unicode, zalamování | Správný rozsah, počet změn a undo; zobrazení nemění bajty souboru |
| P12 | Zkratky, pořadí a přesun karet mezi okny, menu, tisk | Shoda s dohodnutou mapou; dialogy i VoiceOver zůstanou ovladatelné |
| P13 | Světlý/tmavý motiv, velké písmo, čeština/angličtina, VoiceOver | Čitelné a dostupné příkazy, žádné skryté ovládání ani uříznuté texty |
| P14 | Start, 20 karet, dlouhý řádek, soubory 1/10/50 MiB | Změřená odezva, paměť a časy; žádné zamrznutí bez odezvy |
| P15 | Podpis, notarizace, instalace, aktualizace, odinstalace | Spustitelný balík a zachované dokumenty i koncepty při aktualizaci |
| P16 | E01: vyvolání rychlé poznámky, psaní, Escape, přesun, restart, Cmd+Q | Stejný koncept bez duplikace, úspěšný snímek před skrytím, návrat fokusu, zkratka po ukončení neaktivní; ověřit kolizi zkratky a vypnutou obnovu |
| P17 | E02: připnout a pojmenovat koncept, přesunout, restartovat a uložit | Metadata přežijí obnovu, název se nabídne při uložení, existující soubor se nepřejmenuje |
| P18 | E03: filtrovat karty a příkazy, vybrat klávesnicí, Escape | Správný dokument, dostupné akce odpovídají menu, fokus se vrátí; Cmd+P dál tiskne |
| P19 | E04: hledat ve více oknech, editovat nebo zavřít kartu během hledání | Výsledky obsahují koncepty, staré pozice nejsou použité, žádné hledání mimo otevřené dokumenty |
| P20 | E05: znovuotevřít uložený, smazaný a již otevřený soubor; zahozený koncept | Správná identita a kurzor, chyba u chybějícího souboru, žádná obnova výslovně zahozeného textu; limit 20 odkazů a vymazání seznamů |
| P21 | E06: uložit pojmenované i nové dokumenty, Zrušit, chyba, další editace | Přesný výsledek pro každý dokument, již uložené zůstanou uložené, zbytek zůstane změněný |
| P22 | E07: příkazy nad českým textem, duplicitami, posledním řádkem a výběrem | Stanovený rozsah, zachované konce řádků a prázdné řádky, celý příkaz lze vrátit jediným undo |
| P23 | E08: soustředění, okno navrchu a vzhled v úzkém okně, s 20 kartami a VoiceOverem | Všechny režimy lze opustit, aktivní stav je viditelný, editor má fokus; po restartu okno není navrchu |
| P24 | R01: dva panely, stejný i různý dokument, uložení a undo | Sdílená identita, jasný aktivní panel, bez přepsání starší kopií |
| P25 | R02: Markdown, HTML, skripty, vzdálené obrázky a odkazy | Zdrojový text se nemění, žádné spuštění aktivního obsahu a automatické síťové požadavky |
| P26 | R03: uložení, obnova starší verze, limity, vymazání historie a selhání archivace | Obnova jako nový koncept, správné prořezání historie, aktuální data zachována; zahozené změny se nearchivují |
| P27 | R04: externí změna během porovnávání, český text, různé konce řádků | Označené revize a aktuálnost porovnání; změna na disku zneplatní staré potvrzení přepsání |

P09 se nejprve testuje řízeným selháním souborového zápisu. Skutečný plný disk pouze na omezeném testovacím svazku; nikdy zaplněním systémového disku. Testy používají izolovanou datovou složku a umělé dokumenty.

P16 až P23 testují vlastní rozšíření MacPadu; výsledek není tvrzením o shodě s Windows. P24 až P27 jsou vyhrazené verzi 1.1 a nesmějí se vykazovat jako dokončené při vydání 1.0.

## Jak testovat bez zbytečného opakování

- XCTest: převody souborů, změnové stavy a revize, návrat po chybě, relace a obnova; žádné testy kopírující jen implementaci.
- Integrační testy: skutečné dočasné soubory, atomický zápis, konflikt externí změny, přesné bajty a přerušená obnova.
- Testy běžící aplikace: XCTest UI pro stabilní scénáře, VNC pro vizuální kontrolu a skutečné menu, dialogy a fokus.
- Klávesnice a přístupnost: fyzická klávesnice a VoiceOver; vzdálený vstup může změnit význam modifikátorů.
- Kontroly změny: nejmenší příslušná sada po každém celku; plný scénářový průchod před milníkem nebo vydáním.

Každý záznam ověření obsahuje commit, verzi aplikace, macOS, architekturu, způsob vstupu, scénář, očekávaný a skutečný výsledek. Rozlišovat „prošlo“, „selhalo“ a „netestováno“. Soukromé logy a snímky ukládat mimo Git; do projektu patří jen očištěný souhrn výsledků.

Vzdálené sestavení běží na pozadí s identifikátorem procesu a záznamem výsledku. Testy GUI běží v přihlášené uživatelské relaci, nikoli jako root. Přístupy a testovací adresy se berou ze schválené paměti a nikdy z veřejného repozitáře. Před spuštěním ověřit aktuální stav testovacího stroje.

## Výkonnostní cíle

Navržené cíle pro referenční Apple Silicon Mac: studený start do připraveného editoru nejvýše 1 s, vložení a otevření 1 MiB do 300 ms a 10 MiB do 2 s. Při běžném psaní cílit na odezvu pod 50 ms. Klidová paměť s prázdnou kartou má orientační rozpočet 100 MiB RSS. Nejde o naměřené výsledky ani slib pro každý Mac.

Pro rozšíření navrhuji vyvolání rychlé poznámky v běžící aplikaci do 300 ms a první výsledky hledání ve 20 kartách s celkem 10 MiB textu do 500 ms. Hledání musí jít zrušit a nesmí blokovat psaní. Rychlá poznámka nepřidává vlastní nepřetržitě běžící skenování disku ani schránky.

Měřit release build bez debuggeru. Uvést model stroje a medián i nejhorší výsledek pěti opakování, oddělit studený a opakovaný start a obnovu relace. Odezvu psaní neměřit podle latence VNC. Pro 50 MiB soubor ověřit zrušení operace a odezvu UI; případné omezení velikosti určit podle měření a přiznat před otevřením, nikoli soubor zkrátit.
