import Foundation
import MacPadCore

func fileErrorMessage(_ error: Error) -> String {
    if let error = error as? TextFileStoreError {
        switch error {
        case .conflict:
            return L("Soubor na disku se změnil. Uložte kopii, nebo znovu načtěte aktuální soubor. Vaše rozepsané změny zůstávají v kartě.",
                     "The file on disk has changed. Save a copy or reload the current file. Your edits remain in the tab.")
        case .conflictRecovered(let url):
            return L("Souběžná změna byla zachována zde: ", "A concurrent change was preserved here: ") + url.path
        case .unsupportedFile:
            return L("Vyberte běžný textový soubor.", "Choose a regular text file.")
        case .coordinationFailed:
            return L("K souboru nyní nelze bezpečně přistoupit. Zkuste to znovu.", "The file cannot be accessed safely right now. Try again.")
        }
    }
    if let error = error as? TextFileCodecError {
        switch error {
        case .unsupportedUTF32:
            return L("UTF-32 zatím není podporované. Soubor nebyl změněn; nejprve jej převeďte do UTF-8 nebo UTF-16.", "UTF-32 is not supported yet. The file was not changed; convert it to UTF-8 or UTF-16 first.")
        case .invalidData:
            return L("Obsah neodpovídá zvolenému kódování. Soubor nebyl změněn.", "The content does not match the chosen encoding. The file was not changed.")
        case .unrepresentableText:
            return L("Toto kódování neumí uložit některé znaky. Zvolte UTF-8 v nabídce Text.", "This encoding cannot represent some characters. Choose UTF-8 in the Text menu.")
        case .mixedLineEndings:
            return L("Před uložením vyberte konce řádků LF nebo CRLF.", "Choose LF or CRLF line endings before saving.")
        }
    }
    return error.localizedDescription
}
