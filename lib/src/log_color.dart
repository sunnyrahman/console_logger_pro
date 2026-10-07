/// Standard ANSI color representation used to paint console text.
///
/// Designed to work reliably across VS Code Debug Console, Android Studio,
/// iOS / macOS terminals, Linux, and Windows terminals.
class LogColor {
  /// Creates a color using a standard ANSI code string (e.g. `'36'` for cyan).
  const LogColor(this.code);

  /// Creates a color from an ANSI 256-color code (0-255).
  const LogColor.ansi256(int colorCode) : code = '38;5;$colorCode';

  /// Raw ANSI escape sequence code (without the `\x1B[` prefix or `m` suffix).
  final String code;

  // Standard ANSI colors (universal support in VS Code Debug Console & IDEs)
  static const LogColor cyan = LogColor('36');
  static const LogColor brightCyan = LogColor('96');
  static const LogColor green = LogColor('32');
  static const LogColor brightGreen = LogColor('92');
  static const LogColor red = LogColor('31');
  static const LogColor brightRed = LogColor('91');
  static const LogColor gold = LogColor('93'); // Bright Yellow / Golden
  static const LogColor yellow = LogColor('33');
  static const LogColor blue = LogColor('34');
  static const LogColor brightBlue = LogColor('94');
  static const LogColor magenta = LogColor('35');
  static const LogColor pink = LogColor('95'); // Bright Magenta / Pink
  static const LogColor purple = LogColor('35');
  static const LogColor gray = LogColor('90'); // Subtle Gray for borders
  static const LogColor silver = LogColor('37');
  static const LogColor white = LogColor('97'); // Crisp White

  /// Wraps [text] with ANSI escape codes and restores color with reset `\x1B[0m`.
  String paint(String text, {bool bold = false, bool underline = false}) {
    if (text.isEmpty) return text;
    final styles = StringBuffer('\x1B[');
    if (bold) styles.write('1;');
    if (underline) styles.write('4;');
    styles.write('${code}m');
    styles.write(text);
    styles.write('\x1B[0m');
    return styles.toString();
  }

  @override
  bool operator ==(Object other) => other is LogColor && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'LogColor($code)';
}
