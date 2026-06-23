# Notatki

Aplikacja na Androida do tworzenia notatek z przypomnieniami.

## Funkcje
- Tworzenie, edycja i usuwanie notatek
- Przypomnienia z wyborem dnia, roku i godziny
- Rodzaj przypomnienia do wyboru w ustawieniach (dźwięk / ciche / pełnoekranowy alarm)
- Responsywny układ — od tanich ekranów HD po wyświetlacze 2K+
- Tryb jasny i ciemny (zgodnie z systemem)
- Dane trzymane lokalnie na telefonie

## Jak zbudować plik APK (bez instalowania niczego)

1. Załóż darmowe konto na https://github.com
2. Utwórz nowe repozytorium (przycisk **New**), nazwij je np. `notatki`,
   ustaw jako **Private** jeśli chcesz, i kliknij **Create repository**.
3. Wgraj wszystkie pliki z tego folderu:
   - Na stronie repozytorium kliknij **Add file → Upload files**
   - Przeciągnij całą zawartość folderu (uwaga: również ukryty folder `.github`)
   - Kliknij **Commit changes**
4. Przejdź do zakładki **Actions** — budowanie ruszy automatycznie.
   Poczekaj kilka minut, aż pojawi się zielony znacznik.
5. Wejdź w zakończony przebieg, na dole w sekcji **Artifacts**
   pobierz **notatki-apk**. W środku jest plik `app-release.apk`.
6. Przerzuć APK na telefon i zainstaluj
   (włącz „Instalacja z nieznanych źródeł", gdy telefon o to poprosi).

## Uwagi
- APK jest podpisany kluczem testowym — nadaje się do własnego użytku,
  ale nie do publikacji w Google Play.
- Przy pierwszym uruchomieniu aplikacja poprosi o zgodę na powiadomienia.
  Dla pełnoekranowego alarmu może być potrzebna zgoda na „dokładne alarmy"
  w ustawieniach systemowych telefonu.
