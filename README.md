# MacPad

MacPad je připravovaný textový editor pro macOS, který rozšiřuje ovládání známé z Poznámkového bloku ve Windows 11 o rychlé poznámky, připnuté karty a hledání napříč otevřenými texty.

Projekt je ve fázi analýzy a plánování. Aplikace ani instalační balík zatím neexistují. Pracovní název je MacPad.

Základ návrhu: otevřít, rovnou psát, snadno uložit a po dalším spuštění najít rozepsané poznámky. Obnova relace nesmí sama přepisovat původní soubory.

Plán verze 1.0 navíc zahrnuje rychlou poznámku z horní lišty macOS, vlastní názvy konceptů, přepínač karet a příkazů, návrat k zavřeným souborům, Uložit vše, jednoduché úpravy řádků a režim soustředění. Rozšířené funkce se zobrazují podle potřeby. Rozdělený pohled, náhled Markdownu, historie uložených verzí a porovnání změn jsou oddělené návrhy pro verzi 1.1.

- [Analýza a návrh chování](docs/plans/2026-10-09-macpad-design.md)
- [Plán implementace a ověření](PLAN.md)
- [Seznam úkolů](TODO.md)

Navržená technologie je Swift s AppKit. První cílová platforma je macOS 14 a novější na Apple Silicon; nejstarší podporovanou verzi je nutné před vydáním skutečně otestovat. Podpora Intel Maců zůstává otevřená.

## Stav ověření

K 9. 10. 2026 jsou ověřené zdroje k chování Notepadu a dostupnost vzdáleného Macu s macOS 15.7.4, Xcode 26.3 a Swift 6.2.4. Odpovídá také VNC služba. Přihlášení do VNC a ovládání GUI nebylo v této etapě testováno. Funkční shoda aplikace, sestavení ani její výkon zatím nejsou ověřené.

## Budoucí veřejné vydání

Repozitář obsahuje pouze projektové soubory. Přístupy, osobní poznámky, místní konfigurace, podpisové klíče, pracovní logy a snímky testovací plochy sem nepatří. Testovací soubory musí obsahovat pouze umělá data.

Veřejný hosting, konečný název, identifikátor aplikace a licence zatím nejsou zvolené. Samotné založení lokálního Gitu není zveřejnění projektu. Před veřejným vydáním je nutné vyřešit licenci, podpis a notarizaci podle [plánu](PLAN.md).
