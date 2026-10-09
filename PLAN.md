# Plán implementace a ověření

Závazný rozsah aktuální etapy je příprava projektu. Návrh funkcí a pravidel je v [analýze](docs/plans/2026-10-09-macpad-design.md); stav jednotlivých úkolů je v [TODO](TODO.md). Funkce níže zatím nejsou implementované. Etapy se dokončují v uvedeném pořadí, protože obnova a bezpečné ukládání ovlivňují zbytek aplikace.

## A. Reference a technická zkouška

Zaznamenat chování referenčního Windows Notepadu na umělých souborech: karty, zavření, ukončení, uložení, obnova, zkratky a kódování. U každého výsledku uvést verzi, nastavení a rozdíl proti návrhu. Rozpor vyřešit před implementací dotčené funkce.

Na Macu připravit nejmenší spustitelný AppKit projekt a ověřit NSTextView, undo, NSDocument a dvě karty v jednom okně. Vyzkoušet ukončení bez přepsání souboru a následnou obnovu. Rozhodnout mezi využitím AppKit konceptů a vlastní obnovou obsahu; neponechat dva nezávislé zdroje pravdy. Příkazy sestavení zapsat až podle skutečně fungujícího projektu.

Hotovo: aplikace se skutečně spustí, český text projde uložením a načtením, dva dokumenty mají oddělené undo a původní soubor se při pouhé obnově nemění. Výsledky jsou přiřazené ke konkrétní revizi Gitu.

## B. Editor a soubory

Dokončit psaní, schránku, karty, menu, otevření a uložení včetně Uložit jako. Doplnit TextFileCodec a testy reálných bajtů. Zachovat kódování a konce řádků, otevřít více souborů a tutéž identitu neopakovat. Pokrýt zrušené dialogy, soubor bez oprávnění a změnu během ukládání.

Hotovo: P01 až P05 a P09 projdou na běžícím Macu; souborové testy porovnávají bajty, ne pouze zobrazený text. Rozpracovaný text zůstane dostupný po každém neúspěšném uložení.

## C. Obnova a ochrana rozepsaných poznámek

Implementovat a ověřit chování zavření karty, okna a ukončení aplikace podle návrhu. Doplnit periodické snímky, dokončení při ukončení, verze relace, poškozené snímky a odstranění zahozených konceptů. Řešit chybějící nebo externě změněný soubor při obnově.

Hotovo: P06 až P08 a P10 projdou včetně skutečného ukončení procesu a nového spuštění. Ukončuje se jen ověřený PID testovací aplikace. Ověřit obsah na disku samostatně; otevřené okno nestačí jako důkaz obnovy.

## D. První použitelná verze

Doplnit hledání a nahrazování, základní zkratky, zalamování, přiblížení a motivy. Projít souvislou práci: vytvořit poznámky, upravit soubor, uložit kopii, ukončit a pokračovat. První použitelná verze vzniká až po etapách A až D, nikoli po pouhém zobrazení editoru.

Hotovo: základní scénáře P01 až P11, žádná známá ztráta dat, blokující chyba ukládání ani nefunkční obnova. Výkon je alespoň orientačně změřený podle stejného postupu jako níže.

## E. Shoda ovládání a dokončení verze 1.0

Doplnit přesun a pořadí karet, více oken, nedávné soubory, přetažení, tisk, přechod na řádek, stavový řádek, písmo a další kódování. Dokončit české a anglické UI, VoiceOver, ovládání klávesnicí a testy externí Windows klávesnice. Ověřit všechny navržené výjimky vůči Notepadu.

Hotovo: všechna kritéria P01 až P14 mají výsledek nebo výslovně označenou mezeru. Chybějící fyzická klávesnice není úspěšný test kláves. Neověřená platforma se neuvádí jako podporovaná.

## F. Příprava veřejného vydání

Zvolit licenci, název a bundle identifier. Připravit opakovatelný release build, podpis, notarizaci a balíček. Ověřit čistou instalaci i aktualizaci s existujícími poznámkami a stabilním umístěním dat. Spuštění staženého balíčku musí projít běžnou kontrolou Gatekeeperu.

Před prvním zveřejněním zkontrolovat celý dosud neveřejný Git včetně historie na přístupy, soukromé adresy a nechtěné soubory. Zkontrolovat licence použitých závislostí a vlastní grafiku. Zveřejnění repozitáře ani release není součástí současného zadání.

Hotovo: P15 projde na skutečném distribučním balíčku; archiv má verzi, commit a kontrolní součet. Nestačí úspěšné sestavení nebo nahrání. Neověřený Intel nebo starší macOS uvést jako nepodporovaný, dokud nebude otestovaný.

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

P09 se nejprve testuje řízeným selháním souborového zápisu. Skutečný plný disk pouze na omezeném testovacím svazku; nikdy zaplněním systémového disku. Testy používají izolovanou datovou složku a umělé dokumenty.

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

Měřit release build bez debuggeru. Uvést model stroje a medián i nejhorší výsledek pěti opakování, oddělit studený a opakovaný start a obnovu relace. Odezvu psaní neměřit podle latence VNC. Pro 50 MiB soubor ověřit zrušení operace a odezvu UI; případné omezení velikosti určit podle měření a přiznat před otevřením, nikoli soubor zkrátit.
