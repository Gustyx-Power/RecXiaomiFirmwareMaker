enum ExtractionState {
  idle,
  extracting,
  processing,
  creating,
  completed,
  error;

  bool get isProcessing =>
      this == ExtractionState.extracting ||
          this == ExtractionState.processing ||
          this == ExtractionState.creating;

  String get message {
    switch (this) {
      case ExtractionState.idle:
        return 'Ready';
      case ExtractionState.extracting:
        return 'Extracting ROM...';
      case ExtractionState.processing:
        return 'Processing firmware...';
      case ExtractionState.creating:
        return 'Creating ZIP package...';
      case ExtractionState.completed:
        return 'Completed!';
      case ExtractionState.error:
        return 'Error occurred';
    }
  }
}
