import 'package:flutter/material.dart';

// Paleta kolorow notatek. Indeks 0 = domyslny (bez koloru).
// Kolory dobrane tak, by czytelnie wygladaly w trybie jasnym i ciemnym.
class NoteColors {
  static const List<Color?> light = [
    null, // 0 - domyslny (kolor karty z motywu)
    Color(0xFFFFCDD2), // czerwony
    Color(0xFFFFE0B2), // pomaranczowy
    Color(0xFFFFF9C4), // zolty
    Color(0xFFC8E6C9), // zielony
    Color(0xFFB3E5FC), // niebieski
    Color(0xFFD1C4E9), // fioletowy
    Color(0xFFF8BBD0), // rozowy
  ];

  static const List<Color?> dark = [
    null,
    Color(0xFF5D3A3A),
    Color(0xFF5D4A2E),
    Color(0xFF5A552E),
    Color(0xFF36503A),
    Color(0xFF2E4A5A),
    Color(0xFF433A5D),
    Color(0xFF5A3A4A),
  ];

  static const List<String> names = [
    'Domyslny',
    'Czerwony',
    'Pomaranczowy',
    'Zolty',
    'Zielony',
    'Niebieski',
    'Fioletowy',
    'Rozowy',
  ];

  static Color? colorFor(int index, Brightness brightness) {
    if (index < 0 || index >= light.length) return null;
    return brightness == Brightness.dark ? dark[index] : light[index];
  }

  static int get count => light.length;
}
