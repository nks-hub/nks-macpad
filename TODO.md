# Úkoly

Zaškrtnuté jsou pouze dokončené a ověřené položky. Podrobnosti a kritéria jsou v [plánu](PLAN.md).

Implementace editoru a rozšíření E01 až E08 i R01 až R04 je ve zdrojích. Nad zdroji s výběrem kódování prošlo 132 automatických testů na Macu; revize `336e769` má navíc cílenou kontrolu viditelného náhledu a GUI průchod souborových formátů. Otevřené body zahrnují i implementované funkce, kterým ještě chybí úplná přejímka podle plánu; skutečný rozsah je v [záznamu ověření](docs/VALIDATION.md).

## Před pokračováním v ověřování

- [x] Sestavit zdroje odpovídající 82ab271 v Release a spustit připravené testy: 89 prošlo.
- [x] Ověřit nové nastavení, změnu zkratky, vkládání CRLF textu a otevírání souborů na pozadí včetně zrušení (zrušení fronty jen testem, 106 MB se načte dřív, než zrušení dorazí).
- [x] Ověřit klikání, zavírání a přetažení nových karet, nabídky a světlé i tmavé vykreslení.
- [x] Zachytit skutečné světlé a tmavé UI a ověřit výběr karty, výsledek hledání, rychlou poznámku a uložení přes GUI.
- [x] Prověřit ochranu obnovy při vynuceném spuštění více procesů nad stejnou datovou složkou.

## Příprava

- [x] Ověřit výchozí stav adresáře a založit lokální Git na větvi main.
- [x] Připravit ignorování místních souborů, přístupů, sestavení a testovacích výstupů.
- [x] Dohledat zdroje k chování Windows Notepadu a zjistit lokální verzi reference.
- [x] Ověřit dostupnost vzdáleného Macu, Xcode, Swiftu a odpověď VNC služby.
- [x] Sepsat návrh, varianty technologie, pravidla ukládání a rozsah první verze.
- [x] Rozdělit implementaci na etapy s měřitelnými kritérii přijetí.
- [x] Zpracovat druhou iteraci: rozšíření E01 až E08, podobu UI a navazující návrhy R01 až R04.

## A. Reference a technická zkouška

- [ ] Změřit P01 až P12 v izolované relaci Windows Notepadu a zaznamenat verzi i nastavení.
- [ ] Uzavřít rozdíly vůči referenci: zkratky, zavření oken, konce řádků a formát souborů.
- [x] Ověřit přihlášení do VNC a běh testů v uživatelské relaci Macu.
- [x] Vytvořit AppKit projekt, opakovatelný build a XCTest targety.
- [x] Ověřit dvě karty, NSDocument, NSTextView, oddělené undo a bezpečné explicitní ukládání na původním rozhraní.
- [x] Zvolit vlastní SessionStore a ověřit ukončení bez přepsání zdrojového souboru.
- [ ] Ověřit horní lištu, registraci a kolize globální zkratky a návrat fokusu rychlé poznámky.

## B. Editor a soubory

- [x] Implementovat čistý text, schránku, výběr, undo/redo a vypnutí automatických náhrad textu.
- [x] Implementovat karty, fokus, názvy, označení změn a příkazy menu.
- [x] Implementovat otevření více souborů, Finder a rozpoznání opakovaného otevření stejné identity.
- [ ] Implementovat Uložit a Uložit jako včetně zrušení, přepsání cíle a chyby oprávnění.
- [x] Implementovat striktní UTF-8, BOM, UTF-16 a zachování LF/CRLF s bajtovými testy.
- [x] Zajistit atomický zápis, kontrolu revize a ochranu před externí změnou při ukládání.
- [ ] Ověřit P01 až P05 a P09 na běžící aplikaci a skutečných souborech.

## C. Obnova

- [x] Implementovat verzovanou relaci a průběžné snímky bez zápisu do zdrojového dokumentu.
- [ ] Implementovat rozdílné zavření karty, okna a aplikace včetně Zrušit a vypnuté obnovy.
- [ ] Obnovovat obsah, pořadí, aktivní kartu, kurzor a posun; chybějící soubor nabídnout uložit jinam.
- [ ] Ošetřit chybu snímku, poškozená data, přerušení zápisu a novější neznámé schéma.
- [x] Po výslovném zahození odstranit koncept i jeho obnovovací kopie.
- [ ] Ověřit P06 až P08 a P10 včetně pádu a nového spuštění procesu.

## D. První použitelná verze

- [x] Doplnit hledání, nahrazování a nahradit vše jako vratnou změnu.
- [x] Doplnit zkratky Cmd a vybrané Ctrl aliasy omezené na editor.
- [ ] Doplnit zalamování, přiblížení a systémový, světlý i tmavý vzhled.
- [ ] Projít souvislou práci s poznámkami včetně ukončení a obnovy, P01 až P11.
- [x] Změřit první výkonové výsledky release buildu pro 1/10/50 MiB a odstranit nalezené zpomalení editoru.

## E. Rozšířená verze 1.0

- [ ] Doplnit pořadí karet, přesun mezi okny a obnovu více oken.
- [ ] Doplnit nedávné soubory, přetažení a tisk.
- [ ] Doplnit přechod na řádek, volitelná čísla řádků, písmo a stavový řádek včetně výběru nad Unicode.
- [ ] Doplnit Windows-1250, explicitní převody a rozhodnutí pro smíšené konce řádků.
- [ ] Dokončit češtinu a angličtinu, VoiceOver, kontrast a ovládání bez myši.
- [ ] Ověřit Home/End, výběr a modifikátory na fyzické Mac i Windows klávesnici.
- [ ] Ověřit P12 až P14, dlouhé řádky, větší soubory a navržené výkonové cíle.
- [ ] Otestovat nejnižší podporovaný macOS; Intel podporovat pouze po samostatném ověření.
- [ ] E02: doplnit připnutí a vlastní názvy konceptů se zachováním po restartu; ověřit P17.
- [ ] E03: přidat přepínač karet a vyhledání existujících příkazů menu; ověřit P18.
- [x] E04: přidat hledání ve všech otevřených textech s kontrolou revizí a zrušením; ověřit P19.
- [ ] E05: přidat znovuotevření zavřeného souboru bez archivace zahozených změn a mazání seznamů; ověřit P20.
- [ ] E06: přidat Uložit vše s pravdivým výsledkem po zrušení nebo částečném selhání; ověřit P21.
- [ ] E07: přidat datum a čas, duplikaci, přesun a úpravy označených řádků s jedním undo; ověřit P22.
- [ ] E08: přidat režim soustředění a dočasné okno navrchu s dostupným vypnutím; ověřit P23.
- [ ] E01: přidat rychlou poznámku ze systémové lišty a zkratky nad stejným dokumentovým stavem; ověřit P16.
- [x] Ověřit běžné psaní, 20 karet, výsledky hledání a rychlou poznámku v malé šířce, obou motivech a s velkým písmem (440/480 bodů, písmo 24 bodů, revize `89800eb`).
- [x] Změřit odezvu rychlé poznámky a hledání napříč kartami podle doplněných výkonových cílů: 1/16 ms a 334/335 ms (medián/maximum, pět opakování).

## F. Veřejné vydání

- [x] Nastavit identifikátory com.nkshub.macpad a com.nkshub.macpad.core.
- [x] Zvolit MacPad, licenci MIT a veřejný repozitář nks-hub/nks-macpad.
- [ ] Připravit release sestavení a potvrdit oprávněnou podpisovou identitu.
- [ ] Podepsat, notarizovat a ověřit balíček přes Gatekeeper na běžné instalaci.
- [ ] Ověřit P15 včetně aktualizace se zachováním konceptů a dokumentů.
- [x] Zkontrolovat obsah i historii Gitu před zveřejněním na citlivé údaje a nechtěné soubory.
- [x] Doplnit ověřený návod k sestavení a spuštění, licenci MIT a známá omezení.
- [x] Zveřejnit repozitář nks-hub/nks-macpad podle zadání.
- [ ] Vydat první distribuční balíček až po přejímce, podpisu a notarizaci v rámci zadání k vydání.

## G. Návrhy pro verzi 1.1

- [x] R01: rozdělit okno na dva pohledy se sdílenou identitou dokumentu; ověřit P24 (`f594ac1`, testy i běžící aplikace).
- [x] R02: vybrat parser a přidat volitelný bezpečný náhled Markdownu; ověřit P25 (`74fd171`, Foundation, testy i běžící aplikace).
- [x] R03: přidat volitelnou historii uložených verzí s limity, mazáním a obnovou do nového konceptu; ověřit P26 (`9578ba3`, testy i běžící aplikace).
- [x] R04: přidat porovnání externích změn s kontrolou aktuálnosti revizí; ověřit P27 (`f212946`, testy i běžící aplikace).
