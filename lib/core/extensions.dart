import 'dart:math';

extension StringExtension on String {
  String toProperCase() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  bool isValidZip() {
    return endsWith('.zip');
  }
}

extension FileSizeExtension on int {
  String toFileSize() {
    if (this <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (log(this) / log(1024)).floor();
    if (i >= suffixes.length) i = suffixes.length - 1;
    return '${(this / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }
}
