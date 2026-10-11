# Úkoly

Zaškrtnuté jsou pouze dokončené a ověřené položky. Podrobnosti a kritéria jsou v [plánu](PLAN.md).

Implementace editoru a rozšíření E01 až E08 i R01 až R04 je ve zdrojích. Nad revizí `1b8cf91` prošlo 143 automatických testů na Macu. Tisk, rychlá poznámka z lišty, E08 a české i anglické ovládání s VoiceOverem prošly také v běžící aplikaci. Balíček 0.1.0 pro arm64 prošel podpisem, notarizací a přejímkou instalace/aktualizace na macOS 15.7.4. Otevřené body zahrnují i implementované funkce, kterým ještě chybí úplná přejímka podle plánu; skutečný rozsah je v [záznamu ověření](docs/VALIDATION.md).

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

- [ ] Dokončit P01 až P12 v izolovaném Notepadu 11.2607.14.0; vložení, formáty po editaci, tisk do PDF a ztracený cíl prošly, zbývají další větve obnovy/chyb, přesuny karet a úplná mapa zkratek.
- [ ] Uzavřít rozdíly vůči referenci: zkratky, zavření oken, konce řádků a formát souborů; volba kódování, společná identita hardlinků a ochrana externích změn jsou záměrné rozdíly.
- [x] Ověřit přihlášení do VNC a běh testů v uživatelské relaci Macu.
- [x] Vytvořit AppKit projekt, opakovatelný build a XCTest targety.
- [x] Ověřit dvě karty, NSDocument, NSTextView, oddělené undo a bezpečné explicitní ukládání na původním rozhraní.
- [x] Zvolit vlastní SessionStore a ověřit ukončení bez přepsání zdrojového souboru.
- [x] Ověřit horní lištu, registraci a kolize globální zkratky a návrat fokusu rychlé poznámky.

## B. Editor a soubory

- [x] Implementovat čistý text, schránku, výběr, undo/redo a vypnutí automatických náhrad textu.
- [x] Implementovat karty, fokus, názvy, označení změn a příkazy menu.
- [x] Implementovat otevření více souborů, Finder a rozpoznání opakovaného otevření stejné identity.
- [x] Implementovat Uložit a Uložit jako včetně zrušení, přepsání cíle a chyby oprávnění.
- [x] Implementovat striktní UTF-8, BOM, UTF-16 a zachování LF/CRLF s bajtovými testy.
- [x] Zajistit atomický zápis, kontrolu revize a ochranu před externí změnou při ukládání.
- [x] Ověřit P01 až P05 a P09 na běžící aplikaci a skutečných souborech.

## C. Obnova

- [x] Implementovat verzovanou relaci a průběžné snímky bez zápisu do zdrojového dokumentu.
- [x] Implementovat rozdílné zavření karty, okna a aplikace včetně Zrušit a vypnuté obnovy.
- [x] Obnovovat obsah, pořadí, aktivní kartu, kurzor a posun; chybějící soubor nabídnout uložit jinam.
- [x] Ošetřit chybu snímku, poškozená data, přerušení zápisu a novější neznámé schéma.
- [x] Po výslovném zahození odstranit koncept i jeho obnovovací kopie.
- [x] Ověřit P06 až P08 a P10 včetně pádu a nového spuštění procesu.

## D. První použitelná verze

- [x] Doplnit hledání, nahrazování a nahradit vše jako vratnou změnu.
- [x] Doplnit zkratky Cmd a vybrané Ctrl aliasy omezené na editor.
- [x] Doplnit zalamování, přiblížení a systémový, světlý i tmavý vzhled.
- [x] Projít souvislou práci s poznámkami včetně ukončení a obnovy, P01 až P11.
- [x] Změřit první výkonové výsledky release buildu pro 1/10/50 MiB a odstranit nalezené zpomalení editoru.

## E. Rozšířená verze 1.0

- [x] Doplnit pořadí karet, přesun mezi okny a obnovu více oken.
- [x] Doplnit nedávné soubory, přetažení a tisk.
- [x] Doplnit přechod na řádek, volitelná čísla řádků, písmo a stavový řádek včetně výběru nad Unicode.
- [x] Doplnit Windows-1250, explicitní převody a rozhodnutí pro smíšené konce řádků.
- [x] Dokončit češtinu a angličtinu, VoiceOver, kontrast a ovládání bez myši.
- [ ] Ověřit Home/End, výběr a modifikátory na fyzické Mac i Windows klávesnici; hardware není dostupný a syntetické vstupy tuto zkoušku nenahrazují.
- [ ] Uzavřít P12 až P14 a výkonové cíle; zrušení otevření 50 MiB prošlo, studený start po vyčištění cache má medián 1 775 ms proti cíli 1 000 ms.
- [x] Otestovat nejnižší podporovaný macOS; macOS 14.8.9 arm64 prošel 143 testy v CI, Intel zůstává nepodporovaný.
- [x] E02: doplnit připnutí a vlastní názvy konceptů se zachováním po restartu; ověřit P17.
- [x] E03: přidat přepínač karet a vyhledání existujících příkazů menu; ověřit P18.
- [x] E04: přidat hledání ve všech otevřených textech s kontrolou revizí a zrušením; ověřit P19.
- [x] E05: přidat znovuotevření zavřeného souboru bez archivace zahozených změn a mazání seznamů; ověřit P20.
- [x] E06: přidat Uložit vše s pravdivým výsledkem po zrušení nebo částečném selhání; ověřit P21.
- [x] E07: přidat datum a čas, duplikaci, přesun a úpravy označených řádků s jedním undo; ověřit P22.
- [x] E08: přidat režim soustředění a dočasné okno navrchu s dostupným vypnutím; ověřit P23.
- [x] E01: přidat rychlou poznámku ze systémové lišty a zkratky nad stejným dokumentovým stavem; ověřit P16.
- [x] Ověřit běžné psaní, 20 karet, výsledky hledání a rychlou poznámku v malé šířce, obou motivech a s velkým písmem (440/480 bodů, písmo 24 bodů, revize `89800eb`).
- [x] Změřit odezvu rychlé poznámky a hledání napříč kartami podle doplněných výkonových cílů: 1/16 ms a 334/335 ms (medián/maximum, pět opakování).

## F. Veřejné vydání

- [x] Nastavit identifikátory com.nkshub.macpad a com.nkshub.macpad.core.
- [x] Zvolit MacPad, licenci MIT a veřejný repozitář nks-hub/nks-macpad.
- [x] Připravit release sestavení a potvrdit oprávněnou podpisovou identitu.
- [x] Podepsat, notarizovat a ověřit balíček přes Gatekeeper na běžné instalaci.
- [x] Ověřit P15 včetně aktualizace se zachováním konceptů a dokumentů.
- [x] Zkontrolovat obsah i historii Gitu před zveřejněním na citlivé údaje a nechtěné soubory.
- [x] Doplnit ověřený návod k sestavení a spuštění, licenci MIT a známá omezení.
- [x] Zveřejnit repozitář nks-hub/nks-macpad podle zadání.
- [ ] Po přejímce vytvořit a vydat nový podepsaný a notarizovaný balíček v rámci zadání k vydání; ověřený balíček z `3206e99` ještě neobsahuje pozdější opravy.

## G. Návrhy pro verzi 1.1

- [x] R01: rozdělit okno na dva pohledy se sdílenou identitou dokumentu; ověřit P24 (`f594ac1`, testy i běžící aplikace).
- [x] R02: vybrat parser a přidat volitelný bezpečný náhled Markdownu; ověřit P25 (`74fd171`, Foundation, testy i běžící aplikace).
- [x] R03: přidat volitelnou historii uložených verzí s limity, mazáním a obnovou do nového konceptu; ověřit P26 (`9578ba3`, testy i běžící aplikace).
- [x] R04: přidat porovnání externích změn s kontrolou aktuálnosti revizí; ověřit P27 (`f212946`, testy i běžící aplikace).
