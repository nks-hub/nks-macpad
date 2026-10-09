[![Platforma macOS](https://img.shields.io/badge/platforma-macOS-111827)](#požadavky)
[![Swift a AppKit](https://img.shields.io/badge/Swift-AppKit-F05138?logo=swift&logoColor=white)](#sestavení-ze-zdrojů)
[![Licence MIT](https://img.shields.io/badge/licence-MIT-2563EB)](LICENSE)

# MacPad

MacPad je textový editor pro macOS s kartami a ovládáním inspirovaným Poznámkovým blokem ve Windows 11. Otevřete jej, začněte psát a k rozepsaným poznámkám se vraťte po dalším spuštění. Důležité karty lze připnout a text najít napříč otevřenými poznámkami.

**Projekt je ve vývojové verzi 0.1.0.** Aktuálně je určený k sestavení ze zdrojů; podepsaný a notarizovaný instalační balík zatím není vydaný. MacPad je samostatný projekt NKS Hub, není produktem Microsoftu.

## Jak vypadá

![MacPad ve světlém režimu s připnutou poznámkou a třemi kartami](docs/screenshots/macpad-light.png)

<details>
<summary>Tmavý režim</summary>

![MacPad v tmavém režimu](docs/screenshots/macpad-dark.png)

</details>

Obrázky pocházejí ze skutečně spuštěné aplikace. Obsah poznámek je smyšlený.

## Co umí

- **Poznámky v kartách:** nové karty, přepínání, připnutí, vlastní názvy konceptů, přesun mezi okny a znovuotevření zavřeného souboru.
- **Běžné textové soubory:** otevřít, uložit, uložit jako a uložit vše. UTF-8, UTF-16 a Windows-1250; zachování kódování, BOM a konců řádků.
- **Návrat k rozepsané práci:** obnova konceptů, pořadí karet, výběru a posunu. Obnovovací kopie nemění původní soubor.
- **Hledání:** hledat a nahradit v aktuálním dokumentu, vyhledat text ve všech otevřených kartách a přeskočit přímo na výsledek.
- **Rychlé ovládání:** přepínač karet, nabídka příkazů, macOS zkratky a vybrané Ctrl zkratky známé z Windows.
- **Úpravy řádků:** datum a čas, duplikace, přesun, řazení a odstranění přesných duplicit ve výběru; změny lze vrátit.
- **Vlastní pracovní prostředí:** světlý, tmavý a systémový vzhled, písmo, přiblížení, zalamování, čísla řádků, soustředění a okno navrchu.
- **Rychlá poznámka:** kompaktní okno, volitelná položka v horní liště macOS a nastavitelná zkratka. Funguje, když aplikace běží.

Rozhraní je česky a anglicky. Editor pracuje s čistým textem. Náhled Markdownu, rozdělený pohled, historie uložených verzí a porovnání změn jsou navržené pro další verzi, zatím nejsou součástí aplikace.

## Požadavky

| Oblast | Aktuální stav |
| --- | --- |
| Systém | Cíl sestavení je macOS 14 a novější; běh zatím ověřen na macOS 15.7.4 |
| Procesor | Ověřeno na Apple Silicon; Intel zatím neověřen |
| Vývoj | Xcode 26.3 a XcodeGen 2.44.1 |
| Běhové závislosti | Nativní AppKit, Foundation, CryptoKit a Carbon; žádné externí balíčky |
| Distribuce | Vývojový nepodepsaný build ze zdrojů |

## Sestavení ze zdrojů

Nainstalujte Xcode a [XcodeGen](https://github.com/yonaskolb/XcodeGen). XcodeGen musí být v PATH; případně nastavte proměnnou `XCODEGEN` na jeho spustitelný soubor.

```sh
git clone https://github.com/nks-hub/nks-macpad.git
cd nks-macpad
bash scripts/build.sh build
open build/DerivedData/Build/Products/Debug/MacPad.app
```

Skript generuje projekt z `project.yml`. Generovaný `MacPad.xcodeproj`, sestavení a místní nastavení nepatří do Gitu.

Identifikátor aplikace je `com.nkshub.macpad`. Společná knihovna používá `com.nkshub.macpad.core`.

## Klávesové zkratky

| Akce | Zkratka |
| --- | --- |
| Nová karta / nové okno | ⌘N nebo ⌘T / ⇧⌘N |
| Otevřít / uložit / uložit jako | ⌘O / ⌘S / ⇧⌘S |
| Uložit vše | ⌥⌘S |
| Zavřít kartu / okno | ⌘W / ⇧⌘W |
| Hledat / nahradit | ⌘F / ⌥⌘F |
| Hledat ve všech kartách | ⇧⌘F |
| Přepínač karet / příkazy | ⌘K / ⇧⌘P |
| Znovu otevřít zavřený soubor | ⇧⌘T |
| Zpět / znovu | ⌘Z / ⇧⌘Z |
| Tisk | ⌘P |

Ctrl aliasy platí uvnitř editoru a nepřepisují systémovou klávesnici. Globální zkratka rychlé poznámky se zapíná až jejím nastavením.

## Ukládání a soukromí

Soubory na disku se mění až po příkazu k uložení. Při změně souboru jiným programem aplikace upozorní na konflikt. Pokud ke změně dojde těsně během nahrazení souboru, zachová externí obsah v samostatné kopii a ukáže její cestu.

Rozepsané koncepty jsou v `~/Library/Application Support/MacPad`. Nejde o šifrovaný trezor. Obnovu lze vypnout v nastavení; před vypnutím je potřeba uložit nebo zavřít změněné poznámky. Výslovné zahození odstraňuje koncept z obou obnovovacích kopií.

MacPad nevyžaduje účet, nepřidává vlastní cloudovou synchronizaci a neodesílá obsah poznámek. Běžný soubor můžete uložit do své synchronizované složky, souběžné editace však dál mohou vyvolat konflikt.

## Testy a ověření

```sh
bash scripts/build.sh test
```

Při review implementace prošlo na macOS 15.7.4 **76 automatických testů** v konfiguraci Release: 37 testů souborové vrstvy a obnovy a 39 testů AppKitu, životního cyklu a výkonu. Opravy se týkaly mimo jiné zahozených změn při hromadném ukládání, hranic Unicode a řádků, obnovy posunu, kódování a rušení otevíraných souborů.

Na Apple M1 Pro trvalo otevření 50 MiB textu s krátkými ASCII řádky v mediánu 643 ms a vložení znaku na konec 9 ms. Měření úpravy nezahrnuje následné vykreslení. Postup, podmínky a výsledky pro další velikosti jsou v [záznamu měření](docs/VALIDATION.md#měření-výkonu).

Pro testy v konfiguraci Release:

```sh
CONFIGURATION=Release bash scripts/build.sh test
```

Přehled konkrétních výsledků a zbývajících mezer je v [záznamu ověření](docs/VALIDATION.md). Automatické testy nenahrazují ověření fyzické klávesnice, VoiceOveru ani všech podporovaných verzí macOS. Podepisování a notarizace zůstávají před veřejným distribučním vydáním.

Pro vlastní izolované testování lze nastavit `MACPAD_SESSION_DIR` na samostatnou složku. Nepoužívejte skutečné osobní poznámky jako testovací data.

## Vývoj a hlášení chyb

- [Plán](PLAN.md) a [TODO](TODO.md) popisují další práci.
- [Návrh chování](docs/plans/2026-10-09-macpad-design.md) vysvětluje ukládání, obnovu a rozšíření.
- Chyby a návrhy patří do [GitHub Issues](https://github.com/nks-hub/nks-macpad/issues).

K hlášení přidejte verzi macOS, architekturu, revizi aplikace a kroky k reprodukci. Přiložený příklad má obsahovat pouze smyšlený text. Do změn neposílejte osobní dokumenty, přístupy, podpisové klíče ani interní adresy.

## Licence

[MIT](LICENSE). Kód můžete používat, upravovat a šířit za podmínek této licence.

Projekt [NKS Hub](https://github.com/nks-hub).
