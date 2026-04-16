import 'dart:io';
import 'package:keepsafe/models/file_item.dart';

class SFTPService {
  // Mock data stored locally for this phase
  final List<FileItem> _mockFiles = [
    FileItem(
      name: 'Documents',
      path: '/home/ubuntuserver/KeepsafeStorage/Documents',
      isDirectory: true,
      size: 0,
      lastModified: DateTime.now().subtract(const Duration(days: 2)),
    ),
    FileItem(
      name: 'Images',
      path: '/home/ubuntuserver/KeepsafeStorage/Images',
      isDirectory: true,
      size: 0,
      lastModified: DateTime.now().subtract(const Duration(days: 5)),
    ),
    FileItem(
      name: 'readme.txt',
      path: '/home/ubuntuserver/KeepsafeStorage/readme.txt',
      isDirectory: false,
      size: 1024,
      lastModified: DateTime.now().subtract(const Duration(hours: 10)),
    ),
  ];

  /// Connects to the SFTP server (MOCKED)
  Future<bool> connect({
    required String host,
    required int port,
    required String username,
    String? password,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return true; // Always succeeds in mock phase
  }

  /// Disconnects from the server (MOCKED)
  void disconnect() {}

  /// Returns a list of files in the given directory (MOCKED)
  Future<List<FileItem>> listFiles(String path) async {
    await Future.delayed(const Duration(seconds: 1));
    
    // Architect Amendment: Return mock list for root, empty list for subfolders
    if (path == '/home/ubuntuserver/KeepsafeStorage') {
      return List.from(_mockFiles);
    }
    
    // Always return an actual empty list [] for other paths in this mock phase
    return <FileItem>[];
  }

  /// Creates a new directory on the server (MOCKED)
  Future<bool> createDirectory(String remotePath) async {
    await Future.delayed(const Duration(seconds: 1));
    
    final name = remotePath.split('/').last;
    _mockFiles.add(FileItem(
      name: name,
      path: remotePath,
      isDirectory: true,
      size: 0,
      lastModified: DateTime.now(),
    ));
    
    return true;
  }

  /// Placeholder for upload (MOCKED)
  Future<bool> uploadFile(File localFile, String remotePath) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  /// Moves a file or directory (MOCKED)
  Future<bool> moveItem(String sourcePath, String destinationPath) async {
    await Future.delayed(const Duration(seconds: 1));
    
    final index = _mockFiles.indexWhere((item) => item.path == sourcePath);
    if (index != -1) {
      final oldItem = _mockFiles[index];
      final newName = oldItem.name;
      final newPath = destinationPath.endsWith('/') 
          ? '$destinationPath$newName' 
          : '$destinationPath/$newName';
          
      _mockFiles[index] = FileItem(
        name: newName,
        path: newPath,
        isDirectory: oldItem.isDirectory,
        size: oldItem.size,
        lastModified: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  bool get isConnected => true; // Always "connected" in mock phase
}
