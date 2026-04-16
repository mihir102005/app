import 'package:flutter/material.dart';
import 'package:keepsafe/models/file_item.dart';
import 'package:keepsafe/services/sftp_service.dart';

class FileProvider extends ChangeNotifier {
  final SFTPService _sftpService = SFTPService();
  
  String _currentPath = '/home/ubuntuserver/KeepsafeStorage';
  List<FileItem> _files = [];
  bool _isLoading = false;

  String get currentPath => _currentPath;
  List<FileItem> get files => _files;
  bool get isLoading => _isLoading;

  FileProvider() {
    fetchFiles();
  }

  Future<void> fetchFiles() async {
    _isLoading = true;
    notifyListeners();

    try {
      _files = await _sftpService.listFiles(_currentPath);
    } catch (e) {
      debugPrint('Error fetching files: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> navigateToFolder(FileItem folder) async {
    if (!folder.isDirectory) return;
    _currentPath = folder.path;
    await fetchFiles();
  }

  Future<void> navigateUp() async {
    if (_currentPath == '/home/ubuntuserver/KeepsafeStorage') return;
    
    // Simple logic to go up one directory
    final parts = _currentPath.split('/');
    if (parts.length > 1) {
      parts.removeLast();
      _currentPath = parts.join('/');
      await fetchFiles();
    }
  }

  Future<void> createFolder(String name) async {
    _isLoading = true;
    notifyListeners();
    
    final newPath = '$_currentPath/$name';
    final success = await _sftpService.createDirectory(newPath);
    
    if (success) {
      await fetchFiles();
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  bool get isAtRoot => _currentPath == '/home/ubuntuserver/KeepsafeStorage';
}
