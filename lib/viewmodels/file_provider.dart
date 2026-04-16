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

  // Move functionality
  FileItem? _itemToMove;
  FileItem? get itemToMove => _itemToMove;
  bool get isMovingItem => _itemToMove != null;

  void initiateMove(FileItem item) {
    _itemToMove = item;
    notifyListeners();
  }

  void cancelMove() {
    _itemToMove = null;
    notifyListeners();
  }

  Future<void> completeMove() async {
    if (_itemToMove == null) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _sftpService.moveItem(_itemToMove!.path, _currentPath);
      if (!success) {
        debugPrint('Failed to move item');
      }
    } catch (e) {
      debugPrint('Error moving item: $e');
    } finally {
      _itemToMove = null;
      await fetchFiles(); // This will set _isLoading to false and notify
    }
  }
}
