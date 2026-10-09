# Úkoly

Zaškrtnuté jsou pouze dokončené a ověřené položky. Podrobnosti a kritéria jsou v [plánu](PLAN.md).

## Příprava

- [x] Ověřit výchozí stav adresáře a založit lokální Git na větvi main.
- [x] Připravit ignorování místních souborů, přístupů, sestavení a testovacích výstupů.
- [x] Dohledat zdroje k chování Windows Notepadu a zjistit lokální verzi reference.
- [x] Ověřit dostupnost vzdáleného Macu, Xcode, Swiftu a odpověď VNC služby.
- [x] Sepsat návrh, varianty technologie, pravidla ukládání a rozsah první verze.
- [x] Rozdělit implementaci na etapy s měřitelnými kritérii přijetí.

## A. Reference a technická zkouška

- [ ] Změřit P01 až P12 v izolované relaci Windows Notepadu a zaznamenat verzi i nastavení.
- [ ] Uzavřít rozdíly vůči referenci: zkratky, zavření oken, konce řádků a formát souborů.
- [ ] Ověřit přihlášení do VNC a běh testů v uživatelské relaci Macu.
- [ ] Vytvořit AppKit projekt, opakovatelný build a XCTest targety.
- [ ] Ověřit dvě karty, NSDocument, NSTextView, oddělené undo a bezpečné explicitní ukládání.
- [ ] Funkčním pokusem vybrat jediný způsob obnovy obsahu a vyřešit ukončení bez přepsání souboru.

## B. Editor a soubory

- [ ] Implementovat čistý text, schránku, výběr, undo/redo a vypnutí automatických náhrad textu.
- [ ] Implementovat karty, fokus, názvy, označení změn a příkazy menu.
- [ ] Implementovat otevření více souborů, Finder a rozpoznání opakovaného otevření stejné identity.
- [ ] Implementovat Uložit a Uložit jako včetně zrušení, přepsání cíle a chyby oprávnění.
- [ ] Implementovat striktní UTF-8, BOM, UTF-16 a zachování LF/CRLF s bajtovými testy.
- [ ] Zajistit atomický zápis, kontrolu revize a ochranu před externí změnou při ukládání.
- [ ] Ověřit P01 až P05 a P09 na běžící aplikaci a skutečných souborech.

## C. Obnova

- [ ] Implementovat verzovanou relaci a průběžné snímky bez zápisu do zdrojového dokumentu.
- [ ] Implementovat rozdílné zavření karty, okna a aplikace včetně Zrušit a vypnuté obnovy.
- [ ] Obnovovat obsah, pořadí, aktivní kartu, kurzor a posun; chybějící soubor nabídnout uložit jinam.
- [ ] Ošetřit chybu snímku, poškozená data, přerušení zápisu a novější neznámé schéma.
- [ ] Po výslovném zahození odstranit koncept i jeho obnovovací kopie.
- [ ] Ověřit P06 až P08 a P10 včetně pádu a nového spuštění procesu.

## D. První použitelná verze

- [ ] Doplnit hledání, nahrazování a nahradit vše jako vratnou změnu.
- [ ] Doplnit zkratky Cmd a vybrané Ctrl aliasy omezené na editor.
- [ ] Doplnit zalamování, přiblížení a systémový, světlý i tmavý vzhled.
- [ ] Projít souvislou práci s poznámkami včetně ukončení a obnovy, P01 až P11.
- [ ] Změřit první výkonové výsledky release buildu a odstranit blokující chyby.

## E. Verze 1.0

- [ ] Doplnit pořadí karet, přesun mezi okny a obnovu více oken.
- [ ] Doplnit nedávné soubory, přetažení a tisk.
- [ ] Doplnit přechod na řádek, písmo a přesný stavový řádek nad Unicode.
- [ ] Doplnit Windows-1250, explicitní převody a rozhodnutí pro smíšené konce řádků.
- [ ] Dokončit češtinu a angličtinu, VoiceOver, kontrast a ovládání bez myši.
- [ ] Ověřit Home/End, výběr a modifikátory na fyzické Mac i Windows klávesnici.
- [ ] Ověřit P12 až P14, dlouhé řádky, větší soubory a navržené výkonové cíle.
- [ ] Otestovat nejnižší podporovaný macOS; Intel podporovat pouze po samostatném ověření.

## F. Veřejné vydání

- [ ] Rozhodnout konečný název, bundle identifier, licenci a cílový veřejný repozitář.
- [ ] Připravit release sestavení a potvrdit oprávněnou podpisovou identitu.
- [ ] Podepsat, notarizovat a ověřit balíček přes Gatekeeper na běžné instalaci.
- [ ] Ověřit P15 včetně aktualizace se zachováním konceptů a dokumentů.
- [ ] Zkontrolovat obsah i historii Gitu na citlivé údaje a přiložené nechtěné soubory.
- [ ] Doplnit skutečně ověřený návod k sestavení a instalaci, licenci a známá omezení.
- [ ] Zveřejnit repozitář a první release až v rámci výslovného zadání k publikaci.
