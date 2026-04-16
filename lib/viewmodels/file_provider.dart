import 'package:flutter/material.dart';
import 'package:keepsafe/models/file_item.dart';
import 'package:keepsafe/services/sftp_service.dart';

class FileProvider extends ChangeNotifier {
  final SFTPService _sftpService = SFTPService();
  
  String _currentPath = '/';
  List<FileItem> _files = [];
  bool _isLoading = false;
  bool _isTransferring = false;
  String? _errorMessage;

  String get currentPath => _currentPath;
  List<FileItem> get files => _files;
  bool get isLoading => _isLoading;
  bool get isTransferring => _isTransferring;
  String? get errorMessage => _errorMessage;

  FileProvider() {
    Future.microtask(() => fetchFiles());
  }

  Future<void> fetchFiles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _files = await _sftpService.listFiles(_currentPath);
    } catch (e) {
      _errorMessage = e.toString();
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
    if (_currentPath == '/') return;
    
    // Simple logic to go up one directory
    final parts = _currentPath.split('/');
    if (parts.length > 1) {
      parts.removeLast();
      _currentPath = parts.join('/');
      if (_currentPath.isEmpty) _currentPath = '/';
      await fetchFiles();
    }
  }

  Future<void> createFolder(String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    final newPath = _currentPath == '/' ? '/$name' : '$_currentPath/$name';
    
    try {
      final success = await _sftpService.createDirectory(newPath);
      if (success) {
        await fetchFiles();
      } else {
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  bool get isAtRoot => _currentPath == '/';

  // Move functionality
  FileItem? _itemToMove;
  String? _sourceDirectory;
  
  FileItem? get itemToMove => _itemToMove;
  String? get sourceDirectory => _sourceDirectory;
  bool get isMovingItem => _itemToMove != null;

  void initiateMove(FileItem item) {
    _itemToMove = item;
    _sourceDirectory = _currentPath;
    notifyListeners();
  }

  void cancelMove() {
    _itemToMove = null;
    _sourceDirectory = null;
    notifyListeners();
  }

  Future<void> completeMove() async {
    if (_itemToMove == null) return;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _sftpService.moveItem(_itemToMove!.path, _currentPath);
      if (!success) {
        _errorMessage = 'Failed to move item';
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error moving item: $e');
    } finally {
      _itemToMove = null;
      _sourceDirectory = null;
      await fetchFiles(); // This will set _isLoading to false and notify
    }
  }

  /// Picks a local file and uploads it to the current directory
  Future<void> pickAndUploadFile() async {
    if (_isTransferring) return;
    
    _isTransferring = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _sftpService.pickAndUpload(_currentPath);
      if (success) {
        await fetchFiles();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isTransferring = false;
      notifyListeners();
    }
  }

  /// Downloads a remote file to the local device
  Future<void> downloadFile(FileItem file) async {
    if (_isTransferring) return;

    _isTransferring = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final localPath = await _sftpService.downloadToDevice(file.path, file.name);
      if (localPath != null) {
        _errorMessage = 'SUCCESS: Downloaded to $localPath';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isTransferring = false;
      notifyListeners();
    }
  }

  /// Clear error message after displaying it
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
