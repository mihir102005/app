class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime lastModified;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.lastModified,
  });

  String get extension => name.contains('.') ? name.split('.').last : '';
}
