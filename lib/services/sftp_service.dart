import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:yaml/yaml.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:keepsafe/models/file_item.dart';

class SFTPService {
  SSHClient? _client;
  SftpClient? _sftp;
  String? _remoteBasePath;
  String? _username;
  String? _host;
  int? _port;
  String? _keyPath;

  bool _isConfigLoaded = false;

  /// Loads configuration from config.yaml in assets
  Future<void> _loadConfig() async {
    if (_isConfigLoaded) return;
    try {
      // Architect Amendment: Strictly use rootBundle for asset loading
      final yamlString = await rootBundle.loadString('assets/config.yaml');
      final config = loadYaml(yamlString);
      
      _host = config['server_ip'];
      _port = config['ssh_port'];
      _username = config['ssh_username'];
      _remoteBasePath = config['remote_base_path'];
      _keyPath = config['key_path'];
      
      _isConfigLoaded = true;
    } catch (e) {
      throw Exception('Failed to load configuration from rootBundle: $e');
    }
  }

  /// Ensures that the SFTP client is connected (Lazy Connection)
  Future<void> _ensureConnected() async {
    await _loadConfig();
    
    if (_client != null && !_client!.isClosed && _sftp != null) {
      return;
    }

    try {
      // Architect Amendment: Strictly use rootBundle for key loading
      final keyString = await rootBundle.loadString(_keyPath ?? 'assets/keepsafe_app_key');
      final keyPairs = SSHKeyPair.fromPem(keyString);
      
      if (keyPairs.isEmpty) {
        throw Exception('No private keys found in assets/keepsafe_app_key');
      }
      
      final socket = await SSHSocket.connect(_host!, _port!);
      _client = SSHClient(
        socket,
        username: _username!,
        identities: keyPairs,
        printDebug: (s) => print(s),
      );

      _sftp = await _client!.sftp();
    } catch (e) {
      _client = null;
      _sftp = null;
      throw Exception('Failed to connect to SFTP server: $e');
    }
  }

  /// Sanitizes and jails the path to the remote base path
  String _safePath(String relativePath) {
    // Prevent directory traversal
    if (relativePath.contains('..')) {
      throw Exception('Security violation: Directory traversal attempt detected.');
    }

    final base = _remoteBasePath ?? '';
    // Normalize path separators
    final joined = relativePath.isEmpty || relativePath == '/' 
        ? base 
        : (base.endsWith('/') ? '$base${relativePath.startsWith('/') ? relativePath.substring(1) : relativePath}' : '$base/${relativePath.startsWith('/') ? relativePath.substring(1) : relativePath}');
    
    return joined;
  }

  /// Returns a list of files in the given directory
  Future<List<FileItem>> listFiles(String path) async {
    await _ensureConnected();
    final remotePath = _safePath(path);
    
    try {
      final items = await _sftp!.listdir(remotePath);
      
      return items.where((item) => item.filename != '.' && item.filename != '..').map((item) {
        return FileItem(
          name: item.filename,
          path: path == '/' ? '/${item.filename}' : '$path/${item.filename}',
          isDirectory: item.attr.isDirectory ?? item.longname.startsWith('d'),
          size: item.attr.size ?? 0,
          lastModified: DateTime.fromMillisecondsSinceEpoch((item.attr.modifyTime ?? 0) * 1000),
        );
      }).toList();
    } catch (e) {
      throw Exception('Error listing files in $path: $e');
    }
  }

  /// Creates a new directory on the server
  Future<bool> createDirectory(String relativePath) async {
    await _ensureConnected();
    final remotePath = _safePath(relativePath);
    
    try {
      await _sftp!.mkdir(remotePath);
      return true;
    } catch (e) {
      throw Exception('Error creating directory: $e');
    }
  }

  /// Picks a file from the device and uploads it to the current remote path
  Future<bool> pickAndUpload(String relativeRemotePath) async {
    await _ensureConnected();
    
    try {
      final result = await FilePicker.pickFiles();
      if (result == null || result.files.isEmpty) return false;

      final platformFile = result.files.first;
      final localPath = platformFile.path;
      if (localPath == null) return false;

      final localFile = File(localPath);
      final remoteFileName = platformFile.name;
      final remotePath = _safePath(relativeRemotePath.endsWith('/') 
          ? '$relativeRemotePath$remoteFileName' 
          : '$relativeRemotePath/$remoteFileName');
      
      final remoteFile = await _sftp!.open(
        remotePath, 
        mode: SftpFileOpenMode.write | SftpFileOpenMode.create | SftpFileOpenMode.truncate
      );
      
      final stream = localFile.openRead().map((data) => Uint8List.fromList(data));
      await remoteFile.write(stream);
      await remoteFile.close();
      return true;
    } catch (e) {
      throw Exception('Error picking and uploading file: $e');
    }
  }

  /// Downloads a remote file to a temporary location, then exports it to the public Downloads folder via a native dialog
  Future<String?> downloadToDevice(String remoteRelativePath, String fileName) async {
    await _ensureConnected();
    final remotePath = _safePath(remoteRelativePath);
    
    try {
      // Step A: Download to temporary directory first
      final directory = await getTemporaryDirectory();
      final tempFile = File('${directory.path}/$fileName');
      
      final sink = tempFile.openWrite();
      await _sftp!.download(remotePath, sink);
      await sink.close();

      // Step B: Trigger native "Save As" dialog to export to public filesystem
      final params = SaveFileDialogParams(
        sourceFilePath: tempFile.path,
        fileName: fileName,
      );
      
      final finalPath = await FlutterFileDialog.saveFile(params: params);
      
      // Cleanup temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      return finalPath;
    } catch (e) {
      throw Exception('Error downloading and exporting file: $e');
    }
  }

  /// Moves a file or directory
  Future<bool> moveItem(String sourceRelative, String destinationRelative) async {
    await _ensureConnected();
    final sourcePath = _safePath(sourceRelative);
    final destinationPath = _safePath(destinationRelative);
    
    try {
      // In SFTP rename, the second argument is the full target path including the new filename
      final fileName = sourceRelative.split('/').last;
      final fullDestPath = destinationPath.endsWith('/') ? '$destinationPath$fileName' : '$destinationPath/$fileName';
      
      await _sftp!.rename(sourcePath, fullDestPath);
      return true;
    } catch (e) {
      throw Exception('Error moving item: $e');
    }
  }

  void disconnect() {
    _client?.close();
    _client = null;
    _sftp = null;
  }

  bool get isConnected => _client != null && !_client!.isClosed;
}
